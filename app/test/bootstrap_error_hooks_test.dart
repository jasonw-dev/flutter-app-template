import 'package:app/src/bootstrap.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('installErrorHooks 轉送 FlutterError 與 PlatformDispatcher', () {
    final logger = FakeLogger();
    final reporter = FakeCrashReporter();
    final originalOnError = FlutterError.onError;
    final originalPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = originalOnError;
      PlatformDispatcher.instance.onError = originalPlatform;
    });

    installErrorHooks(logger: logger, reporter: reporter);

    FlutterError.onError!(
      FlutterErrorDetails(exception: Exception('widget boom')),
    );
    expect(reporter.recordedErrors, hasLength(1));
    expect(reporter.recordedErrors.single.fatal, isFalse);

    final handled = PlatformDispatcher.instance.onError!(
      Exception('zone boom'),
      StackTrace.empty,
    );
    expect(handled, isTrue);
    expect(reporter.recordedErrors, hasLength(2));
    expect(reporter.recordedErrors[1].fatal, isTrue);
    expect(
      logger.records.where((r) => r.level == LogLevel.error),
      hasLength(2),
    );
  });
}
