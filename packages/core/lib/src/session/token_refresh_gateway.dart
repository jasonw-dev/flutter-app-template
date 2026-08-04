import 'package:core/src/foundation/result.dart';
import 'package:core/src/session/auth_tokens.dart';

/// 以 refresh token 換發新 tokens 的契約。
///
/// 實作由 app / auth feature 提供(refresh API 是應用專屬的),
/// 且實作必須走「不含 AuthInterceptor 的 client」,
/// 否則 401 會遞迴觸發 refresh。
// ignore: one_member_abstracts -- 契約刻意單方法,依架構規則由 app 提供實作
abstract interface class TokenRefreshGateway {
  /// 換發新 tokens;失敗回傳 failure(通常為 UnauthorizedException)。
  Future<Result<AuthTokens>> refresh(String refreshToken);
}
