import 'dart:async';
import 'dart:math';

import 'package:core/src/networking/retry_policy.dart';
import 'package:dio/dio.dart';

/// 對可恢復的失敗做指數退避重試。
///
/// 四條規則,每一條都對應一種真實事故:
///
/// 1. **只重試冪等方法**(`GET`/`HEAD`/`OPTIONS`)。`POST`/`PUT`/`PATCH`/
///    `DELETE` 一律不重試——「送出訂單逾時後重試」等於重複下單。若某支
///    POST 確定冪等(後端有 idempotency key),呼叫端用
///    `options.extra[RetryInterceptor.idempotentKey] = true` 明確 opt-in。
/// 2. **只重試可能會好的錯誤**:連線失敗/逾時與 5xx。**4xx 一律不重試**,
///    它不會自己變好,重試只是浪費電。
/// 3. **429 特別處理**:回應含 `Retry-After` 時用它指定的秒數,不用自己算的
///    退避——伺服器明講了要等多久就等多久。
/// 4. **cancel 不重試**:使用者已經離開頁面了,重試沒有意義。
///
/// 退避加 **jitter**(`delay * (0.5 + random * 0.5)`),避免所有客戶端同時
/// 重試,把剛恢復的後端再打掛。
///
/// 掛載順序見 `createDio`:**`AuthInterceptor` 在前、本攔截器在後**。
class RetryInterceptor extends Interceptor {
  /// 以 [policy] 與不含本攔截器的 [retryClient] 建立。
  ///
  /// [delay] 與 [random] 開放注入僅為了測試:**測試不可以真的等待退避時間**,
  /// 否則測試套件會慢到沒人願意跑。正式呼叫端一律不傳。
  RetryInterceptor({
    required RetryPolicy policy,
    required Dio retryClient,
    Future<void> Function(Duration)? delay,
    Random? random,
  }) : _policy = policy,
       _retryClient = retryClient,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random();

  /// 呼叫端用來明確宣告某支非冪等請求可以重試的 `extra` key。
  static const idempotentKey = 'networking.idempotent';

  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  final RetryPolicy _policy;
  final Dio _retryClient;
  final Future<void> Function(Duration) _delay;
  final Random _random;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // **重試在這裡迴圈,不靠攔截器重入。** 重送走的是不含本攔截器的
    // retryClient(比照 AuthInterceptor,避免遞迴),所以 onError 只會被
    // 呼叫一次——不迴圈的話 maxAttempts 永遠等於 2。
    var current = err;
    var attempt = 1;

    while (_shouldRetry(current, attempt)) {
      await _delay(_backoffFor(current, attempt));
      // 取消可能發生在等待期間,等完再檢查一次。
      if (current.requestOptions.cancelToken?.isCancelled ?? false) {
        break;
      }
      attempt++;
      try {
        handler.resolve(
          await _retryClient.fetch<dynamic>(current.requestOptions),
        );
        return;
      } on DioException catch (retryError) {
        current = retryError;
      }
    }
    handler.next(current);
  }

  bool _shouldRetry(DioException err, int attempt) {
    if (attempt >= _policy.maxAttempts) {
      return false;
    }
    // 規則 4:cancel 不重試。
    if (err.type == DioExceptionType.cancel) {
      return false;
    }
    if (err.requestOptions.cancelToken?.isCancelled ?? false) {
      return false;
    }
    // 規則 1:只重試冪等方法,除非呼叫端明確 opt-in。
    final method = err.requestOptions.method.toUpperCase();
    final optedIn = err.requestOptions.extra[idempotentKey] == true;
    if (!_idempotentMethods.contains(method) && !optedIn) {
      return false;
    }
    // 規則 2:只重試可能會好的錯誤。
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => _isRetryableStatus(
        err.response?.statusCode,
      ),
      _ => false,
    };
  }

  bool _isRetryableStatus(int? status) =>
      status != null && (status >= 500 || status == 429);

  Duration _backoffFor(DioException err, int attempt) {
    // 規則 3:伺服器講了要等多久就等多久,不用自己算的退避。
    final retryAfter = _retryAfterOf(err);
    if (retryAfter != null) {
      return retryAfter;
    }
    final exponential = _policy.baseDelay * pow(2, attempt - 1).toDouble();
    final capped = exponential > _policy.maxDelay
        ? _policy.maxDelay
        : exponential;
    // jitter:0.5 ~ 1.0 倍,避免所有客戶端同時重試。
    final jitter = 0.5 + _random.nextDouble() * 0.5;
    return Duration(
      microseconds: (capped.inMicroseconds * jitter).round(),
    );
  }

  Duration? _retryAfterOf(DioException err) {
    if (err.response?.statusCode != 429) {
      return null;
    }
    final raw = err.response?.headers.value('retry-after');
    final seconds = int.tryParse(raw ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
