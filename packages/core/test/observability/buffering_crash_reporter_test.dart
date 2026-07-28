import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// 包一層 [FakeCrashReporter],模擬真正異步的 reporter(如 Crashlytics)。
class _SlowCrashReporter implements CrashReporter {
  _SlowCrashReporter(this._inner);

  final FakeCrashReporter _inner;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _inner.recordError(error, stackTrace, fatal: fatal);
  }

  @override
  Future<void> setUserId(String? userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _inner.setUserId(userId);
  }

  @override
  Future<void> log(String message) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _inner.log(message);
  }
}

/// 包一層 [FakeCrashReporter],對特定訊息拋錯,其餘照常記錄。
class _ThrowingOnBadCrashReporter implements CrashReporter {
  _ThrowingOnBadCrashReporter(this._inner);

  final FakeCrashReporter _inner;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) => _inner.recordError(error, stackTrace, fatal: fatal);

  @override
  Future<void> setUserId(String? userId) => _inner.setUserId(userId);

  @override
  Future<void> log(String message) async {
    if (message == 'bad') {
      throw StateError('boom');
    }
    return _inner.log(message);
  }
}

void main() {
  test('attach 前緩衝,attach 時依序 flush,之後直通', () async {
    final buffering = BufferingCrashReporter();
    await buffering.recordError('e1', StackTrace.empty);
    await buffering.log('m1');
    await buffering.setUserId('u1');

    final delegate = FakeCrashReporter();
    await buffering.attach(delegate);
    expect(delegate.recordedErrors, hasLength(1));
    expect(delegate.logs, ['m1']);
    expect(delegate.userIds, ['u1']);

    await buffering.recordError('e2', null);
    expect(delegate.recordedErrors, hasLength(2));
  });

  test('緩衝上限 100 筆,超出丟最舊', () async {
    final buffering = BufferingCrashReporter();
    for (var i = 0; i < 105; i++) {
      await buffering.log('m$i');
    }
    final delegate = FakeCrashReporter();
    await buffering.attach(delegate);
    expect(delegate.logs, hasLength(100));
    expect(delegate.logs.first, 'm5');
  });

  test('attach 排水期間新到的呼叫,仍依序排在緩衝之後', () async {
    final buffering = BufferingCrashReporter();
    await buffering.log('m1');
    await buffering.log('m2');

    final fake = FakeCrashReporter();
    final delegate = _SlowCrashReporter(fake);

    final attachFuture = buffering.attach(delegate);
    await buffering.log('during-flush');
    await attachFuture;

    expect(fake.logs, ['m1', 'm2', 'during-flush']);
  });

  test('排水中某筆補送拋錯:不中斷,其餘照送,attach 正常完成', () async {
    final buffering = BufferingCrashReporter();
    await buffering.log('m1');
    await buffering.log('bad');
    await buffering.log('m2');

    final fake = FakeCrashReporter();
    final delegate = _ThrowingOnBadCrashReporter(fake);

    await buffering.attach(delegate);
    expect(fake.logs, ['m1', 'm2']);

    await buffering.log('after');
    expect(fake.logs, ['m1', 'm2', 'after']);
  });
}
