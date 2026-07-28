import 'package:app/src/app.dart';
import 'package:app/src/config/app_config.dart';
import 'package:app/src/di/compose_dependencies.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:localization/testing.dart';
import 'package:persistence/testing.dart';
import 'package:session/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端到端 flow test:本範本的「integration test」形態——真實 DI 組裝 +
/// 內建假後端(`DemoBackendAdapter`)+ 完整 [App],CI 可跑,不需真後端。
///
/// 涵蓋:login 頁輸入/送出 → home 列表 → 詳情頁;以及登入失敗分支
/// (SnackBar 提示、仍留在 login 頁)。
void main() {
  late GetIt gi;

  setUp(() {
    gi = GetIt.asNewInstance();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await gi.reset();
  });

  Future<void> bootTestApp(WidgetTester tester) async {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: 'https://demo.example.com',
      demoBackendLatency: Duration.zero,
    );
    // flutter_secure_storage 在測試環境無平台實作;composeDependencies 的
    // secureStoreOverride 僅供測試注入,取代真實 plugin。
    await composeDependencies(
      gi,
      config,
      secureStoreOverride: InMemorySecureStore(),
    );
    await gi.allReady();
    await gi<SessionManager>().restore();
    await tester.pumpWidget(App(gi: gi));
  }

  testWidgets('登入成功 → home 列表可見 → 點選項目 → 詳情頁可見', (tester) async {
    await bootTestApp(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'correct-password',
    );
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Demo item 1'), findsOneWidget);

    await tester.tap(find.text('Demo item 1'));
    await tester.pumpAndSettle();

    expect(find.text('Description for demo item 1.'), findsOneWidget);
  });

  testWidgets('登入失敗(password 為 wrong)→ SnackBar 提示，仍在 login 頁', (tester) async {
    await bootTestApp(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrong',
    );
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().authLoginFailed), findsOneWidget);
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
  });
}
