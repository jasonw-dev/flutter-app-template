# Changelog

本檔案記錄每次 release 的重點變更;格式依循 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/),版本依循 [SemVer](https://semver.org/lang/zh-TW/)。維護方式見 `docs/conventions.md` 的「分支與 PR 規範」。

## [0.6.0] - 2026-07-29

deep link(#37)與文件重整(#23)。**#15 總表除了三項需要外部資源或實機
驗證的之外全部完成。**

### Added

- **deep link 的 native 骨架(#37)**:Android intent-filter 與 iOS
  associated-domains,網域一律用 `example.com` 佔位符。**推播與 deep link
  共用同一份白名單**(`ExternalAllowedRoutes`)——安全防護只蓋住一半等於
  沒蓋。校驗只檢查第一次導航(冷啟動的初始路由);刻意不用啟發式猜「這次
  導航是不是外部來的」,猜錯會誤擋內部導航。暖啟動的已知缺口與補法寫在
  `docs/how-to/configure-deep-links.md`。
- **`tool/regen.sh`(#23)**:把「改 ARB 要 gen-l10n、改 pubspec 要
  gen_arch_docs」兩條各自獨立的肌肉記憶收成一條指令。
- **`tool/check.sh` markdown 連結檢查(#23)**:掃全部 `.md` 的相對連結,
  指向不存在的路徑就紅燈。取代「逐一 ls 確認」的人力紀律。啟用當下就抓到
  **7 條**由先前重構造成的死連結。步驟數 12 → 13。
- **`tool/guard.sh` 的 CLAUDE.md 正反向斷言(#23)**:防止 AI agent 的唯一
  入口文件再次與現實脫節。

### Changed

- **文件權威來源轉移(#23)**:`architecture.md`(東西放哪、怎麼連)與
  `conventions.md`(怎麼寫)各自成為權威來源,28 處指向設計規格的交叉引用
  全部處理掉。`docs/superpowers` → `docs/archive`(內容一行未刪,標示為
  歷史紀錄)。README 開頭改短,新增「我要改 X,該去哪?」速查表與
  「文件導覽」。CLAUDE.md 全面校正並新增兩條鐵律。

### 未完成

- **#32 golden + integration**:PR #75 已完成全部程式碼,`integration` job
  已在 CI 跑綠(並順帶修好兩個既有的 Android 建置失敗:AGP 8.7.0 → 8.9.1、
  Kotlin 1.8.22 → 2.2.0)。**只差 golden png**——規格上必須由 CI 的
  `update-goldens` job 產生,需手動觸發一次。
- **#33 / #35**:依賴 #32 定案。
- **#29 pigeon**:驗收要求兩個模擬器實跑,暫緩。
- **#28 / #39**:需要 keystore 與 GitHub Secrets。

## [0.5.0] - 2026-07-29

P2 主體與部分 P3(#24 #25 #26 #27 #34 #36 #38)。補上埋點、推播安全、啟動
gate、重試策略、權限樣板,並把架構文件從手寫改為由 pubspec 產生。

### Added

- **自動 screen tracking(#26)**:`app` 掛 `AnalyticsNavigatorObserver`,
  所有頁面自動涵蓋,feature 端零手動呼叫。三條路由補上 `name`。
  先前 `AnalyticsTracker` 註冊完全庫零呼叫點。
- **推播路徑白名單(#25)**:`PushAllowedRoutes` 拆 `exact` / `subtrees`,
  **預設精確比對、子樹要明確 opt-in**——現有已登入頁全掛在 `/home` 的
  ShellRoute 底下,前綴比對等於放行整個 App。query 與 fragment 一律丟棄,
  被拒路徑記 warning。
- **啟動 gate(#27)**:強制更新 / 維護模式的**機制**出貨,判斷依據留成
  擴充點(實作 `StartupGate`、換掉 DI 一行,不必改 bootstrap 或 router)。
  gate 排在登入守衛之前(否則維護模式對未登入者無效);檢查失敗一律放行
  (把使用者鎖在門外的代價遠大於漏擋一次);回前景時重新評估。
- **重試策略(#38)**:`RetryInterceptor` 四條規則——只重試冪等方法、
  只重試可能會好的錯誤、429 用 `Retry-After`、cancel 不重試。退避帶 jitter。
  `createPlainDio`(token refresh)一律不重試。
- **權限流程樣板(#36)**:新增 `packages/permissions`,四條規則 + 通知權限
  活範例(四種狀態都有對應行為)。介面不暴露 `permission_handler` 型別。
- **架構文件由 pubspec 產生(#34)**:`tool/gen_arch_docs.dart` + `check.sh`
  漂移檢查,比照 l10n 的做法。手寫的依賴表在本次之前**已經是過期的**。

### Changed

- **`SessionManager._emit` 改為無條件發布(#24)**:原本用 `runtimeType`
  去重,一旦 `SessionAuthenticated` 加欄位(例如 `userId`),「換帳號」就會
  靜默失效。拿掉去重,不加 `==`——`redirect` 冪等,承受得起重複事件。
- `tool/check.sh` 步驟數 11 → 12。

### 未完成

- **#29 pigeon 原生能力示範**:驗收要求兩個模擬器實跑(`MissingPluginException`
  只有跑起來才會出現),暫緩,理由見該 issue 的留言。
- **#28 / #39 Android 發版與體積預算**:需要 keystore 與 GitHub Secrets。

## [0.4.0] - 2026-07-29

P1 主體(#19 #20 #21 #22 #30 #31)。workspace 從 12 個成員收斂為 7 個,
狀態容器的選擇從「一律 Bloc」改為寫死的判準,並補上分頁與表單兩份樣板。
文件重整(#23)刻意留到最後,因為前面每一項都會改動文件內容。

### Changed

- **workspace 收斂為 4 + N(#19 #20 #21,ADR-0006)**:`foundation` +
  `networking` + `persistence` + `session` + `observability` + `navigation`
  合併為 `packages/core`(內部以資料夾分區);`design_system` 更名為
  `packages/ui`;`push_notifications` 與 Firebase 實作收成**可選成員**
  `packages/integrations`。心智模型:技術基礎設施放 `core`,共用 UI 元件放
  `ui`,文案放 `localization`,其餘都在自己的 feature 裡。
  介面留在 `core`、實作進 `integrations`,「移除 Firebase」因此不需要改動
  任何 feature(步驟見 `docs/how-to/remove-firebase.md`)。
  feature 專屬的型別化 route 下放到各 feature 的 `lib/src/routes/`,共用處
  只留路徑常數與 `AppRoute` 契約。
  已知代價:`foundation` 失去純 Dart 零依賴性質;`core` 內部分層邊界降級為
  資料夾自律。`features/*` 之間的隔離完全未動。
- **狀態容器判準(#22)**:`一律 Bloc,不用 Cubit` 改為依觸發來源數量決定
  ——單一觸發來源用 Cubit,兩個以上或需要 `transformer` 用 Bloc。
  `LoginBloc` → `LoginCubit`、`ItemDetailBloc` → `ItemDetailCubit`;
  `ItemListBloc` 維持 Bloc 作為對照組。產生器改產 Cubit。
- **`refreshItems()` 語意改為「回到第一頁」(#30)**,配合 cursor 分頁。

### Added

- **cursor 分頁樣板(#30)**:`loadMore()` / `hasMore`,四條語意定死——
  refresh 回第一頁、loadMore 只往尾端附加、**只有第一頁進本地快取**、
  loadMore 必須防重入。假後端 demo 資料 5 → 37 筆並支援 cursor/limit。
  UI 用 `itemCount + 1` 與 `hasMore && !loadingMore` 守衛做無限捲動,
  未引入分頁套件。
- **表單樣板(#31)**:`packages/core` 的 `Validators`(回傳 l10n key 而非
  文案)+ `packages/ui` 的 `localizeValidationError()`;`login_page` 改用
  `Form` + `TextFormField` + `autovalidateMode.onUserInteraction`。
  未引入表單套件。**登入表單刻意不檢查密碼長度**——長度規則屬於註冊/改
  密碼流程,在登入頁擋既有使用者的舊密碼是誤導。
- **`tool/check.sh` 新增 Firebase 隔離稽核**(app 與 core 不得直接依賴
  `firebase_*`),由 `guard.sh` 反向斷言保護。步驟數 10 → 11。

## [0.3.0] - 2026-07-29

P0 三項(#16 #17 #18):補上資料層的快取/stream 樣板、拿掉 page 內的全域
service locator、把兩條分層規則從人力紀律改為機器強制。

### Added

- **快取與 stream repository 樣板(#16)**:`ItemRepository` 改為
  `watchItems()`(訂閱後立即收到本地快取,不等網路)/ `refreshItems()`
  (打遠端,成功才更新快取並廣播,失敗保留舊快取)/ `fetchItem()` /
  `dispose()`。以 `KeyValueStore` + `dart:convert` 實作最小可行快取,
  未引入 rxdart/drift/isar/sqflite;快取 key 帶版本號。`ItemListState`
  改為 `Initial` / `Ready(items, refreshing, lastError)`,能表達「有舊
  資料 + 正在刷新 + 刷新失敗」並存;`HomePage` 加下拉刷新與 SnackBar
  提示(失敗不整頁換成錯誤畫面)。規則見 `docs/conventions.md` §6.1。
- **`ApiClient` 的 `CancelToken` 支援與 `CancelledException`(#16)**:
  四個方法各加可選 `cancelToken`;`DioExceptionType.cancel` 從
  `UnknownException` 拆出獨立映射,bloc 才能跟真正的未知錯誤區分。
  取消能力止於 data 層,domain 介面不得出現 `CancelToken`。
- **`tool/check.sh` 三條新稽核**:bloc 純度(bloc/cubit/event/state 不得
  import Flutter)、分層方向(presentation 不得 import data)、
  `GetIt.instance` 禁令。三條皆由 `tool/guard.sh` 反向斷言保護。
  步驟數 7 → 10。

### Changed

- **page 取用 bloc 改為 `context.read<GetIt>()`(#17)**:`app.dart` 以
  `RepositoryProvider<GetIt>.value` 包住 `MaterialApp.router` 外層往下
  傳容器,三個 page 不再呼叫 `GetIt.instance`。六個測試檔改用
  `GetIt.asNewInstance()` 建獨立容器,測試之間不再互相污染。
  `tool/new_feature.dart` 的 page 與 page test 範本同步。

## [0.2.2] - 2026-07-28

### Changed

- Lint 基線:`very_good_analysis` ^8.0.0 → ^10.3.0(跨兩個 major)。新規則
  命中 4 處並已修正:`avoid_types_on_closure_parameters` 3 處
  (`app/lib/src/bootstrap.dart` 賦值給 `FlutterError.onError` 與
  `PlatformDispatcher.instance.onError` 的 closure 移除可推導的參數型別)、
  `unnecessary_ignore` 1 處(`packages/navigation/lib/src/app_route.dart`
  的 `one_member_abstracts` ignore 已多餘——`AppRoute` 的單一成員是 getter
  不是 method,新版規則不涵蓋;理由改寫進 doc comment)。另外三處
  `one_member_abstracts` 的 ignore 未動,其單一成員皆為 method。未停用任何
  新規則(#49)。

### Fixed

- `README.md` 4 處與 `docs/onboarding.md` 1 處的 SDK 版本仍停在升級前的
  Flutter 3.29.3 / Dart ^3.7.0,已更正為 3.44.6 / ^3.12.0。照舊文件去裝
  3.29.3,其附帶的 Dart 3.7 解析不了全部 pubspec 的 `sdk: ^3.12.0`(#47)。
- `.fvmrc` 移除尾端換行。`fvm use`(README 快速開始第 2 步)每次執行都會把
  該檔重寫成無尾端換行的版本,等於每個人 clone 下來照做完工作樹就是髒的;
  改為 committed 內容與 fvm 的輸出一致(#47)。

## [0.2.1] - 2026-07-28

僅修護欄腳本與 CI 設定,無任何 Dart 程式碼或行為變更。

### Fixed

- `tool/check.sh` 在 macOS 上必定失敗(#40)。本專案 iOS 端走 Swift Package
  Manager(`app/ios` 無 Podfile),macOS 執行 `flutter pub get` 會做 SPM 解析,
  把 `firebase_analytics`/`firebase_crashlytics`/`firebase_messaging` 的本體
  與 example app 原始碼展開到 `build/ios/SourcePackages/`(落點在 `./build`
  與 `./app/build`,各 25 個 `.dart` 檔)。三個步驟會掃到它們:1/7 format
  格式化 19 個第三方檔而 `--set-exit-if-changed` 回非 0、2/7 ignore 稽核命中
  第三方 18 處無原因 ignore、6/7 analyze 回報 402 個第三方 issue。CI 是
  ubuntu 無 iOS toolchain 不會產生這些檔,故 CI 綠而 macOS 紅。三步各自限縮
  掃描範圍為第一方原始碼;限縮後的檔案集合與 `git ls-files "*.dart"` 逐檔
  一致(138 個),未少檢查任何一行第一方 code。不改
  `analysis_options.yaml`——`SourcePackages/` 底下每個套件各有自己的
  `pubspec.yaml`,analyzer 會建獨立 analysis context,外層 `exclude` 管不到。
- Dependabot 的 pub 生態自 2026-07-11 設定當天起四次執行全部失敗(#42),
  錯誤皆為 `Only apply dependency_services to the root of the workspace`。
  成因是 `dependabot.yml` 的 pub `directories` 列了 `/app`、`/packages/*`、
  `/features/*` 三個非根目錄,而本 repo 是 pub workspace,Dependabot 底層的
  `dependency_services` 只接受在 workspace 根執行。那些非根目錄本來也沒有
  意義:workspace 只有一份 `pubspec.lock`(在根),從成員目錄執行 pub 指令
  pub 自己會跳回根解析。改為 `directory: "/"`。

## [0.2.0] - 2026-07-11

### Changed

- SDK:`.fvmrc` 與全部 13 份 pubspec 的 `environment.sdk` 升級為 Flutter
  3.44.6 / Dart ^3.12.0(原 3.29.3 / ^3.7.0)。
- Lint 基線:`very_good_analysis` ^7.0.0 → ^8.0.0;修正新規則
  `unnecessary_underscores` 兩處(`(_, __)` → `(_, _)`)。停用單一規則
  `prefer_initializing_formals`(新版 analyzer 對「私有欄位 + 具名建構子
  可讀參數名」此模板既有慣例的建議實際上無法套用——具名參數不得以底線
  開頭,套用即編譯失敗;17 處全屬此類,詳見
  `.superpowers/sdd/deps-upgrade-report.md`)。
- 依賴 major 升級:`get_it` ^8 → ^9、`go_router` ^14 → ^17、
  `flutter_secure_storage` ^9 → ^10、`firebase_core` ^3 → ^4、
  `firebase_analytics` ^11 → ^12、`firebase_crashlytics` ^4 → ^5、
  `firebase_messaging` ^15 → ^16。呼叫端 API 皆相容,無業務邏輯變動。
- 原生設定:Firebase iOS pod 自本次升級版本起要求
  `deployment_target 15.0`;`app/ios` 的 `IPHONEOS_DEPLOYMENT_TARGET` 與
  `Flutter/AppFrameworkInfo.plist` 的 `MinimumOSVersion` 由 13.0 提升為
  15.0。Android `minSdk` 沿用 Flutter 預設(24),未變動。
- 收尾修正:`packages/localization` 補上 `flutter: generate: true`
  (Flutter 3.44 的 `gen-l10n` 要求此旗標)、`l10n.yaml` 移除已無作用的
  `synthetic-package`;`tool/new_feature.dart` 產生器範本同步 SDK/依賴
  主版本與 lint 修正,確保新產生的 feature 在新 SDK 下仍可通過
  `tool/check.sh`。

## [0.1.0] - 2026-07-11

### Added

- 初版模板:pub workspace(app + 9 packages + 2 示範 features)、Bloc + get_it + go_router、假後端出廠可跑。
- 工具鏈:`tool/check.sh`(七段稽核,與 CI 同構)、`tool/guard.sh`、`tool/new_feature.dart`、`tool/rename_project.dart`。
- 文件:CLAUDE.md/AGENTS.md、docs/architecture、conventions、7 份 how-to、5 份 ADR。
- 護欄:CI(check/generator-smoke/gitleaks)、CODEOWNERS、PR template、branch rulesets(master/develop)。
