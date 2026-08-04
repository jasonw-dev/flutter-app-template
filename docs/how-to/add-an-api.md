# How-to:新增一支 API(以 `features/home` 的 `fetchItems` 為例)

本文件完整走查在既有 feature 內新增一支 API 呼叫的五層:DTO → repository
介面 → repository 實作 → bloc → page 三態,並含每層的測試。範例全部取自
[`features/home`](../../features/home) 現存檔案。背景規則見
[`../conventions.md`](../conventions.md)、[`../architecture.md`](../architecture.md)。

若是全新 feature,先跑 [`add-a-feature.md`](add-a-feature.md) 的產生器,再
依本文件把產生器留下的暫用 API 換成真實走法。

## 步驟 0:確認層內依賴方向

`presentation → domain ← data`(見 [`conventions.md` §1](../conventions.md))。
presentation 不碰 DTO 與 data source;新增 API 時由外而內填:先定 domain
契約,再補 data 實作,presentation 只認 domain 型別。

## 步驟 1:DTO(`data/dtos/`)

檔案:[`features/home/lib/src/data/dtos/item_dto.dart`](../../features/home/lib/src/data/dtos/item_dto.dart)。

手寫判準(見 [`conventions.md` §7](../conventions.md)):欄位
少、不值得引入 `json_serializable` codegen 時手寫 `fromJson`;缺欄位時 cast
失敗直接向外拋出,由 `ApiClient._send()` 收攏為 `ParsingException`(不在
DTO 內 try/catch)。

```dart
class ItemDto {
  const ItemDto({required this.id, required this.title, required this.description});

  factory ItemDto.fromJson(Map<String, dynamic> json) => ItemDto(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
  );

  final String id;
  final String title;
  final String description;

  Item toEntity() => Item(id: id, title: title, description: description);
}
```

對應 entity [`features/home/lib/src/domain/entities/item.dart`](../../features/home/lib/src/domain/entities/item.dart)
同樣手寫、不用 freezed(entity 預設手寫,欄位多且需要 `copyWith` 才用
freezed)。`toEntity()` 是 DTO→entity 轉換函式,DTO 只在 data 層可見。

## 步驟 2:repository 介面(`domain/repositories/`)

檔案:[`features/home/lib/src/domain/repositories/item_repository.dart`](../../features/home/lib/src/domain/repositories/item_repository.dart)。

```dart
abstract interface class ItemRepository {
  Future<Result<List<Item>>> fetchItems();
  Future<Result<Item>> fetchItem(String id);
}
```

回傳型別一律 `Result<T>`(單一型別參數,failure 側固定為 `AppException`),不允許
拋出 raw exception。介面只認 entity,不認 DTO。

## 步驟 3:repository 實作(`data/repositories/`)

檔案:[`features/home/lib/src/data/repositories/item_repository_impl.dart`](../../features/home/lib/src/data/repositories/item_repository_impl.dart)。

`sources/` 層省略判準(見 [`conventions.md` §6](../conventions.md)):
單一 remote 來源且無本地快取時,repository 可直接持有 `ApiClient`;出現第二
來源才抽 `sources/`。`fetchItems` 完整實作:

```dart
class ItemRepositoryImpl implements ItemRepository {
  ItemRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Item>>> fetchItems() => _client.get<List<Item>>(
    '/items',
    parse: (data) {
      final items = (data as Map<String, dynamic>)['items'] as List<dynamic>;
      return items
          .map((e) => ItemDto.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();
    },
  );

  @override
  Future<Result<Item>> fetchItem(String id) => _client.get<Item>(
    '/items/$id',
    parse: (data) => ItemDto.fromJson(data as Map<String, dynamic>).toEntity(),
  );
}
```

`ApiClient.get()`(見
[`packages/core/lib/src/networking/api_client.dart`](../../packages/core/lib/src/networking/api_client.dart))
負責把 `DioException` 收攏為 `AppException` 子類、把 `parse()` 拋出的任何
`Object` 收攏為 `ParsingException`,repository 因此不需要自己 try/catch。

## 步驟 4:bloc(`presentation/blocs/`)

檔案:[`features/home/lib/src/presentation/blocs/item_list/`](../../features/home/lib/src/presentation/blocs/item_list/)
(`item_list_bloc.dart`、`item_list_event.dart`、`item_list_state.dart` 三檔)。

Bloc 六鐵律見 [`conventions.md` §2](../conventions.md)。事件:

```dart
sealed class ItemListEvent { const ItemListEvent(); }
final class ItemListRequested extends ItemListEvent { const ItemListRequested(); }
```

狀態(sealed,UI exhaustive switch):

```dart
sealed class ItemListState { const ItemListState(); }
final class ItemListLoading extends ItemListState { const ItemListLoading(); }
final class ItemListLoaded extends ItemListState {
  const ItemListLoaded(this.items);
  final List<Item> items;
}
final class ItemListError extends ItemListState {
  const ItemListError(this.exception);
  final AppException exception;
}
```

Bloc(不 import Flutter,鐵律 6):

```dart
class ItemListBloc extends Bloc<ItemListEvent, ItemListState> {
  ItemListBloc({required ItemRepository repository})
    : _repository = repository,
      super(const ItemListLoading()) {
    on<ItemListRequested>(_onItemListRequested);
  }

  final ItemRepository _repository;

  Future<void> _onItemListRequested(
    ItemListRequested event,
    Emitter<ItemListState> emit,
  ) async {
    emit(const ItemListLoading());
    final result = await _repository.fetchItems();
    result.fold(
      onSuccess: (items) => emit(ItemListLoaded(items)),
      onFailure: (exception) => emit(ItemListError(exception)),
    );
  }
}
```

`usecase` 不需要:預設 bloc 直接呼叫 repository,只有協調兩個以上 repository
或業務規則被兩個以上 bloc 共用時才抽 usecase(見 [`conventions.md` §4](../conventions.md))。

DI 註冊(`lib/src/di.dart`,見
[`features/home/lib/src/di.dart`](../../features/home/lib/src/di.dart)):
repository 用 `registerLazySingleton`,bloc 用 `registerFactory`:

```dart
void registerHomeFeature(GetIt gi) {
  gi
    ..registerLazySingleton<ItemRepository>(() => ItemRepositoryImpl(gi<ApiClient>()))
    ..registerFactory<ItemListBloc>(() => ItemListBloc(repository: gi<ItemRepository>()));
}
```

## 步驟 5:page 三態

檔案:[`features/home/lib/src/presentation/pages/home_page.dart`](../../features/home/lib/src/presentation/pages/home_page.dart)。

整頁三態(loading/success/error)用 exhaustive `switch`(
LoginPage vs HomePage 判準見 [`conventions.md` §2.1](../conventions.md)):

```dart
return switch (state) {
  ItemListLoading() => const AppLoadingIndicator(),
  ItemListError() => AppErrorView(
    message: context.l10n.commonErrorGeneric,
    onRetry: () => context.read<ItemListBloc>().add(const ItemListRequested()),
    retryLabel: context.l10n.commonRetry,
  ),
  ItemListLoaded(:final items) when items.isEmpty =>
    AppEmptyView(message: context.l10n.homeEmpty),
  ItemListLoaded(:final items) => ListView.builder(...),
};
```

`AppLoadingIndicator`、`AppErrorView`、`AppEmptyView` 為 `design_system` 匯出
的公開元件(見
[`packages/ui/lib/design_system.dart`](../../packages/ui/lib/ui.dart));
文案一律走 `context.l10n.<key>`,不硬編字串。

## 步驟 6:測試(三層各一)

### 6.1 repository:`ScriptedAdapter` 三案例

檔案:[`features/home/test/data/item_repository_impl_test.dart`](../../features/home/test/data/item_repository_impl_test.dart)。

用 `package:networking/testing.dart` 匯出的官方 fake `ScriptedAdapter` +
`jsonResponse()`(見
[`packages/core/lib/src/networking/testing/scripted_adapter.dart`](../../packages/core/lib/src/testing/scripted_adapter.dart)),
搭配 `createPlainDio` 組出 `ApiClient`,驗證三種情況:

1. **成功**:`ScriptedAdapter([(_) => jsonResponse(200, '...')])`,斷言
   `Result` 為 `Success<List<Item>>` 且欄位解析正確。
2. **業務錯誤(4xx)**:`jsonResponse(404, '{}')`,斷言為
   `Failure<List<Item>>` 且 `exception` 為 `isA<ApiException>()`(例外斷言
   一律用 `isA<...>()` matcher,`AppException` 不實作 `==`,見
   [`conventions.md` §10](../conventions.md))。
3. **DTO 轉換失敗**:回傳缺欄位 JSON,斷言 `exception` 為
   `isA<ParsingException>()`。

`fetchItem` 另有一則驗證 `adapter.seen.single.path` 打對路徑
(`/items/1`)的測試,示範用 `ScriptedAdapter.seen` 斷言實際送出的請求。

### 6.2 bloc:`bloc_test`

檔案:[`features/home/test/presentation/item_list_bloc_test.dart`](../../features/home/test/presentation/item_list_bloc_test.dart)。

用 `mocktail` mock `ItemRepository`(`class _MockItemRepository extends Mock
implements ItemRepository {}`),`blocTest` 驗證三段事件→狀態序列:初始狀態、
成功序列 `[Loading, Loaded]`、失敗序列 `[Loading, Error]`(`exception` 用
`isA<ApiException>()` matcher)。

### 6.3 page:三態渲染測試

檔案:[`features/home/test/presentation/home_pages_test.dart`](../../features/home/test/presentation/home_pages_test.dart)。

以 `GetIt.instance` 註冊 mock repository 建出的 bloc,`pumpWidget` 含
`AppLocalizations.localizationsDelegates` 的 `MaterialApp`,分別驗證
loading(`CircularProgressIndicator`)、error(重試按鈕點擊後
`verify(...).called(2)`)、loaded(項目數與內容)、loaded 空清單(空狀態文案)
四種渲染,滿足「至少 loading/success/error 三態」的完成度定義(見
[`conventions.md` §8.1](../conventions.md))。文案斷言走
`AppLocalizationsEn()` 取值,不硬編字串(見 [`conventions.md` §8.2`](../conventions.md))。

## 後端有統一回應信封時

模板的示範後端(`DemoBackendAdapter`)回傳的是裸資料,無 `{ code, data,
message }` 之類的統一信封,故不內建信封解析層。若專案後端有信封,兩種接法
擇一:

1. **per-call parse helper**:在 repository 或 DTO 層加一個小 helper,收到
   response body 後先解信封(取出 `data` 欄位)再丟給既有 `fromJson`,失敗
   (信封層 code 非成功)時映射為對應 `AppException` 子類。改動侷限在單一
   API 呼叫路徑,適合信封欄位或錯誤碼含語意需要逐支處理的情況。
2. **`networking` 的 `extraInterceptors` 掛信封拆解 interceptor**:
   `createDio` 提供 `extraInterceptors` 參數(掛在 `AuthInterceptor` 之後,
   見 [`packages/core/lib/src/networking/create_dio.dart`](../../packages/core/lib/src/networking/create_dio.dart)),
   可寫一個 `Interceptor` 在 `onResponse` 統一拆信封、把信封層錯誤碼轉為
   `DioException` 交給既有 `error_mapper.dart` 處理,一次性套用到所有走
   `createDio` 建出的 client。適合信封格式全域一致、無例外的情況;注意
   retryClient 不掛 `extraInterceptors`(見同檔 doc),重試請求不會經過信封
   拆解。

兩者可並存:全域一致的部分走 interceptor,個別 API 的特殊欄位再用
per-call helper 補。

## 收尾

新增/調整 API 後執行:

```
./tool/check.sh
```
