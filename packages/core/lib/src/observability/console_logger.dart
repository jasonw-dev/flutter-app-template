import 'package:core/src/foundation/logger.dart';

/// [AppLogger] 的 console 實作(開發期預設)。
class ConsoleLogger implements AppLogger {
  /// 建立 console logger;低於 [minLevel] 的訊息不輸出。
  ConsoleLogger({this.minLevel = LogLevel.debug, this.output = print});

  /// 最低輸出層級。
  final LogLevel minLevel;

  /// 輸出函式(測試可注入)。
  final void Function(String line) output;

  @override
  void debug(String message) => _write(LogLevel.debug, message);

  @override
  void info(String message) => _write(LogLevel.info, message);

  @override
  void warning(String message) => _write(LogLevel.warning, message);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _write(LogLevel.error, message);
    if (error != null) {
      _write(LogLevel.error, '  cause: $error');
    }
    if (stackTrace != null) {
      _write(LogLevel.error, '  stack: $stackTrace');
    }
  }

  void _write(LogLevel level, String message) {
    if (level.index < minLevel.index) {
      return;
    }
    output('[${level.name.toUpperCase()}] $message');
  }
}
