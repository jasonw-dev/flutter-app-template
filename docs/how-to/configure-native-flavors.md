# How-to:設定原生 flavor(dev/stg/prod)

> **手動選配文件。** 本模板出廠時三個 `main_*.dart` 進入點已可直接執行
> (`flutter run -t app/lib/main_dev.dart` 等),Android/iOS 的
> productFlavors/schemes **尚未設定**。三環境要在同一台
> 裝置並存、或要用 `flutter run --flavor` 切換原生層設定(如不同 bundle id、
> 不同 `google-services.json`)時,才需要本文件的手動步驟。

## 背景

三環境的設定機制:

> 三環境 `dev / stg / prod`,各一個 `main_*.dart`,對應 Android product
> flavors 與 iOS schemes;bundle id 加後綴,三環境可同機並存。

Dart 端三個入口已存在:

- [`app/lib/main_dev.dart`](../../app/lib/main_dev.dart)
- [`app/lib/main_stg.dart`](../../app/lib/main_stg.dart)
- [`app/lib/main_prod.dart`](../../app/lib/main_prod.dart)

各自建構不同 `AppConfig`(`environment`、`apiBaseUrl`)後呼叫
`bootstrap()`。目前 Android `applicationId` 與 iOS bundle id 都固定為
`com.example.template.app`(見
[`app/android/app/build.gradle.kts`](../../app/android/app/build.gradle.kts)),
三個 `main_*.dart` 目前打包出來仍是同一個原生識別碼——這是本文件要補上的
缺口。

## Android:productFlavors + applicationIdSuffix

編輯 [`app/android/app/build.gradle.kts`](../../app/android/app/build.gradle.kts),
在 `android {}` 區塊加入:

```kotlin
android {
    // ...既有設定...

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "MyApp Dev")
        }
        create("stg") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            versionNameSuffix = "-stg"
            resValue("string", "app_name", "MyApp Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "MyApp")
        }
    }
}
```

`applicationId` 維持根設定(`com.example.template.app`,或
`rename_project.dart` 改名後的值);`applicationIdSuffix` 讓 dev/stg 疊加
後綴(`com.example.template.app.dev`),prod 不加後綴,三者可同機並存。

`AndroidManifest.xml` 的 `android:label` 若寫死字串,改引用
`@string/app_name` 才會吃到上面 `resValue` 的 flavor 差異。

執行方式:

```
flutter run --flavor dev -t app/lib/main_dev.dart
flutter run --flavor stg -t app/lib/main_stg.dart
flutter run --flavor prod -t app/lib/main_prod.dart
```

## iOS:schemes + xcconfig

iOS 沒有 Gradle 式 flavor,慣例作法是三個 Xcode scheme + 三份 xcconfig,
在 `app/ios/` 內手動建立(Xcode GUI 或 `xcodebuild` 皆可):

1. 在 `app/ios/Flutter/` 建立 `Dev.xcconfig`、`Stg.xcconfig`、
   `Prod.xcconfig`,各自 `#include "Generated.xcconfig"` 後覆寫:

   ```
   // Dev.xcconfig
   #include "Generated.xcconfig"
   PRODUCT_BUNDLE_IDENTIFIER = com.example.template.app.dev
   PRODUCT_NAME = MyApp Dev
   ```

   stg 同理疊 `.stg` 後綴,prod 沿用不疊後綴的基底 bundle id。

2. 在 Xcode 開啟 `app/ios/Runner.xcworkspace`,對每個
   Debug/Release/Profile build configuration 建立三份對應變體(Xcode 的
   「Duplicate Configuration」),分別指到上述 xcconfig。

3. Product → Scheme → Manage Schemes,建立 `dev`/`stg`/`prod` 三個 scheme,
   各自的 build configuration 對應到步驟 2 建立的變體。

4. 執行方式:

   ```
   flutter run --flavor dev -t app/lib/main_dev.dart
   flutter run --flavor stg -t app/lib/main_stg.dart
   flutter run --flavor prod -t app/lib/main_prod.dart
   ```

   Flutter 的 `--flavor` 參數在 iOS 對應到同名 scheme。

## 與三個 `main_*.dart` 的對應

| Dart 入口 | `AppConfig.environment` | Android flavor | iOS scheme | bundle id 後綴 |
|---|---|---|---|---|
| [`main_dev.dart`](../../app/lib/main_dev.dart) | `AppEnvironment.dev` | `dev` | `dev` | `.dev` |
| [`main_stg.dart`](../../app/lib/main_stg.dart) | `AppEnvironment.stg` | `stg` | `stg` | `.stg` |
| [`main_prod.dart`](../../app/lib/main_prod.dart) | `AppEnvironment.prod` | `prod`(可省略,見下) | `prod` | (無) |

`-t app/lib/main_<env>.dart` 決定跑哪個 Dart 入口(決定 `AppConfig` 與
`bootstrap()` 走哪支);`--flavor <env>` 決定 Android/iOS 原生層走哪個
flavor/scheme(決定 applicationId/bundle id、原生資源、`google-services.json`
/`GoogleService-Info.plist` 選用哪份,見 [`configure-firebase.md`](configure-firebase.md))。
兩者要一致選同一環境,否則會出現「Dart 端打 dev API,但原生層是 prod
bundle id」的錯配。

未設定 flavor 前,`flutter run -t app/lib/main_dev.dart`(不帶
`--flavor`)仍可正常執行,只是三環境會共用同一個原生 bundle id/applicationId
(無法同機並存三份 app)。
