# Changelog

本檔案記錄每次 release 的重點變更;格式依循 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/),版本依循 [SemVer](https://semver.org/lang/zh-TW/)。維護方式見 `docs/conventions.md` 的「分支與 PR 規範」。

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
