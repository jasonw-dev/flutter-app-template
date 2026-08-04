# How-to:新增一個 `packages/` 共用 package

適用於新增橫跨多個 feature 使用的基礎能力(如新的儲存後端、第三方 SDK
包裝)。若是「一項原生能力」,先看
[`add-a-native-capability.md`](add-a-native-capability.md)(骨架略有不同、
多一層 pigeon 流程)。若是新的業務功能,走
[`add-a-feature.md`](add-a-feature.md) 的產生器,不要放進 `packages/`。

## 1. pubspec 慣例

比照現存 package(如
[`packages/core/pubspec.yaml`](../../packages/core/pubspec.yaml)、
[`packages/integrations/pubspec.yaml`](../../packages/integrations/pubspec.yaml)):

```yaml
name: <package_name>
description: <一句話職責>
publish_to: none
resolution: workspace

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter   # 純 Dart package(如 foundation、navigation)省略此行
  foundation: any   # 依實際需要的 workspace 內部依賴

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4  # 若有測試需要
```

`resolution: workspace` 是加入 pub workspace 的必要欄位;`description`
一句話職責會被 [`docs/architecture.md`](../architecture.md) 的成員表引用,
寫清楚。

## 2. 根 `pubspec.yaml` 註冊

在根 [`pubspec.yaml`](../../pubspec.yaml) 的 `workspace:` 清單加入新
package 路徑(依字母序插入,比照現有排序):

```yaml
workspace:
  - app
  - features/auth
  - features/home
  - packages/<new_package>
  - packages/ui
  ...
```

`fvm flutter pub get` 之後 `dart_tool/package_config.json` 會納入該 package
的 resolution。

## 3. `lib/testing.dart` 慣例

若此 package 對外提供「介面」(abstract interface class、可注入的抽象型別),
必須同時提供 `lib/testing.dart` 匯出官方 fake(見
[`conventions.md` §8.1](../conventions.md)):

```dart
// lib/testing.dart
/// 測試專用入口:官方 fake 一律由此匯出(見 conventions.md §8.1)。
library;

export 'src/testing/fake_<thing>.dart';
```

範例:[`packages/core/lib/testing.dart`](../../packages/core/lib/testing.dart)
匯出 `FakeLogger`;[`packages/core/lib/testing.dart`](../../packages/core/lib/testing.dart)
匯出 `FakeTokenRefreshGateway`;[`packages/core/lib/testing.dart`](../../packages/core/lib/testing.dart)
匯出 `ScriptedAdapter` + `FakeTokenProvider`。下游測試(features、`app`)
一律用這裡的官方 fake,禁止各自手寫 mock 頂替介面。

若此 package 純粹是資料型別/工具函式(無介面),可省略 `testing.dart`。

## 4. 依賴白名單登記於 `architecture.md`

新增 workspace 內部依賴(如新 package 依賴 `foundation`,或被 `app`/某個
`features/*` 依賴)後,必須更新
[`docs/architecture.md`](../architecture.md):

1. §1 的成員表加一列(一句話職責 + 連到 `pubspec.yaml` 的連結)。
2. §2.1 的依賴白名單表加一列(該 package 依賴的 workspace 成員)。
3. §2.2 的 mermaid 依賴圖加對應的邊。

這是文件層面的登記;實際邊界由 `depend_on_referenced_packages` error 級
lint + `tool/check.sh` 第 4 步的 pubspec 依賴稽核機器強制(見
[`architecture.md` §2](../architecture.md))——`packages/*` 之間允許依賴但
必須單向,永遠不能依賴 `features/*` 或 `app`;`features/*` 永遠不能依賴其他
`features/*`。若新 package 打算被 `features/*` 依賴,反向(`packages/* →
features/*`)一律禁止,`check.sh` 會擋下。

## 收尾

```
./tool/check.sh
```

第 4 步的依賴稽核與第 6 步的 `flutter analyze` 會驗證新 package 沒有違反
依賴方向;若該 package 有 `test/` 目錄,第 7 步會自動納入逐 package 測試。
