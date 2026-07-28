# flutter-app-template

泛用於不同領域的 Flutter Mobile App **Starter Repo 模板**,鎖定典型
後端驅動 App(登入/會員、API 存取、列表/表單/詳情頁、推播、分析)。核心
特點:Dart 3.6+ 原生 pub workspace 強制多 package 邊界(不用 melos)、
Bloc + get_it 的完整分層架構、`tool/new_feature.dart` 產生器把樣板量吸收
掉、`tool/check.sh` 與 CI 完全同構、規則盡量由編譯器/lint/產生器執行而非
人力紀律,對 AI coding agent 協作友善(見 [`CLAUDE.md`](CLAUDE.md))。附兩個
可直接運行的示範 feature(`auth` 登入、`home` 列表/詳情)與內建假後端,
clone 下來立刻可跑,不需真實後端或 Firebase。

## 快速開始

需求:Flutter **3.44.6**(用 [FVM](https://fvm.app/) 釘選,見
[`.fvmrc`](.fvmrc))。

```bash
git clone <this-repo> my-app && cd my-app
fvm use                                   # 依 .fvmrc 安裝/切換到 Flutter 3.44.6
fvm flutter pub get                       # workspace 一次解析全部 package
fvm flutter run -t app/lib/main_dev.dart  # 跑 dev 環境
```

App 啟動後會停在登入頁,內建假後端([`app/lib/src/demo/demo_backend_adapter.dart`](app/lib/src/demo/demo_backend_adapter.dart))
接手所有 API 呼叫:

- 任意 email + 任意密碼(除了 `wrong`)可登入成功,進入首頁看到 5 筆
  demo 項目,點擊可看詳情。
- 密碼輸入 `wrong` 會登入失敗,顯示 SnackBar 錯誤訊息,停留在登入頁——
  用這組帳密可以看失敗路徑。

`stg`/`prod` 環境同理,換成對應入口:

```bash
fvm flutter run -t app/lib/main_stg.dart
fvm flutter run -t app/lib/main_prod.dart
```

新成員入門:[docs/onboarding.md](docs/onboarding.md)(約兩天的學習歷程)

## 用作專案起點:改名

模板出廠時 Android/iOS 識別碼為 `com.example.template.app`。用
`tool/rename_project.dart` 一次改掉 org、專案名稱、顯示名稱(預設
**dry-run**,只列出將變更內容不寫入;加 `--apply` 才實際寫入):

```bash
fvm dart run tool/rename_project.dart --org com.mycorp --name my_app --display-name "My App"
# 確認輸出無誤後:
fvm dart run tool/rename_project.dart --org com.mycorp --name my_app --display-name "My App" --apply
fvm flutter pub get
```

## 目錄導覽

```
app/                # 唯一可執行的 Flutter app;組裝層(DI、路由、flavor 進入點)
packages/
  foundation/        # Result、AppException、logger 介面;零依賴
  networking/        # dio 封裝、攔截器、統一錯誤轉換
  persistence/        # 本地儲存(secure storage、key-value)
  session/            # 登入狀態單一真相
  navigation/          # 跨 feature 路由路徑常數 + 型別化 route
  design_system/       # design tokens、theme、共用 UI 元件
  localization/        # 官方 gen-l10n + ARB 多語系
  observability/        # log、crash 上報、事件埋點
  push_notifications/   # 推播抽象介面 + FCM 實作
  native/<capability>/  # 原生能力插槽(出廠尚無範例,見 how-to)
features/
  auth/               # 示範:登入流程
  home/               # 示範:API 列表 + 詳情(CRUD 範本)
tool/                 # new_feature.dart、rename_project.dart、check.sh
docs/                 # 架構文件、how-to、ADR
```

## 文件索引

- [`docs/onboarding.md`](docs/onboarding.md) — 新成員入門課綱:約兩天的學習歷程,從先體驗到動手做故意犯規。
- [`CLAUDE.md`](CLAUDE.md) — AI agent 快速定位:鐵律、任務路由、指令清單。
- [`docs/architecture.md`](docs/architecture.md) — workspace 拓撲、依賴方向、關鍵鏈路。
- [`docs/conventions.md`](docs/conventions.md) — 命名、Bloc 規範、測試規範、完成的定義。
- [`docs/how-to/`](docs/how-to/) — 步驟式教學:
  [加 feature](docs/how-to/add-a-feature.md)、
  [加 API](docs/how-to/add-an-api.md)、
  [加原生能力](docs/how-to/add-a-native-capability.md)、
  [加共用 package](docs/how-to/add-a-shared-package.md)、
  [新增語系](docs/how-to/add-a-locale.md)、
  [設定原生 flavor](docs/how-to/configure-native-flavors.md)、
  [設定 Firebase](docs/how-to/configure-firebase.md)。
- [`docs/adr/`](docs/adr/) — 架構決策紀錄。
- [`app/README.md`](app/README.md) — 組裝層定位。

## 需求

- Flutter **3.44.6**(見 [`.fvmrc`](.fvmrc)),用 [FVM](https://fvm.app/) 管理版本。
- Dart SDK ^3.12.0(隨 Flutter 3.44.6 附帶)。

## License

[MIT](LICENSE)
