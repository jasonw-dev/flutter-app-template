# flutter-app-template

後端驅動型 Flutter App 的 **Starter Repo 模板**——登入/會員、API 存取、
列表/表單/詳情頁、推播、分析。

給要開新專案、且希望架構規則由機器而不是人力紀律來守的團隊。最大特點是
**feature 之間由 pub workspace 強制的物理隔離**:A 功能永遠 import 不到 B
功能,不是靠自律,是 pubspec 加 lint 擋住。

clone 下來立刻可跑(內建假後端,不需真實後端或 Firebase)。細節見下方
「文件導覽」。

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

## 我要改 X,該去哪?

| 我要做的事 | 去哪 |
|---|---|
| 改文字/翻譯 | `packages/localization/lib/src/arb/app_*.arb`,改完跑 `bash tool/regen.sh` |
| 改主題色、字級、間距 | `packages/ui/lib/src/tokens.dart`、`theme.dart` |
| 加一個共用元件 | `packages/ui/lib/src/components/` |
| 加一個頁面 | 該 feature 的 `lib/src/presentation/pages/` + 同 feature 的 `routes.dart` |
| 加一支 API | 該 feature 的 `lib/src/data/repositories/*_impl.dart`(透過 `ApiClient`) |
| 加一整個新功能模組 | `fvm dart run tool/new_feature.dart <name>` |
| 加一個表單 | 照 `features/auth/.../login_page.dart` 抄(`Form` + `Validators`) |
| 加一個權限 | `packages/permissions` 的 `AppPermission`,步驟見 [how-to](docs/how-to/add-a-permission.md) |
| 改 API base URL | `app/lib/src/config/app_config.dart` 與 `app/lib/main_*.dart` |
| 從假後端接到真後端 | `app/lib/main_*.dart` 的 `AppConfig(useFakeBackend: false)` |
| 改 App 啟動流程 | `app/lib/src/bootstrap.dart` |
| 改「未登入要導去哪」 | `app/lib/src/router/app_router.dart` 的 `redirect` |
| 接強制更新/維護模式 | 實作 `StartupGate` 並換掉 DI 一行,見 [how-to](docs/how-to/add-force-update.md) |
| 改 token 失效的處理 | `packages/core/lib/src/session/session_manager.dart` |
| 讓某頁能被推播/deep link 開啟 | `packages/core/lib/src/navigation/route_paths.dart` 的 `ExternalAllowedRoutes` |
| 加/改 CI 檢查 | `tool/check.sh`(CI 直接呼叫它,不必改 workflow) |

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
app/                  # 唯一可執行的 Flutter app;組裝層(DI、路由、flavor 進入點)
packages/
  core/               # 技術基礎設施:Result/例外、網路、儲存、session、
                      #   observability、路由契約、推播介面。不含 UI widget
  ui/                 # design tokens、theme、共用 UI 元件
  localization/       # 官方 gen-l10n + ARB 多語系
  permissions/        # 權限請求的統一介面(不暴露 permission_handler 型別)
  integrations/       # Firebase(analytics/crashlytics/messaging)。可選成員,
                      #   不用 Firebase 就整包移除(見 how-to/remove-firebase.md)
  native/<capability>/  # 原生能力插槽(出廠尚無範例,見 how-to)
features/
  auth/               # 示範:登入流程
  home/               # 示範:API 列表 + 詳情(CRUD 範本)
tool/                 # new_feature.dart、rename_project.dart、check.sh
docs/                 # 架構文件、how-to、ADR
```

一句話心智模型:**技術基礎設施放 `core`,共用 UI 元件放 `ui`,文案放
`localization`,其餘都在自己的 feature 裡。**

## 文件導覽

按閱讀順序與時間成本排列:

1. **本 README**(5 分鐘)—— 跑起來、知道東西放哪
2. [`docs/onboarding.md`](docs/onboarding.md)(半天)—— 第一次改 code 前讀
3. [`docs/how-to/`](docs/how-to/)(用到再查)—— 加 API、加語系、加權限、配 Firebase、發版等操作步驟
4. [`docs/architecture.md`](docs/architecture.md) 與 [`docs/conventions.md`](docs/conventions.md)(參考書)—— **規則的權威來源**,遇到爭議時查。前者講「東西放哪、怎麼連」,後者講「怎麼寫」
5. [`docs/adr/`](docs/adr/)(考古用)—— 想知道「為什麼是這樣設計」時讀,含後續修訂
6. [`docs/archive/`](docs/archive/) —— 模板建立當時的規格與階段計畫,**非現行規則**

AI coding agent 從 [`CLAUDE.md`](CLAUDE.md) 開始([`AGENTS.md`](AGENTS.md) 明文指向它)。

## 常見狀況

| 情況 | 怎麼辦 |
|---|---|
| 改了 ARB,CI 說 l10n 漂移 | `(cd packages/localization && fvm flutter gen-l10n)`,把產物納入 commit |
| 加了 package 依賴,CI 說架構文件漂移 | `fvm dart run tool/gen_arch_docs.dart`,把 `docs/architecture.md` 的變更納入 commit |

## 需求

- Flutter **3.44.6**(見 [`.fvmrc`](.fvmrc)),用 [FVM](https://fvm.app/) 管理版本。
- Dart SDK ^3.12.0(隨 Flutter 3.44.6 附帶)。

## License

[MIT](LICENSE)
