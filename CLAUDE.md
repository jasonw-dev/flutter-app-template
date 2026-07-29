# CLAUDE.md

本檔案給 AI coding agent 快速定位:鐵律(不可違反)、任務路由(去哪找/改)、
常用指令。完整規則見 [`docs/conventions.md`](docs/conventions.md) 與
[`docs/architecture.md`](docs/architecture.md);設計背景見
[`docs/superpowers/specs/2026-07-11-flutter-app-template-design.md`](docs/superpowers/specs/2026-07-11-flutter-app-template-design.md)。

## 鐵律清單

1. **依賴四規則**(`docs/architecture.md` §2):`core` 是底層,只依賴第三方
   套件與 Flutter,不依賴其他 workspace 成員(**注意 `core` 含 Flutter**,
   切線是「技術基礎設施 vs 業務功能」而非「碰不碰 Flutter」,見 ADR-0006);
   `packages/*` 間單向依賴且列在依賴圖,永遠不依賴 `features/*`/`app`;
   `features/*` 可依賴 `packages/*`,永遠不依賴其他 feature 或 `app`;
   `app` 什麼都能依賴,自身幾乎不含邏輯。`tool/check.sh` 第 4 步機器強制,
   違規 CI 失敗。

   workspace 成員只有 7 個:`app`、`packages/core`、`packages/ui`、
   `packages/localization`、`packages/integrations`(可選)、`features/auth`、
   `features/home`。心智模型:**技術基礎設施放 `core`,共用 UI 元件放 `ui`,
   文案放 `localization`,其餘都在自己的 feature 裡。**
2. **Cubit 或 Bloc 依觸發來源數量決定**:單一觸發來源(只有使用者在這頁的
   操作)用 Cubit;兩個以上觸發來源(例如同時被使用者操作與 repository 的
   stream 推送驅動)或需要 `transformer` 做 debounce/droppable 用 Bloc。
   判準之外的選擇 code review 退回。State 用 `sealed class`,UI 用 exhaustive
   `switch` 渲染整頁三態(單一旗標/副作用可用 `is`);bloc/cubit 之間禁止
   互相引用;檔案不 import Flutter。六鐵律全文見
   [`docs/conventions.md` §2](docs/conventions.md)。
3. **Result 單一路徑**:repository 一律回傳 `Result<T, AppException>`;
   禁止 bloc/UI 用 `try/catch` 接 raw exception;`AppException` 子類清單
   定死,不自創例外型別(見 [`docs/conventions.md` §3](docs/conventions.md))。
4. **測試用官方 fake**:提供介面的 package 一律從 `lib/testing.dart` 匯出
   fake,下游測試禁止各自手寫 mock;測試替身統一 `mocktail` + `bloc_test`；
   測試文案走 `AppLocalizationsEn()` 等 l10n 實例，不硬編字串；widget 測試
   選取器用 `find.byType(<公開元件型別>)`（見
   [`docs/conventions.md` §8](docs/conventions.md)）。
5. **`ignore` 附原因**:每處逐行 `// ignore: 規則 -- 原因`;`tool/check.sh`
   第 2 步以 grep 擋無原因的 ignore。
6. **`lib/src/` 一切私有**:feature/package 只透過 barrel file
   (`lib/<name>.dart`)對外輸出;`lib/src/` 內容不得被其他 package/feature
   直接 import。
7. **分支規範**:永不直接 push `master`/`develop`;一律 `feature` 分支 + PR
   (見 [`docs/conventions.md` §分支與 PR](docs/conventions.md))。

## 任務路由表

| 任務 | 去哪 |
|---|---|
| 加一個新 feature | `fvm dart run tool/new_feature.dart <name>` 產生骨架 + 接線,後續步驟見 [`docs/how-to/add-a-feature.md`](docs/how-to/add-a-feature.md) |
| 加一支 API(既有 feature 內) | [`docs/how-to/add-an-api.md`](docs/how-to/add-an-api.md)(DTO→repository→bloc→page 三態→測試,以 `features/home` 的 `fetchItems` 為範例) |
| 加一項原生能力 | [`docs/how-to/add-a-native-capability.md`](docs/how-to/add-a-native-capability.md)(pigeon 流程;規範性文件,本模板尚無範例) |
| 加一個共用 `packages/` 成員 | [`docs/how-to/add-a-shared-package.md`](docs/how-to/add-a-shared-package.md) |
| 設定 Android flavor / iOS scheme | [`docs/how-to/configure-native-flavors.md`](docs/how-to/configure-native-flavors.md)(手動選配,出廠未附) |
| 接 Firebase(推播/分析/crash) | [`docs/how-to/configure-firebase.md`](docs/how-to/configure-firebase.md) |
| 改文案 | 改 `packages/localization/lib/src/arb/app_*.arb` 的 key,執行 `cd packages/localization && fvm flutter gen-l10n` regen |
| 新增語系 | [`docs/how-to/add-a-locale.md`](docs/how-to/add-a-locale.md) |
| 架構問題(依賴方向、關鍵鏈路、package 職責) | [`docs/architecture.md`](docs/architecture.md) |
| 命名/檔案位置/Bloc/DI/測試規範 | [`docs/conventions.md`](docs/conventions.md) |

## 指令清單

```bash
./tool/check.sh                                  # 與 CI 完全同構的本機全檢查
cd packages/localization && fvm flutter gen-l10n  # ARB 改動後 regen 產生檔
cd features/home && fvm flutter test              # 單一 package 測試(任一 package/features/app 同理)
fvm dart run tool/new_feature.dart <name>          # 產生新 feature 骨架 + 自動接線
fvm dart run tool/rename_project.dart --org <反向域名> --name <snake_case> [--apply]  # 樣板改名(預設 dry-run)
fvm flutter run -t app/lib/main_dev.dart           # 跑 dev 環境(stg/prod 同理換檔名)
```
