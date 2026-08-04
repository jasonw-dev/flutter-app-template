# 新成員入門(Onboarding)

本文件是新加入本庫的 RD 的學習路徑,約兩天的學習歷程(含分流,見文末)。
四段循序漸進:先體驗 → 讀懂一條真實鏈路 → 動手做且故意犯規(體感護欄)→
懂設計為什麼這樣定案。每段皆引用**現存檔案的真實路徑**,可直接照文中指令操
作。權威文件為 [`docs/architecture.md`](architecture.md)(東西放哪、怎麼連)與
[`docs/conventions.md`](conventions.md)(怎麼寫);AI agent 的入口是
[`CLAUDE.md`](../CLAUDE.md)。

## 從單一 package 專案過來,先知道這三件事

1. **import 一個新東西之前,要先去那個 package 的 `pubspec.yaml` 加依賴。**
   沒加的話 `flutter analyze` 會紅字說 `depend_on_referenced_packages`。
   這不是麻煩——**這正是「A 功能永遠 import 不到 B 功能」的實作方式**,
   是這個模板唯一無可取代的資產。

2. **`fvm flutter pub get` 在根目錄跑一次就好。** pub workspace 會一次解析
   整個 workspace 的全部 package,不需要每個目錄各跑一次。

3. **本機先跑 `bash tool/check.sh`。** 它跟 CI 完全同構,本機過了 CI 就會
   過;不要 push 上去等 CI 告訴你 format 沒對齊。改了 ARB 或 pubspec 依賴
   之後記得先跑 `bash tool/regen.sh`。

## 分流(先看這裡決定怎麼走)

| 身分 | 建議路徑 |
|---|---|
| **Junior RD** | 全部四段照順序走完,含第 2 段全部四個練習。 |
| **Senior RD** | 第 0 段(30 分鐘)+ 第 1 段(垂直切片)+ 第 2 段練習 3(故意犯規,體感護欄),半天內完成即可上手。 |
| **AI coding agent** | 不讀本文件,直接讀 [`CLAUDE.md`](../CLAUDE.md)(鐵律清單 + 任務路由表 + 指令清單,為 agent 設計的精簡定位文件)。 |

---

## 第 0 段(30 分鐘):先體驗

跟 [`README.md`](../README.md) 的「快速開始」一致,實際跑一次:

```bash
git clone <this-repo> my-app && cd my-app
fvm use                                   # 依 .fvmrc 安裝/切換到 Flutter 3.44.6
fvm flutter pub get                       # workspace 一次解析全部 package
fvm flutter run -t app/lib/main_dev.dart  # 跑 dev 環境
```

App 會停在登入頁(`LoginPage`,見第 1 段)。內建假後端
([`app/lib/src/demo/demo_backend_adapter.dart`](../app/lib/src/demo/demo_backend_adapter.dart))
接手所有 API 呼叫,不需真後端。跑一遍以下 demo 操作清單:

1. **任意 email + 任意密碼(非 `wrong`)登入** → 成功導向首頁,看到 5 筆 demo
   項目(`DemoBackendAdapter._items`,固定產出 `Demo item 1`~`Demo item 5`)。
2. **密碼輸入 `wrong`** → 登入失敗,畫面彈出 SnackBar 錯誤訊息(文案為
   `context.l10n.authLoginFailed`,見
   [`packages/localization/lib/src/arb/app_en.arb`](../packages/localization/lib/src/arb/app_en.arb)
   的 `authLoginFailed` key),且停留在登入頁——這是實際打中假後端
   `password == 'wrong'` → 401 `AUTH_INVALID` 的分支(見
   `demo_backend_adapter.dart` 檔頭註解)。
3. **列表 → 詳情**:首頁點擊任一 demo 項目,進入詳情頁(`ItemDetailPage`,
   [`features/home/lib/src/presentation/pages/item_detail_page.dart`](../features/home/lib/src/presentation/pages/item_detail_page.dart))。

這一段只求「看得到東西動」,先不用懂原理——原理留給第 1 段。

---

## 第 1 段(半天):垂直切片導讀

跟一次「登入」請求,從點下按鈕到頁面跳轉,走過完整鏈路。每一站列真實檔案
路徑與**該站要注意的一件事**;程式碼片段皆節錄自現存檔案。

### 站 1:`LoginPage` —— BlocProvider 建立位置 + l10n 取用方式

[`features/auth/lib/src/presentation/pages/login_page.dart`](../features/auth/lib/src/presentation/pages/login_page.dart)

```dart
return BlocProvider(
  create: (_) => GetIt.instance<LoginBloc>(),
  child: BlocListener<LoginBloc, LoginState>(
    listener: (context, state) {
      if (state is LoginFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.authLoginFailed)),
        );
      }
    },
    ...
```

**注意一件事**:`LoginBloc` 由 `BlocProvider` 在頁面建立時透過
`GetIt.instance<LoginBloc>()` 從 DI 容器取出(bloc 一律 `factory` 註冊,跟隨
頁面生命週期,見 [`conventions.md` §5](conventions.md))。文案一律走
`context.l10n.<key>`(l10n 擴充方法,見
[`packages/localization/lib/localization.dart`](../packages/localization/lib/localization.dart)
的 `LocalizationContextX`),不硬編字串。頁面主體(表單)不隨狀態切換,只有
按鈕 `loading` 旗標與失敗 SnackBar 是狀態驅動的局部效果,因此用 `is`
檢查而非 exhaustive `switch`(對照 `HomePage` 整頁三態,見
[`conventions.md` §2.1](conventions.md))。

### 站 2:`LoginBloc` —— sealed state、`fold`、零 Flutter import

[`features/auth/lib/src/presentation/blocs/login/login_bloc.dart`](../features/auth/lib/src/presentation/blocs/login/login_cubit.dart)

```dart
Future<void> _onLoginSubmitted(
  LoginSubmitted event,
  Emitter<LoginState> emit,
) async {
  emit(const LoginSubmitting());
  final result = await _repository.login(email: event.email, password: event.password);
  await result.fold(
    onSuccess: (tokens) async {
      await _session.signIn(tokens);
      emit(const LoginSuccess());
    },
    onFailure: (exception) async {
      emit(LoginFailure(exception));
    },
  );
}
```

**注意一件事**:此檔只 `import 'package:bloc/bloc.dart'`、`session`、
domain 型別,**不 import Flutter**(Bloc 六鐵律第 6 條)。
[`login_state.dart`](../features/auth/lib/src/presentation/blocs/login/login_state.dart)
把 `LoginState` 定義為 `sealed class`(`LoginInitial`/`LoginSubmitting`/
`LoginSuccess`/`LoginFailure`),UI 端靠 exhaustive 檢查或 `is` 判斷,漏處理
是編譯期能抓到的錯誤。登入成功後**不手動導航**——只 `emit(LoginSuccess())`,
真正的頁面跳轉留給站 8 的 router redirect。

### 站 3:`AuthRepository` / `AuthRepositoryImpl` —— Result 單一路徑

[`features/auth/lib/src/domain/repositories/auth_repository.dart`](../features/auth/lib/src/domain/repositories/auth_repository.dart)
定義契約;
[`features/auth/lib/src/data/repositories/auth_repository_impl.dart`](../features/auth/lib/src/data/repositories/auth_repository_impl.dart)
實作:

```dart
Future<Result<AuthTokens>> login({required String email, required String password}) =>
    _client.post<AuthTokens>(
      '/auth/login',
      body: {'email': email, 'password': password},
      parse: (data) => AuthTokensDto.fromJson(data as Map<String, dynamic>).toTokens(),
    );
```

**注意一件事**:repository 一律回傳 `Result<T, AppException>`
([`packages/core`](../packages/core) 的 `src/foundation` 定義),**不寫
`try/catch`**——收攏例外的責任在下一站的 `ApiClient._send()`,repository 只
負責組請求與 DTO→entity 轉換(見 [`conventions.md` §3](conventions.md)「刻意
不提供 `Result.guard`」定案)。

### 站 4:`ApiClient` —— 錯誤收攏的唯一處

[`packages/core/lib/src/networking/api_client.dart`](../packages/core/lib/src/networking/api_client.dart)
的 `_send()`:

```dart
try {
  final response = await request(_dio);
  try {
    return Result.success(parse(response.data));
  } on Object catch (e, st) {
    return Result.failure(ParsingException(cause: e, stackTrace: st));
  }
} on DioException catch (e) {
  return Result.failure(mapDioException(e));
} on Object catch (e, st) {
  return Result.failure(UnknownException(cause: e, stackTrace: st));
}
```

**注意一件事**:這是全庫唯一把 `DioException`/解析例外收攏為
`AppException` 的地方(`mapDioException()` 見
[`packages/core/lib/src/networking/error_mapper.dart`](../packages/core/lib/src/networking/error_mapper.dart))。
`data` 層之上(repository、bloc)只會看到 `AppException`,不會再看到 raw
`DioException`。

### 站 5:`DemoBackendAdapter` —— 假後端接手 HTTP

[`app/lib/src/demo/demo_backend_adapter.dart`](../app/lib/src/demo/demo_backend_adapter.dart)

**注意一件事**:這是 `dio` 的 `HttpClientAdapter` 記憶體實作,不啟本機
HTTP server(見 [ADR-0003](adr/0003-fake-backend-and-e2e-shape.md))。它對
`options.uri.path` 做**精確字串比對**(`path == '/items'` 之類),不是前綴
比對——檔頭註解特別警告:若 `AppConfig.apiBaseUrl` 帶路徑片段(如
`/v1`),所有請求都會落到未知路徑的 404,且無任何錯誤提示,排查時容易誤
以為是後端契約出錯。這是接真後端前務必先讀的一段。

### 站 6:`SessionManager.signIn` —— 登入狀態單一真相

[`packages/core/lib/src/session/session_manager.dart`](../packages/core/lib/src/session/session_manager.dart)
第 73 行起 `Future<void> signIn(AuthTokens tokens)`。

**注意一件事**:`SessionManager` 是 app 生命週期單例(`compose_dependencies.dart`
以 `registerLazySingleton<SessionManager>` 註冊,不提供 dispose,見
[`conventions.md` §9(c)](conventions.md))。`signIn` 把 token 寫入
`persistence` 並發布新的 `SessionState`,**站 2 的 bloc 只呼叫
`signIn`,自己不做任何導航**。

### 站 7:`SessionRefreshListenable` —— 把 session 事件轉成 go_router 訊號

[`app/lib/src/router/session_refresh_listenable.dart`](../app/lib/src/router/session_refresh_listenable.dart)

```dart
class SessionRefreshListenable extends ChangeNotifier {
  SessionRefreshListenable(Stream<SessionState> states) {
    _subscription = states.listen((_) => notifyListeners());
  }
  ...
```

**注意一件事**:訂閱 `SessionManager.states`(同步 broadcast stream,見
[ADR-0004](adr/0004-sync-session-stream.md)),每次事件觸發
`notifyListeners()`,讓 go_router **重新評估** `redirect`——它本身不做任何
判斷,只是訊號轉接器。

### 站 8:router `redirect` —— 登入守衛唯一處

[`app/lib/src/router/app_router.dart`](../app/lib/src/router/app_router.dart)

```dart
redirect: (context, state) {
  final loggedIn = session.state is SessionAuthenticated;
  final goingToLogin = state.matchedLocation == RoutePaths.login;
  if (!loggedIn && !goingToLogin) {
    return RoutePaths.login;
  }
  if (loggedIn && goingToLogin) {
    return RoutePaths.home;
  }
  return null;
},
```

**注意一件事**:這是全庫**唯一**判斷「登入了該去哪」的地方(見
[`architecture.md` §3.3](architecture.md) 表格)。站 2 的 `LoginSuccess`
不直接導航,靠站 6→7→8 這條鏈觸發 router 重新評估,自然導向首頁——這正是
「守衛唯一處」的設計意圖:任何觸發 session 改變的路徑(登入、登出、token
失效)都走同一個 `redirect`,不必在各處各自寫「登入成功後 push 到哪」的
邏輯。

### 搭配閱讀

- 拓撲與三條關鍵鏈路(401 refresh 鏈、bootstrap 五步、三個全域行為唯一
  處):[`architecture.md`](architecture.md)。
- 只讀鐵律(不用照抄,但每條務必先讀懂):[`conventions.md`](conventions.md)
  的 Bloc 六鐵律(§2)、錯誤模型(§3)、測試規範(§8)。

---

## 第 2 段(一天):動手 + 故意犯規

四個練習,每個都有明確步驟與「你應該看到什麼」。全程在 `feature/<name>`
分支操作,不要動 `master`/`develop`。

### 練習 1:產生器解剖——`new_feature.dart` 接了哪六處線

```bash
fvm dart run tool/new_feature.dart practice
git diff --stat
```

**你應該看到什麼**:`git status --short` 會有一個新的未追蹤目錄
`features/practice/`(產生器產出的完整骨架,不算在 `git diff --stat` 內,
因為 diff 只顯示已追蹤檔案的差異);`git diff --stat` 會列出**恰好六個**
被修改的既有檔案:

```
 app/lib/src/di/compose_dependencies.dart     | 2 ++
 app/lib/src/router/app_router.dart           | 2 ++
 app/pubspec.yaml                             | 1 +
 app/test/di_smoke_test.dart                  | 3 +++
 packages/core/lib/src/navigation/route_paths.dart | 3 +++
 pubspec.yaml                                 | 1 +
 6 files changed, 12 insertions(+)
```

這六處分別對應 [`add-a-feature.md`](how-to/add-a-feature.md) 「產生器做了
什麼」的步驟 2~7:根 `workspace:` 清單、`navigation` 的路徑常數與 route
類別範本、`app` 的 pubspec 依賴、DI 註冊呼叫、路由標記區塊、
`di_smoke_test.dart` 的解析斷言——逐一打開這六個檔案,對照
`// {{feature-registry}}` / `// {{route-paths}}` 標記行,確認產生器真的只
在標記行之前插入一行,沒有動其他內容。

還原(練習完先不留著,後面練習不依賴它):

> ⚠️ `git checkout -- .` 會丟棄**整個工作樹**所有未 commit 的修改。執行前先跑
> `git status` 確認除了練習產物外沒有其他 WIP;本文件後續的還原指令同此提醒。

```bash
git checkout -- . && rm -rf features/practice && fvm flutter pub get
```

### 練習 2:`DemoBackendAdapter` 加端點 + practice feature 接上 + l10n key + regen

1. 重跑練習 1 的產生指令(`fvm dart run tool/new_feature.dart practice`)。
2. 在 `demo_backend_adapter.dart` 依現有 `/items` 分支的寫法(精確字串比對
   `options.uri.path`,見第 1 段站 5)加一個 `/practice/entries` 分支,回傳
   固定假資料。
3. 把 `features/practice/lib/src/data/repositories/practice_repository_impl.dart`
   打的路徑對上這個新端點(產生器預設打 `GET /practice/entries`,通常不需
   改)。
4. 在 [`packages/localization/lib/src/arb/app_en.arb`](../packages/localization/lib/src/arb/app_en.arb)
   與 `app_zh.arb` 加 `practice` 前綴的 key,取代 `PracticePage` 內產生器
   留下的暫用字串。
5. 執行 `cd packages/localization && fvm flutter gen-l10n` regen。

**你應該看到什麼**:`git status` 顯示 `packages/localization/lib/src/generated/`
下的檔案(如 `app_localizations_en.dart`)也被改動——這是 regen 的產出,必
須跟著 ARB 改動一起進 commit(見練習 3 的「ARB 不 regen」犯規實驗)。

完成後同樣還原(`git checkout -- . && rm -rf features/practice && fvm flutter pub get`),
除非要接著做練習 3/4。

### 練習 3:觸發每道護欄

依序故意犯規,親眼看訊息,再照上一步指令還原。以下前兩項為本文件實際跑過
`./tool/check.sh` 取得的**真實輸出**;後兩項因不需寫檔案即可推演行為,直
接引用腳本邏輯與 ruleset 說明,不逐一實測。

#### (a) 無理由的 `// ignore`(`check.sh` 2/7)

在任一 `.dart` 檔案加一行沒有 ` -- 原因` 的 ignore,例如在
[`features/home/lib/src/domain/entities/item.dart`](../features/home/lib/src/domain/entities/item.dart)
的 `description` 欄位前加 `// ignore: unused_field`,執行 `./tool/check.sh`。

**實測到的真實輸出**(第 2/7 步中斷):

```
── 2/7 ignore 稽核(// ignore: 必須附 ' -- 原因')──
✗ 未附原因的 ignore:
features/home/lib/src/domain/entities/item.dart:17:  // ignore: unused_field
```

腳本邏輯見 [`tool/check.sh`](../tool/check.sh) 第 2 步:`grep -rn "// ignore"`
掃 `packages app features tool` 下所有 `.dart`,排除 `**/src/generated/**`
(與根 `analysis_options.yaml` 的 `analyzer.exclude` 對齊),再過濾出不含
` -- ` 的行即為違規。還原:`git checkout -- features/home/lib/src/domain/entities/item.dart`。

#### (b) ARB 改動不 regen(`check.sh` 5/7)

在 `app_en.arb` 加一個新 key(如 `"practiceGreeting": "Hello from practice"`)
但**不**執行 `gen-l10n`,執行 `./tool/check.sh`。

**實測到的真實輸出**(第 5/7 步中斷,前 4 步皆通過):

```
── 5/7 l10n 漂移檢查(ARB 需 regen 為 committed 產物)──
...(gen-l10n 產出的 diff,顯示 generated/app_localizations_en.dart 與
    app_localizations_zh.dart 多出 practiceGreeting getter)...
✗ ARB 已改但未 regen:請執行 (cd packages/localization && fvm flutter gen-l10n) 並將 lib/src/generated 的變更納入本 commit
```

腳本邏輯:第 5 步先自己跑一次 `fvm flutter gen-l10n` 把 `generated/` 重新
產出,再用 `git diff --exit-code` 比對——如果 ARB 改了但沒把重新產生的
`generated/` 一起 commit,這裡就會抓到差異。還原:
`git checkout -- packages/localization/lib/src/arb/app_en.arb packages/localization/lib/src/generated/`。

> **注意**:此護欄落在 `check.sh` 的**第 5/7 步**(l10n 漂移檢查),為實測
> 確認的段落編號;全庫文件引用 `check.sh` 段落編號時,一律以
> `tool/check.sh` 原始碼現況(0/7~7/7)為唯一真相。

#### (c) feature 互依(不實測,引用腳本行為)

若 `features/practice/pubspec.yaml` 的 `dependencies:` 區段加入
`home: any`(依賴另一個 feature),`./tool/check.sh` 會在**第 4/7 步「pubspec
依賴稽核」**中斷(見 `tool/check.sh` 第 4 步:掃 `features/*` 的
`dependencies:` 至 `dev_dependencies:` 區段,擋掉任何其他 `features/*`
名稱),印出：

```
✗ 違反依賴方向(feature 不得互依,package 不得依賴 feature/app):
features/practice/pubspec.yaml:   home:
```

（訊息格式節錄自 `tool/check.sh` 的 `dep_violations` 組字邏輯；`3/7` 步是
`tool/guard.sh`「護欄稽核」，稽核的是 `analysis_options.yaml`/產生器標記/
`.fvmrc` 本身有沒有被削弱，不是這條依賴規則——依賴四規則的機器強制落在
4/7。）

#### (d) 直推 `develop`(不實測,引用 ruleset 行為描述)

依 [`conventions.md` §分支與 PR](conventions.md):「`develop`:整合分支,
日常 PR 的目標分支。任何人(含 AI agent)不得直接 push。」倉庫端以 GitHub
ruleset 強制此規則(非本機腳本可驗證,需推到遠端才會觸發),行為預期為:
`git push origin develop` 會被伺服器拒絕(標準 GitHub ruleset 拒絕訊息形態
為 `! [remote rejected] ... (protected branch hook declined)` 或
`GH006: Protected branch update failed`,實際文字依 GitHub 當下版本而定)。
AI agent 的工作方式一律是「開 `feature/<name>` 分支 + PR」,不嘗試直推。

### 練習 4:補 `bloc_test` → `check.sh` 全綠 → 開 PR 看 CI

1. 若練習 2/3 已還原,重跑 `fvm dart run tool/new_feature.dart practice`
   並完成練習 2 的接線步驟。
2. 產生器已經替 `PracticeListCubit` 產出一份可執行的 `bloc_test` 骨架
   (如 `features/practice/test/presentation/practice_list_bloc_test.dart`),
   採全庫統一的測試替身工具鏈——**mocktail + bloc_test**(本文件,見 [`conventions.md` §8.1](conventions.md)):
   `class _MockPracticeRepository extends Mock implements PracticeRepository {}`
   搭配 `blocTest<PracticeListCubit, PracticeListState>(...)`(`blocTest` 對 Cubit 一樣適用),覆蓋初始
   狀態、成功、失敗三種轉換。補齊或調整斷言,使其貼合你在練習 2 加的端點
   回傳資料。
3. 執行 `./tool/check.sh`,逐步修到全綠(0/7 ~ 7/7)。
4. 推上 `feature/practice-<你的名字>` 分支,開 PR(目標分支 `develop`),
   觀察 CI 的三個 job(見 [`.github/workflows/ci.yaml`](../.github/workflows/ci.yaml)):
   - `check`:等同本機 `./tool/guard.sh && ./tool/check.sh`。
   - `generator-smoke`:CI 另外自己跑一次 `fvm dart run tool/new_feature.dart smoke_probe`,
     驗證產生器骨架本身可測試、可通過 analyze(用後即棄,不需你手動清)。
   - `gitleaks`:掃全歷史找洩漏的密鑰。

### 練習結尾:還原沙盒

不論做到第幾個練習,結束時確認回到乾淨狀態,指令與
[`add-a-feature.md` §3.5「失敗復原」](how-to/add-a-feature.md)一致:

```bash
git checkout -- . && rm -rf features/practice
fvm flutter pub get
git status --short   # 應無輸出
```

---

## 第 3 段(半天):懂為什麼

五篇 ADR,各讀一次前先問自己「這篇要回答我心裡的哪個問題」:

| ADR | 讀它回答什麼問題 |
|---|---|
| [0001. 多 package workspace](adr/0001-multi-package-workspace.md) | 為什麼不用 melos、模組邊界靠什麼機制真正擋住(不是靠人力紀律)? |
| [0002. Bloc over Riverpod](adr/0002-bloc-over-riverpod.md) | 為什麼是 Bloc + get_it,不是 Riverpod 或輕量 MVVM? |
| [0003. 假後端形態與 e2e 測試的形狀](adr/0003-fake-backend-and-e2e-shape.md) | 假後端為什麼選 dio mock adapter 而不是本機 HTTP server?「integration test」在這個模板裡實際長什麼樣? |
| [0004. `SessionManager.states` 同步 broadcast](adr/0004-sync-session-stream.md) | 為什麼 session stream 要用同步(`sync: true`)而不是非同步,router 才不會用到過期狀態? |
| [0005. `BufferingCrashReporter`](adr/0005-buffering-crash-reporter.md) | Firebase 還沒 ready 前發生的錯誤去哪了,為什麼不是直接漏掉或降級為僅本地 log? |

### 本文件) §10
(「實作規劃須吸收的已知待辦」)不是一次寫完的清單,而是**五輪計畫(計畫
1~6)各自完成後、獨立審查追加定案**的累積紀錄——第 1~6 條是最初的待辦,
第 7~10 條是「計畫 1 全分支審查後」追加,第 11~15 條是「計畫 2 全分支審查
後」追加,以此類推到第 20~24 條(計畫 4/5 審查後)。§10 末的「§10 驗收狀態」
段落明確記錄「上列 24 條已全數吸收進實作或於文件記載完畢」,並列出三項
「已知殘留、列入路線圖」的邊角(如 pubspec 依賴稽核只掃 `dependencies`
不掃 `dev_dependencies`)。第 25~28 條是之後「通用性缺口重評」再追加的一
輪,其中第 28 條標題直接寫「**已評估並否決(防翻案)**」——例如「連線狀態
監控 package」與「`ApiClient` 內建統一信封層」都被明確評估過並否決,原因
記在條文裡(現有 `ConnectivityException` + retry 已是完整故事;per-call
`parse` 與 `extraInterceptors` 兩個擴充點已存在)。**這是它的作用**:當你
或未來的 AI agent 想重新提案這類「看起來合理」的功能時,先查 §10 有沒有
被討論過、有沒有被否決過——避免同一個提案在不同時間被不同的人(或 AI)
重新翻案又重新討論一次。

---

## 檢核點

獨立完成一次完整流程,不看本文件:

1. `fvm dart run tool/new_feature.dart <你自己取的名字>` 建一個新 feature。
2. 依 [`add-an-api.md`](how-to/add-an-api.md) 接上一支 API(可以是
   `DemoBackendAdapter` 上新加的端點,或既有 `/items` 端點的變體)。
3. 補齊 bloc 事件→狀態轉換測試、repository 錯誤映射測試、page 三態渲染
   測試(依 [`conventions.md` §8.1](conventions.md) 完成的定義)。
4. `./tool/check.sh` 全綠(0/7 ~ 7/7)。
5. 開 PR 到 `develop`,CI 三個 job(`check`、`generator-smoke`、
   `gitleaks`)全過,並勾完
   [PR template](../.github/pull_request_template.md) 的「完成的定義」
   checklist。

做到這五步即代表可以獨立接手一個 feature 任務。
