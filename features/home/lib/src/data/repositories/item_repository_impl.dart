import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:home/src/data/dtos/item_dto.dart';
import 'package:home/src/domain/entities/item.dart';
import 'package:home/src/domain/entities/paged_items.dart';
import 'package:home/src/domain/repositories/item_repository.dart';

/// [ItemRepository] 的 HTTP + 本地快取 + cursor 分頁實作。
///
/// 這是要讓後續所有 feature 抄的參考實作,寫清楚比寫巧妙重要。
class ItemRepositoryImpl implements ItemRepository {
  /// 以 [client] 與 [store] 建立。
  ItemRepositoryImpl({required ApiClient client, required KeyValueStore store})
    : _client = client,
      _store = store;

  /// 快取 key。
  ///
  /// 結尾的 `v1` 是刻意的:[ItemDto] 欄位改動時把它升成 `v2`,舊快取自然
  /// 失效,不會 decode 失敗後靜默清空。
  static const cacheKey = 'home.items.v1.cache';

  /// 每頁筆數。
  static const pageSize = 20;

  final ApiClient _client;
  final KeyValueStore _store;
  final StreamController<List<Item>> _controller = StreamController.broadcast();

  List<Item>? _cached;
  String? _nextCursor;
  var _reachedEnd = false;
  Future<Result<void>>? _inflightLoadMore;

  @override
  bool get hasMore => !_reachedEnd;

  @override
  Stream<List<Item>> watchItems() => Stream.multi((controller) async {
    // 先接上廣播,再讀快取。順序反過來的話,讀快取的 await 期間
    // 若 refreshItems() 完成,那個事件會因為還沒訂閱而永久遺失。
    final sub = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      // onDone 不可省略:少了它,dispose() 關閉 _controller 之後,
      // Stream.multi 建出的這條外層 stream 永遠不會結束,訂閱者收不到
      // done,bloc 的 emit.forEach 也就永遠掛著。
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
    final loaded = await _loadCacheOnce();
    if (!controller.isClosed) {
      controller.add(loaded);
    }
  });

  Future<List<Item>> _loadCacheOnce() async {
    final existing = _cached;
    if (existing != null) {
      return existing;
    }
    final loaded = await _readCache();
    // 注意 `??=` 在 await **之後**才判斷:若 refresh 在讀檔期間搶先寫入
    // `_cached`,這裡會保留 refresh 的新資料,不會被舊快取覆寫。
    return _cached ??= loaded;
  }

  Future<List<Item>> _readCache() async {
    // data 層唯一允許 try/catch 的情境:快取壞掉不能讓 App 開不起來,
    // 任何例外都退回空清單,由後續 refresh 補上。
    try {
      final raw = await _store.readString(cacheKey);
      if (raw == null) {
        return const [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ItemDto.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<Result<PagedItems>> _fetchPage({String? cursor}) =>
      _client.get<PagedItems>(
        '/items',
        queryParameters: {'limit': '$pageSize', 'cursor': ?cursor},
        parse: (data) {
          final map = data as Map<String, dynamic>;
          final items = (map['items'] as List<dynamic>)
              .map(
                (e) => ItemDto.fromJson(e as Map<String, dynamic>).toEntity(),
              )
              .toList();
          return PagedItems(
            items: items,
            nextCursor: map['nextCursor'] as String?,
          );
        },
      );

  @override
  Future<Result<void>> refreshItems() async {
    final result = await _fetchPage();
    return result.fold(
      onSuccess: (page) async {
        // 語意是「回到第一頁」:後續頁面全部丟掉,游標重設。
        _cached = page.items;
        _nextCursor = page.nextCursor;
        _reachedEnd = page.nextCursor == null;
        // **只有第一頁寫進本地快取。** 離線時看得到第一頁就夠了;把幾百筆
        // 全存進 KeyValueStore 會讓啟動時的 JSON decode 變慢,那是該換 DB
        // 的訊號,而不是把 key-value 撐大。
        await _writeCache(page.items);
        _controller.add(page.items);
        return const Result<void>.success(null);
      },
      onFailure: (exception) async {
        // 不動 _cached、不廣播:斷網不該清空畫面。
        return Result<void>.failure(exception);
      },
    );
  }

  @override
  Future<Result<void>> loadMore() {
    if (_reachedEnd) {
      return Future.value(const Result<void>.success(null));
    }
    // 防重入:使用者快速捲動會連續觸發,不擋的話會同時發出多個同 cursor
    // 的請求,清單出現重複項目。做法比照 SessionManager.refreshTokens()。
    return _inflightLoadMore ??= _loadMore().whenComplete(() {
      _inflightLoadMore = null;
    });
  }

  Future<Result<void>> _loadMore() async {
    final result = await _fetchPage(cursor: _nextCursor);
    return result.fold(
      onSuccess: (page) async {
        _cached = [...?_cached, ...page.items];
        _nextCursor = page.nextCursor;
        _reachedEnd = page.nextCursor == null;
        // 刻意不寫快取,理由見 refreshItems()。
        _controller.add(_cached!);
        return const Result<void>.success(null);
      },
      onFailure: (exception) async => Result<void>.failure(exception),
    );
  }

  Future<void> _writeCache(List<Item> items) async {
    // 寫入快取失敗不算整體失敗:記憶體快取已更新、也會廣播,使用者看得到
    // 資料,下次啟動再抓一次即可。
    try {
      await _store.writeString(
        cacheKey,
        jsonEncode(items.map((e) => ItemDto.fromEntity(e).toJson()).toList()),
      );
    } on StorageException {
      // 刻意吞掉,理由見上。
    }
  }

  @override
  Future<Result<Item>> fetchItem(String id) => _client.get<Item>(
    '/items/$id',
    parse: (data) => ItemDto.fromJson(data as Map<String, dynamic>).toEntity(),
  );

  @override
  void dispose() => unawaited(_controller.close());
}
