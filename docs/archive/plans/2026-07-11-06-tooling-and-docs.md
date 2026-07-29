# 產生器 + 文件 + 護欄增強 實作計畫(6/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付模板的「程序護欄」層:check.sh 依賴/l10n 稽核、`new_feature` 與 `rename_project` 產生器、完整 docs(architecture/conventions/how-to/ADR)、CLAUDE.md 與 README;吸收 spec §10 全部剩餘待辦(5、13、14、18、22、23、24 與 §6.3-6.5)。

**Architecture:** 產生器用純 Dart script(spec §9:先 script、驗證後才考慮 mason);feature 骨架以 `features/home` 為藍本(「範例即規範」);標記插入方向統一為「插在標記行之前」(§10.24)。文件以現存程式碼為範例來源,how-to 與實際檔案互相印證(spec §6.5)。

**Tech Stack:** 純 Dart(tool/)、bash(check.sh)、Markdown。

## Global Constraints

- 沿用全部既有約束(fvm、strict lint、繁中、conventional commits、每 task commit 不 push、最後統一推)。
- 文件語言:繁體中文(程式碼/指令/識別字原文)。文件中引用的檔案路徑與 API 必須與 repo 現況一致(寫文件前先讀對應原始碼)。
- spec 為文件內容的權威來源:`docs/superpowers/specs/2026-07-11-flutter-app-template-design.md`(§2 架構、§2.4 錯誤模型、§3 測試、§4 feature 規範、§5 app 層、§6 工具鏈、§10 歷次定案)。
- 工作目錄:`<repo>`。

---

### Task 1: check.sh 增強——pubspec 依賴稽核與 l10n 漂移檢查

**Files:**
- Modify: `tool/check.sh`
- Modify(統一標記,§10.24): `app/lib/src/di/compose_dependencies.dart`、`app/test/di_smoke_test.dart`(把既有插入內容移到標記行**之前**,與 app_router 一致)

**規格:**
- 新增第 2.5 段「pubspec 依賴稽核」(§10.14/spec §2.2 的機器驗證):
  - `features/*/pubspec.yaml` 的 dependencies 不得含 `app` 或其他 `features/*` 成員名(auth、home、…動態取自 features/ 目錄清單)。
  - `packages/*/pubspec.yaml` 的 dependencies 不得含 `app` 或任何 feature 名。
  - 違規 → 印出違規行並 exit 1。實作用 grep/awk 於 dependencies: 與 dev_dependencies: 區段之間比對。
- 新增第 2.6 段「l10n 漂移檢查」(§10.18):`(cd packages/localization && fvm flutter gen-l10n)` 後 `git diff --exit-code -- packages/localization/lib/src/generated` ;有 diff → 提示「ARB 已改但未 regen」並 exit 1。
- 自我驗證步驟:蓄意在 features/home pubspec 加 `auth: any` → check.sh 第 2.5 段必須攔下(證據進報告)→ 還原;蓄意改一個 ARB 值不 regen → 第 2.6 段攔下 → 還原(regen 恢復)。
- Commit `feat(tool): check.sh 依賴稽核與 l10n 漂移檢查;標記插入方向統一`。

---

### Task 2: tool/new_feature.dart 產生器

**Files:**
- Create: `tool/new_feature.dart`
- Test: 實跑驗證(見下),不留產物

**規格(spec §6.3 + §10.22/24):**
- 用法:`fvm dart run tool/new_feature.dart <snake_case_name>`;驗證名稱(小寫+底線,非保留名,features/ 下不存在)。
- 產出 `features/<name>/`,骨架以 `features/home` 現況為藍本:pubspec(白名單同 home,description 佔位)、barrel(di/routes export + 組裝層匯出區)、`src/di.dart`(register<Pascal>Feature:一個 repository lazySingleton + 一個 bloc factory)、`src/routes.dart`(單一 GoRoute)、三層目錄與可運作範例——`domain/entities/<name>_item.dart`?**簡化:單一 entity `<Pascal>Thing` 不對;採用:產生「list 範例」的最小切片**:entity `<Pascal>Entry(id,title)`、`<Pascal>Repository { Future<Result<List<<Pascal>Entry>>> fetchEntries(); }`、DTO、impl(GET /<name>/entries)、`<Pascal>ListBloc`(Requested/Loading/Loaded/Error,handler 先 emit Loading)、`<Pascal>Page`(StatelessWidget,exhaustive switch 三態,AppPageScaffold(title 暫用 name 字串,TODO 換 l10n))、對應測試(repository ScriptedAdapter 三案例、bloc_test 成功/失敗、page 三態 widget test)。
- 自動接線(標記行**之前**插入):根 pubspec workspace 清單(依字母序)、`packages/navigation/lib/src/route_paths.dart`(`static const <camel> = '/<name>';`)、`app/lib/src/di/compose_dependencies.dart`(`register<Pascal>Feature(gi);`)、`app/lib/src/router/app_router.dart`(shell 內 `...<camel>Routes(),`)、`app/test/di_smoke_test.dart`(repository 與 bloc 解析)。app pubspec dependencies 加 `<name>: any`。
- 產生後印出後續步驟清單(l10n key、真 API 對接、navigation typed route 如需參數)。
- 標記匹配規則:行內含 `{{route-paths}}`/`{{feature-registry}}` 即為插入點(§10.22)。
- **驗證(必須,證據進報告)**:實跑 `fvm dart run tool/new_feature.dart sample` → `./tool/check.sh` 全綠(sample 的測試一併通過)→ `git checkout -- . && git clean -fd features/sample && fvm flutter pub get` 還原 → 再跑 check.sh 確認還原乾淨。
- Commit `feat(tool): new_feature 產生器(骨架 + 自動接線)`。

---

### Task 3: tool/rename_project.dart

**Files:**
- Create: `tool/rename_project.dart`

**規格(spec §10.5/10):**
- 用法:`fvm dart run tool/rename_project.dart --org com.mycorp --name my_app [--display-name "My App"] [--apply]`;預設 **dry-run**(只列出將變更的檔案與替換內容),`--apply` 才寫入。
- 替換清單:根 pubspec `name: workspace_root` → `<name>_workspace`;`app/pubspec.yaml` name(維持 `app`,不改——workspace 成員名與匯入耦合,doc 說明);Android `applicationId`/`namespace`(build.gradle)與 Kotlin package 目錄、iOS `PRODUCT_BUNDLE_IDENTIFIER`(pbxproj)、`CFBundleDisplayName`/label(Info.plist、AndroidManifest android:label)——由 `com.example.template.app` → `<org>.<name>`。
- 驗證:dry-run 實跑,輸出清單與預期一致(證據進報告);`--apply` 不在本 repo 實跑(模板本身保持 com.example.template)。替換邏輯抽成純函式並加 `tool/test/rename_project_test.dart`?tool 目錄無 package——**簡化:script 內建 `--self-test` 旗標跑內部斷言**(替換函式的單元驗證),CI 不跑、報告附輸出。
- Commit `feat(tool): rename_project(dry-run 預設)`。

---

### Task 4: docs——architecture、conventions、ADR

**Files:**
- Create: `docs/architecture.md`
- Create: `docs/conventions.md`
- Create: `docs/adr/0001-multi-package-workspace.md`、`0002-bloc-over-riverpod.md`、`0003-fake-backend-and-e2e-shape.md`、`0004-sync-session-stream.md`、`0005-buffering-crash-reporter.md`

**規格:**
- `architecture.md`:workspace 拓撲(現況 12 成員)、依賴方向四規則與白名單表(spec §2.2 + 各 pubspec 現況)、mermaid 依賴圖、每成員一句話職責、關鍵鏈路說明(401 refresh 鏈、bootstrap 五步、守衛/推播/登出三個全域行為的唯一處)。
- `conventions.md`:命名與檔案位置(feature 三層形狀,以 features/home 為範例)、Bloc 六鐵律(spec §4.2)+ §10.23a 的 switch/is 判準、錯誤模型對照表(§2.4 + networking 轉換責任)、usecase 準則(§4.3)、DI 規範(§4.4)、測試規範(§3 四條 + §10.23b/e 測試文案與元件選取器慣例)、§10.23c sources 層判準、§10.23d DTO codegen 判準、§10.13(cancel→Unknown 的 bloc 處理、import house style、SessionManager 單例/no-replay)、§10.7(例外斷言 isA)、ignore 註解格式。
- ADR 各一頁(背景/決策/後果),內容取自 spec 與歷次審查定案:0004 記 sync broadcast + `_emit` 先賦值的契約;0005 記排水後切換與失敗不中斷。
- 文件中的程式碼片段必須從現存檔案節錄(附路徑),不得虛構。
- Commit `docs: architecture、conventions 與 ADR`。

---

### Task 5: how-to、CLAUDE.md、README、雜項收尾

**Files:**
- Create: `docs/how-to/add-a-feature.md`(產生器流程 + 產物導覽 + 後續步驟:l10n、真 API、typed route)
- Create: `docs/how-to/add-an-api.md`(以 home 的 fetchItems 為完整範例:DTO→repository→bloc→UI 五步,含測試)
- Create: `docs/how-to/add-a-native-capability.md`(pigeon 流程:packages/native/<capability> plugin package 骨架、pigeon 定義、Dart 介面包裝、NativeException 錯誤約定;本模板尚無 native package,文件為規範性描述並註明)
- Create: `docs/how-to/add-a-shared-package.md`
- Create: `docs/how-to/configure-native-flavors.md`(§10.19:Android productFlavors + iOS schemes 手動步驟、bundle id 後綴、與三個 main 的對應)
- Create: `docs/how-to/configure-firebase.md`(FlutterFire CLI、firebaseEnabled 開關、useFakeBackend 關閉時機)
- Create: `CLAUDE.md`(repo 根;spec §6.4:一頁內——鐵律清單/任務路由表/指令清單)
- Rewrite: `README.md`(模板定位、快速開始:clone→bootstrap 三步→flutter run、demo 帳密說明、目錄導覽、文件索引)
- Rewrite: `app/README.md`(一段話 + 指回根 README)
- Modify: `app/lib/main_prod.dart`(useFakeBackend 顯式註解,§10.24)、`app/lib/src/demo/demo_backend_adapter.dart`(baseUrl 前綴陷阱 doc,§10.24)
- Modify(§10.23b/e 測試慣例落地): `app/test/app_flow_test.dart`(SnackBar 文案改 `AppLocalizationsEn().authLoginFailed`)、`features/auth/test/presentation/login_page_test.dart`(文案取值同式樣;`find.byType(FilledButton)` 改 `find.byType(AppPrimaryButton)`)、`features/home/test/presentation/home_pages_test.dart`(文案取值)
- Commit `docs: how-to、CLAUDE.md、README;測試文案慣例落地`。

---

### Task 6: 收尾、最終驗證與 CI

- `./tool/check.sh` 全綠;`fvm dart run tool/new_feature.dart --help`?(無 help 需求——名稱缺失時印用法即可)驗證兩個 tool 的 dry-run/用法輸出正常。
- 白名單/標記/文件連結抽查:docs 內部相對連結有效(`grep -o '\](\S*\.md)' docs -r` 逐一存在);CLAUDE.md 指令實測可跑。
- 殘餘 commit(`chore: Plan 6 收尾`)+ push;CI foreground poll 至 success。

---

## 完成定義(本計畫)

- [ ] check.sh 六段(pub get/format/ignore/依賴稽核/l10n 漂移/analyze/tests)全綠且兩項新稽核經蓄意違規實測。
- [ ] `new_feature.dart` 實跑產生的 feature 通過 check.sh 後乾淨還原;`rename_project.dart` dry-run 與 self-test 通過。
- [ ] docs/CLAUDE.md/README 完整且引用與 repo 現況一致;spec §10 全部條目已吸收或明確記載於文件。
- [ ] CI 綠;模板對外可用(clone → README 三步 → 可跑)。
