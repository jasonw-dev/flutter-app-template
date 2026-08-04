# How-to:新增一支 API

以 [`features/home`](../../features/home) 的項目清單為範例走一遍。**所有程式碼
直接看範例檔,本文只講決策點與順序**——貼在文件裡的程式碼會漂,而
`features/home` 一定是對的(它有測試釘住)。

若是全新 feature,先跑 [`add-a-feature.md`](add-a-feature.md) 的產生器,再依
本文把產生器留下的暫用 API 換成真實走法。

## 順序

`presentation → domain ← data`。從 domain 開始往兩邊長,不要從 page 開始寫。

| # | 檔案位置 | 範例 |
|---|---|---|
| 1 | `domain/entities/` | [`item.dart`](../../features/home/lib/src/domain/entities/item.dart) |
| 2 | `domain/repositories/`(介面) | [`item_repository.dart`](../../features/home/lib/src/domain/repositories/item_repository.dart) |
| 3 | `data/dtos/` | [`item_dto.dart`](../../features/home/lib/src/data/dtos/item_dto.dart) |
| 4 | `data/repositories/`(實作) | [`item_repository_impl.dart`](../../features/home/lib/src/data/repositories/item_repository_impl.dart) |
| 5 | `presentation/blocs/` | [`item_list/`](../../features/home/lib/src/presentation/blocs/item_list/) |
| 6 | `presentation/pages/` | [`home_page.dart`](../../features/home/lib/src/presentation/pages/home_page.dart) |
| 7 | `src/di.dart` | [`di.dart`](../../features/home/lib/src/di.dart) |
| 8 | `test/` | [`item_repository_impl_test.dart`](../../features/home/test/data/item_repository_impl_test.dart) |

## 每步的決策點

**1. entity** —— 預設手寫,欄位多且需要 `copyWith` 才用 freezed
([`conventions.md` §7](../conventions.md))。

**2. repository 介面** —— 回傳型別查
[`conventions.md` §3.2 的矩陣](../conventions.md)。常見兩種形狀:

- **單純讀取**:`Future<Result<T>>`。
- **帶快取的清單**:`Stream<List<T>> watchItems()` 讀 + `Future<Result<void>>
  refreshItems()` / `loadMore()` 寫。四條語意定死在
  [`conventions.md` §6.1](../conventions.md),照抄別自己發明。

**3. DTO** —— 欄位少就手寫 `fromJson`,不值得引入 `json_serializable`
([`conventions.md` §7](../conventions.md))。**cast 失敗直接往外拋**,
`ApiClient._send` 會收攏成 `ParsingException`,不要自己 try/catch。

**4. repository 實作** —— 直接持有 `ApiClient`。**只有出現第二個資料來源**
(本地快取、第二個 remote 端點)才抽 `data/sources/`
([`conventions.md` §6](../conventions.md))。

**5. bloc 還是 cubit** —— 依觸發來源數量,不憑感覺
([`conventions.md` §2](../conventions.md)):

- 只有使用者在這頁的操作 → **Cubit**。範例
  [`ItemDetailCubit`](../../features/home/lib/src/presentation/blocs/item_detail/item_detail_cubit.dart)。
- 兩個以上觸發來源(例如同時被下拉刷新與 repository stream 推送驅動)→
  **Bloc**。範例
  [`ItemListBloc`](../../features/home/lib/src/presentation/blocs/item_list/item_list_bloc.dart)
  ——它的檔頭註解寫明了為什麼是 Bloc。

state 用 `sealed class`,**檔案不 import Flutter**(`check.sh` 會擋)。

`usecase` 預設不要:只有協調兩個以上 repository、或業務規則被兩個以上 bloc
共用時才抽([`conventions.md` §4](../conventions.md))。

**6. page** —— 整頁三態用 exhaustive `switch`,單一旗標或副作用用 `is`
([`conventions.md` §2.1](../conventions.md))。文案一律 `context.l10n.<key>`。

**7. DI** —— repository `registerLazySingleton`(多頁共用同一份快取),bloc
`registerFactory`(跟隨頁面生命週期)。**帶 stream 的 repository 註冊時要給
`dispose:`**,由容器負責關閉——bloc 生命週期比 repository 短,讓 bloc 去 close
會讓下一個頁面拿到已關閉的 stream。

**8. 測試** —— 三層各一([`conventions.md` §8.1](../conventions.md)):

- **repository**:用
  [`ScriptedAdapter`](../../packages/core/lib/src/testing/scripted_adapter.dart)
  餵假回應,至少涵蓋成功、後端錯誤碼、解析失敗三種。
- **bloc**:`blocTest`,涵蓋初始、成功、失敗的狀態序列。
- **page**:三態渲染,選取器用 `find.byType(<公開元件型別>)`。

## 假後端要同步

`AppConfig.useFakeBackend` 出廠是 `true`,所有請求會被
[`DemoBackendAdapter`](../../app/lib/src/demo/demo_backend_adapter.dart) 接走。
**新端點要在那裡加一個分支**,否則會拿到 404。

它對 `options.uri.path` 做**精確字串比對**——若 `AppConfig.apiBaseUrl` 帶路徑
片段(如 `/v1`),所有請求都會落到未知路徑而回 404,且沒有任何提示。接真後端前
先確認這件事。

## 後端有統一回應信封時

若後端回的是 `{"code": 0, "data": {...}, "message": "ok"}` 這種信封,**在
`parse` 裡剝掉,不要改 `ApiClient`**:

```dart
parse: (data) {
  final envelope = data as Map<String, dynamic>;
  return ItemDto.fromJson(envelope['data'] as Map<String, dynamic>).toItem();
}
```

`ApiClient` 刻意不內建信封層——不同專案的信封長得不一樣,而 `parse` 這個擴充點
已經夠用。業務錯誤碼的處理見 [`conventions.md` §3.3](../conventions.md):在
repository 翻譯成 feature 自己的 outcome,不要讓 bloc switch 字串。

## 收尾

1. 文案加進 `packages/localization/lib/src/arb/app_*.arb`,key 以 feature 名為
   前綴,跑 `bash tool/regen.sh`。
2. `bash tool/check.sh` 全綠。
