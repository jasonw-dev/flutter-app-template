/// 型別化路由的共同契約:能把自己轉成 go_router 可用的 location 字串。
///
/// 契約刻意只有單一成員,實作為各路由類別。
abstract interface class AppRoute {
  /// 完整 location(路徑 + 已編碼 query)。
  String get location;
}

/// 組合路徑與 query(自動 URL 編碼)。
String buildLocation(String path, {Map<String, String> query = const {}}) {
  if (query.isEmpty) {
    return path;
  }
  return Uri(path: path, queryParameters: query).toString();
}
