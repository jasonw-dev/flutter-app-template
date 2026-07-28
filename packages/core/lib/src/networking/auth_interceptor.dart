import 'package:core/src/networking/token_provider.dart';
import 'package:dio/dio.dart';

/// 注入 Authorization header,並在 401 時做單次 refresh 重試。
///
/// 重試一律走 [_retryClient](不含本攔截器的獨立 Dio):
/// QueuedInterceptor 序列化回呼,重試若走同一個 Dio 會死結。
class AuthInterceptor extends QueuedInterceptor {
  /// 以 token 來源與重試用 client 建立攔截器。
  AuthInterceptor({
    required TokenProvider tokenProvider,
    required Dio retryClient,
  }) : _tokenProvider = tokenProvider,
       _retryClient = retryClient;

  static const _retriedKey = 'networking.auth_retried';

  final TokenProvider _tokenProvider;
  final Dio _retryClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenProvider.currentAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    final currentToken = await _tokenProvider.currentAccessToken();
    if (currentToken == null) {
      handler.next(err);
      return;
    }
    String token;
    final failedAuthHeader = options.headers['Authorization'];
    if (failedAuthHeader != 'Bearer $currentToken') {
      // 失敗請求所帶的 token 已與現行 token 不同:代表併發的另一個
      // 請求期間已完成 refresh,直接沿用現行 token 重試,
      // 不再重覆呼叫 refreshTokens()(避免序列化 N 次 refresh)。
      token = currentToken;
    } else {
      final refreshed = await _tokenProvider.refreshTokens();
      if (!refreshed) {
        handler.next(err);
        return;
      }
      final refreshedToken = await _tokenProvider.currentAccessToken();
      if (refreshedToken == null) {
        // refresh 回報成功但拿不到新 token:不可送出 `Bearer null`,
        // 視同重試失敗,原錯誤往下傳。
        handler.next(err);
        return;
      }
      token = refreshedToken;
    }
    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await _retryClient.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
