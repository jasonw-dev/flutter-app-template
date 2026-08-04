# 上手指南

**目標:一小時內能獨立加一個 feature。** 三段:跑起來(15 分)、讀懂一條請求
(30 分)、加你的第一個 feature(30 分)。

規則要查的時候去 [`conventions.md`](conventions.md)(怎麼寫)與
[`architecture.md`](architecture.md)(東西放哪);想知道某個設計為什麼這樣定
再去看 [`adr/`](adr/)。**這份文件不解釋為什麼,只讓你動起來。**

## 從單一 package 專案過來,先知道三件事

1. **import 一個新東西之前,要先去那個 package 的 `pubspec.yaml` 加依賴。**
   沒加的話 `flutter analyze` 會紅字 `depend_on_referenced_packages`。這不是
   麻煩——**這就是「A 功能永遠 import 不到 B 功能」的實作方式**,是這個模板
   唯一無可取代的東西。
2. **`fvm flutter pub get` 在根目錄跑一次就好。** pub workspace 一次解析全部
   package,不用每個目錄各跑一次。
3. **push 前先跑 `bash tool/check.sh`。** 它跟 CI 同構,本機過了 CI 就會過。
   改過 ARB 或 pubspec 依賴的話先跑 `bash tool/regen.sh`。

## 第 1 段(15 分):跑起來

```bash
fvm use && fvm flutter pub get
fvm flutter run -t app/lib/main_dev.dart
```

內建假後端([`demo_backend_adapter.dart`](../app/lib/src/demo/demo_backend_adapter.dart))
接手所有 API,不需真後端。跑這三件事:

| 操作 | 應該看到 |
|---|---|
| 任意 email + 任意密碼登入 | 進首頁,5 筆 `Demo item N` |
| 密碼輸入 `wrong` | SnackBar 錯誤訊息,停在登入頁 |
| 點任一項目 | 進詳情頁 |

## 第 2 段(30 分):讀懂一條登入請求

按順序開這八個檔案,跟一次「按下登入按鈕 → 跳轉首頁」。每個檔只看一件事。

| # | 檔案 | 看這一件事 |
|---|---|---|
| 1 | [`login_page.dart`](../features/auth/lib/src/presentation/pages/login_page.dart) | cubit 從 `context.read<GetIt>()<LoginCubit>()` 取,**不是** `GetIt.instance`;文案一律 `context.l10n.<key>` |
| 2 | [`login_cubit.dart`](../features/auth/lib/src/presentation/blocs/login/login_cubit.dart) | 只 import bloc 與 domain,**零 Flutter import**;用 `result.fold` 消費,不 try/catch |
| 3 | [`auth_repository.dart`](../features/auth/lib/src/domain/repositories/auth_repository.dart) | domain 只有介面,回傳 `Result<T>` |
| 4 | [`auth_repository_impl.dart`](../features/auth/lib/src/data/repositories/auth_repository_impl.dart) | data 層做 DTO ↔ entity 轉換,presentation 看不到 DTO |
| 5 | [`api_client.dart`](../packages/core/lib/src/networking/api_client.dart) | **全庫例外收攏的唯一處**,所有失敗在這裡變成 `AppException` |
| 6 | [`session_manager.dart`](../packages/core/lib/src/session/session_manager.dart) | 登入狀態的單一真相;訂閱前先讀 `state` getter 拿現值 |
| 7 | [`session_refresh_listenable.dart`](../app/lib/src/router/session_refresh_listenable.dart) | 把 session 事件轉成 go_router 的重新評估訊號 |
| 8 | [`app_router.dart`](../app/lib/src/router/app_router.dart) | `redirect` 是**登入守衛的唯一處**,別在頁面裡各自判斷 |

看完這條線,整個模板的形狀就懂了——其他 feature 都長一樣。

想看清單頁的三態渲染(loading / error / empty / loaded 的 exhaustive
`switch`),多開一個
[`item_list_bloc.dart`](../features/home/lib/src/presentation/blocs/item_list/item_list_bloc.dart)
與 [`home_page.dart`](../features/home/lib/src/presentation/pages/home_page.dart)。

## 第 3 段(30 分):加你的第一個 feature

```bash
git checkout -b feature/practice
fvm dart run tool/new_feature.dart practice
fvm flutter pub get
```

產生器會產出骨架,並自動接好根 pubspec、`app` 的 DI、路由表、`di_smoke_test`
與 `core` 的路徑常數——**你不用手動接線**。接下來:

1. 依 [`add-an-api.md`](how-to/add-an-api.md) 加一支 API(可以在
   `DemoBackendAdapter` 上新增一個端點)。
2. 文案加進 `packages/localization/lib/src/arb/app_*.arb`,跑 `bash tool/regen.sh`。
3. 補測試:bloc 的事件→狀態轉換、repository 的錯誤映射、page 的三態渲染。
   產生器已經給了 `bloc_test` 骨架,改斷言即可。
4. `bash tool/check.sh` 修到全綠,開 PR 到 `develop`。

**做完就丟掉**(注意:這會一併丟掉你自己還沒 commit 的其他改動):

```bash
git checkout -- . && rm -rf features/practice && fvm flutter pub get
```

## 護欄速查:做錯什麼會被誰擋

全部由 `bash tool/check.sh` 執行,CI 跑同一支腳本。

| 你做了什麼 | 誰擋 |
|---|---|
| feature A 的 pubspec 依賴 feature B | pubspec 依賴稽核 |
| bloc / cubit / state 檔 import Flutter | bloc 純度稽核 |
| presentation 層 import data 層 | 分層方向稽核 |
| 頁面裡寫 `GetIt.instance` | `GetIt.instance` 稽核 |
| `// ignore:` 沒附 ` -- 原因` | ignore 稽核 |
| 改了 ARB 沒 regen | l10n 漂移檢查 |
| 加了 package 依賴沒 regen 架構文件 | 架構文件漂移檢查 |
| `app` 或 `core` 直接 import `firebase_*` | Firebase 隔離稽核 |
| 改壞畫面 | golden test(**只在 CI 比對**,本機顯示 skipped) |
| 文件裡的相對連結指向不存在的檔案 | markdown 連結檢查 |
| 開 `features/shared` / `common` / `utils` | `tool/guard.sh` |

錯誤訊息都會寫「缺什麼 + 去哪補」。**照著訊息做就好,不用回來查文件。**

## 想更深入

| 想知道 | 去哪 |
|---|---|
| 某條規則怎麼寫 | [`conventions.md`](conventions.md) |
| 東西該放哪個 package | [`architecture.md`](architecture.md) |
| 怎麼做某件具體的事 | [`how-to/`](how-to/) |
| 為什麼是 Bloc 不是 Riverpod、為什麼多 package | [`adr/`](adr/) |
| AI agent 要讀什麼 | [`CLAUDE.md`](../CLAUDE.md) |

## 檢核點

不看本文件,獨立完成:產生一個 feature → 接一支 API → 補三種測試 →
`check.sh` 全綠 → 開 PR 且 CI 全過。

做到就可以接手正式的 feature 任務了。
