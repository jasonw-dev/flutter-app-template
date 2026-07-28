import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 端到端測試專用 gateway:回傳固定結果,不需要走完整 fake 的併發語意。
class _StubGateway implements TokenRefreshGateway {
  _StubGateway(this._result);

  final Result<AuthTokens> _result;

  int callCount = 0;

  @override
  Future<Result<AuthTokens>> refresh(String refreshToken) async {
    callCount++;
    return _result;
  }
}

void main() {
  late InMemorySecureStore store;
  late FakeLogger logger;

  setUp(() {
    store = InMemorySecureStore();
    logger = FakeLogger();
  });

  test('成功鏈:401 → SessionManager.refreshTokens → 重試成功、新 tokens 持久化', () async {
    final gateway = _StubGateway(
      const Result.success(AuthTokens(accessToken: 'a1', refreshToken: 'r1')),
    );
    final manager = SessionManager(
      store: store,
      gateway: gateway,
      logger: logger,
    );
    await manager.signIn(
      const AuthTokens(accessToken: 'a0', refreshToken: 'r0'),
    );

    final adapter = ScriptedAdapter([
      (_) => jsonResponse(401, '{}'),
      (_) => jsonResponse(200, '{"ok":true}'),
    ]);
    final dio = createDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
      tokenProvider: manager,
      adapter: adapter,
    );

    final res = await dio.get<dynamic>('/me');

    expect(res.statusCode, 200);
    expect(adapter.seen, hasLength(2));
    expect(adapter.seen[1].headers['Authorization'], 'Bearer a1');
    expect(store.values[SessionManager.accessTokenKey], 'a1');
    expect(store.values[SessionManager.refreshTokenKey], 'r1');
    expect(gateway.callCount, 1);
  });

  test('失敗鏈:401 → refresh 未授權失敗 → 原 401 傳遞、session 登出', () async {
    final gateway = _StubGateway(const Result.failure(UnauthorizedException()));
    final manager = SessionManager(
      store: store,
      gateway: gateway,
      logger: logger,
    );
    await manager.signIn(
      const AuthTokens(accessToken: 'a0', refreshToken: 'r0'),
    );

    final adapter = ScriptedAdapter([(_) => jsonResponse(401, '{}')]);
    final dio = createDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
      tokenProvider: manager,
      adapter: adapter,
    );

    await expectLater(
      dio.get<dynamic>('/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(manager.state, isA<SessionUnauthenticated>());
    expect(store.values, isEmpty);
  });
}
