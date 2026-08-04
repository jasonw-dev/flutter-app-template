import 'package:core/src/observability/crash_reporter.dart';

/// 啟動期緩衝的 crash reporter(見 docs/adr/0005)。
///
/// bootstrap 在第 3 步就掛錯誤捕捉,但 Firebase 要到第 4 步才 init;
/// 期間的錯誤先緩衝,attach 真正的 reporter 後依序補送。
class BufferingCrashReporter implements CrashReporter {
  static const _capacity = 100;

  final List<Future<void> Function(CrashReporter r)> _buffer = [];
  CrashReporter? _delegate;

  /// 掛上真正的 reporter;先依序 flush 緩衝(含 flush 期間新到的呼叫),完成後才直通。
  ///
  /// 只能呼叫一次。
  Future<void> attach(CrashReporter delegate) async {
    assert(_delegate == null, 'attach() 只能呼叫一次');
    while (_buffer.isNotEmpty) {
      final replay = _buffer.removeAt(0);
      try {
        await replay(delegate);
      } on Object {
        // 補送失敗不得中斷排水與啟動;上報遺失可接受。
      }
    }
    _delegate = delegate;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.recordError(error, stackTrace, fatal: fatal);
    }
    _push((r) => r.recordError(error, stackTrace, fatal: fatal));
  }

  @override
  Future<void> setUserId(String? userId) async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.setUserId(userId);
    }
    _push((r) => r.setUserId(userId));
  }

  @override
  Future<void> log(String message) async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.log(message);
    }
    _push((r) => r.log(message));
  }

  void _push(Future<void> Function(CrashReporter r) replay) {
    if (_buffer.length >= _capacity) {
      _buffer.removeAt(0);
    }
    _buffer.add(replay);
  }
}
