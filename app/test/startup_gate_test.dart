import 'package:app/src/router/app_router.dart';
import 'package:app/src/startup/startup_blocked_page.dart';
import 'package:app/src/startup/startup_gate.dart';
import 'package:app/src/startup/startup_gate_controller.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';
import 'package:localization/localization.dart';
import 'package:permissions/permissions.dart';
import 'package:permissions/testing.dart';

/// 回傳固定結果的 gate;可設定為丟例外。
class _ScriptedGate implements StartupGate {
  _ScriptedGate(this.result, {this.throws = false});

  StartupGateState result;
  bool throws;
  int calls = 0;

  @override
  Future<StartupGateState> evaluate() async {
    calls++;
    if (throws) {
      throw StateError('gate blew up');
    }
    return result;
  }
}

void main() {
  late GetIt gi;
  late SessionManager session;

  Future<void> setUpContainer() async {
    gi = GetIt.asNewInstance();
    session = SessionManager(
      store: InMemorySecureStore(),
      gateway: FakeTokenRefreshGateway(),
      logger: FakeLogger(),
    );
    await session.restore();
    final client = ApiClient(
      createPlainDio(
        config: const NetworkingConfig(baseUrl: 'https://api.test'),
        adapter: ScriptedAdapter([]),
      ),
    );
    gi
      ..registerSingleton<SessionManager>(session)
      ..registerSingleton<ApiClient>(client)
      ..registerSingleton<KeyValueStore>(InMemoryKeyValueStore())
      ..registerSingleton<Permissions>(
        FakePermissions(
          initial: {AppPermission.notifications: PermissionOutcome.granted},
        ),
      );
    registerAuthFeature(gi);
    registerHomeFeature(gi);
  }

  Future<void> pump(
    WidgetTester tester,
    StartupGateController controller,
  ) async {
    final router = buildRouter(session, gateController: controller);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<GetIt>.value(
        value: gi,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(setUpContainer);
  tearDown(() => gi.reset());

  testWidgets('允許時行為與現況相同(未登入 → login)', (tester) async {
    final controller = StartupGateController(const AlwaysAllowedStartupGate());
    await controller.evaluate();
    await pump(tester, controller);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(StartupBlockedPage), findsNothing);
  });

  testWidgets('強制更新:**未登入**時也被導到 /startup-blocked', (tester) async {
    // 這條是重點:證明 gate 排在登入守衛之前。順序反過來的話,維護模式對
    // 未登入的使用者完全無效。
    final controller = StartupGateController(
      _ScriptedGate(const StartupUpdateRequired(storeUrl: 'https://store')),
    );
    await controller.evaluate();
    await pump(tester, controller);

    expect(find.byType(StartupBlockedPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('維護模式:已登入使用者同樣被擋', (tester) async {
    await session.signIn(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    final controller = StartupGateController(
      _ScriptedGate(const StartupUnderMaintenance()),
    );
    await controller.evaluate();
    await pump(tester, controller);

    expect(find.byType(StartupBlockedPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('gate 變回 allowed 並通知 → router 把使用者放回去', (tester) async {
    await session.signIn(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    final gate = _ScriptedGate(const StartupUnderMaintenance());
    final controller = StartupGateController(gate);
    await controller.evaluate();
    await pump(tester, controller);
    expect(find.byType(StartupBlockedPage), findsOneWidget);

    gate.result = const StartupAllowed();
    await controller.evaluate();
    await tester.pumpAndSettle();

    // 驗證 Listenable.merge 有把 gate 接進 refreshListenable。
    expect(find.byType(StartupBlockedPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('gate 丟例外時 App 仍能啟動', (tester) async {
    // 對應 StartupGate 契約註解的精神:把使用者鎖在門外的代價遠大於漏擋一次。
    final controller = StartupGateController(
      _ScriptedGate(const StartupAllowed(), throws: true),
    );
    await controller.evaluate();
    await pump(tester, controller);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('evaluate() 併發呼叫兩次,底層 gate 只被呼叫一次', () async {
    final gate = _ScriptedGate(const StartupAllowed());
    final controller = StartupGateController(gate);

    await Future.wait([controller.evaluate(), controller.evaluate()]);

    expect(gate.calls, 1);
  });
}
