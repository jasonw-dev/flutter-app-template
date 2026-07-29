import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:permissions/src/permissions.dart';

/// 以 `permission_handler` 實作的 [Permissions]。
///
/// 選套件而不是自己寫 pigeon 的理由:兩端實作與 edge case(Android 的
/// `shouldShowRequestPermissionRationale`、iOS 的一次性授權)都處理好了,
/// 自己寫是重造輪子。這也正是 `docs/how-to/add-a-native-capability.md`
/// 那句「有成熟套件就先用套件」的實例。
class PermissionHandlerPermissions implements Permissions {
  /// 建立實作。
  const PermissionHandlerPermissions();

  @override
  Future<PermissionOutcome> check(AppPermission permission) async =>
      _map(await _resolve(permission).status);

  @override
  Future<PermissionOutcome> request(AppPermission permission) async =>
      _map(await _resolve(permission).request());

  @override
  Future<void> openSettings() => ph.openAppSettings();

  ph.Permission _resolve(AppPermission permission) => switch (permission) {
    AppPermission.notifications => ph.Permission.notification,
  };

  PermissionOutcome _map(ph.PermissionStatus status) => switch (status) {
    ph.PermissionStatus.granted ||
    ph.PermissionStatus.limited ||
    ph.PermissionStatus.provisional => PermissionOutcome.granted,
    ph.PermissionStatus.permanentlyDenied =>
      PermissionOutcome.permanentlyDenied,
    ph.PermissionStatus.restricted => PermissionOutcome.unsupported,
    ph.PermissionStatus.denied => PermissionOutcome.denied,
  };
}
