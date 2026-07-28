import 'package:auth/src/data/repositories/auth_repository_impl.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = NetworkingConfig(baseUrl: 'https://api.test');

void main() {
  group('AuthRepositoryImpl.login', () {
    test('成功時回傳 Success(AuthTokens)', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, '{"accessToken":"a1","refreshToken":"r1"}'),
      ]);
      final client = ApiClient(
        createPlainDio(config: _config, adapter: adapter),
      );
      final repository = AuthRepositoryImpl(client);

      final result = await repository.login(email: 'a@b.com', password: 'pw');

      expect(result, isA<Success<AuthTokens>>());
      final tokens = (result as Success<AuthTokens>).value;
      expect(tokens.accessToken, 'a1');
      expect(tokens.refreshToken, 'r1');
    });

    test('401 時回傳 Failure(UnauthorizedException)', () async {
      final adapter = ScriptedAdapter([(_) => jsonResponse(401, '{}')]);
      final client = ApiClient(
        createPlainDio(config: _config, adapter: adapter),
      );
      final repository = AuthRepositoryImpl(client);

      final result = await repository.login(
        email: 'a@b.com',
        password: 'wrong',
      );

      expect(result, isA<Failure<AuthTokens>>());
      expect(
        (result as Failure<AuthTokens>).exception,
        isA<UnauthorizedException>(),
      );
    });

    test('回應缺欄位時回傳 Failure(ParsingException)', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, '{"accessToken":"a1"}'),
      ]);
      final client = ApiClient(
        createPlainDio(config: _config, adapter: adapter),
      );
      final repository = AuthRepositoryImpl(client);

      final result = await repository.login(email: 'a@b.com', password: 'pw');

      expect(result, isA<Failure<AuthTokens>>());
      expect(
        (result as Failure<AuthTokens>).exception,
        isA<ParsingException>(),
      );
    });
  });
}
