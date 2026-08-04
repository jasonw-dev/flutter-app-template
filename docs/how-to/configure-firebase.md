# How-to:設定 Firebase(推播/分析/crash 上報)

本模板已把 Firebase 隔在抽象介面後(`observability` 的 `CrashReporter`/
`AnalyticsTracker`、`push_notifications` 的 `PushNotifications`),出廠預設
**`firebaseEnabled = false`**——不接 Firebase 也能跑,DI 會走
[`app/lib/src/di/disabled_services.dart`](../../app/lib/src/di/disabled_services.dart)
的空實作。要接上真正的 Firebase 專案,依本文件操作。

## 1. 建立 Firebase 專案並跑 FlutterFire CLI

前置需求:一個 Firebase 專案(Firebase Console 建立),`firebase-tools` 與
`flutterfire_cli` 已安裝(`dart pub global activate flutterfire_cli`)。

在 `app/` 目錄(FlutterFire CLI 需要能讀到 `app/pubspec.yaml`)執行:

```
cd app
flutterfire configure --project=<firebase-project-id>
```

CLI 會互動式讓你選平台(Android/iOS)與 Firebase apps,並產生:

- `app/lib/firebase_options.dart`(Dart 端設定,含各平台的 API key 等)。
- `app/android/app/google-services.json`。
- `app/ios/Runner/GoogleService-Info.plist`。

## 2. 三環境設定檔

若已依 [`configure-native-flavors.md`](configure-native-flavors.md) 設好
flavor,每個環境(dev/stg/prod)應各自對應一個 Firebase 專案(或至少不同的
Firebase app),避免 dev 測試資料污染 prod 的 Analytics/Crashlytics。做法:

1. 對每個環境各跑一次 `flutterfire configure --project=<env-project-id>`,
   用不同輸出檔名區分,如 `firebase_options_dev.dart`、
   `firebase_options_stg.dart`、`firebase_options_prod.dart`。
2. 各環境的 `google-services.json`/`GoogleService-Info.plist` 放進對應
   flavor 的資源目錄(Android:`app/android/app/src/<flavor>/`;iOS:對應
   scheme 的 target membership)。
3. 各 `main_*.dart`(見
   [`app/lib/main_dev.dart`](../../app/lib/main_dev.dart) 等)在呼叫
   `Firebase.initializeApp()` 前(即 `bootstrap()` 內部,見
   [`app/lib/src/bootstrap.dart`](../../app/lib/src/bootstrap.dart) 第 4b
   步)改用對應環境的 `DefaultFirebaseOptions`,或直接讓 `bootstrap()`
   吃一個 `FirebaseOptions?` 參數由呼叫端傳入。

三環境各一份設定檔可同時進版控(非機密),真正機密(API key 若不想入庫)
走 `--dart-define-from-file` 機制。

## 3. `AppConfig.firebaseEnabled` 開 true 的時機

[`app/lib/src/config/app_config.dart`](../../app/lib/src/config/app_config.dart)
的 `firebaseEnabled` 出廠預設 `false`。**先完成上面兩步、確認
`google-services.json`/`GoogleService-Info.plist` 已就位,再改 true**——
`bootstrap()` 的第 4b 步(見
[`app/lib/src/bootstrap.dart`](../../app/lib/src/bootstrap.dart)):

```dart
if (config.firebaseEnabled) {
  await Firebase.initializeApp();
  await gi<BufferingCrashReporter>().attach(
    CrashlyticsCrashReporter(FirebaseCrashlytics.instance),
  );
}
```

若設定檔缺失就把 `firebaseEnabled` 改 true,`Firebase.initializeApp()` 會
在啟動期丟例外(這段例外會被 §3 步驟掛好的
`installErrorHooks` 捕捉並上報,但 app 仍可能無法正常初始化 Firebase 相關
服務)。

在各 `main_*.dart` 把對應環境的 `AppConfig(firebaseEnabled: true, ...)`
改掉;[`app/lib/main_prod.dart`](../../app/lib/main_prod.dart) 目前留有明確
註解說明「出廠預設維持 false,待專案完成 Firebase 設定後再改為 true」。

同時搭配 [`app/lib/src/di/compose_dependencies.dart`](../../app/lib/src/di/compose_dependencies.dart)——
`AnalyticsTracker`、`PushNotifications` 已依 `config.firebaseEnabled` 切換
真實 Firebase 實作與 `disabled_services.dart` 的空實作,不需要額外改動 DI
程式碼,只要 `AppConfig` 的旗標打開即可生效。

## 4. `useFakeBackend` 改 false 的時機

`firebaseEnabled` 與 `useFakeBackend`(見
[`app/lib/src/config/app_config.dart`](../../app/lib/src/config/app_config.dart))
是兩個獨立旗標,不要混為一談:

- `firebaseEnabled`:控制 Analytics/Crashlytics/推播是否接真 Firebase。
- `useFakeBackend`:控制業務 API(登入、`/items`)是否走內建假後端
  ([`app/lib/src/demo/demo_backend_adapter.dart`](../../app/lib/src/demo/demo_backend_adapter.dart))。

對接真實後端 API 時把 `useFakeBackend` 改 `false`(各 `main_*.dart` 目前皆
用預設值 `true`);這與是否啟用 Firebase 無關,可以「已接真後端但尚未接
Firebase」或反過來,兩者獨立切換。

## 5. 推播(APNs)注意事項

- iOS 推播需要在 Apple Developer 後台開通 Push Notifications capability,
  上傳 APNs 認證金鑰(`.p8`)到 Firebase 專案設定(Cloud Messaging 頁籤)。
- Xcode 專案(`app/ios/Runner.xcodeproj`)需要加上 `Push Notifications` 與
  `Background Modes → Remote notifications` capability。
- 冷啟動點擊(app 未執行時點推播開啟)由
  `PushNotifications.initialTap()` 處理(對應
  `FirebaseMessaging.instance.getInitialMessage()`),接線見
  [`app/lib/src/app.dart`](../../app/lib/src/app.dart) 的
  `_AppState.initState()`——首幀後呼叫,結果與前景點擊
  (`taps` stream)最終都經過 router 的登入守衛評估(見
  [`architecture.md` §3.3](../architecture.md))。
- 前景收到的推播由 `PushNotifications.foregroundMessages` stream 暴露
  (對應 `FirebaseMessaging.onMessage`);Android 前景不會自動顯示系統通知,
  是否呈現(banner/本地通知/靜默)由專案自行決定。注意 iOS 預設**會**在
  前景顯示系統橫幅——若專案改用 in-app 呈現,需另呼叫
  `setForegroundNotificationPresentationOptions` 關閉原生橫幅,避免雙重顯示。
- 實體裝置才收得到 APNs 推播;iOS 模擬器需 Xcode 15+ 且僅支援本機模擬推播
  (不支援真正的遠端推播測試)。

## 收尾

```
./tool/check.sh
```

`google-services.json`/`GoogleService-Info.plist`、`firebase_options*.dart`
若含機密或環境專屬資訊,依團隊政策決定是否入庫;範例占位檔案不應提交真實
專案的機密金鑰。
