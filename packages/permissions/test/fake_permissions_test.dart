import 'package:flutter_test/flutter_test.dart';
import 'package:permissions/permissions.dart';
import 'package:permissions/testing.dart';

void main() {
  test('未設定初值時視為 denied', () async {
    final permissions = FakePermissions();

    expect(
      await permissions.check(AppPermission.notifications),
      PermissionOutcome.denied,
    );
    expect(permissions.checked, [AppPermission.notifications]);
  });

  test('request 套用 requestResults 並記錄呼叫', () async {
    final permissions = FakePermissions()
      ..requestResults[AppPermission.notifications] = PermissionOutcome.granted;

    expect(
      await permissions.request(AppPermission.notifications),
      PermissionOutcome.granted,
    );
    // 狀態要跟著更新,後續 check 才拿得到新值。
    expect(
      await permissions.check(AppPermission.notifications),
      PermissionOutcome.granted,
    );
    expect(permissions.requested, [AppPermission.notifications]);
  });

  test('未設定 requestResults 時 request 沿用現值', () async {
    final permissions = FakePermissions(
      initial: {
        AppPermission.notifications: PermissionOutcome.permanentlyDenied,
      },
    );

    expect(
      await permissions.request(AppPermission.notifications),
      PermissionOutcome.permanentlyDenied,
    );
  });

  test('openSettings 計次', () async {
    final permissions = FakePermissions();

    await permissions.openSettings();
    await permissions.openSettings();

    expect(permissions.openSettingsCalls, 2);
  });

  test('Permissions 可被 FakePermissions 替換', () {
    expect(FakePermissions(), isA<Permissions>());
  });
}
