# 移除 Firebase

模板出廠預設 `firebaseEnabled: false`(見
[`app/lib/src/config/app_config.dart`](../../app/lib/src/config/app_config.dart)),
但四個 Firebase SDK 仍在依賴圖裡:Android 端進 gradle、iOS 端進 SPM,
APK/IPA 體積因此增加,native build 也跟著要求設定檔。

不需要 Firebase 的專案照以下四步移除。**這不是「零改動即可移除」,而是
「移除範圍收斂到四個明確位置」。**

## 步驟

### 1. 移除 workspace 成員

根 [`pubspec.yaml`](../../pubspec.yaml) 的 `workspace:` 清單刪掉
`packages/integrations` 那一行,然後:

```bash
rm -rf packages/integrations
```

### 2. `app/pubspec.yaml` 移除依賴

刪掉 `integrations: any` 那一行。

### 3. `app/lib/src/bootstrap.dart`

刪掉這一段與對應的 `import 'package:integrations/integrations.dart';`:

```dart
if (config.firebaseEnabled) {
  await initializeFirebase(gi<BufferingCrashReporter>());
}
```

### 4. `app/lib/src/di/compose_dependencies.dart`

把 `AnalyticsTracker` 與 `PushNotifications` 兩處註冊改成無條件使用停用實作,
並刪掉 `integrations` 的 import:

```dart
..registerLazySingleton<AnalyticsTracker>(
  () => const DisabledAnalyticsTracker(),
)
..registerLazySingleton<PushNotifications>(
  () => const DisabledPushNotifications(),
);
```

`DisabledAnalyticsTracker` 與 `DisabledPushNotifications` 已存在於
[`app/lib/src/di/disabled_services.dart`](../../app/lib/src/di/disabled_services.dart),
正是為此準備的。

## 驗證

```bash
fvm flutter pub get
bash tool/check.sh      # 應全綠
```

`AppConfig.firebaseEnabled` 這個旗標可以留著(它現在永遠是 false,不影響
任何行為),也可以順手刪掉——那屬於專案自己的清理,不影響上述四步的正確性。

## 為什麼介面留在 `core`

`CrashReporter`、`AnalyticsTracker`、`AppLogger`、`PushNotifications` 這些
**介面**住在 `packages/core`,`packages/integrations` 只有 **Firebase 實作**。
這條切線就是「移除 Firebase 不需要改動任何 feature」的原因:feature 只認得
介面,換掉實作對它們是透明的。
