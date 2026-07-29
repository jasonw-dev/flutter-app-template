# 示範 features(auth、home)+ 假後端 實作計畫(5/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立兩個「範例即規範」的 feature package(auth:有狀態流程;home:API 列表+詳情),以假後端讓模板 clone 後 `flutter run` 即可完整體驗登入→列表→詳情;以全 DI 的 App 級 widget test 取代裝置型 integration test。

**Architecture:** feature 內部依 spec §4(data/domain/presentation 三層、sealed state Bloc、Result 單一錯誤路徑)。假後端定案(spec §10.2):`DemoBackendAdapter implements HttpClientAdapter` 住在 app 層(demo 資料屬組裝範疇),由 `AppConfig.useFakeBackend` 開關(出廠 true)。`AuthTokenRefreshGateway` 走 `createPlainDio`(§10.20c,無 AuthInterceptor 的結構性保證),取代 Placeholder。端到端驗證用「真 DI + 假後端」的 App widget test(CI 可跑);裝置型 integration_test 不出廠(記 spec §10)。

**Tech Stack:** flutter_bloc ^9.0.0、bloc_test ^10.0.0(dev)、既有全部 packages。

## Global Constraints(所有 task 一體適用)

- 沿用前四計畫全部約束(fvm、strict lint 全綠、繁中 doc、TDD、每 task commit 不 push、Task 8 統一推)。
- **Bloc 規範(spec §4.2,全部硬性)**:一律 Bloc 不用 Cubit;state 用 sealed class + UI exhaustive switch;事件命名主詞+過去式;bloc 間禁互引;repository 回傳 `Result`,bloc 禁 try/catch;bloc 檔案不 import Flutter(僅 `package:bloc`)。
- feature 依賴白名單:`auth → flutter, flutter_bloc, foundation, networking, session, navigation, design_system, localization, get_it`;`home → flutter, flutter_bloc, foundation, networking, navigation, design_system, localization, get_it`;dev 一律 `flutter_test, bloc_test, mocktail`。feature 之間互不依賴(§2.2)。
- feature 形狀依 spec §4.1:barrel 只匯出 routes 建構函式、DI 註冊函式、(必要的)gateway 類別;`lib/src/` 私有。
- 測試斷言例外用 `isA<T>()`;官方 fake 一律取自各 package `testing.dart`。
- 假後端 API 契約(demo):`POST /auth/login {email,password}`→200 `{accessToken,refreshToken}`(password 為 `wrong` → 401 envelope `{code:'AUTH_INVALID',message:'Invalid credentials'}`);`POST /auth/refresh {refreshToken}`→200 新 tokens(refreshToken 為 `expired` → 401);`GET /items`→200 `{items:[{id,title,description}×5]}`;`GET /items/<id>`→200 單品或 404。
- 工作目錄:`<repo>`。

---

### Task 1: networking — createDio 擴充與 createPlainDio(§10.20)

**Files:**
- Modify: `packages/networking/lib/src/create_dio.dart`
- Test: `packages/networking/test/create_dio_test.dart`(追加)

**Interfaces:**
- `createDio` 新增可選參數 `List<Interceptor> extraInterceptors = const []`(掛在 AuthInterceptor 之後;doc 註明 retryClient 不掛 extra——重試請求不經過它們,為已知取捨)。
- 新增 `Dio createPlainDio({required NetworkingConfig config, HttpClientAdapter? adapter})`:同 baseOptions、無任何攔截器。doc:「專供 TokenRefreshGateway 實作使用——refresh 呼叫走含 AuthInterceptor 的 client 會在 401 時遞迴觸發 refresh(§2.3 的結構性保證)」。

- [ ] **Step 1:** 追加失敗測試:

```dart
  test('createPlainDio 不含任何攔截器且套用 config', () {
    final dio = createPlainDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
    );
    expect(dio.options.baseUrl, 'https://api.test');
    expect(dio.interceptors.whereType<AuthInterceptor>(), isEmpty);
  });

  test('extraInterceptors 掛在 auth 之後', () {
    final marker = InterceptorsWrapper();
    final dio = createDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
      tokenProvider: FakeTokenProvider(),
      extraInterceptors: [marker],
    );
    final authIndex =
        dio.interceptors.indexWhere((i) => i is AuthInterceptor);
    expect(dio.interceptors.indexOf(marker), greaterThan(authIndex));
  });
```

- [ ] **Step 2:** RED → 實作(createDio 的 interceptors 加 `...extraInterceptors`;createPlainDio 建 baseOptions + adapter)→ GREEN(networking 全部)+ analyze。
- [ ] **Step 3:** Commit `feat(networking): extraInterceptors 掛點與 createPlainDio(§10.20)`。

---

### Task 2: localization — feature 文案

**Files:**
- Modify: `packages/localization/lib/src/arb/app_en.arb`、`app_zh.arb`
- Regen: `packages/localization/lib/src/generated/`
- Test: `packages/localization/test/localization_test.dart`(追加一則)

**Interfaces:** 新 keys(feature 前綴,spec §2.1):
`authLoginTitle`(Login/登入)、`authEmailLabel`(Email/電子郵件)、`authPasswordLabel`(Password/密碼)、`authLoginButton`(Sign in/登入)、`authLoginFailed`(Sign-in failed. Check your credentials./登入失敗,請確認帳號密碼。)、`homeTitle`(Home/首頁)、`homeEmpty`(No items yet./目前沒有項目。)、`homeDetailTitle`(Detail/詳情)。

- [ ] **Step 1:** ARB 追加(en/zh 各 8 key,`// {{feature-arb}}` 無法放 JSON——以 key 排序慣例維持,產生器規格於 Plan 6 處理)→ `fvm flutter gen-l10n` → 追加測試(zh 的 `authLoginTitle == '登入'`、`homeEmpty == '目前沒有項目。'`)→ GREEN + analyze + check.sh format 段通過。
- [ ] **Step 2:** Commit `feat(localization): auth/home feature 文案(en/zh)`。

---

### Task 3: features/auth — domain、data 與 TokenRefreshGateway

**Files:**
- Create: `features/auth/pubspec.yaml`(白名單依賴;`resolution: workspace`;sdk `^3.7.0`)
- Create: `features/auth/lib/auth.dart`(barrel:`registerAuthFeature`、`authRoutes`、`AuthTokenRefreshGateway` 三項——routes/di 於 Task 4 補入 export)
- Create: `features/auth/lib/src/domain/repositories/auth_repository.dart`
- Create: `features/auth/lib/src/data/dtos/login_response_dto.dart`
- Create: `features/auth/lib/src/data/repositories/auth_repository_impl.dart`
- Create: `features/auth/lib/src/data/auth_token_refresh_gateway.dart`
- Modify: `pubspec.yaml`(根 workspace 追加 `- features/auth`)
- Test: `features/auth/test/data/auth_repository_impl_test.dart`
- Test: `features/auth/test/data/auth_token_refresh_gateway_test.dart`

**Interfaces:**
- `abstract interface class AuthRepository { Future<Result<AuthTokens>> login({required String email, required String password}); }`(AuthTokens 來自 session package)。
- `LoginResponseDto.fromJson(Map<String, dynamic>)` → `AuthTokens toTokens()`(欄位 accessToken/refreshToken;手寫 fromJson,不引 json_serializable——兩欄位不值 codegen,conventions 於 Plan 6 記載此判準)。
- `AuthRepositoryImpl(ApiClient client) implements AuthRepository`:`POST /auth/login`,parse 走 DTO;錯誤由 ApiClient 收攏。
- `AuthTokenRefreshGateway(ApiClient plainClient) implements TokenRefreshGateway`:`POST /auth/refresh {refreshToken}`;**doc 註明建構參數必須是 plain client(createPlainDio)**。
- 測試用 `ScriptedAdapter`(`package:networking/testing.dart`)+ 真 ApiClient:成功解析、401 → `Failure(UnauthorizedException)`、格式錯誤 → `Failure(ParsingException)`。

- [ ] **Step 1:** 骨架 + 根註冊 → pub get OK。
- [ ] **Step 2:** 失敗測試(repository:成功回 AuthTokens、401 → UnauthorizedException、缺欄位 → ParsingException;gateway:成功、401、送出 body 含 refreshToken)→ RED。
- [ ] **Step 3:** 實作四檔 → GREEN + analyze。
- [ ] **Step 4:** Commit `feat(auth): domain/data 層與 AuthTokenRefreshGateway`。

---

### Task 4: features/auth — LoginBloc、LoginPage、routes、di

**Files:**
- Create: `features/auth/lib/src/presentation/blocs/login/login_bloc.dart`(+`login_event.dart`、`login_state.dart`,part 或獨立檔皆可,慣例:三檔同資料夾)
- Create: `features/auth/lib/src/presentation/pages/login_page.dart`
- Create: `features/auth/lib/src/routes.dart`
- Create: `features/auth/lib/src/di.dart`
- Modify: `features/auth/lib/auth.dart`
- Test: `features/auth/test/presentation/login_bloc_test.dart`
- Test: `features/auth/test/presentation/login_page_test.dart`

**Interfaces:**
- events:`sealed class LoginEvent`;`final class LoginSubmitted extends LoginEvent { final String email; final String password; }`。
- states:`sealed class LoginState`;`LoginInitial`/`LoginSubmitting`/`LoginSuccess`/`LoginFailure(AppException exception)`(全 const)。
- `class LoginBloc extends Bloc<LoginEvent, LoginState>`:`LoginBloc({required AuthRepository repository, required SessionManager session})`;`LoginSubmitted` → emit Submitting → `repository.login` → fold:成功 `await session.signIn(tokens)` 後 emit Success;失敗 emit `LoginFailure(exception)`。**檔案不 import Flutter**。
- `LoginPage`:StatefulWidget;`BlocProvider(create: (_) => GetIt.instance<LoginBloc>())`;email/password `TextField` + `AppPrimaryButton(label: context.l10n.authLoginButton, loading: state is LoginSubmitting)`;`BlocListener`:`LoginFailure` → `ScaffoldMessenger` SnackBar(`context.l10n.authLoginFailed`)。**LoginSuccess 不手動導航**——session 狀態變更觸發 router redirect(app 層守衛唯一處)。頁面用 `AppPageScaffold(title: context.l10n.authLoginTitle)`。
- `List<GoRoute> authRoutes()`:`GoRoute(path: RoutePaths.login, builder: (_, __) => const LoginPage())`。
- `void registerAuthFeature(GetIt gi)`:`gi..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(gi<ApiClient>()))..registerFactory<LoginBloc>(() => LoginBloc(repository: gi<AuthRepository>(), session: gi<SessionManager>()));`(gateway 由 app 以 plain client 組裝,不在此註冊)。
- bloc_test:成功序列 `[LoginSubmitting, LoginSuccess]` 且 session 已 signIn(用 `InMemorySecureStore` 組真 SessionManager 驗證);失敗序列 `[LoginSubmitting, LoginFailure]` 且 `exception isA<UnauthorizedException>`、session 仍未登入。repository 用 mocktail mock(介面 mock 屬呼叫端測試,允許——官方 fake 規則適用於 package 提供的介面)。
- widget test:輸入帳密點按鈕 → bloc 收到事件(以假 repository 驗證)、Submitting 時按鈕 loading、Failure 顯示 SnackBar 文案。

- [ ] **Step 1:** 失敗測試(bloc_test + widget)→ RED。
- [ ] **Step 2:** 實作 → GREEN(auth 全部)+ analyze。
- [ ] **Step 3:** Commit `feat(auth): LoginBloc、LoginPage 與 feature 註冊`。

---

### Task 5: features/home — domain、data

**Files:**
- Create: `features/home/pubspec.yaml`、`features/home/lib/home.dart`
- Create: `features/home/lib/src/domain/entities/item.dart`
- Create: `features/home/lib/src/domain/repositories/item_repository.dart`
- Create: `features/home/lib/src/data/dtos/item_dto.dart`
- Create: `features/home/lib/src/data/repositories/item_repository_impl.dart`
- Modify: `pubspec.yaml`(根 workspace 追加 `- features/home`)
- Test: `features/home/test/data/item_repository_impl_test.dart`

**Interfaces:**
- `class Item { const Item({required this.id, required this.title, required this.description}); }`(純 Dart)。
- `abstract interface class ItemRepository { Future<Result<List<Item>>> fetchItems(); Future<Result<Item>> fetchItem(String id); }`
- `ItemDto.fromJson` → `Item toEntity()`;`ItemRepositoryImpl(ApiClient)`:`GET /items`(parse `{items: [...]}`)、`GET /items/$id`。
- 測試同 Task 3 模式(ScriptedAdapter):列表成功、404 → `ApiException`、缺欄位 → `ParsingException`、單品成功。

- [ ] **Step 1:** 骨架+根註冊 → 失敗測試 → RED → 實作 → GREEN + analyze。
- [ ] **Step 2:** Commit `feat(home): domain/data 層`。

---

### Task 6: features/home — blocs、pages、routes、di + navigation 常數

**Files:**
- Create: `features/home/lib/src/presentation/blocs/item_list/`(bloc/event/state 三檔)
- Create: `features/home/lib/src/presentation/blocs/item_detail/`(bloc/event/state 三檔)
- Create: `features/home/lib/src/presentation/pages/home_page.dart`、`item_detail_page.dart`
- Create: `features/home/lib/src/routes.dart`、`features/home/lib/src/di.dart`
- Modify: `features/home/lib/home.dart`
- Modify: `packages/navigation/lib/src/route_paths.dart`(於 `{{route-paths}}` 標記處插入)
- Create: `packages/navigation/lib/src/home_routes.dart`(typed route)
- Modify: `packages/navigation/lib/navigation.dart`
- Test: `features/home/test/presentation/item_list_bloc_test.dart`、`item_detail_bloc_test.dart`、`home_pages_test.dart`
- Test: `packages/navigation/test/routes_test.dart`(追加)

**Interfaces:**
- navigation:`RoutePaths.homeItemDetail = '/home/items/:id'`(插在標記處);`class ItemDetailRoute implements AppRoute { const ItemDetailRoute(this.id); final String id; String get location => '/home/items/$id'; }`;測試斷言 location。
- `ItemListBloc`:event `ItemListRequested`;states `ItemListLoading`(初始即 Loading,建構時不自動載入——頁面 initState 加事件)/`ItemListLoaded(List<Item> items)`/`ItemListError(AppException exception)`。
- `ItemDetailBloc`:event `ItemDetailRequested(String id)`;states `ItemDetailLoading`/`ItemDetailLoaded(Item item)`/`ItemDetailError(AppException exception)`。
- `HomePage`:BlocProvider + initState 發 `ItemListRequested`;body exhaustive switch——Loading → `AppLoadingIndicator`;Error → `AppErrorView(message: context.l10n.commonErrorGeneric, onRetry: 再發事件, retryLabel: context.l10n.commonRetry)`;Loaded 且空 → `AppEmptyView(context.l10n.homeEmpty)`;Loaded → ListView(`ListTile` onTap → `context.go(ItemDetailRoute(item.id).location)`)。標題 `context.l10n.homeTitle`(HomePage 本身不含 Scaffold——shell 已提供;直接回傳 body 內容並以 `AppPageScaffold` 包?**決策:HomePage 用 AppPageScaffold**(shell 無 AppBar,巢狀 Scaffold 可接受且讓每頁自帶標題)。
- `ItemDetailPage(id)`:同式樣三態;`AppPageScaffold(title: context.l10n.homeDetailTitle)`。
- `List<RouteBase> homeRoutes()`:`GoRoute(path: RoutePaths.home, builder: HomePage, routes: [GoRoute(path: 'items/:id', builder: (_, state) => ItemDetailPage(id: state.pathParameters['id']!))])`。
- `void registerHomeFeature(GetIt gi)`:ItemRepository lazySingleton、兩個 bloc factory(ItemDetailBloc 需 id?——**不**:id 由事件攜帶,bloc factory 無參)。
- bloc_test:兩個 bloc 各測成功/失敗序列(mock repository);widget test:三態渲染(Loading/Error+retry 重發/Loaded 列表)——用假 repository 注入 bloc,`MaterialApp` 包 l10n delegates。

- [ ] **Step 1:** navigation 常數+typed route(TDD)→ Commit 併入本 task 最終 commit。
- [ ] **Step 2:** 失敗測試(blocs、pages)→ RED → 實作 → GREEN(home + navigation)+ analyze。
- [ ] **Step 3:** Commit `feat(home): 列表/詳情 blocs、pages 與路由`。

---

### Task 7: app 接線 — 假後端、feature 註冊、路由替換、e2e flow test

**Files:**
- Create: `app/lib/src/demo/demo_backend_adapter.dart`
- Modify: `app/lib/src/config/app_config.dart`(+`useFakeBackend = true`、`demoBackendLatency = Duration(milliseconds: 300)`)
- Modify: `app/lib/src/di/compose_dependencies.dart`(adapter 注入;`TokenRefreshGateway` 改 `AuthTokenRefreshGateway(ApiClient(createPlainDio(...adapter)))`;標記處插入 `registerAuthFeature(gi)`、`registerHomeFeature(gi)`)
- Delete: `app/lib/src/di/placeholder_token_refresh_gateway.dart`、`app/lib/src/pages/placeholder_pages.dart`
- Modify: `app/lib/src/router/app_router.dart`(佔位 GoRoute 換 `...authRoutes()` 與 shell 內 `...homeRoutes()`;加 `errorBuilder`——`AppErrorView` + 回首頁按鈕,文案用 l10n common keys)
- Modify: `app/lib/src/shell/app_shell.dart`(佔位 destination 改視覺隱形:`icon: SizedBox.shrink()`、空 label、enabled false;`// Plan 6/次一 feature 時替換`)
- Modify: `app/pubspec.yaml`(+auth、home:any)
- Modify: `app/test/di_smoke_test.dart`(標記處插入解析:`AuthRepository`、`LoginBloc`、`ItemRepository`、`ItemListBloc`、`ItemDetailBloc`、`TokenRefreshGateway` 為 `isA<AuthTokenRefreshGateway>()`)
- Modify: `app/test/router_test.dart`、`app_test.dart`(佔位頁文案斷言改 feature 頁面斷言:login 頁找 `authLoginButton` 文案/`LoginPage` type;home 找 `HomePage` type——測試需包 l10n delegates,改用 pump 完整 `App`)
- Test: `app/test/app_flow_test.dart`(端到端)

**Interfaces:**
- `DemoBackendAdapter({Duration latency = const Duration(milliseconds: 300)}) implements HttpClientAdapter`:實作 Global Constraints 的 demo API 契約;5 筆 items(`id: '1'..'5'`,title `Demo item N`);不驗證 Authorization header;未知路徑 404 envelope。
- compose:`final adapter = config.useFakeBackend ? DemoBackendAdapter(latency: config.demoBackendLatency) : null;` 傳給 createDio 與 createPlainDio。
- `app/test/app_flow_test.dart`(**本模板的「integration test」形態:真 DI + 假後端 + 完整 App**,CI 可跑):config 用 `demoBackendLatency: Duration.zero`;流程——啟動→login 頁;輸入 email/password、點登入→pumpAndSettle→home 列表 `Demo item 1` 可見;tap→詳情頁 description 可見;`password: 'wrong'` 分支→SnackBar `authLoginFailed` 文案、仍在 login 頁。

- [ ] **Step 1:** 失敗的 app_flow_test + di_smoke_test 更新 → RED。
- [ ] **Step 2:** 實作接線(依 Files 清單)→ 全 app 測試 GREEN + analyze。
- [ ] **Step 3:** Commit `feat(app): 假後端、feature 接線與端到端 flow test`。

---

### Task 8: 收尾與 CI

- [ ] **Step 1:** `./tool/check.sh` → 12 成員全綠(9 packages + 2 features + app)。
- [ ] **Step 2:** 依賴白名單抽查(features/auth、features/home 的 dependencies 與 Global Constraints 比對;確認無 feature 依賴 feature)。
- [ ] **Step 3:** 殘餘 commit(`chore: Plan 5 收尾`)+ push;CI 至 success(foreground poll;只修 script/env)。

---

## 完成定義(本計畫)

- [ ] clone 後 `fvm flutter run -t app/lib/main_dev.dart` 可完整體驗登入→列表→詳情(假後端;手動驗證項記入報告)。
- [ ] check.sh 全綠(12 成員);CI 綠;app_flow_test 覆蓋成功與失敗登入路徑。
- [ ] Bloc 規範(§4.2)六條全數落實;bloc 檔案零 Flutter import;UI 三態 exhaustive switch。
- [ ] PlaceholderTokenRefreshGateway 與佔位頁已刪除;gateway 走 createPlainDio;§10.20c/21 吸收。
- [ ] feature 之間零依賴;barrel 只露 di/routes/gateway。

## 後續計畫

6. tool 產生器(new_feature/rename_project)+ CLAUDE.md + docs/how-to + ADR + check.sh 增強(§10.13/14/18/22 與 §10.20a/b 收斂)
