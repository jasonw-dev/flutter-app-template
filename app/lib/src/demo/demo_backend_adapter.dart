import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 假後端:demo API 契約的記憶體實作,接上真後端前供開發與 e2e 測試使用。
///
/// 契約(app pubspec 的 Global Constraints):
/// - `POST /auth/login` `{email,password}` → 200 `{accessToken,refreshToken}`;
///   `password == 'wrong'` → 401
///   `{code:'AUTH_INVALID', message:'Invalid credentials'}`。
/// - `POST /auth/refresh` `{refreshToken}` → 200 新 tokens;
///   `refreshToken == 'expired'` → 401。
/// - `GET /items` → 200 `{items:[...5 筆...]}`。
/// - `GET /items/<id>` → 200 單品;不存在 → 404 `{code:'NOT_FOUND', message:''}`。
/// - 未知路徑一律 404;不驗證 `Authorization` header(假後端不做授權檢查)。
///
/// **`baseUrl` 路徑前綴陷阱**:上述路徑比對(`path == '/items'`、
/// `path.startsWith('/items/')` 等)是對 `options.uri.path` 的**精確字串**
/// 比對,不做尾段/後綴匹配。若 `AppConfig.apiBaseUrl`(見
/// `app/lib/src/config/app_config.dart`)帶有路徑片段(如
/// `https://api.example.com/v1`),dio 組出的實際請求路徑會變成
/// `/v1/items`,不再等於這裡寫死的 `/items`,所有分支都會落到未知路徑的
/// 404,且不會有任何錯誤訊息提示——排查時容易誤以為是後端契約或
/// `ItemDto` 解析出錯。**`apiBaseUrl` 搭配假後端使用時務必只放
/// scheme+host(不帶路徑),** 或改寫本檔的路徑比對邏輯以支援前綴。
class DemoBackendAdapter implements HttpClientAdapter {
  /// 建立假後端 adapter;[latency] 模擬每個請求的網路延遲。
  DemoBackendAdapter({this.latency = const Duration(milliseconds: 300)});

  /// 每個請求前的模擬延遲。
  final Duration latency;

  // 刻意不是 limit 的整數倍:最後一頁會是不滿的,能驗到邊界。
  static final List<Map<String, String>> _items = List.generate(
    37,
    (i) => {
      'id': '${i + 1}',
      'title': 'Demo item ${i + 1}',
      'description': 'Description for demo item ${i + 1}.',
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(latency);

    final path = options.uri.path;
    final method = options.method.toUpperCase();

    if (method == 'POST' && path == '/auth/login') {
      final body = options.data as Map<String, dynamic>? ?? const {};
      if (body['password'] == 'wrong') {
        return _json(401, {
          'code': 'AUTH_INVALID',
          'message': 'Invalid credentials',
        });
      }
      return _json(200, {
        'accessToken': 'demo-access-1',
        'refreshToken': 'demo-refresh-1',
      });
    }

    if (method == 'POST' && path == '/auth/refresh') {
      final body = options.data as Map<String, dynamic>? ?? const {};
      if (body['refreshToken'] == 'expired') {
        return _json(401, {
          'code': 'AUTH_INVALID',
          'message': 'Invalid refresh token',
        });
      }
      return _json(200, {
        'accessToken': 'demo-access-1',
        'refreshToken': 'demo-refresh-1',
      });
    }

    if (method == 'GET' && path == '/items') {
      // cursor 分頁:cursor 是「上一頁最後一筆的 id」,不帶就從頭開始。
      final query = options.uri.queryParameters;
      final limit = int.tryParse(query['limit'] ?? '') ?? 20;
      final cursor = query['cursor'];
      var start = 0;
      if (cursor != null) {
        final index = _items.indexWhere((e) => e['id'] == cursor);
        start = index < 0 ? _items.length : index + 1;
      }
      final end = (start + limit).clamp(0, _items.length);
      final page = _items.sublist(start.clamp(0, _items.length), end);
      final nextCursor = end < _items.length ? page.last['id'] : null;
      return _json(200, {'items': page, 'nextCursor': nextCursor});
    }

    if (method == 'GET' && path.startsWith('/items/')) {
      final id = path.substring('/items/'.length);
      final matches = _items.where((e) => e['id'] == id);
      if (matches.isEmpty) {
        return _json(404, {'code': 'NOT_FOUND', 'message': ''});
      }
      return _json(200, matches.first);
    }

    return _json(404, {'code': 'NOT_FOUND', 'message': ''});
  }

  ResponseBody _json(int statusCode, Object body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
