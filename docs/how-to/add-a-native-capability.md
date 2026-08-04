# How-to:新增一項原生能力(pigeon 流程)

> **先確認你真的需要走這條路。** 本庫的規範是**有成熟套件時優先用套件**——
> [`packages/permissions`](../../packages/permissions) 就是該原則的實例(包
> `permission_handler`,不自己寫 method channel)。相機、生物辨識、分享這類
> 需求多半有維護良好的 plugin,包一層介面 + fake 就夠了,做法見
> [`add-a-shared-package.md`](add-a-shared-package.md)。
>
> 只有**找不到堪用套件、需要 Dart ↔ 原生雙向通訊**時才走本文。
>
> **模板出廠沒有 `packages/native/<capability>` 範例**(評估後決定不做,見
> issue #29),本文是規範性描述,不是照抄現存檔案的走查。

## 唯一的硬規則

**feature 與 `app` 永遠不直接寫 `MethodChannel`。** 每項原生能力一個 plugin
package,channel 程式碼一律由 pigeon 產生。散落各處的 method channel 字串 key
是 Flutter 專案最容易腐爛的地方。

## 骨架

```
packages/native/<capability>/
├── pubspec.yaml            # flutter plugin 宣告 + 依賴 core(NativeException)
├── pigeons/<capability>.dart   # pigeon 定義(HostApi、資料類別)
├── lib/
│   ├── <capability>.dart   # barrel
│   ├── testing.dart        # 官方 fake(conventions.md §8.1 第 1 條要求)
│   └── src/
│       ├── generated/      # pigeon 產出,不手改,analyzer.exclude 對齊
│       ├── <capability>_api.dart    # abstract interface class
│       └── <capability>_impl.dart   # 呼叫 pigeon,轉換錯誤
├── android/ ios/           # Kotlin / Swift 實作
└── test/
```

依賴方向同其他 `packages/*`:可依賴 `core`,**不得依賴 `features/*` 或 `app`**
([`architecture.md` §2](../architecture.md))。

## 關鍵五點

**1. pubspec 必須有 plugin 宣告。** 少了它 native 端不會被註冊,runtime 一定丟
`MissingPluginException`:

```yaml
flutter:
  plugin:
    platforms:
      android: { package: com.example.<capability>, pluginClass: <Capability>Plugin }
      ios: { pluginClass: <Capability>Plugin }
```

**2. pigeon 產出 commit 進 repo**,並排除在 analyzer 之外(比照
`packages/localization/lib/src/generated/`)。CI 不跑 pigeon 產生。

**3. 錯誤一律轉成 `NativeException`。** Dart 端接住 `PlatformException`,轉成
`NativeException(code)`,**不要讓 `PlatformException` 漏到 repository 之上**
——那是全庫錯誤模型的破口([`conventions.md` §3](../conventions.md))。

**4. 必須出貨 `lib/testing.dart` 的官方 fake。** 提供介面的 package 一律如此
([`conventions.md` §8.1](../conventions.md)),否則下游只能各自手寫 mock。

**5. 第三方 SDK 的原生初始化留在 `app/android/`、`app/ios/`**,不要塞進能力
package——那是 app 的組裝責任。

## 收尾

加進根 `pubspec.yaml` 的 `workspace:`,跑 `bash tool/regen.sh`(架構文件會自動
更新)與 `bash tool/check.sh`。
