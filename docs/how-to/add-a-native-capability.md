# How-to:新增一項原生能力(pigeon 流程)

> **本模板出廠尚無任何 `packages/native/<capability>` 範例。** 本文件為
> **規範性(prescriptive)文件**——描述應遵循的流程與骨架形狀,而非「照抄現存
> 檔案」的走查(架構定義了插槽位置,但實作留給實際需求出現時再補)。

## 何時需要一個新的 native package

規則:「features 永遠不直接碰 `MethodChannel`。每項原生能力一個 plugin package,
channel 程式碼一律用 pigeon 產生;第三方 SDK 的原生初始化設定留在
`app/android/`、`app/ios/`,Dart 端存取一律透過 `packages/` 抽象介面。」

換言之:任何需要 Dart↔原生雙向通訊的能力(生物辨識、原生分享、背景任務…),
一律新建 `packages/native/<capability>`,不得在 feature 或 `app` 裡手寫
`MethodChannel`。

## 骨架

```
packages/native/<capability>/
├── pubspec.yaml                       # 依賴 foundation(NativeException);flutter plugin
├── pigeons/
│   └── <capability>.dart              # pigeon 定義檔(HostApi/FlutterApi、資料類別)
├── lib/
│   ├── <capability>.dart              # barrel:匯出 Dart 介面 + 產生的訊息型別
│   ├── testing.dart                   # 官方 fake(測試規範第 1 條)
│   └── src/
│       ├── generated/                 # pigeon 產出,不手改(比照 localization 的
│       │                              # lib/src/generated/ 慣例,analyzer.exclude
│       │                              # 對齊)
│       ├── <capability>_api.dart      # Dart 對外介面(abstract interface class)
│       ├── <capability>_impl.dart     # 呼叫 pigeon 產生的 Host API,轉換錯誤
│       └── testing/
│           └── fake_<capability>_api.dart
├── android/                            # Kotlin 端 Host API 實作
├── ios/                                 # Swift 端 Host API 實作
└── test/
    └── <capability>_impl_test.dart
```

依賴方向與其他 `packages/*` 相同:可依賴 `foundation`(取用
`NativeException`),不得依賴 `features/*` 或 `app`(見
[`../architecture.md`](../architecture.md) §2)。

## 步驟

### 1. 建立 package 骨架

比照 [`add-a-shared-package.md`](add-a-shared-package.md) 的 `packages/`
新成員步驟(pubspec 慣例、根 workspace 註冊),差異在於 `packages/native/`
底下多一層 `<capability>` 目錄,且要以 `flutter create --template=plugin`
或手動建立 plugin 骨架(含 `android/`、`ios/` 原生專案骨架)。

### 2. 定義 pigeon 訊息與 API(`pigeons/<capability>.dart`)

pigeon 定義檔用 Dart 語法描述訊息型別與 `HostApi`(Dart→原生)/
`FlutterApi`(原生→Dart),例如:

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/generated/<capability>.g.dart',
  kotlinOut: 'android/.../<Capability>Api.g.kt',
  swiftOut: 'ios/Classes/<Capability>Api.g.swift',
))
@HostApi()
abstract class <Capability>HostApi {
  bool isAvailable();
  <Result>Data perform(<Args>Data args);
}
```

執行 `dart run pigeon --input pigeons/<capability>.dart` 產生
`lib/src/generated/` 與對應的 Kotlin/Swift 檔案。**channel 程式碼一律用
pigeon 產生,禁止手寫 `MethodChannel`**。

### 3. Dart 介面包裝

`lib/src/<capability>_api.dart` 定義對外抽象介面(feature 只認這層,不認
pigeon 產生的型別):

```dart
abstract interface class <Capability>Api {
  Future<Result<bool>> isAvailable();
  Future<Result<ResultType>> perform(ArgsType args);
}
```

`lib/src/<capability>_impl.dart` 實作該介面,呼叫 pigeon 產生的 Host API,
並把原生端拋出的例外轉換為 `Result`(見下一步)。

### 4. `NativeException` 轉換

原生端呼叫失敗時(pigeon 產生的 API 呼叫拋出 `PlatformException` 或 pigeon
自訂的錯誤型別),`<capability>_impl.dart` 必須捕捉並轉換為 `foundation` 定義
的 `NativeException(code)`(見
[`packages/core/lib/src/foundation/exceptions.dart`](../../packages/core/lib/src/foundation/exceptions.dart)):

```dart
@override
Future<Result<ResultType>> perform(ArgsType args) async {
  try {
    final data = await _hostApi.perform(args.toPigeon());
    return Result.success(data.toEntity());
  } on PlatformException catch (e, st) {
    return Result.failure(
      NativeException(code: e.code, cause: e, stackTrace: st),
    );
  } on Object catch (e, st) {
    return Result.failure(
      NativeException(code: 'unknown', cause: e, stackTrace: st),
    );
  }
}
```

這與 `networking` 的 `mapDioException()`(見
[`../conventions.md` §3](../conventions.md))是同一種責任分工:原生呼叫的
錯誤收攏發生在這個 package 內,上層(repository、bloc)只會看到
`AppException`,一律走 `Result`。

### 5. 官方 fake(`lib/testing.dart`)

比照測試規範第 1 條(見 [`../conventions.md` §8.1](../conventions.md)):提供
介面的 package 必須同時從 `lib/testing.dart` 匯出官方 fake,供下游 feature
測試使用,禁止各自手寫 mock:

```dart
// lib/testing.dart
library;

export 'src/testing/fake_<capability>_api.dart';
```

`FakeAcapabilityApi` 實作 `<Capability>Api`,以可設定的回傳值/例外驅動,
供 feature 端 `bloc_test`/widget test 直接使用(不透過 mocktail mock 原生
呼叫)。

### 6. 平台端初始化留在 `app/`

第三方 SDK 若需要原生端初始化設定(如 API key、原生 SDK bootstrap),放在
`app/android/`、`app/ios/`,`packages/native/<capability>`
只放「呼叫」邏輯,不放全域初始化。

### 7. `app` 組裝

在 `app/lib/src/di/compose_dependencies.dart` 註冊
`<Capability>Api`(`registerLazySingleton`,比照其他 `packages/*` 抽象介面的
注入方式)。feature 端一律依賴 `<Capability>Api` 抽象型別,不直接 import
`_impl.dart`。

## 收尾

```
./tool/check.sh
```

新增原生能力後,若涉及 CI 環境無法執行原生建置(如缺 Xcode/Android SDK),
在該 package 的 `test/` 內針對 Dart 端邏輯(轉換函式、`NativeException`
映射)寫測試,原生端(Kotlin/Swift)測試不屬於本模板 CI 範圍。
