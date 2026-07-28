import 'package:app/src/demo/demo_backend_adapter.dart';
import 'package:app/src/router/app_router.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:home/home.dart';
import 'package:localization/localization.dart';

void main() {
  late GetIt gi;
  late SessionManager session;
  late GoRouter router;

  setUp(() async {
    gi = GetIt.asNewInstance();
    session = SessionManager(
      store: InMemorySecureStore(),
      gateway: FakeTokenRefreshGateway(),
      logger: FakeLogger(),
    );
    await session.restore(); // 空儲存 → Unauthenticated
    final apiClient = ApiClient(
      createDio(
        config: const NetworkingConfig(baseUrl: 'https://demo.example.com'),
        tokenProvider: session,
        adapter: DemoBackendAdapter(latency: Duration.zero),
      ),
    );
    gi
      ..registerSingleton<SessionManager>(session)
      ..registerSingleton<ApiClient>(apiClient)
      // home feature 的 repository 需要 KeyValueStore 做本地快取。
      ..registerSingleton<KeyValueStore>(InMemoryKeyValueStore());
    registerAuthFeature(gi);
    registerHomeFeature(gi);
    router = buildRouter(session);
  });

  tearDown(() async {
    await gi.reset();
  });

  // 本測試不經 App,直接用 buildRouter 的產物,因此要自己提供容器——
  // page 是靠 context.read<GetIt>() 解析 bloc 的。
  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    RepositoryProvider<GetIt>.value(
      value: gi,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );

  testWidgets('未登入導向 login', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('signIn 後轉 home;signOut 後回 login', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await session.signIn(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    router.go(RoutePaths.login);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await session.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('已登入時導向不存在路由 → 錯誤頁;點回首頁按鈕 → home', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await session.signIn(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    router.go('/no/such/route');
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));
    expect(find.text(context.l10n.commonErrorGeneric), findsOneWidget);

    await tester.tap(find.text(context.l10n.homeTitle));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });
}
