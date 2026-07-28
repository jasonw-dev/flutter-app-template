/// 應用程式日誌層級定義。
enum LogLevel {
  /// Debug 層級。
  debug,

  /// Info 層級。
  info,

  /// Warning 層級。
  warning,

  /// Error 層級。
  error,
}

/// 全專案的 log 介面。正式實作在 observability package
/// (console + crash 上報),foundation 只定義契約。
abstract interface class AppLogger {
  /// 記錄 debug 等級訊息。
  void debug(String message);

  /// 記錄 info 等級訊息。
  void info(String message);

  /// 記錄 warning 等級訊息。
  void warning(String message);

  /// 記錄 error 等級訊息,可含錯誤物件與堆疊追蹤。
  void error(String message, {Object? error, StackTrace? stackTrace});
}
