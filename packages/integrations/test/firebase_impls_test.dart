import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrations/integrations.dart';
import 'package:mocktail/mocktail.dart';

class _MockCrashlytics extends Mock implements FirebaseCrashlytics {}

class _MockAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  group('CrashlyticsCrashReporter', () {
    late _MockCrashlytics inner;
    late CrashlyticsCrashReporter reporter;

    setUp(() {
      inner = _MockCrashlytics();
      reporter = CrashlyticsCrashReporter(inner);
      when(
        () =>
            inner.recordError(any<Object>(), any(), fatal: any(named: 'fatal')),
      ).thenAnswer((_) async {});
      when(() => inner.setUserIdentifier(any())).thenAnswer((_) async {});
      when(() => inner.log(any())).thenAnswer((_) async {});
    });

    test('轉呼叫底層', () async {
      await reporter.recordError('e', StackTrace.empty, fatal: true);
      await reporter.setUserId('u1');
      await reporter.setUserId(null);
      await reporter.log('m');
      verify(
        () => inner.recordError('e', StackTrace.empty, fatal: true),
      ).called(1);
      verify(() => inner.setUserIdentifier('u1')).called(1);
      verify(() => inner.setUserIdentifier('')).called(1);
      verify(() => inner.log('m')).called(1);
    });
  });

  group('FirebaseAnalyticsTracker', () {
    late _MockAnalytics inner;
    late FirebaseAnalyticsTracker tracker;

    setUp(() {
      inner = _MockAnalytics();
      tracker = FirebaseAnalyticsTracker(inner);
      when(
        () => inner.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => inner.logScreenView(screenName: any(named: 'screenName')),
      ).thenAnswer((_) async {});
    });

    test('trackEvent 過濾 null 參數', () async {
      await tracker.trackEvent('tap', parameters: {'a': 1, 'b': null});
      verify(() => inner.logEvent(name: 'tap', parameters: {'a': 1})).called(1);
    });

    test('trackScreen 轉呼叫 logScreenView', () async {
      await tracker.trackScreen('Home');
      verify(() => inner.logScreenView(screenName: 'Home')).called(1);
    });
  });
}
