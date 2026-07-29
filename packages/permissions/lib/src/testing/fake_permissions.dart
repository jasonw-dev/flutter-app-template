import 'package:permissions/src/permissions.dart';

/// [Permissions] 的官方 fake。
class FakePermissions implements Permissions {
  /// 以每個權限的初始狀態建立;未指定者視為 [PermissionOutcome.denied]。
  FakePermissions({Map<AppPermission, PermissionOutcome>? initial})
    : _states = {...?initial};

  final Map<AppPermission, PermissionOutcome> _states;

  /// `request()` 被呼叫時要回傳的結果;未設定時沿用現值。
  final Map<AppPermission, PermissionOutcome> requestResults = {};

  /// `check()` 的呼叫紀錄。
  final List<AppPermission> checked = [];

  /// `request()` 的呼叫紀錄。
  final List<AppPermission> requested = [];

  /// `openSettings()` 的呼叫次數。
  int openSettingsCalls = 0;

  @override
  Future<PermissionOutcome> check(AppPermission permission) async {
    checked.add(permission);
    return _states[permission] ?? PermissionOutcome.denied;
  }

  @override
  Future<PermissionOutcome> request(AppPermission permission) async {
    requested.add(permission);
    final next = requestResults[permission];
    if (next != null) {
      _states[permission] = next;
    }
    return _states[permission] ?? PermissionOutcome.denied;
  }

  @override
  Future<void> openSettings() async => openSettingsCalls++;
}
