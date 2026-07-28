/// 一組登入憑證。
class AuthTokens {
  /// 以 access/refresh token 建立。
  const AuthTokens({required this.accessToken, required this.refreshToken});

  /// 短效存取 token。
  final String accessToken;

  /// 用於換發新 token 的長效 token。
  final String refreshToken;
}
