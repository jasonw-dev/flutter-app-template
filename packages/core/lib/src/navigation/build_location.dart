/// 組合路徑與 query(自動 URL 編碼)。
///
/// 跨 feature 導航用 `RoutePaths` 的路徑常數;需要帶參數時自己組。
String buildLocation(String path, {Map<String, String> query = const {}}) {
  if (query.isEmpty) {
    return path;
  }
  return Uri(path: path, queryParameters: query).toString();
}
