import 'package:core/src/networking/auth_interceptor.dart';
import 'package:core/src/networking/retry_interceptor.dart';
import 'package:core/src/networking/retry_policy.dart';
import 'package:core/src/networking/token_provider.dart';
import 'package:dio/dio.dart';

/// networking 的環境設定。
class NetworkingConfig {
  /// 建立設定;timeout 有合理預設。
  const NetworkingConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.retryPolicy = const RetryPolicy(),
  });

  /// API 的 base URL。
  final String baseUrl;

  /// 連線逾時。
  final Duration connectTimeout;

  /// 接收逾時。
  final Duration receiveTimeout;

  /// 重試策略;規則見 [RetryInterceptor]。
  final RetryPolicy retryPolicy;
}

/// 建立掛好攔截器的 Dio(app 組裝層唯一入口)。
///
/// [adapter] 僅供測試注入;非 null 時同時套用到主 client 與
/// retry client,確保 401 重試也走測試 adapter。
///
/// [extraInterceptors] 會掛在 AuthInterceptor 之後。retryClient 不掛
/// extra——重試請求不經過它們,為已知取捨。
Dio createDio({
  required NetworkingConfig config,
  required TokenProvider tokenProvider,
  HttpClientAdapter? adapter,
  List<Interceptor> extraInterceptors = const [],
}) {
  final baseOptions = BaseOptions(
    baseUrl: config.baseUrl,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
  );
  final retryClient = Dio(baseOptions);
  final dio = Dio(baseOptions);
  if (adapter != null) {
    retryClient.httpClientAdapter = adapter;
    dio.httpClientAdapter = adapter;
  }
  // **順序不可調換:AuthInterceptor 在前、RetryInterceptor 在後。**
  // 401 由 AuthInterceptor 處理(refresh 後重試一次),RetryInterceptor 不該
  // 碰 401——它在規則 2 已排除 4xx,但順序錯的話會先看到 401 再交給 auth,
  // 行為變得難以推理。
  dio.interceptors.add(
    AuthInterceptor(tokenProvider: tokenProvider, retryClient: retryClient),
  );
  if (config.retryPolicy.maxAttempts > 1) {
    dio.interceptors.add(
      RetryInterceptor(policy: config.retryPolicy, retryClient: retryClient),
    );
  }
  // extraInterceptors 仍然掛在最後。
  dio.interceptors.addAll(extraInterceptors);
  return dio;
}

/// 建立無攔截器的 plain Dio。
///
/// 專供 TokenRefreshGateway 實作使用——refresh 呼叫走含 AuthInterceptor
/// 的 client 會在 401 時遞迴觸發 refresh(§2.3 的結構性保證)。
///
/// **一律不重試**:refresh 失敗要立刻讓使用者知道,不該悄悄重試三次讓登出
/// 延遲好幾秒。
Dio createPlainDio({
  required NetworkingConfig config,
  HttpClientAdapter? adapter,
}) {
  final baseOptions = BaseOptions(
    baseUrl: config.baseUrl,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
  );
  final dio = Dio(baseOptions);
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  return dio;
}
