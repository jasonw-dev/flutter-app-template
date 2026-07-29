# design_system + localization + navigation + observability + push_notifications 實作計畫(3/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立五個 UI/服務層 package:`navigation`(跨 feature 導航契約)、`design_system`(tokens/theme/共用元件)、`localization`(gen-l10n)、`observability`(log/crash/埋點,含啟動期緩衝)、`push_notifications`(FCM 抽象)。

**Architecture:** 依 spec §2.1:五個 package 彼此不依賴(各自最多依賴 foundation);Firebase 一律隔在抽象介面後(spec §7),plugin 實例由 app 組裝層(計畫 4)建構注入,本計畫不含任何 Firebase 初始化。`BufferingCrashReporter` 解決 spec §10 第 3 條(Firebase init 前的錯誤緩衝)。

**Tech Stack:** flutter_localizations + intl(gen-l10n)、firebase_crashlytics ^4.3.0、firebase_analytics ^11.4.0、firebase_messaging ^15.2.0、mocktail(dev)。

## Global Constraints(所有 task 一體適用)

- 沿用 Plan 1/2 全部約束:fvm(Flutter 3.29.3)、`^3.7.0`、`publish_to: none` + `resolution: workspace`、根 pubspec workspace 註冊、conventional commits、每 task commit 不 push(Task 8 統一推)、不夾帶 `.flutter-plugins*`。
- lint very_good_analysis strict;**程式碼區塊是語意規格**,實作須補 doc comments(繁中)/排版讓 `fvm flutter analyze` 全綠;ignore 必附 ` -- 原因`。
- 依賴白名單(超出即違規):`navigation → (無依賴)`;`design_system → flutter`;`localization → flutter, flutter_localizations, intl`;`observability → flutter, foundation, firebase_analytics, firebase_crashlytics`;`push_notifications → flutter, firebase_messaging`。dev 依賴一律僅 `flutter_test`(+`mocktail`)或 `test`。
- 提供介面的 package 自 `lib/testing.dart` 匯出官方 fake;barrel 不匯出 testing。
- 例外斷言用 `isA<T>()`;測試替身 mocktail 或手寫 fake。
- 純 Dart package(navigation)用 `fvm dart test`;其餘用 `fvm flutter test`。
- 工作目錄:`<repo>`。

---

### Task 1: navigation package(導航契約 + 核心路由)

**Files:**
- Create: `packages/navigation/pubspec.yaml`
- Create: `packages/navigation/lib/navigation.dart`
- Create: `packages/navigation/lib/src/app_route.dart`
- Create: `packages/navigation/lib/src/route_paths.dart`
- Create: `packages/navigation/lib/src/core_routes.dart`
- Modify: `pubspec.yaml`(根,workspace 追加)
- Test: `packages/navigation/test/routes_test.dart`

**Interfaces:**
- Consumes: 無(零依賴純 Dart)。
- Produces(features 與 app 的導航單一真相):
  - `abstract interface class AppRoute { String get location; }`
  - `String buildLocation(String path, {Map<String, String> query = const {}})`:query 空時回 path;否則以 `Uri(path:, queryParameters:)` 組合(自動編碼)。
  - `abstract final class RoutePaths`:`static const login = '/login'; static const home = '/home';` 並保留產生器標記 `// {{route-paths}}`。
  - `class LoginRoute implements AppRoute`、`class HomeRoute implements AppRoute`(const 建構、location 對應常數)。核心路由先行,feature 專屬路由由 Plan 5/產生器插入。

- [ ] **Step 1: 建 package 骨架與根 workspace 註冊**

`packages/navigation/pubspec.yaml`:

```yaml
name: navigation
description: 跨 feature 導航契約:路由路徑常數與型別化路由。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dev_dependencies:
  test: ^1.25.0
```

根 `pubspec.yaml` workspace 追加 `- packages/navigation`。
Run: `fvm flutter pub get` → `Got dependencies!`

- [ ] **Step 2: 寫失敗測試**

`packages/navigation/test/routes_test.dart`:

```dart
import 'package:navigation/navigation.dart';
import 'package:test/test.dart';

void main() {
  test('核心路由的 location 對應路徑常數', () {
    expect(const LoginRoute().location, RoutePaths.login);
    expect(const HomeRoute().location, RoutePaths.home);
    expect(const LoginRoute(), isA<AppRoute>());
  });

  test('buildLocation 無 query 時回傳原路徑', () {
    expect(buildLocation('/items'), '/items');
  });

  test('buildLocation 組合並編碼 query', () {
    final location = buildLocation('/items', query: {'q': 'a b', 'page': '2'});
    expect(location, '/items?q=a+b&page=2');
  });
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `cd packages/navigation && fvm dart test`
Expected: 編譯失敗,型別未定義。

- [ ] **Step 4: 最小實作**

`packages/navigation/lib/src/app_route.dart`:

```dart
/// 型別化路由的共同契約:能把自己轉成 go_router 可用的 location 字串。
// ignore: one_member_abstracts -- 契約刻意單方法,實作為各路由類別
abstract interface class AppRoute {
  /// 完整 location(路徑 + 已編碼 query)。
  String get location;
}

/// 組合路徑與 query(自動 URL 編碼)。
String buildLocation(String path, {Map<String, String> query = const {}}) {
  if (query.isEmpty) {
    return path;
  }
  return Uri(path: path, queryParameters: query).toString();
}
```

`packages/navigation/lib/src/route_paths.dart`:

```dart
/// 全 app 的路由路徑常數(單一真相;app 的路由表與 features 都取用這裡)。
abstract final class RoutePaths {
  /// 登入頁。
  static const login = '/login';

  /// 首頁。
  static const home = '/home';

  // {{route-paths}} -- tool/new_feature.dart 於此插入新 feature 的路徑常數
}
```

`packages/navigation/lib/src/core_routes.dart`:

```dart
import 'package:navigation/src/app_route.dart';
import 'package:navigation/src/route_paths.dart';

/// 導向登入頁。
class LoginRoute implements AppRoute {
  /// 建立登入頁路由。
  const LoginRoute();

  @override
  String get location => RoutePaths.login;
}

/// 導向首頁。
class HomeRoute implements AppRoute {
  /// 建立首頁路由。
  const HomeRoute();

  @override
  String get location => RoutePaths.home;
}
```

`packages/navigation/lib/navigation.dart`:

```dart
/// 跨 feature 導航契約:路由路徑常數與型別化路由。
library;

export 'src/app_route.dart';
export 'src/core_routes.dart';
export 'src/route_paths.dart';
```

- [ ] **Step 5: 測試與 analyze 通過後 Commit**

Run: `cd packages/navigation && fvm dart test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

```bash
git add -A
git commit -m "feat(navigation): 導航契約與核心路由"
```

---

### Task 2: design_system — tokens 與 theme

**Files:**
- Create: `packages/design_system/pubspec.yaml`
- Create: `packages/design_system/lib/design_system.dart`
- Create: `packages/design_system/lib/src/tokens.dart`
- Create: `packages/design_system/lib/src/theme.dart`
- Modify: `pubspec.yaml`(根)
- Test: `packages/design_system/test/theme_test.dart`

**Interfaces:**
- Consumes: 無(僅 flutter)。
- Produces:
  - `abstract final class AppSpacing`:`static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;`
  - `abstract final class AppRadii`:`static const double sm = 8, md = 12, lg = 16;`
  - `abstract final class AppDurations`:`static const fast = Duration(milliseconds: 150); normal = Duration(milliseconds: 300);`
  - `ThemeData buildAppTheme({required Brightness brightness, Color seedColor = const Color(0xFF3B82F6)})`:Material 3、`ColorScheme.fromSeed`、`AppBarTheme(centerTitle: true)`、`FilledButtonTheme` 以 `AppRadii.md` 圓角與 `AppSpacing.md` 垂直內距。app(計畫 4)以此建 light/dark 兩套。

- [ ] **Step 1: 建骨架**

`packages/design_system/pubspec.yaml`:

```yaml
name: design_system
description: design tokens、theme、共用 UI 元件與頁面外框元件。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

根 workspace 追加 `- packages/design_system`。Run: `fvm flutter pub get`。

- [ ] **Step 2: 寫失敗測試**

`packages/design_system/test/theme_test.dart`:

```dart
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tokens 有預期值', () {
    expect(AppSpacing.md, 16);
    expect(AppRadii.md, 12);
    expect(AppDurations.fast, const Duration(milliseconds: 150));
  });

  test('buildAppTheme 產出 M3 主題且明暗各自成立', () {
    final light = buildAppTheme(brightness: Brightness.light);
    final dark = buildAppTheme(brightness: Brightness.dark);
    expect(light.useMaterial3, isTrue);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(light.appBarTheme.centerTitle, isTrue);
  });

  test('seedColor 影響 colorScheme', () {
    final a = buildAppTheme(
      brightness: Brightness.light,
      seedColor: const Color(0xFFE11D48),
    );
    final b = buildAppTheme(brightness: Brightness.light);
    expect(a.colorScheme.primary, isNot(b.colorScheme.primary));
  });
}
```

- [ ] **Step 3: RED**

Run: `cd packages/design_system && fvm flutter test`
Expected: 編譯失敗。

- [ ] **Step 4: 最小實作**

`packages/design_system/lib/src/tokens.dart`:

```dart
/// 間距刻度(dp)。
abstract final class AppSpacing {
  /// 4。
  static const double xs = 4;

  /// 8。
  static const double sm = 8;

  /// 16。
  static const double md = 16;

  /// 24。
  static const double lg = 24;

  /// 32。
  static const double xl = 32;
}

/// 圓角刻度(dp)。
abstract final class AppRadii {
  /// 8。
  static const double sm = 8;

  /// 12。
  static const double md = 12;

  /// 16。
  static const double lg = 16;
}

/// 動畫時長刻度。
abstract final class AppDurations {
  /// 150ms:微互動。
  static const fast = Duration(milliseconds: 150);

  /// 300ms:頁面轉場等。
  static const normal = Duration(milliseconds: 300);
}
```

`packages/design_system/lib/src/theme.dart`:

```dart
import 'package:design_system/src/tokens.dart';
import 'package:flutter/material.dart';

/// 建立 app 主題(Material 3);light/dark 各呼叫一次。
ThemeData buildAppTheme({
  required Brightness brightness,
  Color seedColor = const Color(0xFF3B82F6),
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    appBarTheme: const AppBarTheme(centerTitle: true),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    ),
  );
}
```

`packages/design_system/lib/design_system.dart`:

```dart
/// design tokens、theme、共用 UI 元件與頁面外框元件。
library;

export 'src/theme.dart';
export 'src/tokens.dart';
```

- [ ] **Step 5: GREEN + analyze + Commit**

Run: `cd packages/design_system && fvm flutter test && cd ../.. && fvm flutter analyze` → 全綠。

```bash
git add -A
git commit -m "feat(design_system): tokens 與 M3 theme"
```

---

### Task 3: design_system — 共用元件

**Files:**
- Create: `packages/design_system/lib/src/components/app_page_scaffold.dart`
- Create: `packages/design_system/lib/src/components/app_status_views.dart`
- Create: `packages/design_system/lib/src/components/app_primary_button.dart`
- Modify: `packages/design_system/lib/design_system.dart`
- Test: `packages/design_system/test/components_test.dart`

**Interfaces:**
- Consumes: Task 2 tokens。
- Produces(Plan 5 頁面直接使用;所有文案由呼叫端傳入——design_system 不依賴 localization):
  - `AppPageScaffold({required String title, required Widget body, List<Widget>? actions})`:AppBar + SafeArea body。
  - `AppLoadingIndicator()`:置中 `CircularProgressIndicator`。
  - `AppErrorView({required String message, VoidCallback? onRetry, String? retryLabel})`:置中訊息 + 可選重試按鈕(onRetry 非 null 時必須提供 retryLabel)。
  - `AppEmptyView({required String message})`。
  - `AppPrimaryButton({required String label, VoidCallback? onPressed, bool loading = false})`:`FilledButton`;loading 時顯示 indicator 並停用。

- [ ] **Step 1: 寫失敗測試**

`packages/design_system/test/components_test.dart`:

```dart
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: child,
    );

void main() {
  testWidgets('AppPageScaffold 顯示標題與 body', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppPageScaffold(title: 'T', body: Text('B'))),
    );
    expect(find.text('T'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('AppErrorView 顯示訊息並觸發 onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: AppErrorView(
            message: 'boom',
            onRetry: () => retried = true,
            retryLabel: 'Retry',
          ),
        ),
      ),
    );
    expect(find.text('boom'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('AppErrorView 無 onRetry 時不顯示按鈕', (tester) async {
    await tester.pumpWidget(
      _wrap(const Scaffold(body: AppErrorView(message: 'x'))),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('AppPrimaryButton loading 時停用且顯示 indicator', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: AppPrimaryButton(
            label: 'Go',
            loading: true,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(pressed, isFalse);
  });

  testWidgets('AppEmptyView 與 AppLoadingIndicator 可渲染', (tester) async {
    await tester.pumpWidget(
      _wrap(const Scaffold(body: AppEmptyView(message: 'empty'))),
    );
    expect(find.text('empty'), findsOneWidget);
    await tester.pumpWidget(
      _wrap(const Scaffold(body: AppLoadingIndicator())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: RED**

Run: `cd packages/design_system && fvm flutter test test/components_test.dart` → 編譯失敗。

- [ ] **Step 3: 最小實作**

`packages/design_system/lib/src/components/app_page_scaffold.dart`:

```dart
import 'package:flutter/material.dart';

/// 頁面外框元件:統一 AppBar 與 SafeArea(spec §2.1 design_system)。
class AppPageScaffold extends StatelessWidget {
  /// 建立頁面外框。
  const AppPageScaffold({
    required this.title,
    required this.body,
    this.actions,
    super.key,
  });

  /// AppBar 標題。
  final String title;

  /// 頁面內容。
  final Widget body;

  /// AppBar 右側動作。
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
    );
  }
}
```

`packages/design_system/lib/src/components/app_status_views.dart`:

```dart
import 'package:design_system/src/tokens.dart';
import 'package:flutter/material.dart';

/// 置中的載入指示。
class AppLoadingIndicator extends StatelessWidget {
  /// 建立載入指示。
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// 錯誤畫面:訊息 + 可選重試。文案由呼叫端提供(design_system 不依賴 localization)。
class AppErrorView extends StatelessWidget {
  /// 建立錯誤畫面;[onRetry] 非 null 時必須提供 [retryLabel]。
  const AppErrorView({
    required this.message,
    this.onRetry,
    this.retryLabel,
    super.key,
  }) : assert(
          onRetry == null || retryLabel != null,
          'onRetry 存在時必須提供 retryLabel',
        );

  /// 錯誤訊息。
  final String message;

  /// 重試回呼。
  final VoidCallback? onRetry;

  /// 重試按鈕文字。
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: Text(retryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 空狀態畫面。
class AppEmptyView extends StatelessWidget {
  /// 建立空狀態畫面。
  const AppEmptyView({required this.message, super.key});

  /// 空狀態訊息。
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

`packages/design_system/lib/src/components/app_primary_button.dart`:

```dart
import 'package:flutter/material.dart';

/// 主要動作按鈕;loading 時停用並顯示 indicator。
class AppPrimaryButton extends StatelessWidget {
  /// 建立主要按鈕。
  const AppPrimaryButton({
    required this.label,
    this.onPressed,
    this.loading = false,
    super.key,
  });

  /// 按鈕文字。
  final String label;

  /// 點擊回呼;null 時停用。
  final VoidCallback? onPressed;

  /// 是否處於載入中。
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
```

`design_system.dart` export 追加三個 components 檔(字母排序)。

- [ ] **Step 4: GREEN + analyze + Commit**

Run: `cd packages/design_system && fvm flutter test && cd ../.. && fvm flutter analyze` → 全綠。

```bash
git add -A
git commit -m "feat(design_system): 頁面外框與共用元件"
```

---

### Task 4: localization package(gen-l10n)

**Files:**
- Create: `packages/localization/pubspec.yaml`
- Create: `packages/localization/l10n.yaml`
- Create: `packages/localization/lib/src/arb/app_en.arb`
- Create: `packages/localization/lib/src/arb/app_zh.arb`
- Create: `packages/localization/lib/localization.dart`
- Create(產生): `packages/localization/lib/src/generated/`(gen-l10n 輸出,**進版控**)
- Modify: `pubspec.yaml`(根)、`analysis_options.yaml`(根,排除 generated)
- Test: `packages/localization/test/localization_test.dart`

**Interfaces:**
- Consumes: 無。
- Produces:
  - `AppLocalizations`(gen-l10n 產出):起始 key——`commonRetry`、`commonCancel`、`commonConfirm`、`commonLoading`、`commonErrorGeneric`。feature 文案之後以 feature 前綴命名插入(spec §2.1)。
  - `extension LocalizationContextX on BuildContext { AppLocalizations get l10n; }`
  - app(計畫 4)使用 `AppLocalizations.localizationsDelegates` 與 `AppLocalizations.supportedLocales`。
  - 產生的程式碼**提交進版控**(消費端不需跑 codegen),analyzer 排除 `**/src/generated/**`。

- [ ] **Step 1: 建骨架與設定**

`packages/localization/pubspec.yaml`:

```yaml
name: localization
description: 多語系(官方 gen-l10n + ARB),含各 feature 文案。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any

dev_dependencies:
  flutter_test:
    sdk: flutter
```

(`intl: any`——版本由 flutter_localizations 決定,避免與 SDK 綁定的版本打架。)

`packages/localization/l10n.yaml`:

```yaml
arb-dir: lib/src/arb
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/src/generated
synthetic-package: false
nullable-getter: false
```

(若目前 Flutter 版本警告 `synthetic-package` 已移除,刪除該行即可,行為相同。)

根 `pubspec.yaml` workspace 追加 `- packages/localization`;根 `analysis_options.yaml` 的 `analyzer:` 區塊追加:

```yaml
  exclude:
    - "**/src/generated/**"
```

- [ ] **Step 2: 寫 ARB**

`packages/localization/lib/src/arb/app_en.arb`:

```json
{
  "@@locale": "en",
  "commonRetry": "Retry",
  "commonCancel": "Cancel",
  "commonConfirm": "Confirm",
  "commonLoading": "Loading…",
  "commonErrorGeneric": "Something went wrong. Please try again."
}
```

`packages/localization/lib/src/arb/app_zh.arb`:

```json
{
  "@@locale": "zh",
  "commonRetry": "重試",
  "commonCancel": "取消",
  "commonConfirm": "確認",
  "commonLoading": "載入中…",
  "commonErrorGeneric": "發生錯誤,請再試一次。"
}
```

- [ ] **Step 3: 產生 + barrel + 失敗測試**

Run: `cd packages/localization && fvm flutter gen-l10n`
Expected: `lib/src/generated/` 產出 `app_localizations.dart`、`app_localizations_en.dart`、`app_localizations_zh.dart`。

`packages/localization/lib/localization.dart`:

```dart
/// 多語系入口:AppLocalizations 與 BuildContext 便捷取用。
library;

import 'package:flutter/widgets.dart';
import 'package:localization/src/generated/app_localizations.dart';

export 'src/generated/app_localizations.dart';

/// 讓頁面以 `context.l10n.commonRetry` 取用文案。
extension LocalizationContextX on BuildContext {
  /// 目前 locale 的文案。
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

`packages/localization/test/localization_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localization/localization.dart';

Widget _app(Locale locale, void Function(BuildContext) capture) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          capture(context);
          return const SizedBox.shrink();
        },
      ),
    );

void main() {
  testWidgets('en 與 zh 文案正確', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_app(const Locale('en'), (c) => ctx = c));
    expect(ctx.l10n.commonRetry, 'Retry');

    await tester.pumpWidget(_app(const Locale('zh'), (c) => ctx = c));
    await tester.pumpAndSettle();
    expect(ctx.l10n.commonRetry, '重試');
    expect(ctx.l10n.commonErrorGeneric, '發生錯誤,請再試一次。');
  });

  test('supportedLocales 含 en 與 zh', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      containsAll(['en', 'zh']),
    );
  });
}
```

- [ ] **Step 4: 跑測試(此時應直接 GREEN——實作即產生碼)+ analyze**

Run: `cd packages/localization && fvm flutter test && cd ../.. && fvm flutter analyze && ./tool/check.sh`
Expected: 全綠。若 `check.sh` 的 format 段抱怨 generated 檔案,對 `lib/src/generated` 跑一次 `fvm dart format` 後納入 commit(generated 檔已被 analyzer 排除,format 只需一次性満足)。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(localization): gen-l10n 基礎與共用文案(en/zh)"
```

---

### Task 5: observability — 介面、ConsoleLogger、BufferingCrashReporter

**Files:**
- Create: `packages/observability/pubspec.yaml`
- Create: `packages/observability/lib/observability.dart`
- Create: `packages/observability/lib/src/crash_reporter.dart`
- Create: `packages/observability/lib/src/analytics_tracker.dart`
- Create: `packages/observability/lib/src/console_logger.dart`
- Create: `packages/observability/lib/src/buffering_crash_reporter.dart`
- Create: `packages/observability/lib/src/testing/fakes.dart`
- Create: `packages/observability/lib/testing.dart`
- Modify: `pubspec.yaml`(根)
- Test: `packages/observability/test/console_logger_test.dart`
- Test: `packages/observability/test/buffering_crash_reporter_test.dart`

**Interfaces:**
- Consumes: foundation 的 `AppLogger`/`LogLevel`。
- Produces:
  - `abstract interface class CrashReporter`:`Future<void> recordError(Object error, StackTrace? stackTrace, {bool fatal = false})`、`Future<void> setUserId(String? userId)`、`Future<void> log(String message)`。
  - `abstract interface class AnalyticsTracker`:`Future<void> trackEvent(String name, {Map<String, Object?> parameters = const {}})`、`Future<void> trackScreen(String screenName)`。
  - `class ConsoleLogger implements AppLogger`:`ConsoleLogger({LogLevel minLevel = LogLevel.debug, void Function(String) output = print})`;低於 minLevel 不輸出;格式 `[LEVEL] message`(error 附 error/stackTrace 行)。
  - `class BufferingCrashReporter implements CrashReporter`(spec §10 第 3 條解法):`attach(CrashReporter delegate)` 前把呼叫緩衝(上限 100 筆,超出丟最舊);attach 時依序 flush 給 delegate,之後直通。
  - testing.dart:`FakeCrashReporter`(記錄 `recordedErrors`、`userIds`、`logs`)、`FakeAnalyticsTracker`(記錄 `events`、`screens`)。

- [ ] **Step 1: 建骨架**

`packages/observability/pubspec.yaml`:

```yaml
name: observability
description: log 輸出端、crash 上報、事件埋點(介面 + Firebase 實作)。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  firebase_analytics: ^11.4.0
  firebase_crashlytics: ^4.3.0
  flutter:
    sdk: flutter
  foundation: any

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

根 workspace 追加 `- packages/observability`。Run: `fvm flutter pub get`。

- [ ] **Step 2: 寫失敗測試**

`packages/observability/test/console_logger_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:observability/observability.dart';

void main() {
  test('依 minLevel 過濾並格式化輸出', () {
    final lines = <String>[];
    final logger = ConsoleLogger(minLevel: LogLevel.info, output: lines.add);
    logger.debug('skip me');
    logger.info('hello');
    logger.error('boom', error: 'cause');
    expect(lines, hasLength(3));
    expect(lines[0], '[INFO] hello');
    expect(lines[1], '[ERROR] boom');
    expect(lines[2], contains('cause'));
  });

  test('可當 AppLogger 注入', () {
    expect(ConsoleLogger(), isA<AppLogger>());
  });
}
```

`packages/observability/test/buffering_crash_reporter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:observability/observability.dart';
import 'package:observability/testing.dart';

void main() {
  test('attach 前緩衝,attach 時依序 flush,之後直通', () async {
    final buffering = BufferingCrashReporter();
    await buffering.recordError('e1', StackTrace.empty);
    await buffering.log('m1');
    await buffering.setUserId('u1');

    final delegate = FakeCrashReporter();
    buffering.attach(delegate);
    expect(delegate.recordedErrors, hasLength(1));
    expect(delegate.logs, ['m1']);
    expect(delegate.userIds, ['u1']);

    await buffering.recordError('e2', null);
    expect(delegate.recordedErrors, hasLength(2));
  });

  test('緩衝上限 100 筆,超出丟最舊', () async {
    final buffering = BufferingCrashReporter();
    for (var i = 0; i < 105; i++) {
      await buffering.log('m$i');
    }
    final delegate = FakeCrashReporter();
    buffering.attach(delegate);
    expect(delegate.logs, hasLength(100));
    expect(delegate.logs.first, 'm5');
  });
}
```

- [ ] **Step 3: RED**

Run: `cd packages/observability && fvm flutter test` → 編譯失敗。

- [ ] **Step 4: 最小實作**

`packages/observability/lib/src/crash_reporter.dart`:

```dart
/// crash 上報契約;Firebase 實作見 CrashlyticsCrashReporter。
abstract interface class CrashReporter {
  /// 上報錯誤;[fatal] 標記是否為致命錯誤。
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  });

  /// 設定(或以 null 清除)使用者識別。
  Future<void> setUserId(String? userId);

  /// 附掛除錯訊息到下一次 crash 報告。
  Future<void> log(String message);
}
```

`packages/observability/lib/src/analytics_tracker.dart`:

```dart
/// 事件埋點契約;Firebase 實作見 FirebaseAnalyticsTracker。
abstract interface class AnalyticsTracker {
  /// 上報事件。
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  });

  /// 上報畫面瀏覽。
  Future<void> trackScreen(String screenName);
}
```

`packages/observability/lib/src/console_logger.dart`:

```dart
import 'package:foundation/foundation.dart';

/// [AppLogger] 的 console 實作(開發期預設)。
class ConsoleLogger implements AppLogger {
  /// 建立 console logger;低於 [minLevel] 的訊息不輸出。
  ConsoleLogger({this.minLevel = LogLevel.debug, this.output = print});

  /// 最低輸出層級。
  final LogLevel minLevel;

  /// 輸出函式(測試可注入)。
  final void Function(String line) output;

  @override
  void debug(String message) => _write(LogLevel.debug, message);

  @override
  void info(String message) => _write(LogLevel.info, message);

  @override
  void warning(String message) => _write(LogLevel.warning, message);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _write(LogLevel.error, message);
    if (error != null) {
      _write(LogLevel.error, '  cause: $error');
    }
    if (stackTrace != null) {
      _write(LogLevel.error, '  stack: $stackTrace');
    }
  }

  void _write(LogLevel level, String message) {
    if (level.index < minLevel.index) {
      return;
    }
    output('[${level.name.toUpperCase()}] $message');
  }
}
```

(注意:`error()` 的 cause/stack 行不受 minLevel 過濾影響——它們與主行同層級。上面測試預期 3 行:INFO、ERROR 主行、cause 行。)

`packages/observability/lib/src/buffering_crash_reporter.dart`:

```dart
import 'package:observability/src/crash_reporter.dart';

/// 啟動期緩衝的 crash reporter(spec §10 第 3 條)。
///
/// bootstrap 在第 3 步就掛錯誤捕捉,但 Firebase 要到第 4 步才 init;
/// 期間的錯誤先緩衝,attach 真正的 reporter 後依序補送。
class BufferingCrashReporter implements CrashReporter {
  static const _capacity = 100;

  final List<Future<void> Function(CrashReporter r)> _buffer = [];
  CrashReporter? _delegate;

  /// 掛上真正的 reporter 並 flush 緩衝(依原順序)。
  void attach(CrashReporter delegate) {
    _delegate = delegate;
    for (final replay in _buffer) {
      // 依序補送;不 await,避免 attach 被上報 IO 卡住。
      // ignore: discarded_futures -- 補送為 fire-and-forget,失敗不影響啟動
      replay(delegate);
    }
    _buffer.clear();
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.recordError(error, stackTrace, fatal: fatal);
    }
    _push((r) => r.recordError(error, stackTrace, fatal: fatal));
  }

  @override
  Future<void> setUserId(String? userId) async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.setUserId(userId);
    }
    _push((r) => r.setUserId(userId));
  }

  @override
  Future<void> log(String message) async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.log(message);
    }
    _push((r) => r.log(message));
  }

  void _push(Future<void> Function(CrashReporter r) replay) {
    if (_buffer.length >= _capacity) {
      _buffer.removeAt(0);
    }
    _buffer.add(replay);
  }
}
```

`packages/observability/lib/src/testing/fakes.dart`:

```dart
import 'package:observability/src/analytics_tracker.dart';
import 'package:observability/src/crash_reporter.dart';

/// 一筆被記錄的錯誤。
class RecordedError {
  /// 建立紀錄。
  const RecordedError(this.error, this.stackTrace, {required this.fatal});

  /// 錯誤本體。
  final Object error;

  /// 堆疊。
  final StackTrace? stackTrace;

  /// 是否致命。
  final bool fatal;
}

/// [CrashReporter] 的官方 fake。
class FakeCrashReporter implements CrashReporter {
  /// 記錄的錯誤。
  final List<RecordedError> recordedErrors = [];

  /// 記錄的 userId 設定(含 null)。
  final List<String?> userIds = [];

  /// 記錄的 log 訊息。
  final List<String> logs = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async =>
      recordedErrors.add(RecordedError(error, stackTrace, fatal: fatal));

  @override
  Future<void> setUserId(String? userId) async => userIds.add(userId);

  @override
  Future<void> log(String message) async => logs.add(message);
}

/// 一筆被記錄的事件。
class TrackedEvent {
  /// 建立紀錄。
  const TrackedEvent(this.name, this.parameters);

  /// 事件名。
  final String name;

  /// 參數。
  final Map<String, Object?> parameters;
}

/// [AnalyticsTracker] 的官方 fake。
class FakeAnalyticsTracker implements AnalyticsTracker {
  /// 記錄的事件。
  final List<TrackedEvent> events = [];

  /// 記錄的畫面。
  final List<String> screens = [];

  @override
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async =>
      events.add(TrackedEvent(name, parameters));

  @override
  Future<void> trackScreen(String screenName) async =>
      screens.add(screenName);
}
```

`packages/observability/lib/observability.dart`:

```dart
/// log 輸出端、crash 上報、事件埋點。
library;

export 'src/analytics_tracker.dart';
export 'src/buffering_crash_reporter.dart';
export 'src/console_logger.dart';
export 'src/crash_reporter.dart';
```

`packages/observability/lib/testing.dart`:

```dart
/// 測試專用入口:官方 fake 一律由此匯出(spec §3 規則 1)。
library;

export 'src/testing/fakes.dart';
```

- [ ] **Step 5: GREEN + analyze + Commit**

Run: `cd packages/observability && fvm flutter test && cd ../.. && fvm flutter analyze` → 全綠。

```bash
git add -A
git commit -m "feat(observability): 介面、ConsoleLogger 與啟動期緩衝 reporter"
```

---

### Task 6: observability — Firebase 實作

**Files:**
- Create: `packages/observability/lib/src/crashlytics_crash_reporter.dart`
- Create: `packages/observability/lib/src/firebase_analytics_tracker.dart`
- Modify: `packages/observability/lib/observability.dart`
- Test: `packages/observability/test/firebase_impls_test.dart`

**Interfaces:**
- Consumes: Task 5 介面;plugin 實例由建構子注入(app 於計畫 4 建構,本 package 不 init Firebase)。
- Produces:
  - `class CrashlyticsCrashReporter implements CrashReporter`:`CrashlyticsCrashReporter(FirebaseCrashlytics crashlytics)`;recordError → `crashlytics.recordError(error, stackTrace, fatal: fatal)`;setUserId → `setUserIdentifier(userId ?? '')`;log → `crashlytics.log(message)`。
  - `class FirebaseAnalyticsTracker implements AnalyticsTracker`:`FirebaseAnalyticsTracker(FirebaseAnalytics analytics)`;trackEvent → `analytics.logEvent(name:, parameters:)`(參數需過濾為 `Map<String, Object>`,丟棄 null 值);trackScreen → `analytics.logScreenView(screenName:)`。

- [ ] **Step 1: 寫失敗測試**

`packages/observability/test/firebase_impls_test.dart`:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:observability/observability.dart';

class _MockCrashlytics extends Mock implements FirebaseCrashlytics {}

class _MockAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  group('CrashlyticsCrashReporter', () {
    late _MockCrashlytics inner;
    late CrashlyticsCrashReporter reporter;

    setUp(() {
      inner = _MockCrashlytics();
      reporter = CrashlyticsCrashReporter(inner);
      when(
        () => inner.recordError(
          any<Object>(),
          any(),
          fatal: any(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});
      when(() => inner.setUserIdentifier(any())).thenAnswer((_) async {});
      when(() => inner.log(any())).thenAnswer((_) async {});
    });

    test('轉呼叫底層', () async {
      await reporter.recordError('e', StackTrace.empty, fatal: true);
      await reporter.setUserId('u1');
      await reporter.setUserId(null);
      await reporter.log('m');
      verify(
        () => inner.recordError('e', StackTrace.empty, fatal: true),
      ).called(1);
      verify(() => inner.setUserIdentifier('u1')).called(1);
      verify(() => inner.setUserIdentifier('')).called(1);
      verify(() => inner.log('m')).called(1);
    });
  });

  group('FirebaseAnalyticsTracker', () {
    late _MockAnalytics inner;
    late FirebaseAnalyticsTracker tracker;

    setUp(() {
      inner = _MockAnalytics();
      tracker = FirebaseAnalyticsTracker(inner);
      when(
        () => inner.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => inner.logScreenView(screenName: any(named: 'screenName')),
      ).thenAnswer((_) async {});
    });

    test('trackEvent 過濾 null 參數', () async {
      await tracker.trackEvent('tap', parameters: {'a': 1, 'b': null});
      verify(
        () => inner.logEvent(name: 'tap', parameters: {'a': 1}),
      ).called(1);
    });

    test('trackScreen 轉呼叫 logScreenView', () async {
      await tracker.trackScreen('Home');
      verify(() => inner.logScreenView(screenName: 'Home')).called(1);
    });
  });
}
```

- [ ] **Step 2: RED**

Run: `cd packages/observability && fvm flutter test test/firebase_impls_test.dart` → 編譯失敗。

- [ ] **Step 3: 最小實作**

`packages/observability/lib/src/crashlytics_crash_reporter.dart`:

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:observability/src/crash_reporter.dart';

/// [CrashReporter] 的 Crashlytics 實作;實例由 app 組裝層注入。
class CrashlyticsCrashReporter implements CrashReporter {
  /// 以既有的 [FirebaseCrashlytics] 建立。
  CrashlyticsCrashReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) =>
      _crashlytics.recordError(error, stackTrace, fatal: fatal);

  @override
  Future<void> setUserId(String? userId) =>
      _crashlytics.setUserIdentifier(userId ?? '');

  @override
  Future<void> log(String message) => _crashlytics.log(message);
}
```

`packages/observability/lib/src/firebase_analytics_tracker.dart`:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:observability/src/analytics_tracker.dart';

/// [AnalyticsTracker] 的 Firebase Analytics 實作;實例由 app 組裝層注入。
class FirebaseAnalyticsTracker implements AnalyticsTracker {
  /// 以既有的 [FirebaseAnalytics] 建立。
  FirebaseAnalyticsTracker(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) {
    final filtered = <String, Object>{
      for (final entry in parameters.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    return _analytics.logEvent(name: name, parameters: filtered);
  }

  @override
  Future<void> trackScreen(String screenName) =>
      _analytics.logScreenView(screenName: screenName);
}
```

`observability.dart` export 追加兩檔(字母排序)。

- [ ] **Step 4: GREEN + analyze + Commit**

Run: `cd packages/observability && fvm flutter test && cd ../.. && fvm flutter analyze` → 全綠。

```bash
git add -A
git commit -m "feat(observability): Crashlytics 與 Firebase Analytics 實作"
```

---

### Task 7: push_notifications package

**Files:**
- Create: `packages/push_notifications/pubspec.yaml`
- Create: `packages/push_notifications/lib/push_notifications.dart`
- Create: `packages/push_notifications/lib/src/push_notifications.dart`
- Create: `packages/push_notifications/lib/src/fcm_push_notifications.dart`
- Create: `packages/push_notifications/lib/src/testing/fake_push_notifications.dart`
- Create: `packages/push_notifications/lib/testing.dart`
- Modify: `pubspec.yaml`(根)
- Test: `packages/push_notifications/test/fcm_push_notifications_test.dart`

**Interfaces:**
- Consumes: 無(firebase_messaging 由建構子注入)。
- Produces:
  - `class PushTapEvent { const PushTapEvent({this.routePath, this.data = const {}}); final String? routePath; final Map<String, dynamic> data; }`——`routePath` 取自 FCM data payload 的 `route` key(**與後端的契約**,寫進 doc);app(計畫 4)訂閱後轉 `router.go(routePath)`。
  - `abstract interface class PushNotifications`:`Future<bool> requestPermission()`、`Future<String?> currentToken()`、`Stream<String> get tokenRefreshes`、`Stream<PushTapEvent> get taps`。
  - `class FcmPushNotifications implements PushNotifications`:`FcmPushNotifications({required FirebaseMessaging messaging, required Stream<RemoteMessage> openedMessages, Stream<String>? tokenRefreshes})`——`openedMessages` 由 app 傳入 `FirebaseMessaging.onMessageOpenedApp`(static stream 無法 mock,故注入);requestPermission 對 `authorized`/`provisional` 回 true。
  - testing.dart:`FakePushNotifications`,可設定 `permissionResult`/`token`,並提供 `emitTap(PushTapEvent)`、`emitTokenRefresh(String)` 供測試驅動。

- [ ] **Step 1: 建骨架**

`packages/push_notifications/pubspec.yaml`:

```yaml
name: push_notifications
description: 推播抽象介面 + FCM 實作、token 生命週期、點擊轉路由事件。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  firebase_messaging: ^15.2.0
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

根 workspace 追加 `- packages/push_notifications`。Run: `fvm flutter pub get`。

- [ ] **Step 2: 寫失敗測試**

`packages/push_notifications/test/fcm_push_notifications_test.dart`:

```dart
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_notifications/push_notifications.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockSettings extends Mock implements NotificationSettings {}

void main() {
  late _MockMessaging messaging;
  late StreamController<RemoteMessage> opened;

  FcmPushNotifications build() => FcmPushNotifications(
        messaging: messaging,
        openedMessages: opened.stream,
      );

  setUp(() {
    messaging = _MockMessaging();
    opened = StreamController<RemoteMessage>();
  });

  tearDown(() async {
    await opened.close();
  });

  NotificationSettings _settings(AuthorizationStatus status) {
    final s = _MockSettings();
    when(() => s.authorizationStatus).thenReturn(status);
    return s;
  }

  test('requestPermission:authorized/provisional 為 true,denied 為 false',
      () async {
    final push = build();
    when(messaging.requestPermission).thenAnswer(
      (_) async => _settings(AuthorizationStatus.authorized),
    );
    expect(await push.requestPermission(), isTrue);

    when(messaging.requestPermission).thenAnswer(
      (_) async => _settings(AuthorizationStatus.provisional),
    );
    expect(await push.requestPermission(), isTrue);

    when(messaging.requestPermission).thenAnswer(
      (_) async => _settings(AuthorizationStatus.denied),
    );
    expect(await push.requestPermission(), isFalse);
  });

  test('currentToken 轉呼叫 getToken', () async {
    when(messaging.getToken).thenAnswer((_) async => 'tok');
    expect(await build().currentToken(), 'tok');
  });

  test('taps 把 RemoteMessage 映射為 PushTapEvent(route key)', () async {
    final push = build();
    final events = <PushTapEvent>[];
    final sub = push.taps.listen(events.add);

    opened
      ..add(const RemoteMessage(data: {'route': '/home', 'x': '1'}))
      ..add(const RemoteMessage(data: {'x': '2'}));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, hasLength(2));
    expect(events[0].routePath, '/home');
    expect(events[0].data['x'], '1');
    expect(events[1].routePath, isNull);
  });
}
```

- [ ] **Step 3: RED**

Run: `cd packages/push_notifications && fvm flutter test` → 編譯失敗。

- [ ] **Step 4: 最小實作**

`packages/push_notifications/lib/src/push_notifications.dart`:

```dart
/// 使用者點擊推播的事件。
class PushTapEvent {
  /// 建立事件。
  const PushTapEvent({this.routePath, this.data = const {}});

  /// 目標路由(取自 FCM data payload 的 `route` key——與後端的契約);
  /// 無此 key 時為 null,由 app 決定預設行為。
  final String? routePath;

  /// 完整 data payload。
  final Map<String, dynamic> data;
}

/// 推播能力契約;FCM 實作見 FcmPushNotifications。
abstract interface class PushNotifications {
  /// 要求推播權限;授權(含 provisional)回 true。
  Future<bool> requestPermission();

  /// 目前裝置 token;不可用時為 null。
  Future<String?> currentToken();

  /// token 更新事件(app 應上報後端)。
  Stream<String> get tokenRefreshes;

  /// 使用者點擊推播的事件(app 訂閱後轉路由)。
  Stream<PushTapEvent> get taps;
}
```

`packages/push_notifications/lib/src/fcm_push_notifications.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:push_notifications/src/push_notifications.dart';

/// [PushNotifications] 的 FCM 實作。
///
/// [openedMessages] 由 app 傳入 `FirebaseMessaging.onMessageOpenedApp`
/// (static stream 無法注入替身,故由組裝層提供)。
class FcmPushNotifications implements PushNotifications {
  /// 以注入的 messaging 實例與事件來源建立。
  FcmPushNotifications({
    required FirebaseMessaging messaging,
    required Stream<RemoteMessage> openedMessages,
    Stream<String>? tokenRefreshes,
  })  : _messaging = messaging,
        _openedMessages = openedMessages,
        _tokenRefreshes = tokenRefreshes;

  final FirebaseMessaging _messaging;
  final Stream<RemoteMessage> _openedMessages;
  final Stream<String>? _tokenRefreshes;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> currentToken() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes =>
      _tokenRefreshes ?? _messaging.onTokenRefresh;

  @override
  Stream<PushTapEvent> get taps => _openedMessages.map(
        (message) => PushTapEvent(
          routePath: message.data['route'] as String?,
          data: message.data,
        ),
      );
}
```

`packages/push_notifications/lib/src/testing/fake_push_notifications.dart`:

```dart
import 'dart:async';

import 'package:push_notifications/src/push_notifications.dart';

/// [PushNotifications] 的官方 fake。
class FakePushNotifications implements PushNotifications {
  /// 建立 fake。
  FakePushNotifications({this.permissionResult = true, this.token = 'fake'});

  /// requestPermission 的固定回傳。
  final bool permissionResult;

  /// currentToken 的固定回傳。
  final String? token;

  final _tokenController = StreamController<String>.broadcast();
  final _tapController = StreamController<PushTapEvent>.broadcast();

  /// 模擬 token 更新。
  void emitTokenRefresh(String token) => _tokenController.add(token);

  /// 模擬使用者點擊推播。
  void emitTap(PushTapEvent event) => _tapController.add(event);

  @override
  Future<bool> requestPermission() async => permissionResult;

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get tokenRefreshes => _tokenController.stream;

  @override
  Stream<PushTapEvent> get taps => _tapController.stream;
}
```

`packages/push_notifications/lib/push_notifications.dart`:

```dart
/// 推播抽象介面 + FCM 實作、token 生命週期、點擊轉路由事件。
library;

export 'src/fcm_push_notifications.dart';
export 'src/push_notifications.dart';
```

`packages/push_notifications/lib/testing.dart`:

```dart
/// 測試專用入口:官方 fake 一律由此匯出(spec §3 規則 1)。
library;

export 'src/testing/fake_push_notifications.dart';
```

- [ ] **Step 5: GREEN + analyze + Commit**

Run: `cd packages/push_notifications && fvm flutter test && cd ../.. && fvm flutter analyze` → 全綠。

```bash
git add -A
git commit -m "feat(push_notifications): 推播抽象與 FCM 實作"
```

---

### Task 8: 全 workspace 收尾與 CI

**Files:** 無新檔;驗證與推送。

- [ ] **Step 1:** `./tool/check.sh` → 九個 package 全綠(foundation/networking/persistence/session/navigation/design_system/localization/observability/push_notifications),`✓ all checks passed`。format 殘餘納入收尾 commit。
- [ ] **Step 2:** 依賴白名單抽查:`grep -A8 "^dependencies:" packages/{navigation,design_system,localization,observability,push_notifications}/pubspec.yaml`,與 Global Constraints 比對。
- [ ] **Step 3:** `git add -A && git diff --cached --quiet || git commit -m "chore: Plan 3 收尾"`,`git push origin main`。
- [ ] **Step 4:** `gh run list --repo hey-jason404/flutter-app-template --limit 1 --json status,conclusion,databaseId` → `success`。失敗只修 script/workflow/環境,package 邏輯問題回報。

---

## 完成定義(本計畫)

- [ ] 九個 package check.sh 全綠;CI 綠。
- [ ] 五個新 package 依賴白名單無違規;fake 僅由 testing.dart 匯出。
- [ ] localization 產生碼進版控且 analyzer 排除;`context.l10n` 可用。
- [ ] `BufferingCrashReporter` 解決 spec §10 第 3 條(有測試)。
- [ ] Firebase 全部隔在介面後,無任何 Firebase 初始化碼進入本計畫。

## 後續計畫

4. app 組裝層(config/bootstrap/DI/router/shell + di_smoke_test;吸收 spec §10 第 11 條 createDio 擴充)
5. 示範 features(auth、home)+ 假後端 + integration test
6. tool 產生器 + CLAUDE.md + docs + ADR(spec §10 第 13、14 條)
