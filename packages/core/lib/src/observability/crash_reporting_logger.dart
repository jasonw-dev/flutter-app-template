import 'package:core/src/foundation/logger.dart';
import 'package:core/src/observability/crash_reporter.dart';

/// 把 [AppLogger] 導向 crash 上報的組合 logger(production 組裝用)。
///
/// debug 僅本地;info/warning 附掛為 breadcrumb;error 直接 recordError。
class CrashReportingLogger implements AppLogger {
  /// 以本地 logger 與 crash reporter 組合。
  CrashReportingLogger({
    required AppLogger inner,
    required CrashReporter reporter,
  }) : _inner = inner,
       _reporter = reporter;

  final AppLogger _inner;
  final CrashReporter _reporter;

  @override
  void debug(String message) => _inner.debug(message);

  @override
  void info(String message) {
    _inner.info(message);
    // ignore: discarded_futures -- breadcrumb 為 fire-and-forget
    _reporter.log('[INFO] $message');
  }

  @override
  void warning(String message) {
    _inner.warning(message);
    // ignore: discarded_futures -- breadcrumb 為 fire-and-forget
    _reporter.log('[WARNING] $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _inner.error(message, error: error, stackTrace: stackTrace);
    // ignore: discarded_futures -- 上報為 fire-and-forget
    _reporter.recordError(error ?? message, stackTrace);
  }
}
