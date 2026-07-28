import 'package:auth/src/data/dtos/auth_tokens_dto.dart';
import 'package:core/core.dart';

/// [TokenRefreshGateway] 的 HTTP 實作。
///
/// 建構參數 [ApiClient] 必須以 `createPlainDio` 組裝（不含
/// AuthInterceptor 的 plain client），否則 refresh 呼叫本身收到 401
/// 會遞迴觸發 refresh，造成無窮迴圈。
class AuthTokenRefreshGateway implements TokenRefreshGateway {
  /// 以 plain [ApiClient] 建立。
  AuthTokenRefreshGateway(this._plainClient);

  final ApiClient _plainClient;

  @override
  Future<Result<AuthTokens>> refresh(String refreshToken) =>
      _plainClient.post<AuthTokens>(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
        parse: (data) =>
            AuthTokensDto.fromJson(data as Map<String, dynamic>).toTokens(),
      );
}
