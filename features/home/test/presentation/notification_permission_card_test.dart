import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/src/presentation/widgets/notification_permission_card.dart';
import 'package:localization/localization.dart';
import 'package:localization/testing.dart';
import 'package:permissions/permissions.dart';
import 'package:permissions/testing.dart';

final _l10n = AppLocalizationsEn();

void main() {
  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  Future<void> pump(WidgetTester tester, FakePermissions permissions) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationPermissionCard(
            permissions: permissions,
            store: store,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('已授權 → 完全不顯示,也不 request', (tester) async {
    final permissions = FakePermissions(
      initial: {AppPermission.notifications: PermissionOutcome.granted},
    );

    await pump(tester, permissions);

    expect(find.text(_l10n.permissionNotificationTitle), findsNothing);
    expect(permissions.requested, isEmpty, reason: '規則 2:已授權不再 request');
  });

  testWidgets('未授權 → 顯示卡片,但**在按下前不 request**', (tester) async {
    final permissions = FakePermissions();

    await pump(tester, permissions);

    expect(find.text(_l10n.permissionNotificationTitle), findsOneWidget);
    // 規則 1:不在 initState 直接請求,系統對話框不該在使用者不知道為什麼
    // 的時候跳出來。
    expect(permissions.requested, isEmpty);
    expect(permissions.checked, [AppPermission.notifications]);
  });

  testWidgets('按「開啟」才 request;被拒絕後卡片還在(拒絕不是錯誤)', (tester) async {
    final permissions = FakePermissions()
      ..requestResults[AppPermission.notifications] = PermissionOutcome.denied;

    await pump(tester, permissions);
    await tester.tap(find.text(_l10n.permissionEnable));
    await tester.pumpAndSettle();

    expect(permissions.requested, [AppPermission.notifications]);
    expect(find.text(_l10n.permissionNotificationTitle), findsOneWidget);
  });

  testWidgets('permanentlyDenied → 按鈕變「前往設定」,呼叫 openSettings 而不是 request', (
    tester,
  ) async {
    final permissions = FakePermissions(
      initial: {
        AppPermission.notifications: PermissionOutcome.permanentlyDenied,
      },
    );

    await pump(tester, permissions);

    expect(find.text(_l10n.permissionOpenSettings), findsOneWidget);
    expect(find.text(_l10n.permissionEnable), findsNothing);
    expect(find.text(_l10n.permissionBlockedBody), findsOneWidget);

    await tester.tap(find.text(_l10n.permissionOpenSettings));
    await tester.pumpAndSettle();

    expect(permissions.openSettingsCalls, 1);
    // 規則 3:不重複 request——那不會跳對話框,使用者會以為 App 壞了。
    expect(permissions.requested, isEmpty);
  });

  testWidgets('按「稍後」→ 卡片消失,且下次建立時不再出現', (tester) async {
    final permissions = FakePermissions();

    await pump(tester, permissions);
    await tester.tap(find.text(_l10n.permissionLater));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.permissionNotificationTitle), findsNothing);
    expect(
      await store.readBool(NotificationPermissionCard.dismissedKey),
      isTrue,
    );

    // 重建一次(模擬重啟)。
    await pump(tester, FakePermissions());
    expect(find.text(_l10n.permissionNotificationTitle), findsNothing);
  });

  testWidgets('unsupported → 不顯示', (tester) async {
    final permissions = FakePermissions(
      initial: {AppPermission.notifications: PermissionOutcome.unsupported},
    );

    await pump(tester, permissions);

    expect(find.text(_l10n.permissionNotificationTitle), findsNothing);
  });
}
