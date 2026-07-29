# 加一個權限

流程規則見 [`docs/conventions.md`](../conventions.md) 的「權限流程」四條。
這份講的是**加新權限時要動哪些檔**。

## 步驟

### 1. `AppPermission` 加一個 enum 值

[`packages/permissions/lib/src/permissions.dart`](../../packages/permissions/lib/src/permissions.dart)。

**用到才加。** 列了沒用到的權限,某些商店審查會問你為什麼要。

### 2. 對應到 `permission_handler` 的型別

同 package 的 `permission_handler_permissions.dart`,在 `_resolve()` 的
switch 補一個分支。那個 switch 是 exhaustive 的,漏了會編譯失敗——這是刻意的。

### 3. native 宣告

| 平台 | 要動的檔 |
|---|---|
| Android | [`app/android/app/src/main/AndroidManifest.xml`](../../app/android/app/src/main/AndroidManifest.xml) 加 `<uses-permission>` |
| iOS | `app/ios/Runner/Info.plist` 加對應的 `NS*UsageDescription`,**內容要是使用者看得懂的理由**(審查會看) |

通知權限的現況:Android 已加 `POST_NOTIFICATIONS`(13+ 才需要,舊版忽略);
iOS 不需要額外設定,FCM 已處理。

### 4. UI

照 [`notification_permission_card.dart`](../../features/home/lib/src/presentation/widgets/notification_permission_card.dart)
抄。那份是四條規則的活範例,四種狀態(granted / denied / permanentlyDenied /
unsupported)都有對應行為與測試。

文案走 ARB(前綴 `permission*`),改完 `(cd packages/localization && fvm flutter gen-l10n)`。

## 為什麼用 `permission_handler` 而不是自己寫 pigeon

兩端實作與 edge case(Android 的 `shouldShowRequestPermissionRationale`、
iOS 的一次性授權)都處理好了,自己寫是重造輪子。這正是
[`add-a-native-capability.md`](add-a-native-capability.md) 那句「有成熟套件
就先用套件」的實例。

介面刻意**不暴露 `permission_handler` 的型別**:上層因此不依賴第三方套件,
fake 也好寫。換套件時只要改 `PermissionHandlerPermissions` 一個檔。
