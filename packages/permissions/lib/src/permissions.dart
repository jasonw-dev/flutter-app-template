/// 權限狀態。
///
/// 刻意**不直接暴露 `permission_handler` 的型別**:讓上層不依賴第三方套件,
/// 也讓 fake 好寫。
enum PermissionOutcome {
  /// 已授權。
  granted,

  /// 本次拒絕,之後還可以再問。
  denied,

  /// 永久拒絕(使用者選了「不再詢問」),**只能引導去系統設定**。
  permanentlyDenied,

  /// 此平台不支援(例如 iOS 沒有的權限)。
  unsupported,
}

/// App 需要的權限種類。
///
/// **用到才加,不要一次列滿。** 列了沒用到的權限,某些商店審查會問。
enum AppPermission {
  /// 通知權限(Android 13+ 的 POST_NOTIFICATIONS / iOS 的推播授權)。
  notifications,
}

/// 權限請求契約。
///
/// 流程規則見 `docs/conventions.md` 的「權限流程」一節,四條都對應一種
/// 常見的做錯方式。
abstract interface class Permissions {
  /// 查詢目前狀態,**不會**跳出系統對話框。
  Future<PermissionOutcome> check(AppPermission permission);

  /// 請求權限,可能跳出系統對話框。
  Future<PermissionOutcome> request(AppPermission permission);

  /// 開啟系統設定頁([PermissionOutcome.permanentlyDenied] 時的唯一出路)。
  Future<void> openSettings();
}
