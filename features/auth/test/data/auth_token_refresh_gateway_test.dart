import 'package:auth/src/data/auth_token_refresh_gateway.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = NetworkingConfig(baseUrl: 'https://api.test');

void main() {
  group('AuthTokenRefreshGateway.refresh', () {
    test('成功時回傳 Success(AuthTokens)', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, '{"accessToken":"a2","refreshToken":"r2"}'),
      ]);
      final gateway = AuthTokenRefreshGateway(
        ApiClient(createPlainDio(config: _config, adapter: adapter)),
      );

      final result = await gateway.refresh('r1');

      expect(result, isA<Success<AuthTokens>>());
      final tokens = (result as Success<AuthTokens>).value;
      expect(tokens.accessToken, 'a2');
      expect(tokens.refreshToken, 'r2');
    });

    test('401 時回傳 Failure(UnauthorizedException)', () async {
      final adapter = ScriptedAdapter([(_) => jsonResponse(401, '{}')]);
      final gateway = AuthTokenRefreshGateway(
        ApiClient(createPlainDio(config: _config, adapter: adapter)),
      );

      final result = await gateway.refresh('r1');

      expect(result, isA<Failure<AuthTokens>>());
      expect(
        (result as Failure<AuthTokens>).exception,
        isA<UnauthorizedException>(),
      );
    });

    test('送出的 body 含 refreshToken', () async {
      final adapter = ScriptedAdapter([
        (_) => jsonResponse(200, '{"accessToken":"a2","refreshToken":"r2"}'),
      ]);
      final gateway = AuthTokenRefreshGateway(
        ApiClient(createPlainDio(config: _config, adapter: adapter)),
      );

      await gateway.refresh('the-refresh-token');

      expect(adapter.seen, hasLength(1));
      expect(adapter.seen.single.data, {'refreshToken': 'the-refresh-token'});
    });
  });
}
