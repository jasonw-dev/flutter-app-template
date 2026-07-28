import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeLogger inner;
  late FakeCrashReporter reporter;
  late CrashReportingLogger logger;

  setUp(() {
    inner = FakeLogger();
    reporter = FakeCrashReporter();
    logger = CrashReportingLogger(inner: inner, reporter: reporter);
  });

  test('debug 只進 inner', () {
    logger.debug('d');
    expect(inner.records.single.level, LogLevel.debug);
    expect(reporter.logs, isEmpty);
    expect(reporter.recordedErrors, isEmpty);
  });

  test('info/warning 進 inner 並留 breadcrumb', () {
    logger
      ..info('i')
      ..warning('w');
    expect(inner.records, hasLength(2));
    expect(reporter.logs, ['[INFO] i', '[WARNING] w']);
  });

  test('error 上報 recordError,error 為 null 時以 message 上報', () {
    logger
      ..error('boom', error: 'cause', stackTrace: StackTrace.empty)
      ..error('no-cause');
    expect(inner.records, hasLength(2));
    expect(reporter.recordedErrors, hasLength(2));
    expect(reporter.recordedErrors[0].error, 'cause');
    expect(reporter.recordedErrors[1].error, 'no-cause');
  });
}
