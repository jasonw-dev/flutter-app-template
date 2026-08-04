# How-to:新增一個 feature

本文件示範用產生器建立一個全新 feature 的完整流程。權威來源與背景見
[`docs/archive/specs/2026-07-11-flutter-app-template-design.md`](../archive/specs/2026-07-11-flutter-app-template-design.md)
§6.3;feature 內部形狀與 Bloc 規範見 [`../conventions.md`](../conventions.md)
§1-2;workspace 拓撲與依賴規則見 [`../architecture.md`](../architecture.md)。

## 1. 執行產生器

```
fvm dart run tool/new_feature.dart <snake_case_name>
```

名稱規則(見 [`tool/new_feature.dart`](../../tool/new_feature.dart) 的
`_validateName`):

- 須符合 `^[a-z][a-z0-9_]*$`(小寫字母開頭,僅含小寫字母、數字、底線)。
- `features/<name>` 不可已存在。
- 不可為保留名:`app`、`dart`、`flutter`、`integration_test`、`test`,或任何
  現有 `packages/*` 名稱。

參數錯誤或格式不符時,產生器會印出用法並以非 0 結束,不會動任何檔案。

## 2. 產生器做了什麼

以 [`features/home`](../../features/home) 為藍本產出最小「清單」骨架,並自動
接好五處線。**你不用手動接線**——漏接的那幾處正是新人最容易卡住的地方。

| 動到什麼 | 內容 |
|---|---|
| `features/<name>/` | pubspec、barrel、`di.dart`、`routes.dart`、三層目錄、一組會動的範例(entity、DTO、repository 介面/實作、list bloc、頁面)與測試骨架 |
| 根 [`pubspec.yaml`](../../pubspec.yaml) | `workspace:` 清單加入 `features/<name>` |
| [`route_paths.dart`](../../packages/core/lib/src/navigation/route_paths.dart) | `// {{route-paths}}` 標記前插入 `RoutePaths.<name>` |
| [`app/pubspec.yaml`](../../app/pubspec.yaml) | 加入 `<name>: any` |
| [`compose_dependencies.dart`](../../app/lib/src/di/compose_dependencies.dart) | `// {{feature-registry}}` 標記前插入 `register<Pascal>Feature(gi);` |
| [`app_router.dart`](../../app/lib/src/router/app_router.dart) | 同標記前插入 `...<camel>Routes(),` |
| [`di_smoke_test.dart`](../../app/test/di_smoke_test.dart) | 同標記前插入解析斷言——**忘記註冊會在 CI 失敗,不會等到執行期閃退** |

最後對所有觸及的檔案跑一次 `dart format`。任何一步失敗會印出中斷訊息與復原
指令(見 §3.5)。

## 3. 產生器印出的後續步驟

執行成功後,產生器印出 `_printNextSteps`(見
[`tool/new_feature.dart`](../../tool/new_feature.dart))的固定訊息,原文如下
(以 `order` 為例):

```
✓ features/order 已建立並完成接線。後續步驟:
  1. l10n:於 packages/localization 的 ARB 加入 order 前綴
     的 key(如 orderTitle、orderEmpty),取代 OrderPage 內的
     暫用字串與 // TODO(l10n) 註解,並 gen-l10n 重新產生。
  2. API:將 OrderRepositoryImpl 的 GET /order/entries 換成真實
     後端路徑與欄位(視需要調整 OrderEntryDto)。
  3. 若清單項目需要導向詳情頁,於 navigation package 補上型別化
     route 類別(如 OrderDetailRoute),並在 routes.dart 加入巢狀
     GoRoute(參考 features/home 的 items/:id)。
  4. 若此 feature 需在底部導覽列顯示,於 app 的 shell(AppShell)加入
     分頁項目並導向 RoutePaths.order。
  5. 執行 ./tool/check.sh 確認全綠。
```

以下逐項展開實際操作。

### 3.1 l10n:加入文案 key 並 regen

1. 在 [`packages/localization/lib/src/arb/app_en.arb`](../../packages/localization/lib/src/arb/app_en.arb)
   加入以 feature 前綴命名的 key,比照現有 `home*`(`homeTitle`、
   `homeEmpty`、`homeDetailTitle`,見該檔)與 `auth*` 的命名方式。
2. 執行:

   ```
   cd packages/localization && fvm flutter gen-l10n
   ```

   這會重新產生 `lib/src/generated/`(`AppLocalizations`、
   `AppLocalizationsEn` 等)。`tool/check.sh` 第 5 步會做「l10n 漂移檢查」
   (ARB 改了卻忘記 regen 即 CI 失敗),見
   [`tool/check.sh`](../../tool/check.sh)。
3. 頁面內 `context.l10n.<key>` 取用(擴充方法定義於
   [`packages/localization/lib/localization.dart`](../../packages/localization/lib/localization.dart)
   的 `LocalizationContextX`),取代產生器留下的暫用字串。

### 3.2 對接真 API

產生器留下的是打 `GET /<name>/entries` 的暫用實作。換成真實 API 的完整走查見
[`add-an-api.md`](add-an-api.md)——那份講決策點(回傳型別怎麼選、bloc 還是
cubit、什麼時候才抽 `sources/`),照著走即可。

### 3.3 typed route 帶參數(仿 `ItemDetailRoute`)

若清單項目要導向詳情頁,在
[`packages/core/lib/src/navigation/route_paths.dart`](../../packages/core/lib/src/navigation/route_paths.dart)
新增巢狀路徑常數(如 `orderItemDetail = '/order/items/:id'`),並仿
[`features/home/lib/src/routes.dart`](../../features/home/lib/src/routes.dart)
的 `ItemDetailRoute`:

```dart
class OrderDetailRoute {
  const OrderDetailRoute(this.id);
  final String id;

  @override
  String get location => RoutePaths.orderItemDetail.replaceFirst(':id', id);
}
```

在 feature 的 `routes.dart` 加入巢狀 `GoRoute`,參考
[`features/home/lib/src/routes.dart`](../../features/home/lib/src/routes.dart):

```dart
GoRoute(
  path: RoutePaths.order,
  builder: (_, __) => const OrderPage(),
  routes: [
    GoRoute(
      path: 'items/:id',
      builder: (_, state) => OrderDetailPage(id: state.pathParameters['id']!),
    ),
  ],
),
```

頁面內導航一律 `context.go(OrderDetailRoute(id).location)`,不手寫路徑字串
(見 [`conventions.md` §1](../conventions.md))。

### 3.4 shell tab 擴充

若此 feature 要出現在底部導覽列,修改
[`app/lib/src/shell/app_shell.dart`](../../app/lib/src/shell/app_shell.dart)
的 `AppShell`:把現有佔位 `NavigationDestination`(`SizedBox.shrink()` +
`enabled: false`,留給下一個 feature 用)換成真正的分頁項目,並在點擊時
`context.go(RoutePaths.order)`。若 tab 數超過 2 個,依 `NavigationBar` 慣例
擴充。

### 3.5 失敗復原

若產生器中途失敗(如格式化失敗、標記找不到),它會印出:

```
✗ 產生中斷:<原因>
請執行:git checkout -- . && rm -rf features/<name>
然後 fvm flutter pub get 還原 workspace
```

依指示還原後可重新執行產生器。產生器本身不做部分回滾,所以「先還原、再重
跑」是唯一支援的復原路徑。

## 4. 收尾

依 [`conventions.md` §11](../conventions.md) 的產生器工作流總結,完成上述
人工步驟後執行:

```
./tool/check.sh
```

確認全綠(format、ignore 稽核、依賴稽核、l10n 漂移檢查、analyze、逐 package
測試)。

## 要加表單頁？

產生器產出的是列表頁。表單頁照
[`features/auth/lib/src/presentation/pages/login_page.dart`](../../features/auth/lib/src/presentation/pages/login_page.dart)
抄:`Form` + `TextFormField` + `Validators` + `localizeValidationError()`,
規則見 [`docs/conventions.md`](../conventions.md) 的「表單樣板」一節。
