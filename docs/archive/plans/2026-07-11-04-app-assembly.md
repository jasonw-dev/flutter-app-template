# app 組裝層實作計畫(4/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立可執行的 `app/` 組裝層:AppConfig 三環境、bootstrap 五步序列、get_it 組裝(含標記區塊)、GoRouter 登入守衛、shell、di_smoke_test;並吸收 spec §10 第 16–17 條的前置修正。

**Architecture:** 依 spec §5:app 只組裝不含業務邏輯。Firebase 以 `AppConfig.firebaseEnabled` 開關(模板出廠為 false,配置好 Firebase 專案後才開),所有 Firebase 建構延遲到 bootstrap 第 4 步之後;未啟用時以 app 層的 Disabled 替身滿足介面。真正的 `TokenRefreshGateway` 由計畫 5 的 auth feature 提供,本計畫先註冊「一律失敗」的占位實作(token 過期→登出,安全預設)。登入/首頁先以佔位頁面撐起路由與守衛,計畫 5 以 feature 頁面取代(標記區塊已備)。

**Tech Stack:** go_router ^14.6.0、get_it ^8.0.0、firebase_core ^3.10.0(+既有 firebase 套件)、既有九個 workspace packages。

## Global Constraints(所有 task 一體適用)

- 沿用前三計畫全部約束(fvm 3.29.3、strict lint 全綠、繁中 doc、ignore 附原因、conventional commits、每 task commit 不 push、最後統一推、不夾帶產生檔)。
- app 依賴:flutter + 上述三個新套件 + firebase_analytics/crashlytics/messaging + shared_preferences + flutter_secure_storage + 全部九個 workspace packages(any);dev 僅 flutter_test + mocktail。
- **app 層紀律(spec §5.3)**:不得出現業務邏輯;佔位頁與 Disabled 替身必須以 `// Plan 5 取代` / `// {{feature-registry}}` 標記。
- bootstrap 順序定死(spec §5.2):binding → composeDependencies(純註冊)→ 錯誤捕捉掛載 → await 初始化(allReady/Firebase/session.restore)→ runApp。
- di_smoke_test 用 `firebaseEnabled: false` 的 config(不需 Firebase 環境)。
- 原生 flavor/scheme(Android productFlavors、iOS schemes、bundle id 後綴)**不在本計畫**:三個 main 進入點即可運行;原生設定歸入計畫 6 的 how-to 手動設定文件(記入 spec §10)。
- 工作目錄:`<repo>`。

---

### Task 1: 吸收前置修正(observability / push_notifications / design_system)

**Files:**
- Create: `packages/observability/lib/src/crash_reporting_logger.dart`
- Modify: `packages/observability/lib/observability.dart`
- Modify: `packages/push_notifications/lib/src/push_notifications.dart`
- Modify: `packages/push_notifications/lib/src/fcm_push_notifications.dart`
- Modify: `packages/push_notifications/lib/src/testing/fake_push_notifications.dart`
- Modify: `packages/design_system/lib/src/components/app_status_views.dart`
- Modify: `packages/observability/lib/src/analytics_tracker.dart`(doc)
- Test: `packages/observability/test/crash_reporting_logger_test.dart`
- Test: `packages/push_notifications/test/fcm_push_notifications_test.dart`(追加)
- Test: `packages/design_system/test/components_test.dart`(追加)

**Interfaces:**
- Consumes: 各 package 既有 API。
- Produces(spec §10 第 16–17 條):
  - `class CrashReportingLogger implements AppLogger`:`CrashReportingLogger({required AppLogger inner, required CrashReporter reporter})`——debug 只進 inner;info/warning 進 inner + `reporter.log('[LEVEL] message')`(breadcrumb);error 進 inner + `reporter.recordError(error ?? message, stackTrace)`(error 為 null 時以 message 字串上報)。
  - `PushNotifications` 介面新增 `Future<PushTapEvent?> initialTap()`(冷啟動點擊;無則 null)。`FcmPushNotifications` 建構子新增 `required Future<RemoteMessage?> Function() getInitialMessage`(注入 `messaging.getInitialMessage` 的 tear-off 或閉包),實作映射;`FakePushNotifications` 新增建構參數 `PushTapEvent? initialTapEvent`。
  - `PushTapEvent` 映射改防禦式:`data['route']` 非 String 時 routePath 為 null(Fcm 的 taps 與 initialTap 共用同一映射函式)。
  - `AppErrorView`:移除 assert,改為 `onRetry != null && retryLabel != null` 才渲染按鈕(release 安全);doc 註明兩者需成對提供。
  - `AnalyticsTracker.trackEvent` doc 註明參數值限 String/num(Firebase 限制)。

- [ ] **Step 1: 寫失敗測試**

`packages/observability/test/crash_reporting_logger_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/testing.dart';
import 'package:observability/observability.dart';
import 'package:observability/testing.dart';

void main() {
  late FakeLogger inner;
  late FakeCrashReporter reporter;
  late CrashReportingLogger logger;

  setUp(() {
    inner = FakeLogger();
    reporter = FakeCrashReporter();
    logger = CrashReportingLogger(inner: inner, reporter: reporter);
  });

  test('debug 只進 inner', () {
    logger.debug('d');
    expect(inner.records.single.level, LogLevel.debug);
    expect(reporter.logs, isEmpty);
    expect(reporter.recordedErrors, isEmpty);
  });

  test('info/warning 進 inner 並留 breadcrumb', () {
    logger.info('i');
    logger.warning('w');
    expect(inner.records, hasLength(2));
    expect(reporter.logs, ['[INFO] i', '[WARNING] w']);
  });

  test('error 上報 recordError,error 為 null 時以 message 上報', () {
    logger.error('boom', error: 'cause', stackTrace: StackTrace.empty);
    logger.error('no-cause');
    expect(inner.records, hasLength(2));
    expect(reporter.recordedErrors, hasLength(2));
    expect(reporter.recordedErrors[0].error, 'cause');
    expect(reporter.recordedErrors[1].error, 'no-cause');
  });
}
```

`packages/push_notifications/test/fcm_push_notifications_test.dart` 追加(沿用檔內既有 mocktail mocks 與 harness 慣例):

```dart
  test('initialTap:有冷啟動訊息時映射,無則 null', () async {
    final withMessage = FcmPushNotifications(
      messaging: messaging,
      openedMessages: opened.stream,
      getInitialMessage: () async => RemoteMessage(data: {'route': '/home'}),
    );
    final tap = await withMessage.initialTap();
    expect(tap?.routePath, '/home');

    final without = FcmPushNotifications(
      messaging: messaging,
      openedMessages: opened.stream,
      getInitialMessage: () async => null,
    );
    expect(await without.initialTap(), isNull);
  });

  test('data route 非字串時 routePath 為 null(防禦式)', () async {
    final push = FcmPushNotifications(
      messaging: messaging,
      openedMessages: opened.stream,
      getInitialMessage: () async =>
          RemoteMessage(data: {'route': 123, 'k': 'v'}),
    );
    final tap = await push.initialTap();
    expect(tap, isNotNull);
    expect(tap!.routePath, isNull);
    expect(tap.data['k'], 'v');
  });
```

(既有 taps/requestPermission/currentToken 測試的 `FcmPushNotifications(...)` 建構呼叫全數補上 `getInitialMessage: () async => null`。)

`packages/design_system/test/components_test.dart` 追加:

```dart
  testWidgets('AppErrorView:onRetry 有但 retryLabel 缺 → 不渲染按鈕也不崩潰',
      (tester) async {
    await tester.pumpWidget(
      _wrap(Scaffold(body: AppErrorView(message: 'x', onRetry: () {}))),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('x'), findsOneWidget);
  });
```

- [ ] **Step 2: RED**

Run: `cd packages/observability && fvm flutter test`;`cd packages/push_notifications && fvm flutter test`;`cd packages/design_system && fvm flutter test`
Expected: 新測試編譯失敗/失敗;push 既有測試因新必填參數編譯失敗(預期,一併修)。

- [ ] **Step 3: 實作**

`packages/observability/lib/src/crash_reporting_logger.dart`:

```dart
import 'package:foundation/foundation.dart';
import 'package:observability/src/crash_reporter.dart';

/// 把 [AppLogger] 導向 crash 上報的組合 logger(production 組裝用)。
///
/// debug 僅本地;info/warning 附掛為 breadcrumb;error 直接 recordError。
class CrashReportingLogger implements AppLogger {
  /// 以本地 logger 與 crash reporter 組合。
  CrashReportingLogger({required AppLogger inner, required CrashReporter reporter})
      : _inner = inner,
        _reporter = reporter;

  final AppLogger _inner;
  final CrashReporter _reporter;

  @override
  void debug(String message) => _inner.debug(message);

  @override
  void info(String message) {
    _inner.info(message);
    // ignore: discarded_futures -- breadcrumb 為 fire-and-forget
    _reporter.log('[INFO] $message');
  }

  @override
  void warning(String message) {
    _inner.warning(message);
    // ignore: discarded_futures -- breadcrumb 為 fire-and-forget
    _reporter.log('[WARNING] $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _inner.error(message, error: error, stackTrace: stackTrace);
    // ignore: discarded_futures -- 上報為 fire-and-forget
    _reporter.recordError(error ?? message, stackTrace);
  }
}
```

`push_notifications.dart`(介面檔)追加:

```dart
  /// 冷啟動點擊:app 由推播點擊啟動時的事件;無則 null。
  /// app 應於首幀後檢查一次並轉路由。
  Future<PushTapEvent?> initialTap();
```

`fcm_push_notifications.dart`:建構子加 `required Future<RemoteMessage?> Function() getInitialMessage`,欄位 `_getInitialMessage`;抽私有頂層/靜態映射函式:

```dart
PushTapEvent _toTapEvent(RemoteMessage message) {
  final route = message.data['route'];
  return PushTapEvent(
    routePath: route is String ? route : null,
    data: message.data,
  );
}
```

`taps` 改 `.map(_toTapEvent)`;

```dart
  @override
  Future<PushTapEvent?> initialTap() async {
    final message = await _getInitialMessage();
    return message == null ? null : _toTapEvent(message);
  }
```

`fake_push_notifications.dart`:建構子加 `this.initialTapEvent`,`Future<PushTapEvent?> initialTap() async => initialTapEvent;`。

`app_status_views.dart`:移除 assert;按鈕條件改 `if (onRetry != null && retryLabel != null)`;doc 補「兩者需成對提供,缺一則不顯示按鈕」。

`analytics_tracker.dart`:trackEvent doc 追加「參數值限 String/num(Firebase 限制),其他型別行為未定義」。

- [ ] **Step 4: GREEN + analyze + Commit**

Run: 三個 package `fvm flutter test` 全綠 + 根 `fvm flutter analyze` → `No issues found!`

```bash
git add -A
git commit -m "feat(observability,push,design_system): 計畫 4 前置吸收(§10.16-17)"
```

---

### Task 2: app 骨架與 AppConfig 三環境

**Files:**
- Create: `app/`(`fvm flutter create --project-name app --org com.example.template app` 後整理)
- Modify: `app/pubspec.yaml`(重寫)
- Delete: `app/lib/main.dart`、`app/test/widget_test.dart`
- Create: `app/lib/main_dev.dart`、`app/lib/main_stg.dart`、`app/lib/main_prod.dart`
- Create: `app/lib/src/config/app_config.dart`
- Create: `app/lib/src/bootstrap.dart`(本 task 先佔位:直接 `runApp` 一個 Placeholder,Task 4 完成真序列)
- Modify: `pubspec.yaml`(根,workspace 追加 `- app`)
- Test: `app/test/app_config_test.dart`

**Interfaces:**
- Produces:
  - `enum AppEnvironment { dev, stg, prod }`
  - `class AppConfig { const AppConfig({required this.environment, required this.apiBaseUrl, this.firebaseEnabled = false}); }` 同名欄位。
  - 三個 main 各兩行:`void main() => bootstrap(const AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'https://dev.api.example.com'));`(stg/prod 對應網址;prod 的 firebaseEnabled 仍為 false,出廠預設,配置 Firebase 後才改 true——doc 註明)。

- [ ] **Step 1:** `fvm flutter create --project-name app --org com.example.template --platforms ios,android app`;刪 `app/lib/main.dart`、`app/test/widget_test.dart`。
- [ ] **Step 2:** 重寫 `app/pubspec.yaml`:

```yaml
name: app
description: 組裝層:flavor 進入點、DI、路由、shell。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  design_system: any
  firebase_analytics: ^11.4.0
  firebase_core: ^3.10.0
  firebase_crashlytics: ^4.3.0
  firebase_messaging: ^15.2.0
  flutter:
    sdk: flutter
  flutter_secure_storage: ^9.2.2
  foundation: any
  get_it: ^8.0.0
  go_router: ^14.6.0
  localization: any
  navigation: any
  networking: any
  observability: any
  persistence: any
  push_notifications: any
  session: any
  shared_preferences: ^2.3.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
```

根 workspace 追加 `- app`。Run: `fvm flutter pub get` → OK。

- [ ] **Step 3:** 失敗測試 `app/test/app_config_test.dart`:

```dart
import 'package:app/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConfig 保存環境設定,firebaseEnabled 預設 false', () {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: 'https://dev.api.example.com',
    );
    expect(config.environment, AppEnvironment.dev);
    expect(config.apiBaseUrl, 'https://dev.api.example.com');
    expect(config.firebaseEnabled, isFalse);
  });
}
```

- [ ] **Step 4:** RED → 實作 `app_config.dart`(如 Interfaces)、三個 main、佔位 bootstrap:

```dart
import 'package:app/src/config/app_config.dart';
import 'package:flutter/material.dart';

/// 啟動序列;Task 4 完成完整五步,目前為可編譯佔位。
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Placeholder());
}
```

- [ ] **Step 5:** GREEN(`cd app && fvm flutter test`)+ analyze 全綠 → Commit `feat(app): 骨架、AppConfig 與三環境進入點`。

---

### Task 3: DI 組裝與 di_smoke_test

**Files:**
- Create: `app/lib/src/di/compose_dependencies.dart`
- Create: `app/lib/src/di/disabled_services.dart`
- Create: `app/lib/src/di/placeholder_token_refresh_gateway.dart`
- Test: `app/test/di_smoke_test.dart`

**Interfaces:**
- Produces:
  - `Future<void> composeDependencies(GetIt gi, AppConfig config)`:註冊順序——config、`BufferingCrashReporter`(singleton,兼 `CrashReporter`)、`AppLogger`(prod → `CrashReportingLogger(inner: ConsoleLogger(), reporter: gi<CrashReporter>())`;其他 → `ConsoleLogger()`)、`registerSingletonAsync<SharedPreferences>`、`KeyValueStore`/`SecureStore`、`PlaceholderTokenRefreshGateway`(占位,`// Plan 5 auth feature 取代`)、`SessionManager`(兼 `TokenProvider`)、`Dio`(createDio)+ `ApiClient`、`AnalyticsTracker`(enabled ? Firebase : Disabled)、`PushNotifications`(enabled ? Fcm(注入 instance 與 static streams)ize : Disabled)。**Firebase 相關一律 lazy,未啟用時不觸碰 Firebase API**。尾端保留 `// {{feature-registry}}` 標記。
  - `DisabledAnalyticsTracker`/`DisabledPushNotifications`:app 層替身(空行為;doc 註明僅供未配置 Firebase 的出廠狀態)。
  - `PlaceholderTokenRefreshGateway implements TokenRefreshGateway`:恆回 `Result.failure(UnauthorizedException())`(安全預設:token 過期即登出)。
  - `app/test/di_smoke_test.dart`:compose(dev config, firebaseEnabled=false)→ `await gi.allReady()` → 逐一解析:`AppConfig`、`AppLogger`、`CrashReporter`、`KeyValueStore`、`SecureStore`、`SessionManager`、`TokenProvider`、`ApiClient`、`AnalyticsTracker`、`PushNotifications`;含 `// {{feature-registry}}` 標記區塊(產生器插入點)。

- [ ] **Step 1:** 寫失敗 smoke test(結構如上,`setUp` 用 `GetIt.asNewInstance()`)。
- [ ] **Step 2:** RED → 實作三檔。`composeDependencies` 骨架:

```dart
Future<void> composeDependencies(GetIt gi, AppConfig config) async {
  gi
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<BufferingCrashReporter>(BufferingCrashReporter())
    ..registerLazySingleton<CrashReporter>(() => gi<BufferingCrashReporter>())
    ..registerLazySingleton<AppLogger>(
      () => config.environment == AppEnvironment.prod
          ? CrashReportingLogger(
              inner: ConsoleLogger(),
              reporter: gi<CrashReporter>(),
            )
          : ConsoleLogger(),
    )
    ..registerSingletonAsync<SharedPreferences>(SharedPreferences.getInstance)
    ..registerLazySingleton<KeyValueStore>(
      () => SharedPreferencesStore(gi<SharedPreferences>()),
    )
    ..registerLazySingleton<SecureStore>(
      () => SecureStorageStore(const FlutterSecureStorage()),
    )
    ..registerLazySingleton<TokenRefreshGateway>(
      PlaceholderTokenRefreshGateway.new, // Plan 5 auth feature 取代
    )
    ..registerLazySingleton<SessionManager>(
      () => SessionManager(
        store: gi<SecureStore>(),
        gateway: gi<TokenRefreshGateway>(),
        logger: gi<AppLogger>(),
      ),
    )
    ..registerLazySingleton<TokenProvider>(() => gi<SessionManager>())
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        createDio(
          config: NetworkingConfig(baseUrl: config.apiBaseUrl),
          tokenProvider: gi<TokenProvider>(),
        ),
      ),
    )
    ..registerLazySingleton<AnalyticsTracker>(
      () => config.firebaseEnabled
          ? FirebaseAnalyticsTracker(FirebaseAnalytics.instance)
          : const DisabledAnalyticsTracker(),
    )
    ..registerLazySingleton<PushNotifications>(
      () => config.firebaseEnabled
          ? FcmPushNotifications(
              messaging: FirebaseMessaging.instance,
              openedMessages: FirebaseMessaging.onMessageOpenedApp,
              getInitialMessage: () =>
                  FirebaseMessaging.instance.getInitialMessage(),
            )
          : DisabledPushNotifications(),
    );
  // {{feature-registry}} -- tool/new_feature.dart 於此插入 feature 註冊
}
```

(Disabled 替身:`DisabledAnalyticsTracker` 全空實作 const;`DisabledPushNotifications` permission false、token null、兩個 stream 為 `Stream.empty()`、initialTap null。)

- [ ] **Step 3:** GREEN(`cd app && fvm flutter test test/di_smoke_test.dart`)+ analyze → Commit `feat(app): DI 組裝與 di_smoke_test(標記區塊)`。

---

### Task 4: bootstrap 五步序列與錯誤邊界

**Files:**
- Modify: `app/lib/src/bootstrap.dart`
- Test: `app/test/bootstrap_error_hooks_test.dart`

**Interfaces:**
- Produces:完整 `bootstrap(AppConfig)`(spec §5.2 五步),以及可獨立測試的 `void installErrorHooks({required AppLogger logger, required CrashReporter reporter})`:設定 `FlutterError.onError`(轉 logger.error + reporter.recordError(fatal:false)後仍呼叫 `FlutterError.presentError`)與 `PlatformDispatcher.instance.onError`(上報 fatal:true,回傳 true)。

- [ ] **Step 1:** 失敗測試(注入 fakes,手動觸發兩個 hook,斷言上報內容;測試結束還原原 handler):

```dart
import 'dart:ui';

import 'package:app/src/bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/testing.dart';
import 'package:observability/testing.dart';

void main() {
  test('installErrorHooks 轉送 FlutterError 與 PlatformDispatcher', () {
    final logger = FakeLogger();
    final reporter = FakeCrashReporter();
    final originalOnError = FlutterError.onError;
    final originalPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = originalOnError;
      PlatformDispatcher.instance.onError = originalPlatform;
    });

    installErrorHooks(logger: logger, reporter: reporter);

    FlutterError.onError!(
      FlutterErrorDetails(exception: Exception('widget boom')),
    );
    expect(reporter.recordedErrors, hasLength(1));
    expect(reporter.recordedErrors.single.fatal, isFalse);

    final handled = PlatformDispatcher.instance.onError!(
      Exception('zone boom'),
      StackTrace.empty,
    );
    expect(handled, isTrue);
    expect(reporter.recordedErrors, hasLength(2));
    expect(reporter.recordedErrors[1].fatal, isTrue);
    expect(logger.records.where((r) => r.level == LogLevel.error), hasLength(2));
  });
}
```

(需 `import 'package:foundation/foundation.dart';` 取 LogLevel——實作時補齊 import。)

- [ ] **Step 2:** RED → 實作:

```dart
/// 啟動序列(spec §5.2,順序不可變)。
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();               // 1
  final gi = GetIt.instance;
  await composeDependencies(gi, config);                   // 2 純註冊
  installErrorHooks(                                        // 3
    logger: gi<AppLogger>(),
    reporter: gi<CrashReporter>(),
  );
  await gi.allReady();                                      // 4a persistence 等就緒
  if (config.firebaseEnabled) {                             // 4b
    await Firebase.initializeApp();
    await gi<BufferingCrashReporter>()
        .attach(CrashlyticsCrashReporter(FirebaseCrashlytics.instance));
  }
  await gi<SessionManager>().restore();                     // 4c
  runApp(App(gi: gi));                                      // 5
}
```

`installErrorHooks` 如 Interfaces(FlutterError:log + recordError 後 `FlutterError.presentError(details)`;PlatformDispatcher:log + recordError(fatal: true) 回 true)。`App` widget 於 Task 6 建立——本 task 先以 `runApp(const Placeholder())` 保持可編譯,Task 6 換上(在檔內留 `// Task 6 換 App`)。

- [ ] **Step 3:** GREEN + analyze → Commit `feat(app): bootstrap 五步序列與錯誤邊界`。

---

### Task 5: 路由(登入守衛 + 佔位頁 + 標記)

**Files:**
- Create: `app/lib/src/router/app_router.dart`
- Create: `app/lib/src/router/session_refresh_listenable.dart`
- Create: `app/lib/src/pages/placeholder_pages.dart`
- Test: `app/test/router_test.dart`

**Interfaces:**
- Produces:
  - `GoRouter buildRouter(SessionManager session)`:`initialLocation: RoutePaths.home`;`refreshListenable: SessionRefreshListenable(session.states)`;redirect——未登入且目標非 login → login;已登入且目標為 login → home;其餘 null。routes:`GoRoute(RoutePaths.login → PlaceholderLoginPage)`、`GoRoute(RoutePaths.home → PlaceholderHomePage)`,尾端 `// {{feature-registry}}` 標記(Plan 5/產生器插入)。
  - `SessionRefreshListenable extends ChangeNotifier`:訂閱 stream,事件即 `notifyListeners()`;`dispose` 取消訂閱。
  - 佔位頁(`// Plan 5 以 feature 頁面取代`):`PlaceholderLoginPage` 用 `AppPageScaffold(title: 'Login')` 包 `Text('login placeholder')`;`PlaceholderHomePage` 同式樣 `'home placeholder'`。

- [ ] **Step 1:** 失敗測試 `app/test/router_test.dart`(widget test:`MaterialApp.router` + 以 `InMemorySecureStore`/`FakeTokenRefreshGateway`/`FakeLogger` 組 `SessionManager`):
  1. 未登入啟動 → 顯示 `login placeholder`(守衛導向)。
  2. `await session.signIn(...)` 後 `pumpAndSettle` → 顯示 `home placeholder`(refreshListenable 觸發 redirect)。
  3. 已登入時 `router.go(RoutePaths.login)` → 仍顯示 home(反向守衛)。
  4. `await session.signOut()` 後 → 回 login(token 失效登出路徑,spec §5.3)。

```dart
import 'package:app/src/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/testing.dart';
import 'package:navigation/navigation.dart';
import 'package:persistence/testing.dart';
import 'package:session/session.dart';
import 'package:session/testing.dart';

void main() {
  late SessionManager session;
  late GoRouter router; // import 'package:go_router/go_router.dart';

  setUp(() async {
    session = SessionManager(
      store: InMemorySecureStore(),
      gateway: FakeTokenRefreshGateway(),
      logger: FakeLogger(),
    );
    await session.restore(); // 空儲存 → Unauthenticated
    router = buildRouter(session);
  });

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

  testWidgets('未登入導向 login', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('login placeholder'), findsOneWidget);
  });

  testWidgets('signIn 後轉 home;signOut 後回 login', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await session.signIn(
      const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    await tester.pumpAndSettle();
    expect(find.text('home placeholder'), findsOneWidget);

    router.go(RoutePaths.login);
    await tester.pumpAndSettle();
    expect(find.text('home placeholder'), findsOneWidget);

    await session.signOut();
    await tester.pumpAndSettle();
    expect(find.text('login placeholder'), findsOneWidget);
  });
}
```

- [ ] **Step 2:** RED → 實作三檔(如 Interfaces;redirect 用 `state.matchedLocation`)。
- [ ] **Step 3:** GREEN + analyze → Commit `feat(app): 路由與登入守衛(佔位頁 + 標記區塊)`。

---

### Task 6: App widget 與 shell

**Files:**
- Create: `app/lib/src/app.dart`
- Create: `app/lib/src/shell/app_shell.dart`
- Modify: `app/lib/src/bootstrap.dart`(換上 App)
- Modify: `app/lib/src/router/app_router.dart`(home 路由包進 ShellRoute)
- Test: `app/test/app_test.dart`

**Interfaces:**
- Produces:
  - `class App extends StatefulWidget`:`App({required GetIt gi})`;建 router(一次);`MaterialApp.router` 綁 `theme: buildAppTheme(light)`、`darkTheme: buildAppTheme(dark)`、`localizationsDelegates`/`supportedLocales`(localization);initState 訂閱 `PushNotifications.taps`(routePath 非 null → `router.go`)、首幀後檢查 `initialTap()` 轉路由;dispose 取消訂閱。
  - `AppShell({required Widget child})`:`Scaffold` + `NavigationBar`(單一 Home destination,`// Plan 5 隨 feature 擴充`);`app_router` 的 home 路由改包 `ShellRoute(builder: AppShell)`。
  - 守衛以外的全域行為(推播轉路由)只在 App 一處(spec §5.3)。

- [ ] **Step 1:** 失敗測試 `app/test/app_test.dart`:組最小 GetIt(手動註冊 fakes:SessionManager(fake 組件)、`FakePushNotifications`、localization 由 App 內建)——
  1. 未登入 pump `App` → login placeholder 顯示、`NavigationBar` 不存在。
  2. signIn 後 → home placeholder + `NavigationBar` 存在(shell 生效)。
  3. `fakePush.emitTap(PushTapEvent(routePath: RoutePaths.login))` 已登入時 → 守衛擋回 home(仍顯示 home);`initialTapEvent` 設 `RoutePaths.home` 未登入啟動 → 守衛導 login(不崩潰)。
- [ ] **Step 2:** RED → 實作;bootstrap 的 runApp 換 `App(gi: gi)`。
- [ ] **Step 3:** GREEN + analyze;`cd app && fvm flutter test`(全部 app 測試)→ Commit `feat(app): App widget、shell 與推播轉路由`。

---

### Task 7: 收尾與 CI

- [ ] **Step 1:** `./tool/check.sh` → 10 個成員全綠(九 packages + app),`✓ all checks passed`。
- [ ] **Step 2:** app 依賴抽查:`sed -n '/^dependencies:/,/^dev_dependencies:/p' app/pubspec.yaml` 與 Global Constraints 比對;`git ls-files app | grep -E '\\.flutter-plugins'` 應為空。
- [ ] **Step 3:** 殘餘 commit(`chore: Plan 4 收尾`)+ trailer,`git push origin main`。
- [ ] **Step 4:** `gh run list` 至最新 run `success`;失敗僅修 script/workflow/環境。

---

## 完成定義(本計畫)

- [ ] `fvm flutter run -t app/lib/main_dev.dart` 可啟動至 login 佔位頁(手動驗證項,記入報告即可,CI 不跑)。
- [ ] check.sh 全綠(含 app);CI 綠;di_smoke_test 涵蓋全部註冊並含標記區塊。
- [ ] bootstrap 五步順序與 spec §5.2 一致;錯誤邊界有測試。
- [ ] 守衛/推播轉路由/token 失效登出三個全域行為各只存在一處且有測試。
- [ ] spec §10.16-17 吸收完畢。

## 後續計畫

5. 示範 features(auth、home)+ 假後端 + integration test(取代佔位頁與 PlaceholderTokenRefreshGateway)
6. tool 產生器 + CLAUDE.md + docs + ADR(含原生 flavor/scheme 手動設定 how-to;spec §10.13/14/18)
