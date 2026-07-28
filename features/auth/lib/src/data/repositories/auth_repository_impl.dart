import 'package:auth/src/data/dtos/auth_tokens_dto.dart';
import 'package:auth/src/domain/repositories/auth_repository.dart';
import 'package:core/core.dart';

/// [AuthRepository] 的 HTTP 實作。
class AuthRepositoryImpl implements AuthRepository {
  /// 以 [ApiClient] 建立；client 需含 AuthInterceptor（一般登入流程）。
  AuthRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<AuthTokens>> login({
    required String email,
    required String password,
  }) => _client.post<AuthTokens>(
    '/auth/login',
    body: {'email': email, 'password': password},
    parse: (data) =>
        AuthTokensDto.fromJson(data as Map<String, dynamic>).toTokens(),
  );
}
