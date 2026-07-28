import 'dart:async';
import 'dart:convert';

import 'package:foundation/foundation.dart';
import 'package:home/src/data/dtos/item_dto.dart';
import 'package:home/src/domain/entities/item.dart';
import 'package:home/src/domain/repositories/item_repository.dart';
import 'package:networking/networking.dart';
import 'package:persistence/persistence.dart';

/// [ItemRepository] 的 HTTP + 本地快取實作。
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

  final ApiClient _client;
  final KeyValueStore _store;
  final StreamController<List<Item>> _controller = StreamController.broadcast();

  List<Item>? _cached;

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

  @override
  Future<Result<void>> refreshItems() async {
    final result = await _client.get<List<Item>>(
      '/items',
      parse: (data) {
        final items = (data as Map<String, dynamic>)['items'] as List<dynamic>;
        return items
            .map((e) => ItemDto.fromJson(e as Map<String, dynamic>).toEntity())
            .toList();
      },
    );
    return result.fold(
      onSuccess: (items) async {
        _cached = items;
        // 寫入快取失敗不算整體失敗:記憶體快取已更新、也已廣播,
        // 使用者看得到資料,下次啟動再抓一次即可。
        try {
          await _store.writeString(
            cacheKey,
            jsonEncode(
              items.map((e) => ItemDto.fromEntity(e).toJson()).toList(),
            ),
          );
        } on StorageException {
          // 刻意吞掉,理由見上。
        }
        _controller.add(items);
        return const Result<void>.success(null);
      },
      onFailure: (exception) async {
        // 不動 _cached、不廣播:斷網不該清空畫面。
        return Result<void>.failure(exception);
      },
    );
  }

  @override
  Future<Result<Item>> fetchItem(String id) => _client.get<Item>(
    '/items/$id',
    parse: (data) => ItemDto.fromJson(data as Map<String, dynamic>).toEntity(),
  );

  @override
  void dispose() => unawaited(_controller.close());
}
