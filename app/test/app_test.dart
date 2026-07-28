import 'package:app/src/app.dart';
import 'package:app/src/demo/demo_backend_adapter.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';

void main() {
  late GetIt gi;
  late SessionManager session;
  late FakePushNotifications push;

  // page 透過 context.read<GetIt>() 取用容器,而 App 會把建構參數 gi 用
  // RepositoryProvider 往下傳,因此這裡可以用完全獨立的容器,
  // 測試之間不會互相污染(見 docs/conventions.md §5 DI 規範)。
  Future<void> setupGetIt({PushTapEvent? initialTapEvent}) async {
    gi = GetIt.asNewInstance();
    session = SessionManager(
      store: InMemorySecureStore(),
      gateway: FakeTokenRefreshGateway(),
      logger: FakeLogger(),
    );
    await session.restore(); // 空儲存 → Unauthenticated
    push = FakePushNotifications(initialTapEvent: initialTapEvent);
    final apiClient = ApiClient(
      createDio(
        config: const NetworkingConfig(baseUrl: 'https://demo.example.com'),
        tokenProvider: session,
        adapter: DemoBackendAdapter(latency: Duration.zero),
      ),
    );
    gi
      ..registerSingleton<SessionManager>(session)
      ..registerSingleton<PushNotifications>(push)
      ..registerSingleton<ApiClient>(apiClient)
      // home feature 的 repository 需要 KeyValueStore 做本地快取。
      ..registerSingleton<KeyValueStore>(InMemoryKeyValueStore());
    registerAuthFeature(gi);
    registerHomeFeature(gi);
  }

  tearDown(() async {
    await gi.reset();
  });

  testWidgets('未登入 → 顯示 login 頁，且 shell 不生效(無 NavigationBar)', (tester) async {
    await setupGetIt();
    await tester.pumpWidget(App(gi: gi));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('signIn 後 → 顯示 home 頁，shell 生效(有 NavigationBar)', (tester) async {
    await setupGetIt();
    await tester.pumpWidget(App(gi: gi));
    await tester.pumpAndSettle();

    await session.signIn(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('已登入時點擊推播導向 login → 守衛擋回，仍顯示 home', (tester) async {
    await setupGetIt();
    await tester.pumpWidget(App(gi: gi));
    await tester.pumpAndSettle();

    await session.signIn(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    push.emitTap(const PushTapEvent(routePath: RoutePaths.login));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('冷啟動點擊(未登入)導向 home → 守衛導回 login，不崩潰', (tester) async {
    await setupGetIt(
      initialTapEvent: const PushTapEvent(routePath: RoutePaths.home),
    );
    await tester.pumpWidget(App(gi: gi));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
