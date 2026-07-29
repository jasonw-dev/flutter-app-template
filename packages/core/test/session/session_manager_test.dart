import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore store;
  late FakeTokenRefreshGateway gateway;
  late FakeLogger logger;

  SessionManager build() =>
      SessionManager(store: store, gateway: gateway, logger: logger);

  setUp(() {
    store = InMemorySecureStore();
    gateway = FakeTokenRefreshGateway();
    logger = FakeLogger();
  });

  test('初始狀態為 SessionRestoring', () {
    expect(build().state, isA<SessionRestoring>());
  });

  test('restore:儲存有完整 tokens → Authenticated 並可取 access token', () async {
    store.values[SessionManager.accessTokenKey] = 'a1';
    store.values[SessionManager.refreshTokenKey] = 'r1';
    final manager = build();
    await manager.restore();
    expect(manager.state, isA<SessionAuthenticated>());
    expect(await manager.currentAccessToken(), 'a1');
  });

  test('restore:儲存缺 token → Unauthenticated', () async {
    final manager = build();
    await manager.restore();
    expect(manager.state, isA<SessionUnauthenticated>());
    expect(await manager.currentAccessToken(), isNull);
  });

  test('signIn 寫入儲存並發布 Authenticated', () async {
    final manager = build();
    final emitted = <SessionState>[];
    final sub = manager.states.listen(emitted.add);
    await manager.signIn(
      const AuthTokens(accessToken: 'a2', refreshToken: 'r2'),
    );
    await sub.cancel();
    expect(store.values[SessionManager.accessTokenKey], 'a2');
    expect(store.values[SessionManager.refreshTokenKey], 'r2');
    expect(manager.state, isA<SessionAuthenticated>());
    expect(emitted.single, isA<SessionAuthenticated>());
  });

  test('signOut 清除儲存與快取並發布 Unauthenticated', () async {
    final manager = build();
    await manager.signIn(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    await manager.signOut();
    expect(store.values, isEmpty);
    expect(manager.state, isA<SessionUnauthenticated>());
    expect(await manager.currentAccessToken(), isNull);
  });

  test('無條件發布:連續兩次 signOut 收到 2 個事件', () async {
    // 釘住「拿掉去重」這個決定,避免有人日後又把 runtimeType 比較加回去。
    // 先前的行為是只收到 1 個。
    final session = SessionManager(
      store: InMemorySecureStore(),
      gateway: FakeTokenRefreshGateway(),
      logger: FakeLogger(),
    );
    await session.restore();

    final events = <SessionState>[];
    final sub = session.states.listen(events.add);
    addTearDown(sub.cancel);

    await session.signOut();
    await session.signOut();

    expect(events.length, 2);
    expect(events.every((e) => e is SessionUnauthenticated), isTrue);
  });
}
