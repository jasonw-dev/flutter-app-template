import 'package:app/src/app.dart';
import 'package:app/src/config/app_config.dart';
import 'package:app/src/di/compose_dependencies.dart';
import 'package:auth/auth.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localization/testing.dart';

/// 一條完整旅程,走內建假後端,不需要真後端。
///
/// 這是唯一能證明「App 真的能跑」的東西:`check.sh` 擋的全是結構,golden
/// 擋的是單頁畫面,只有這條路徑會把 DI、router、session、資料層串起來跑。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  testWidgets('登入 → 清單 → 詳情 → 返回', (tester) async {
    final gi = GetIt.asNewInstance();
    addTearDown(gi.reset);
    await composeDependencies(
      gi,
      const AppConfig(
        environment: AppEnvironment.dev,
        apiBaseUrl: 'https://demo.example.com',
        demoBackendLatency: Duration.zero,
      ),
      secureStoreOverride: InMemorySecureStore(),
    );

    await tester.pumpWidget(App(gi: gi));
    await tester.pumpAndSettle();

    // 1. 冷啟動 → 停在登入頁。
    expect(find.byType(LoginPage), findsOneWidget);

    // 2. 輸入合法 email + 任意密碼 → 送出。
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'secret',
    );
    await tester.tap(find.text(l10n.authLoginButton));
    await tester.pumpAndSettle();

    // 3. 進到首頁 → 看到清單。
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);

    // 4. 點第一筆 → 進詳情頁 → 看到標題。
    final firstTitle = tester.widgetList<ListTile>(find.byType(ListTile)).first;
    await tester.tap(find.byWidget(firstTitle));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailPage), findsOneWidget);

    // 5. 返回 → 回到首頁。
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });
}
