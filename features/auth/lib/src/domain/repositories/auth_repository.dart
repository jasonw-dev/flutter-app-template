import 'package:core/core.dart';

/// 登入功能的 domain 契約。
// ignore: one_member_abstracts -- 契約刻意單方法，對齊 TokenRefreshGateway 慣例
abstract interface class AuthRepository {
  /// 以 email/password 登入，成功回傳一組 [AuthTokens]。
  Future<Result<AuthTokens>> login({
    required String email,
    required String password,
  });
}
