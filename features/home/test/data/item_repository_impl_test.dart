import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/src/data/repositories/item_repository_impl.dart';
import 'package:home/src/domain/entities/item.dart';

const _config = NetworkingConfig(baseUrl: 'https://api.test');

const _itemsJson = '''
{"items":[
  {"id":"1","title":"t1","description":"d1"},
  {"id":"2","title":"t2","description":"d2"}
],"nextCursor":null}
''';

/// 第一頁,還有下一頁。
const _page1Json = '''
{"items":[{"id":"1","title":"t1","description":"d1"}],"nextCursor":"1"}
''';

/// 第二頁,還有下一頁。
const _page2Json = '''
{"items":[{"id":"2","title":"t2","description":"d2"}],"nextCursor":"2"}
''';

/// 第三頁,已是最後一頁。
const _page3Json = '''
{"items":[{"id":"3","title":"t3","description":"d3"}],"nextCursor":null}
''';

const _updatedJson = '''
{"items":[
  {"id":"9","title":"t9","description":"d9"}
],"nextCursor":null}
''';

ItemRepositoryImpl _repository(ScriptedAdapter adapter, KeyValueStore store) =>
    ItemRepositoryImpl(
      client: ApiClient(createPlainDio(config: _config, adapter: adapter)),
      store: store,
    );

void main() {
  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  test('沒有快取時 watchItems() 第一個事件是空清單', () async {
    final repository = _repository(ScriptedAdapter([]), store);
    addTearDown(repository.dispose);

    await expectLater(repository.watchItems().first, completion(isEmpty));
  });

  test('refreshItems() 成功後訂閱者收到新清單,且已寫入 store', () async {
    final repository = _repository(
      ScriptedAdapter([(_) => jsonResponse(200, _itemsJson)]),
      store,
    );
    addTearDown(repository.dispose);

    final events = <List<Item>>[];
    final sub = repository.watchItems().listen(events.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);

    final result = await repository.refreshItems();
    // broadcast 的投遞是非同步的,要讓出一個迴合才收得到。
    await Future<void>.delayed(Duration.zero);

    expect(result, isA<Success<void>>());
    expect(events.last.map((e) => e.id), ['1', '2']);
    final raw = await store.readString(ItemRepositoryImpl.cacheKey);
    expect(raw, isNotNull);
    expect((jsonDecode(raw!) as List<dynamic>).length, 2);
  });

  test('離線可看:新 repository 實例讀到前一次寫入的快取', () async {
    final first = _repository(
      ScriptedAdapter([(_) => jsonResponse(200, _itemsJson)]),
      store,
    );
    await first.refreshItems();
    first.dispose();

    // 同一個 store、全新的 repository,且腳本為空(不會有任何網路回應)。
    final second = _repository(ScriptedAdapter([]), store);
    addTearDown(second.dispose);

    final firstEvent = await second.watchItems().first;
    expect(firstEvent.map((e) => e.id), ['1', '2']);
  });

  test('refreshItems() 失敗時:回 Failure、不廣播、快取不變', () async {
    final seeded = _repository(
      ScriptedAdapter([(_) => jsonResponse(200, _itemsJson)]),
      store,
    );
    await seeded.refreshItems();
    seeded.dispose();
    final before = await store.readString(ItemRepositoryImpl.cacheKey);

    final repository = _repository(
      ScriptedAdapter([(_) => jsonResponse(500, '{}')]),
      store,
    );
    addTearDown(repository.dispose);
    final events = <List<Item>>[];
    final sub = repository.watchItems().listen(events.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);
    final countBeforeRefresh = events.length;

    final result = await repository.refreshItems();

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).exception, isA<ServerException>());
    expect(events.length, countBeforeRefresh, reason: '失敗不得廣播');
    expect(await store.readString(ItemRepositoryImpl.cacheKey), before);
  });

  test('快取內容壞掉時 watchItems() 回空清單而不是丟例外', () async {
    await store.writeString(ItemRepositoryImpl.cacheKey, 'not json at all');
    final repository = _repository(ScriptedAdapter([]), store);
    addTearDown(repository.dispose);

    await expectLater(repository.watchItems().first, completion(isEmpty));
  });

  test('競速回歸:訂閱後立刻 refresh,最終收到的是遠端新資料', () async {
    // 先讓 store 有一份舊快取。
    await store.writeString(
      ItemRepositoryImpl.cacheKey,
      jsonEncode([
        {'id': 'old', 'title': 'old', 'description': 'old'},
      ]),
    );
    final repository = _repository(
      ScriptedAdapter([(_) => jsonResponse(200, _updatedJson)]),
      store,
    );
    addTearDown(repository.dispose);

    final events = <List<Item>>[];
    // 關鍵:**不** await 第一個事件就直接 refresh。先 await 再 refresh
    // 就驗不到 race,請勿「順手」改成先 await。
    final sub = repository.watchItems().listen(events.add);
    addTearDown(sub.cancel);
    await repository.refreshItems();
    await Future<void>.delayed(Duration.zero);

    expect(events.last.map((e) => e.id), ['9'], reason: '新資料不得被舊快取覆寫');
    expect(
      events.any((e) => e.length == 1 && e.first.id == '9'),
      isTrue,
      reason: 'refresh 的廣播事件不得遺失',
    );
  });

  test('dispose() 後既有訂閱者收到 done,不丟例外', () async {
    final repository = _repository(ScriptedAdapter([]), store);
    var done = false;
    final sub = repository.watchItems().listen(null, onDone: () => done = true);
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);

    repository.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(done, isTrue);
  });

  group('fetchItem', () {
    test('成功時回傳 Success(Item) 並打對路徑', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, '{"id":"7","title":"t7","description":"d7"}'),
      ]);
      final repository = _repository(adapter, store);
      addTearDown(repository.dispose);

      final result = await repository.fetchItem('7');

      expect(result, isA<Success<Item>>());
      expect((result as Success<Item>).value.title, 't7');
      expect(adapter.seen.single.path, '/items/7');
    });

    test('欄位缺漏時回傳 Failure(ParsingException)', () async {
      final repository = _repository(
        ScriptedAdapter([(_) => jsonResponse(200, '{"id":"7"}')]),
        store,
      );
      addTearDown(repository.dispose);

      final result = await repository.fetchItem('7');

      expect(result, isA<Failure<Item>>());
      expect((result as Failure<Item>).exception, isA<ParsingException>());
    });
  });

  group('cursor 分頁', () {
    test('loadMore() 把第二頁附加在第一頁後面', () async {
      final repository = _repository(
        ScriptedAdapter([
          (_) => jsonResponse(200, _page1Json),
          (_) => jsonResponse(200, _page2Json),
        ]),
        store,
      );
      addTearDown(repository.dispose);
      final events = <List<Item>>[];
      final sub = repository.watchItems().listen(events.add);
      addTearDown(sub.cancel);

      await repository.refreshItems();
      await repository.loadMore();
      await Future<void>.delayed(Duration.zero);

      expect(events.last.map((e) => e.id), ['1', '2']);
      expect(repository.hasMore, isTrue);
    });

    test('最後一頁之後 hasMore 為 false,再 loadMore 不發請求也不報錯', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, _page3Json),
      ]);
      final repository = _repository(adapter, store);
      addTearDown(repository.dispose);

      await repository.refreshItems();
      expect(repository.hasMore, isFalse);

      final result = await repository.loadMore();

      expect(result, isA<Success<void>>());
      expect(adapter.seen.length, 1, reason: '不得再發請求');
    });

    test('refreshItems() 在載入三頁之後呼叫 → 清單回到只有第一頁', () async {
      final repository = _repository(
        ScriptedAdapter([
          (_) => jsonResponse(200, _page1Json),
          (_) => jsonResponse(200, _page2Json),
          (_) => jsonResponse(200, _page3Json),
          (_) => jsonResponse(200, _page1Json),
        ]),
        store,
      );
      addTearDown(repository.dispose);
      final events = <List<Item>>[];
      final sub = repository.watchItems().listen(events.add);
      addTearDown(sub.cancel);

      await repository.refreshItems();
      await repository.loadMore();
      await repository.loadMore();
      await Future<void>.delayed(Duration.zero);
      expect(events.last.length, 3);

      await repository.refreshItems();
      await Future<void>.delayed(Duration.zero);

      expect(events.last.map((e) => e.id), ['1']);
      expect(repository.hasMore, isTrue, reason: '游標一併重設');
    });

    test('防重入:連續兩次 loadMore 只打一次遠端,清單不重複', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, _page1Json),
        (_) => jsonResponse(200, _page2Json),
      ]);
      final repository = _repository(adapter, store);
      addTearDown(repository.dispose);
      final events = <List<Item>>[];
      final sub = repository.watchItems().listen(events.add);
      addTearDown(sub.cancel);
      await repository.refreshItems();

      // 不 await 第一次就發第二次——這正是快速捲動時的情況。
      final first = repository.loadMore();
      final second = repository.loadMore();
      await Future.wait([first, second]);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.seen.length, 2, reason: 'refresh 1 次 + loadMore 1 次');
      expect(events.last.map((e) => e.id), ['1', '2'], reason: '不得有重複項目');
    });

    test('只有第一頁進快取:載入三頁後,新實例只讀到第一頁', () async {
      final seeded = _repository(
        ScriptedAdapter([
          (_) => jsonResponse(200, _page1Json),
          (_) => jsonResponse(200, _page2Json),
          (_) => jsonResponse(200, _page3Json),
        ]),
        store,
      );
      await seeded.refreshItems();
      await seeded.loadMore();
      await seeded.loadMore();
      seeded.dispose();

      final fresh = _repository(ScriptedAdapter([]), store);
      addTearDown(fresh.dispose);

      final firstEvent = await fresh.watchItems().first;
      expect(firstEvent.map((e) => e.id), ['1']);
    });
  });
}
