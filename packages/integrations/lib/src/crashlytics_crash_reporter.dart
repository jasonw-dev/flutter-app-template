import 'package:core/core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// [CrashReporter] 的 Crashlytics 實作;實例由 app 組裝層注入。
class CrashlyticsCrashReporter implements CrashReporter {
  /// 以既有的 [FirebaseCrashlytics] 建立。
  CrashlyticsCrashReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) => _crashlytics.recordError(error, stackTrace, fatal: fatal);

  @override
  Future<void> setUserId(String? userId) =>
      _crashlytics.setUserIdentifier(userId ?? '');

  @override
  Future<void> log(String message) => _crashlytics.log(message);
}
