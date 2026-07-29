# Flutter Mobile App 泛用模板 — 設計文件

日期:2026-07-11
狀態:已與需求方確認全部設計段落,待實作規劃

## 1. 目的與需求

建立一個泛用於不同領域的 Flutter Mobile App **Starter Repo 模板**,讓不同資質的 RD 都能快速建立並共同維護一個架構清晰的中大型 App。

已確認的需求邊界:

- **適用範圍**:典型後端驅動 App——登入/會員、API 存取、列表/表單/詳情頁、推播、分析。
- **交付形式**:可直接 clone/copy 的範本專案(含基礎設施代碼、示範 feature、工具鏈、文件)。
- **使用者輪廓**:需求方本人(medium level mobile developer)為主要維護者,與不同資質的 RD 共同維護。設計原則:規則由工具(編譯器、lint、CI、產生器)執行,不靠人力紀律。
- **硬性條件**:對 AI coding agent 協作友善;內建常見服務(Firebase 推播/分析/crash 上報)的整合位置。
- **選型定案**:Bloc + get_it(完整分層、事件可追溯,取其中大型專案的可控性;樣板量由 AI 輔助與程式碼產生器吸收)。已明確排除 Riverpod 路線與輕量 MVVM 路線。

## 2. 核心架構決策:多 package workspace

模組邊界用 **Dart 3.6+ 原生 pub workspace(多 package)** 強制,不用 melos。

邊界的強制機制(精準描述):pub workspace 是共享 resolution,整個 workspace 只有一份 `package_config.json`,因此「未在 pubspec 宣告依賴的 import」**仍然編譯得過**——真正守住依賴邊界的是 analyzer 的 `depend_on_referenced_packages` lint(very_good_analysis 已內含,本模板升為 **error 級**)加上 CI 的 `flutter analyze` 硬性把關。也就是說:邊界是「pubspec 宣告式 + lint error + CI 強制」,機器可驗證、不靠人力紀律,但不是編譯器級;文件其他處提及依賴邊界時皆以此為準。

### 2.1 Workspace 拓撲

```
<project_name>/
├── pubspec.yaml               # workspace 根(Dart 3.6+ 原生 workspace)
├── .fvmrc                     # 鎖定 Flutter 版本(FVM),全團隊/CI 一致
├── app/                       # 唯一可執行的 Flutter app —— 純組裝層
├── packages/
│   ├── foundation/            # 純 Dart 零依賴:Result<T>、例外體系、logger 介面、
│   │                          #   原生錯誤共用型別
│   ├── networking/            # dio 封裝:client 工廠、攔截器、統一錯誤轉換;
│   │                          #   定義 TokenProvider 介面(由 session 實作)
│   ├── persistence/           # 本地儲存:secure storage、key-value、(選配)db
│   ├── session/               # 登入狀態單一真相:token 存取(用 persistence)、
│   │                          #   SessionState stream、實作 networking 的 TokenProvider
│   ├── navigation/            # 跨 feature 導航契約:路由路徑常數 + 型別化參數
│   ├── design_system/         # design tokens、theme、共用 UI 元件、頁面外框元件
│   │                          #   (page scaffold)、共用 assets
│   ├── localization/          # 多語系(官方 gen-l10n + ARB),含各 feature 文案
│   │                          #   (以 feature 前綴命名 key)
│   ├── observability/         # log 輸出端、crash 上報、事件埋點(介面 + Firebase 實作)
│   ├── push_notifications/    # 推播抽象介面 + FCM 實作、token 生命週期、
│   │                          #   點擊轉路由事件
│   └── native/                # 原生能力群:每項能力一個 plugin package
│       └── <capability>/      #   (Dart 介面 + android/ Kotlin + ios/ Swift),
│                              #   channel 程式碼一律用 pigeon 產生,不手寫
├── features/                  # 每個 feature 一個獨立 package,互不依賴
│   ├── auth/                  # 示範 1:有狀態流程(登入),驅動 session
│   └── home/                  # 示範 2:API 列表+詳情(CRUD 範本)
├── tool/                      # 開發指令:new_feature.dart、rename_project.dart、
│                              #   check.sh(與 CI 同構)
├── docs/                      # 架構文件、how-to 教學、ADR
└── .github/workflows/ci.yaml
```

### 2.2 依賴方向規則(四條)

1. `foundation` 不依賴任何東西(純 Dart,不依賴 Flutter)。
2. `packages/*` 之間允許依賴,但必須單向、且在 `docs/architecture.md` 的依賴圖中明列;永遠不能依賴 `features/*` 或 `app`。
3. `features/*` 可依賴 `packages/*` 與 `foundation`;**永遠不能依賴其他 feature**,不能依賴 `app`。
4. `app` 是唯一什麼都能依賴的地方,負責組裝(DI、路由表、flavor 進入點),自身幾乎不含邏輯。

### 2.3 關鍵糾結點的定案解法

- **token 循環依賴**:`networking` 定義 `TokenProvider` 介面但不實作;`session` 依賴 `networking` 並實作該介面(含 401 refresh 流程);`app` 組裝時注入。依賴單向:`session → networking → foundation`。`auth` feature 只負責 UI 流程,登入成功後把 token 交給 `session`。
- **跨 feature 溝通**:feature 之間永遠不直接對話。共享狀態的抽象契約下沉到 `packages/`(如 `session`),由 `app` 組裝接線。
- **跨 feature 導航**:`navigation` package 只放路由路徑常數與型別化參數類別(如 `OrderDetailRoute(orderId)`),不含頁面。features 依賴它發起導航;`app` 把路徑對應到實際頁面。**型別化路由 ↔ path 的轉換約定(定死)**:不採用 go_router_builder(避免多一套 code-gen 及其對路由組裝位置的約束);每個 route 類別在 `navigation` 內手寫 `String get location`(組合路徑常數 + 參數 + query),路徑常數與 route 類別同檔定義。feature 端導航一律寫 `context.go(OrderDetailRoute(orderId).location)`;`app` 的 `GoRoute(path:)` 取用同一份路徑常數,單一真相。route 類別範本由 `new_feature` 產生器產出。
- **feature 對外的臉**:每個 feature 只透過 barrel file(`lib/<name>.dart`)輸出:路由建構函式、DI 註冊函式、極少數公開 widget。`lib/src/` 內一切私有(Dart 語言級保護)。
- **原生平台通訊**:features 永遠不直接碰 MethodChannel。每項原生能力一個 plugin package,channel 程式碼一律用 pigeon 產生;第三方 SDK 的原生初始化設定留在 `app/android/`、`app/ios/`,Dart 端存取一律透過 `packages/` 抽象介面。

### 2.4 錯誤模型(foundation 定義,全專案單一路徑)

`AppException` 為 sealed class,子類清單定死,不允許各 feature 自創例外型別:

| 子類 | 語意 | 主要來源 |
|---|---|---|
| `ConnectivityException` | 無網路、DNS 失敗、連線逾時 | networking |
| `ServerException(statusCode)` | 5xx | networking |
| `UnauthorizedException` | 401 / token 失效且 refresh 失敗 | networking(觸發 session 過期) |
| `ApiException(code, message)` | 4xx 業務錯誤(後端錯誤碼) | networking |
| `ParsingException` | JSON 解析 / DTO 轉換失敗 | data 層 |
| `StorageException` | 本地儲存讀寫失敗 | persistence |
| `NativeException(code)` | 原生能力呼叫失敗 | packages/native/* |
| `UnknownException(cause)` | 以上皆非的兜底 | 各處 |

`networking` 的攔截器負責把 dio 例外與 HTTP 狀態碼轉換成上表對應子類(對照表落在 `docs/conventions.md`);data 層只會看到 `AppException`,repository 將其放進 `Result` 的 failure 端;bloc 對 sealed 子類做 exhaustive switch 轉成使用者可見狀態。

## 3. 測試架構

原則:**測試跟著 package 走,每個 package 可獨立測試**,不需模擬器、Firebase、真後端。

```
packages/<name>/test/          # 結構鏡射 lib/src/
packages/<name>/lib/testing.dart   # 提供介面的 package 必須附官方假實作(fake)
features/<name>/test/
├── data/                      # repository:假 API client,驗證 DTO 轉換與錯誤映射
├── domain/                    # 純邏輯(如有)
└── presentation/              # bloc_test 驗證事件→狀態序列;page 三態渲染測試
app/test/di_smoke_test.dart    # 逐一解析已註冊型別:「忘記註冊」在 CI 失敗,
                               #   不在執行期閃退(機制見下方說明)
app/integration_test/          # 假後端啟動 app,跑登入→首頁關鍵路徑(nightly)
```

測試規範(四條):

1. 提供介面的 package 必須同時從 `lib/testing.dart` 匯出官方 fake;下游測試一律用官方 fake,禁止各自手寫 mock。
2. 測試替身統一用 **mocktail**(無 code-gen)+ **bloc_test**。工具唯一化,不給選擇。
3. 完成的定義(進 conventions.md 與 PR checklist):bloc 事件→狀態轉換、repository 資料轉換與錯誤映射必須有測試;page 至少有 loading/success/error 三態渲染測試。golden、integration 為建議項。
4. `tool/new_feature.dart` 連同測試骨架一起產出。

**di_smoke_test 的機制(定死)**:get_it 沒有列舉全部註冊項的公開 API,因此採「清單維護在測試檔」的做法——`di_smoke_test.dart` 內有 `// {{feature-registry}}` 標記區塊,列出每個 feature/package 公開註冊型別的解析呼叫(如 `gi<AuthRepository>()`);`new_feature` 產生器建立 feature 時自動插入該 feature 的解析呼叫,基礎 packages 的解析項在模板中一次寫好。清單與註冊不同步時,測試即失敗,達到把關目的。

## 4. Feature package 內部結構與 Bloc 規範

### 4.1 內部結構(所有 feature 形狀一致)

```
features/<name>/
├── pubspec.yaml               # 依賴依需要,不多不少
├── lib/
│   ├── <name>.dart            # barrel:路由建構函式、DI 註冊函式、極少數公開 widget
│   └── src/
│       ├── di.dart            # void register<Name>Feature(GetIt gi)
│       ├── routes.dart        # List<GoRoute> <name>Routes(),路徑常數取自 navigation
│       ├── data/
│       │   ├── dtos/          # json_serializable + DTO→entity 轉換函式
│       │   ├── sources/       # remote(用 networking client)、local
│       │   └── repositories/  # domain 介面的實作
│       ├── domain/
│       │   ├── entities/      # 純 Dart 業務物件
│       │   ├── repositories/  # 抽象介面
│       │   └── usecases/      # 選配(準則見 4.3)
│       └── presentation/
│           ├── blocs/         # 一個使用情境一個資料夾:bloc、event、state 三檔
│           ├── pages/
│           └── widgets/       # feature 私有元件
└── test/
```

層內依賴方向:`presentation → domain ← data`。presentation 不碰 DTO 與 data source;DTO 欄位變動的爆炸範圍止於 data 層。

### 4.2 Bloc 規範(定死,不給選擇)

1. 一律用 Bloc,不用 Cubit。
2. State 用 Dart 3 `sealed class` 表達互斥狀態;UI 用 exhaustive `switch` 渲染——漏處理狀態是編譯錯誤。
3. 命名:事件用「主詞+過去式動詞」(`LoginSubmitted`),不用命令式;狀態類別 `<情境><階段>`。
4. Bloc 之間禁止互相引用;共享狀態下沉到 domain(repository 暴露 stream),各自訂閱。
5. 錯誤處理單一路徑:repository 一律回傳 `Result<T, AppException>`(foundation 定義);禁止 bloc/UI 以 `try/catch` 接 raw exception。
6. Bloc 檔案不 import Flutter,保持純 Dart。

### 4.3 usecase 選配準則(唯一允許的彈性)

預設 bloc 直接呼叫 repository。僅兩種情況抽 usecase:(a) 一個動作協調兩個以上 repository;(b) 同一段業務規則被兩個以上 bloc 使用。準則外新增 usecase,code review 退回。

### 4.4 DI 規範

- repository、data source 註冊 `lazySingleton`;bloc 一律 `factory`,跟隨頁面生命週期,不做全域 bloc。全域狀態(如 session 監聽)不住在 feature。
- feature 的 `di.dart` 是唯一註冊點;`app` 只呼叫一行註冊函式;`di_smoke_test` 驗證全部可解析。

## 5. app/ 組裝層

定位:把所有 package 接起來、決定啟動順序,自己不含業務邏輯,刻意保持薄。

```
app/
├── lib/
│   ├── main_dev.dart / main_stg.dart / main_prod.dart   # 各兩行:建 AppConfig → bootstrap()
│   └── src/
│       ├── config/            # AppConfig:API base URL、feature flags、環境名
│       ├── bootstrap.dart     # 啟動序列,全專案唯一一份
│       ├── di.dart            # composeDependencies(gi, config)
│       ├── router.dart        # 合併 feature routes、登入守衛 redirect、深連結落地
│       ├── app.dart           # MaterialApp.router、theme、locale 綁定
│       └── shell/             # 登入後外殼 UI(底部導覽列)——app 層唯一合法 UI
├── android/ ios/              # flavor/scheme、Firebase 設定檔(三環境各一)
├── test/di_smoke_test.dart
└── integration_test/
```

### 5.1 環境策略(定死)

- 三環境 `dev / stg / prod`,各一個 `main_*.dart`,對應 Android product flavors 與 iOS schemes;bundle id 加後綴,三環境可同機並存。
- 非機密環境常數寫在各環境 `AppConfig`,進版控。
- 機密用 `--dart-define-from-file` 注入,定義檔 gitignore,附 `env/secrets.example.json`。

### 5.2 bootstrap 啟動序列(定死)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `composeDependencies(gi, config)`(純註冊,不做 I/O)
3. 掛載全域錯誤捕捉:`PlatformDispatcher.onError` + `FlutterError.onError` → `observability`
4. `await` 必要初始化:persistence 開啟、Firebase init、session 還原
5. `runApp()`

整段在錯誤邊界內,啟動期未捕捉例外進 crash 上報。

### 5.3 全域行為歸屬

- **登入守衛**:只在 `router.dart` 的 `redirect`,讀 session 狀態。
- **token 失效登出**:app 層訂閱 `SessionState`,過期時清資料導回登入。
- **推播點擊/深連結**:`push_notifications` 只發「指向某路徑的點擊事件」,app 訂閱後轉 `router.go(path)`。

app 層紀律:出現業務行為的環境分支、或 shell 之外的頁面,即為腐化訊號,review 退回。

## 6. 護欄工具鏈與 AI 協作配套

### 6.1 Lint 基線

- workspace 根唯一一份 `analysis_options.yaml`:`very_good_analysis` + `strict-casts / strict-inference / strict-raw-types`,全 package 繼承,禁止放寬。邊界說明(2026-07-11 補):「因語言限制而無可行寫法的規則」得於根設定停用單一規則,必須附可驗證的理由註解且經 CODEOWNERS 核可,不視為放寬(先例:`prefer_initializing_formals`——具名參數不得底線開頭,私有欄位賦值模式無法改寫)。
- `depend_on_referenced_packages` 升為 **error 級**——這是依賴邊界(§2)的實際執法者,analyze 不過 CI 就不過。
- 例外僅允許逐行 `// ignore: 規則 -- 原因`;CI 以 grep 擋無原因的 ignore。

### 6.2 CI(與 tool/check.sh 完全同構)

1. `dart format --set-exit-if-changed`
2. `flutter analyze`(全 workspace)
3. 逐 package `flutter test`(平行;「只測變動 package」為後續優化項)
4. integration test 為 nightly 獨立 job,不擋 PR

PR template 內建「完成的定義」checklist。

### 6.3 tool/new_feature.dart 產生器規格

`dart run tool/new_feature.dart <name>` 之後:

1. 產生完整 feature 骨架:pubspec、barrel、di.dart、routes.dart、三層目錄、一組會動的範例(bloc + 頁面 + 測試),範例即規範。
2. 自動把新 package 加進 workspace 根 pubspec。
3. 自動插入 `app` 的 DI 與路由標記區塊(`// {{feature-registry}}`),接線不靠人記得。
4. 在 `navigation` package 的標記區塊插入路徑常數與 route 類別範本。
5. 在 `app/test/di_smoke_test.dart` 的標記區塊插入新 feature 註冊型別的解析呼叫(§3 機制)。

### 6.4 CLAUDE.md(一頁以內,三種內容)

1. **鐵律清單**:四條依賴規則、一律 Bloc + sealed state、repository 回傳 Result、測試用官方 fake。
2. **任務路由表**:加 feature → 產生器 + `docs/how-to/add-a-feature.md`;加 API → `add-an-api.md`;加原生能力 → `add-a-native-capability.md`。
3. **指令清單**:check.sh、codegen、單 package 測試。

### 6.5 docs/ 結構

```
docs/
├── architecture.md            # 拓撲圖 + 依賴方向圖 + 每 package 一句話職責
├── conventions.md             # 命名、檔案位置、Bloc 規範、完成的定義
├── how-to/
│   ├── add-a-feature.md
│   ├── add-an-api.md          # DTO → source → repository → bloc → UI 完整走法
│   ├── add-a-native-capability.md   # pigeon 流程
│   └── add-a-shared-package.md
└── adr/                       # 0001-multi-package-workspace、0002-bloc-over-riverpod…
```

how-to 以示範 feature 的實際檔案為範例,文件與代碼互相印證。

## 7. 主要技術選型一覽

| 領域 | 選型 | 備註 |
|---|---|---|
| 狀態管理 | flutter_bloc(一律 Bloc) | sealed class state |
| DI | get_it | feature 各自註冊,di_smoke_test 把關 |
| 路由 | go_router | app 層組裝,navigation package 放契約 |
| HTTP | dio | networking package 統一封裝 |
| 序列化 | json_serializable | DTO 限 data 層 |
| 不可變物件 | freezed(entities/DTO 視需要) | sealed state 可手寫,不強制 freezed |
| 多語系 | 官方 gen-l10n + ARB | 集中於 localization package |
| 原生通訊 | pigeon | 禁手寫 MethodChannel |
| 測試 | mocktail + bloc_test | 官方 fake 從 lib/testing.dart 匯出 |
| 推播/分析/crash | Firebase(FCM/Analytics/Crashlytics) | 一律隔在抽象介面後 |
| 版本管理 | FVM + pub workspace | 不用 melos |
| Lint | very_good_analysis + strict 模式 | 根目錄唯一一份 |

## 8. 護欄總覽(對應「不同資質共同維護」)

1. **編譯器級**:`lib/src/` 私有性、sealed state 的 exhaustive switch、pigeon 型別安全。
2. **工具級(CI 硬性強制)**:pubspec 依賴邊界(`depend_on_referenced_packages` error 級)、strict lint、di_smoke_test、CI 同構 check.sh。
3. **程序級**:new_feature 產生器(骨架與接線自動化)、how-to 文件、PR checklist。
4. **AI 級**:CLAUDE.md 鐵律 + 任務路由,AI 產出自然落在正確位置,違規會被前三層擋下。

## 9. 範圍外(本次不做)

- Web / Desktop 支援、離線優先與本地資料庫深度整合(persistence 留有選配位置)。
- mason brick 形式的產生器(先用 Dart script,驗證後再考慮)。
- 「只測變動 package」的 CI 優化。

## 10. 實作規劃須吸收的已知待辦(獨立審查發現,規格層級刻意留給實作計畫)

1. 產生器補 localization 接線:ARB 檔的標記區塊插入,以及 feature 取用文案的工作流(依賴 `localization` 的產出類別、key 以 feature 前綴命名)寫進 `docs/how-to/add-a-feature.md`。
2. 定義示範 feature 與 integration_test 共用的「假後端」形態(dio mock adapter / 本機 HTTP server 擇一)。
3. bootstrap 時序的 crash 上報語義:Firebase init(第 4 步)前發生的錯誤,observability 需先緩衝、init 後補送;做不到則明確降級為僅本地 log,文件同步說明。
4. freezed 使用準則定死(建議:DTO 一律 json_serializable、entity 預設手寫,欄位多且需 copyWith 時才用 freezed),寫進 conventions.md。
5. `rename_project.dart` 的完整規格:package 名、Android applicationId/namespace、iOS bundle id/scheme、app 顯示名稱、Firebase 設定檔占位的替換清單。
6. 措辭修正:§4.2 第 4 條(feature 內共享狀態下沉到 domain)與 §2.3(跨 feature 契約下沉到 packages/)是兩個不同 scope 的規則,conventions.md 中需分開表述。

以下為計畫 1 最終全分支審查後定案的追加事項:

7. 例外相等策略(定案):`AppException` 不實作 `==`/`hashCode`;測試斷言一律用 `isA<ServerException>()` 類 matcher,不做例外實例的相等比較。寫進 conventions.md(計畫 6),bloc_test 範例(計畫 5)遵循。
8. check.sh 追加 pubspec 依賴稽核(計畫 2 或 6):`depend_on_referenced_packages` 只擋未宣告的 import,擋不住「宣告了被禁止的依賴」;需以腳本檢查 features/* 的 dependencies 不含 features/*、packages/* 不含 features/* 與 app,使 §2.2 四條規則全數機器可驗證。
9. `Result.guard`(try/catch → Result 轉換 helper)待計畫 2 依 repository 實際樣板量決定是否補進 foundation,不預先鍍金。
10. `rename_project.dart` 替換清單需包含 workspace 根 pubspec 的 `name: workspace_root`。

以下為計畫 2 最終全分支審查後定案的追加事項:

11. 計畫 4(app 組裝層)須擴充 `createDio`:(a) 可追加額外 interceptors(observability 的 logging 需要掛點);(b) 決定 retryClient 是否共掛 logging(否則重試請求從 log 消失);(c) 提供「無 AuthInterceptor 的 plain client」工廠給 `TokenRefreshGateway` 實作使用,把「gateway 不得走含攔截器 client」從文件約束升級為結構性保證。
12. 計畫 4/5 視需要補 `ApiClient` 的 `patch` 方法與 per-request headers / `CancelToken` 傳入口(目前刻意未做,遇到實際需求再加)。
13. 計畫 6 conventions.md 需記載:(a) 請求取消(`DioExceptionType.cancel`)映射為 `UnknownException`,bloc 於 dispose-cancel 情境應忽略此錯誤;(b) package 內部 import 採 `package:x/src/...` 絕對路徑為 house style;(c) `SessionManager` 為 app 生命週期單例、`states` 無 replay 的訂閱模式。
14. §10 第 8 條的 check.sh pubspec 依賴稽核**定於計畫 6** 落地(計畫 2 未做,勿失落)。
15. 已知邊角(有意識接受):AuthInterceptor 對「無 Authorization header 卻收到 401」的請求會以現行 token 重試一次而不觸發 refresh;`ApiException` 在 statusCode 缺失時 code 為 '0'。

以下為計畫 3 最終全分支審查後定案的追加事項:

16. 計畫 4 須吸收:(a) push 冷啟動點擊——`PushNotifications` 介面補 `initialTap()`(對應 `getInitialMessage()`)或於組裝層 merge 並在 doc 寫明;(b) AppLogger → CrashReporter 橋接(composite logger)實作於 observability,供 production 組裝,不得散在 app 層。
17. 計畫 4/5 呼叫端落地時收斂:`AppErrorView` 的 `retryLabel!` 在 release 為 null-check 風險(改條件渲染);`PushTapEvent` 的 `data['route']` cast 改防禦式 `is String`;`AnalyticsTracker` doc 註明參數值限 String/num。
18. 計畫 6:check.sh 加 l10n 漂移檢查(`gen-l10n && git diff --exit-code`,防 ARB 改了忘 regen);docs 註明 zh-Hant/Hans 擴充方式(`app_zh_Hant.arb`)。
19. 原生 flavor/scheme 設定(Android productFlavors、iOS schemes、bundle id 後綴,§5.1)不隨模板出廠:三個 main 進入點已可運行(`flutter run -t app/lib/main_dev.dart`);原生設定以計畫 6 的 `docs/how-to/configure-native-flavors.md` 手動步驟文件交付,連同 Firebase 專案配置(`AppConfig.firebaseEnabled` 開關)一併說明。

以下為計畫 4 最終全分支審查後定案的追加事項:

20. **§10.11(createDio 擴充)遞延至計畫 5,勿失落**:計畫 4 未吸收。計畫 5 的真實 TokenRefreshGateway 需要「無 AuthInterceptor 的 plain client 工廠」(§10.11c),必須隨 auth feature 一併落地;(a) 額外 interceptors 掛點與 (b) retryClient logging 決策亦於計畫 5 或 6 收斂。
21. 計畫 5:App 補 go_router `errorBuilder`(推播任意 routePath 落到預設錯誤頁無返回途徑);Plan 5 移除 NavigationBar 佔位 destination 時一併打磨。
22. 計畫 6:產生器的標記匹配規則定為「行內含 `{{feature-registry}}` / `{{route-paths}}` 即為插入點」(現存標記行有無 ` -- 說明` 後綴不一);`app/README.md` 改寫(現為 flutter create 樣板)。

以下為計畫 5 最終全分支審查後定案的追加事項(全部歸計畫 6):

23. conventions.md 需記載的判準:(a) UI 狀態渲染——整頁三態用 exhaustive switch,單一旗標/副作用允許 `is` 檢查(LoginPage vs HomePage 為對照範例);(b) 測試取用文案一律走 `AppLocalizationsEn()` 等 l10n 實例,不硬編字串;(c) demo repository 省略 `sources/` 層的判準——單一 remote 來源且無本地快取時 repository 可直呼 ApiClient,出現第二來源時抽 source;(d) DTO 手寫 fromJson 的判準(欄位少不值 codegen);(e) widget 測試點擊元件用 `find.byType(AppPrimaryButton)` 等公開元件型別,不耦合內部實作。
24. 產生器實作規格:標記插入方向統一(定為「插在標記行之前」並修正現存不一致);`DemoBackendAdapter` doc 加 baseUrl 路徑前綴陷阱說明;`main_prod.dart` 加 `useFakeBackend` 顯式註解(prod 靜默走假後端為模板陷阱)。

## §10 驗收狀態(2026-07-11)

上列 24 條已全數吸收進實作或於文件記載完畢;已知殘留(列入路線圖,非本次收尾範圍):(a) `tool/check.sh` 的 pubspec 依賴稽核(§10.8/14)只掃 `dependencies`,不掃 `dev_dependencies`,理論上仍可能經由 dev_dependencies 繞開依賴四規則;(b) `tool/check.sh` 的 l10n 漂移檢查(§10.18)對「本機已 regen 但尚未 `git add`」的未 staged 差異仍會判定為漂移而失敗,屬預期行為但易誤讀為 CI 誤報;(c) 產生器藍本(`features/home`)與 `tool/new_feature.dart` 模板之間的同步依賴人工比對,無自動化防呆,亦無獨立 CI smoke job 驗證產生器產物在乾淨環境下可過 `check.sh`,列為後續路線圖項目。

以下為 2026-07-11 通用性缺口重評(以 template 原則重新推導,排除特定專案視角)後定案:

25. `PushNotifications` 介面補 `foregroundMessages` stream:FCM 前景訊息不暴露會逼專案直接觸碰 FirebaseMessaging.onMessage,違反「Firebase 隔在介面後」鐵律——屬介面完整性缺陷。呈現方式(in-app banner/本地通知/靜默)為專案決策,模板不綁 flutter_local_notifications。
26. conventions.md 補「第三方 plugin 包裝判準」:需在測試中被替換、或含轉換邏輯的第三方能力 → 包成 packages/ 成員並附 testing.dart fake(先例:persistence、push_notifications);純 UI/一次性工具 → feature 內直接使用。
27. architecture.md 全域行為節補「啟動 gate(強制更新/維護模式)歸屬」規範性指引:bootstrap 4c 後檢查 + go_router redirect 最高優先層攔截;模板不預建實作(規範性文件,比照 add-a-native-capability.md 先例)。
28. 已評估並否決(防翻案):連線狀態監控 package(networking 的 ConnectivityException + retry 已是完整故事,需要時依 add-a-shared-package.md 自行擴充)、ApiClient 內建統一信封層(per-call parse 與 extraInterceptors 兩個擴充點已存在;接法寫入 add-an-api.md)。
