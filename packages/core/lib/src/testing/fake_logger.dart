import 'package:core/src/foundation/logger.dart';

/// [AppLogger] 的官方 fake(conventions.md §8.1 第 1 條)。
///
/// 下游測試一律使用本類,禁止各自手寫 logger mock。
class FakeLogger implements AppLogger {
  /// 所有記錄過的日誌記錄。
  final List<LogRecord> records = [];

  @override
  void debug(String message) => records.add(LogRecord(LogLevel.debug, message));

  @override
  void info(String message) => records.add(LogRecord(LogLevel.info, message));

  @override
  void warning(String message) =>
      records.add(LogRecord(LogLevel.warning, message));

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      records.add(
        LogRecord(
          LogLevel.error,
          message,
          error: error,
          stackTrace: stackTrace,
        ),
      );
}

/// 單一日誌記錄。
class LogRecord {
  /// 建立日誌記錄。
  const LogRecord(this.level, this.message, {this.error, this.stackTrace});

  /// 日誌層級。
  final LogLevel level;

  /// 日誌訊息。
  final String message;

  /// 關聯的錯誤物件。
  final Object? error;

  /// 關聯的堆疊追蹤。
  final StackTrace? stackTrace;
}
