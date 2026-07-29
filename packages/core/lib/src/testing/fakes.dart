import 'package:core/src/observability/analytics_tracker.dart';
import 'package:core/src/observability/crash_reporter.dart';

/// 一筆被記錄的錯誤。
class RecordedError {
  /// 建立紀錄。
  const RecordedError(this.error, this.stackTrace, {required this.fatal});

  /// 錯誤本體。
  final Object error;

  /// 堆疊。
  final StackTrace? stackTrace;

  /// 是否致命。
  final bool fatal;
}

/// [CrashReporter] 的官方 fake。
class FakeCrashReporter implements CrashReporter {
  /// 記錄的錯誤。
  final List<RecordedError> recordedErrors = [];

  /// 記錄的 userId 設定(含 null)。
  final List<String?> userIds = [];

  /// 記錄的 log 訊息。
  final List<String> logs = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async =>
      recordedErrors.add(RecordedError(error, stackTrace, fatal: fatal));

  @override
  Future<void> setUserId(String? userId) async => userIds.add(userId);

  @override
  Future<void> log(String message) async => logs.add(message);
}

/// 一筆被記錄的事件。
class TrackedEvent {
  /// 建立紀錄。
  const TrackedEvent(this.name, this.parameters);

  /// 事件名。
  final String name;

  /// 參數。
  final Map<String, Object?> parameters;
}

/// [AnalyticsTracker] 的官方 fake。
class FakeAnalyticsTracker implements AnalyticsTracker {
  /// 記錄的事件。
  final List<TrackedEvent> events = [];

  /// 記錄的畫面。
  final List<String> screens = [];

  @override
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async => events.add(TrackedEvent(name, parameters));

  @override
  Future<void> trackScreen(String screenName) async => screens.add(screenName);
}
