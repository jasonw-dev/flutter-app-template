# 開發慣例

**本文件是「怎麼寫」這類規則的權威來源。** 涵蓋命名與檔案位置、
Bloc / Cubit 六鐵律、錯誤模型、usecase 準則、DI 規範、測試規範,以及各項
判準的理由。

所有程式碼片段皆節錄自現存檔案並標註路徑;架構層級的規則(東西放哪、
怎麼連)見 [`architecture.md`](architecture.md)。

## 1. Feature 三層形狀

所有 feature 形狀一致。以 [`features/home`](../features/home) 為導覽範例,實際檔案樹:

```
features/home/
├── pubspec.yaml
├── lib/
│ ├── home.dart # barrel
│ └── src/
│ ├── di.dart # registerHomeFeature(GetIt gi)
│ ├── routes.dart # homeRoutes
│ ├── data/
│ │ ├── dtos/
│ │ │ └── item_dto.dart
│ │ └── repositories/
│ │ └── item_repository_impl.dart
│ ├── domain/
│ │ ├── entities/
│ │ │ └── item.dart
│ │ └── repositories/
│ │ └── item_repository.dart
│ └── presentation/
│ ├── blocs/
│ │ ├── item_detail/
│ │ │ ├── item_detail_bloc.dart
│ │ │ ├── item_detail_event.dart
│ │ │ └── item_detail_state.dart
│ │ └── item_list/
│ │ ├── item_list_bloc.dart
│ │ ├── item_list_event.dart
│ │ └── item_list_state.dart
│ └── pages/
│ ├── home_page.dart
│ └── item_detail_page.dart
└── test/
 ├── data/item_repository_impl_test.dart
 └── presentation/
 ├── home_pages_test.dart
 ├── item_detail_bloc_test.dart
 └── item_list_bloc_test.dart
```

注意 `features/home` 沒有 `data/sources/` 目錄——判準見 §6。`presentation/widgets/`(feature 私有元件)在此範例未用到,但本文件保留該位置。

層內依賴方向:`presentation → domain ← data`。presentation 不碰 DTO 與 data source;DTO 欄位變動的爆炸範圍止於 data 層。此條由 [`tool/check.sh`](../tool/check.sh) 的「分層方向稽核」機器強制(grep `features/*/lib/src/presentation` 底下對 `package:*/src/data/` 的 import),違反會讓 CI 紅燈。

feature 對外只透過 barrel file(`lib/<name>.dart`)輸出;`lib/src/` 內一切私有(Dart 語言級保護)。例:[`features/home/lib/home.dart`](../features/home/lib/home.dart) 匯出 DI 註冊函式、路由建構函式與 presentation 型別供 `app` 的 DI/路由/`di_smoke_test` 取用,barrel 內註明「features 之間仍禁止互相依賴(pubspec 白名單擋住)」。

**同 feature 內導航**用型別化 route 類別,類別跟該 feature 的 `GoRoute` 清單同住 `lib/src/routes.dart`;**跨 feature 導航**用 `core` 的路徑常數(`RoutePaths.xxx`),帶參數時自己 `buildLocation(RoutePaths.xxx, query: {...})`。route 類別一律手寫 `location`(不採 `go_router_builder`)。

型別安全在跨 feature 時降級成字串常數,這是刻意的取捨:route 類別若集中在共用處,該處就會累積每一個 feature 的知識,兩個人平行開兩個功能必然改到同一個檔——那是模板裡少數幾個必然的 merge conflict 熱點(ADR-0006)。跨 feature 導航本來就少,而路徑常數仍是單一真相,改路徑仍然只要改一處。

例:[`packages/core/lib/src/navigation/route_paths.dart`](../packages/core/lib/src/navigation/route_paths.dart) 定義 `RoutePaths.homeItemDetail`,[`features/home/lib/src/routes.dart`](../features/home/lib/src/routes.dart) 的 `ItemDetailRoute` 組合出 `location`;`app` 的 `GoRoute(path:)` 與 feature 內的 `context.go(ItemDetailRoute(id).location)` 取用同一份路徑常數。

## 2. Bloc / Cubit 六鐵律

1. **Cubit 或 Bloc 依觸發來源數量決定,不憑感覺**:
 - **用 Cubit**:狀態只有**單一觸發來源**(使用者在這個頁面上的操作),且不需要事件的併發控制。絕大多數表單頁、設定頁屬於此類。
 - **用 Bloc**:有**兩個以上觸發來源**(例如同時被使用者操作與 repository 的 stream 推送驅動),或需要 `transformer` 做 debounce / droppable / 序列化。

 判準之外的選擇,code review 退回。改寫時機:一個 Cubit 開始需要處理第二個觸發來源,就升級為 Bloc——這是預期中的演進,不是設計失誤。

 活範例:[`LoginCubit`](../features/auth/lib/src/presentation/blocs/login/login_cubit.dart) 與 [`ItemDetailCubit`](../features/home/lib/src/presentation/blocs/item_detail/item_detail_cubit.dart) 是單一觸發來源;[`ItemListBloc`](../features/home/lib/src/presentation/blocs/item_list/item_list_bloc.dart) 同時被下拉刷新與 repository stream 驅動,是兩個觸發來源。

 其餘五條對 Cubit **一體適用**。目錄名維持 `blocs/`,同時容納 bloc 與 cubit。
2. State 用 Dart 3 `sealed class` 表達互斥狀態;UI 用 exhaustive `switch` 渲染——漏處理狀態是編譯錯誤。
3. 命名:事件用「主詞+過去式動詞」(`LoginSubmitted`),不用命令式;狀態類別 `<情境><階段>`。
4. Bloc 之間禁止互相引用;**feature 內**共享狀態下沉到 domain(repository 暴露 stream),各自訂閱——這與 §2.3 的「**跨 feature** 契約下沉到 `packages/`」是兩個不同 scope 的規則,不可混為一談。
5. 錯誤處理單一路徑:repository 一律回傳 `Result<T>`(`core` 的 `src/foundation` 定義;**單一型別參數**,failure 側固定為 `AppException`);禁止 bloc/UI 以 `try/catch` 接 raw exception。
6. Bloc 檔案不 import Flutter,保持純 Dart。此條由 [`tool/check.sh`](../tool/check.sh) 的「bloc 純度稽核」機器強制(檢查 `*_bloc.dart`、`*_cubit.dart`、`*_event.dart`、`*_state.dart` 是否 import `package:flutter/` 或 `package:flutter_bloc/`),違反會讓 CI 紅燈。

範例:[`features/home/lib/src/presentation/blocs/item_list/item_list_bloc.dart`](../features/home/lib/src/presentation/blocs/item_list/item_list_bloc.dart)——只 import `package:bloc/bloc.dart` 與 domain 型別,不 import Flutter:

```dart
class ItemListBloc extends Bloc<ItemListEvent, ItemListState> {
 ItemListBloc({required ItemRepository repository})
 : _repository = repository,
 super(const ItemListLoading) {
 on<ItemListRequested>(_onItemListRequested);
 }
 ...
 result.fold(
 onSuccess: (items) => emit(ItemListLoaded(items)),
 onFailure: (exception) => emit(ItemListError(exception)),
 );
}
```

### 2.1 switch/is 判準:LoginPage vs HomePage 對照

整頁三態(loading/success/error)渲染一律用 exhaustive `switch`;單一旗標或副作用(如 loading 中禁用按鈕、失敗時彈 SnackBar)允許用 `is` 檢查。

- **HomePage(整頁三態 → exhaustive switch)**:[`features/home/lib/src/presentation/pages/home_page.dart`](../features/home/lib/src/presentation/pages/home_page.dart)

 ```dart
 return switch (state) {
 ItemListLoading => const AppLoadingIndicator,
 ItemListError => AppErrorView(...),
 ItemListLoaded(:final items) when items.isEmpty => AppEmptyView(...),
 ItemListLoaded(:final items) => ListView.builder(...),
 };
 ```

- **LoginPage(表單頁,狀態只影響單一旗標/副作用 → `is`)**:[`features/auth/lib/src/presentation/pages/login_page.dart`](../features/auth/lib/src/presentation/pages/login_page.dart)——頁面主體(表單)不隨狀態切換,只有按鈕 `loading` 旗標與失敗 SnackBar 是狀態驅動的局部效果:

 ```dart
 BlocListener<LoginBloc, LoginState>(
 listener: (context, state) {
 if (state is LoginFailure) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(context.l10n.authLoginFailed)),
 );
 }
 },
 ...
 )
 // 按鈕:
 AppPrimaryButton(loading: state is LoginSubmitting, ...)
 ```

## 3. 錯誤模型與轉換責任

`AppException` 為 `foundation` 定義的 `sealed class`([`packages/core/lib/src/foundation/exceptions.dart`](../packages/core/lib/src/foundation/exceptions.dart)),子類清單定死,不允許各 feature 自創例外型別:

| 子類 | 語意 | 主要來源 |
|---|---|---|
| `ConnectivityException` | 無網路、DNS 失敗、連線逾時 | networking |
| `ServerException(statusCode)` | 5xx | networking |
| `UnauthorizedException` | 401 / token 失效且 refresh 失敗 | networking(觸發 session 過期) |
| `ApiException(code, message)` | 4xx 業務錯誤(後端錯誤碼) | networking |
| `ParsingException` | JSON 解析 / DTO 轉換失敗 | data 層 |
| `StorageException` | 本地儲存讀寫失敗 | persistence |
| `NativeException(code)` | 原生能力呼叫失敗 | packages/native/* |
| `CancelledException` | 請求被主動取消(`CancelToken`) | networking |
| `UnknownException(cause)` | 以上皆非的兜底 | 各處 |

轉換責任落在 [`packages/core/lib/src/networking/error_mapper.dart`](../packages/core/lib/src/networking/error_mapper.dart) 的 `mapDioException`——把 `DioException` 依 `type` 與狀態碼收攏為上表對應子類:

```dart
switch (exception.type) {
 case DioExceptionType.connectionTimeout:
 case DioExceptionType.sendTimeout:
 case DioExceptionType.receiveTimeout:
 case DioExceptionType.connectionError:
 case DioExceptionType.badCertificate:
 case DioExceptionType.transformTimeout:
 return ConnectivityException(cause: exception, stackTrace: stackTrace);
 case DioExceptionType.badResponse:
 return _mapBadResponse(exception, stackTrace);
 case DioExceptionType.cancel:
 return CancelledException(cause: exception, stackTrace: stackTrace);
 case DioExceptionType.unknown:
 return UnknownException(cause: exception, stackTrace: stackTrace);
}
```

`_mapBadResponse` 內:401 → `UnauthorizedException`;5xx → `ServerException`;其餘依後端 envelope 的 `code`/`message` → `ApiException`(`statusCode` 缺失時 `code` 退回 `'$statusCode'`,即已知邊角)。`networking` 的攔截器負責產生前四類;data 層(DTO `fromJson`/轉換函式)只在轉換失敗時產生 `ParsingException`,見 [`packages/core/lib/src/networking/api_client.dart`](../packages/core/lib/src/networking/api_client.dart) 的 `_send`——`parse` 拋出的任何 `Object` 皆收攏為 `ParsingException`;`persistence` 產生 `StorageException`;`packages/native/*` 產生 `NativeException`。`data` 層之上(repository、bloc)只會看到 `AppException`,repository 一律回傳 `Result<T>`。

刻意不提供 `Result.guard`——`ApiClient` 已在 `_send` 集中收攏例外為 `AppException`,repository 因此不需要、也不應該再寫 `try/catch` 樣板去手動包裝。

### 3.1 重試策略

`createDio` 掛的 [`RetryInterceptor`](../packages/core/lib/src/networking/retry_interceptor.dart)
對可恢復的失敗做指數退避重試。四條規則,每一條都對應一種真實事故:

1. **只重試冪等方法**(`GET`/`HEAD`/`OPTIONS`)。`POST`/`PUT`/`PATCH`/`DELETE` 一律不重試——「送出訂單逾時後重試」等於重複下單。某支 POST 若確定冪等(後端有 idempotency key),呼叫端用 `options.extra[RetryInterceptor.idempotentKey] = true` **明確 opt-in**,預設不重試。
2. **只重試可能會好的錯誤**:連線失敗/逾時與 5xx。**4xx 一律不重試**,它不會自己變好。
3. **429 用 `Retry-After`**:伺服器明講了要等多久就等多久,不用自己算的退避。
4. **cancel 不重試**,包含退避等待期間才被取消的情況。

退避加 **jitter**(`delay * (0.5 + random * 0.5)`),避免所有客戶端同時重試把剛恢復的後端再打掛。

**呼叫端需要知道「哪些請求不會被重試」**:寫 POST 的人要自己處理逾時後的不確定性——請求可能已經成功但回應沒回來,正確做法是查詢一次確認,而不是重送。

掛載順序 **`AuthInterceptor` 在前、`RetryInterceptor` 在後**(401 由 auth 處理,retry 不碰 4xx)。`createPlainDio`(token refresh 專用)**一律不重試**:refresh 失敗要立刻讓使用者知道,不該悄悄重試三次讓登出延遲好幾秒。

### 3.2 回傳型別矩陣

「什麼時候該包 `Result`」如果沒有寫死的判準,結果一定是:純函式被過度包成
`Result`、例外從 data 層漏到 bloc、用 `null` 表達真正的失敗。以下是每一層的
預設回傳型別,**照著查就好,不要憑感覺**。

| 情境 | 預設回傳 | 規則 |
|---|---|---|
| 純運算、entity 上的計算 | `T` | 沒有「可恢復的執行期失敗」就不要包 `Result`。 |
| 正常的「查無此物」 | `T?` | 只在**缺席是唯一的另一種結果**、且呼叫端不需要知道原因時使用。需要原因就用 `Result`。 |
| 網路 / 原生 / 儲存的邊界 | `Future<Result<T>>` | 在這裡把外部例外收攏成 `AppException`,**再往上就不該看到原始例外**。 |
| repository 的讀取與命令 | `Future<Result<T>>` | 失敗必須出現在簽章上。成功無回傳值時用 `Result<void>`。 |
| repository 的快取觀察 | `Stream<T>` | stream 代表「值隨時間變化」,不代表操作結果。重抓/載入這類命令另外用 `Future<Result<void>>` 回報失敗。 |
| usecase | 沿用 / 組合 `Result<T>` | 不要拆開再重拋。只有在 usecase 自己擁有該政策時才做轉換。 |
| bloc / cubit | state 轉換 | 消費 `Result` 後 emit 窮盡的 sealed state。**不得把 `Result` 當成 widget 的 state**,也不得 `try/catch`。 |
| 內部的 best-effort 操作 | `T` / `Future<T>` | 僅限於「函式自己擁有並記載了確定的降級行為」,例如快取損壞就當空快取。 |
| 多結果的業務流程 | `Result<某某 Outcome>` | 傳輸/基礎設施失敗留在 `Result` 的 failure 側;**業務上預期的分支**(需要 OTP、被拒絕、已核准)用 feature 自己的 sealed 型別,見 §3.3。 |
| 程式錯誤、違反不變式 | `throw` `Error` 子類 | 不要轉成 `AppException`,也不要當成可恢復的 UI 錯誤顯示。那是 bug,要炸出來。 |

`Result<T>` **只有一個型別參數**,failure 側固定為 `AppException`。不引入
`Either<L, R>`,也不改成 `Result<T, E>`——那是改動全 App 的錯誤模型,需要一份
新的 ADR,不是某個 feature 順手決定的事。

DTO → entity 的轉換函式回傳 `T`(直接回值),轉換失敗屬於**解析邊界**的責任:
`ApiClient._send` 會把 `parse` 拋出的任何 `Object` 收攏為 `ParsingException`
(見 §3)。所以轉換函式本身不必也不應該包 `Result`。

### 3.3 技術失敗 vs feature 業務結果

`AppException` 是**封閉的**,而且只裝「跨 feature 都有意義的技術失敗」。
feature 自己預期中的業務結果**不繼承 `AppException`**,用 feature 擁有的
sealed 型別表達。

```text
跨 feature 的技術失敗   → Result<T>.failure(AppException)
feature 預期中的業務結果 → Result<FeatureOutcome>.success(outcome)
程式錯誤 / 違反不變式    → throw Error(不轉成 AppException)
```

**新增 `AppException` 子類的准入規則**——兩者滿足其一才可以加:

> 1. 有**多個** feature 需要同一種技術分類,或
> 2. App 對它有**全域**的處理政策(例如 `UnauthorizedException` 觸發登出)。

**只因為某個 feature 想要一個有名字的業務拒絕,不構成理由。** 那種東西放在
feature 自己的 sealed outcome 裡:

```dart
// features/payment 內部,不進 core
sealed class PaymentOutcome {}

final class PaymentApproved extends PaymentOutcome {
  const PaymentApproved(this.receiptId);
  final String receiptId;
}

final class PaymentRequiresOtp extends PaymentOutcome {
  const PaymentRequiresOtp(this.challengeId);
  final String challengeId;
}

final class PaymentRejected extends PaymentOutcome {
  const PaymentRejected(this.reasonCode);
  final String reasonCode;
}
```

repository 的簽章因此是 `Future<Result<PaymentOutcome>>`:**連不上後端**是
`Result.failure(ConnectivityException(...))`,**後端說要 OTP** 是
`Result.success(PaymentRequiresOtp(...))`。兩者的差別不是風格問題——前者該重試
或提示網路,後者該導去輸入驗證碼,混在一起 bloc 就分不出來。

後端業務錯誤碼(`ApiException(code, message)`)**在 feature 的 repository 裡
翻譯成 outcome**,不要讓 bloc 或 UI 去 switch 字串錯誤碼。認得的碼轉成對應的
outcome,認不得的碼原樣留在 `Result.failure(ApiException(...))` 走通用錯誤路徑
——這樣後端新增錯誤碼時 App 不會當掉,只是顯示通用訊息。

為什麼不走另外兩種極端:

- **全部塞進 `AppException`**:`core` 會長出 `InsufficientBalanceException`、`CouponExpiredException`、`SeatAlreadyTakenException`。即使 import 方向還是合法的,`core` 在概念上已經依賴每一個 feature 的業務詞彙。
- **每個 feature 自建完整錯誤體系**:`PaymentNetworkFailure`、`MemberNetworkFailure`、`OrderNetworkFailure` 各一份,session 過期與錯誤上報的全域行為會變得不一致。

## 4. usecase 選配準則

預設 bloc/cubit 直接呼叫 repository(見 `ItemListBloc`、`LoginCubit` 範例,皆未經 usecase)。僅兩種情況抽 usecase:

- (a) 一個動作協調兩個以上 repository;
- (b) 同一段業務規則被兩個以上 bloc 使用。

準則外新增 usecase,code review 退回。本模板兩個示範 feature(`auth`、`home`)皆未觸發這兩個條件,因此 `domain/usecases/` 目錄未建立。

## 5. DI 規範

- repository、data source 註冊 `lazySingleton`;bloc 一律 `factory`,跟隨頁面生命週期,不做全域 bloc。全域狀態(如 session 監聽)不住在 feature。
- feature 的 `di.dart` 是唯一註冊點;`app` 只呼叫一行註冊函式;`di_smoke_test` 驗證全部可解析。
- **page 取用 bloc 一律 `context.read<GetIt><XxxBloc>`,禁止在 `lib/` 內出現 `GetIt.instance`。** 唯一例外是 [`app/lib/src/bootstrap.dart`](../app/lib/src/bootstrap.dart),那是容器的建立處。容器由 [`app/lib/src/app.dart`](../app/lib/src/app.dart) 以 `RepositoryProvider<GetIt>.value` 往下傳(包在 `MaterialApp.router` **外層**,go_router 建出的頁面才讀得到)。此條由 [`tool/check.sh`](../tool/check.sh) 的「`GetIt.instance` 稽核」機器強制。
- 好處是 page 測試不必配置全域單例:用 `GetIt.asNewInstance` 建獨立容器,外層包 `RepositoryProvider<GetIt>.value` 即可,測試之間不會互相污染。

範例:[`features/home/lib/src/di.dart`](../features/home/lib/src/di.dart)

```dart
void registerHomeFeature(GetIt gi) {
 gi
 ..registerLazySingleton<ItemRepository>(
  => ItemRepositoryImpl(gi<ApiClient>),
 )
 ..registerFactory<ItemListBloc>(
  => ItemListBloc(repository: gi<ItemRepository>),
 )
 ..registerFactory<ItemDetailBloc>(
  => ItemDetailBloc(repository: gi<ItemRepository>),
 );
}
```

`app` 呼叫端:[`app/lib/src/di/compose_dependencies.dart`](../app/lib/src/di/compose_dependencies.dart) 末尾 `registerAuthFeature(gi); registerHomeFeature(gi);` 加上 `// {{feature-registry}}` 標記,供 `tool/new_feature.dart` 插入新 feature 的註冊呼叫。

全域狀態的例外:`SessionManager` 不是 feature 註冊的一部分,而是 `app` 組裝層以 `registerLazySingleton<SessionManager>` 註冊的 app 生命週期單例(見 §9)。

## 6. `sources/` 層判準

demo repository 可省略 `data/sources/` 層——單一 remote 來源且無本地快取時,repository 可直呼 `ApiClient`;出現第二來源(如加入本地快取、多個 remote 端點)時才抽 `sources/`。

現況兩個示範 feature 皆未建立 `sources/`,repository 直接持有 `ApiClient`:

- [`features/home/lib/src/data/repositories/item_repository_impl.dart`](../features/home/lib/src/data/repositories/item_repository_impl.dart):`ItemRepositoryImpl(this._client)`,`_client` 型別為 `ApiClient`。
- [`features/auth/lib/src/data/repositories/auth_repository_impl.dart`](../features/auth/lib/src/data/repositories/auth_repository_impl.dart):同樣直接持有 `ApiClient`。

### 6.1 快取、stream 與分頁樣板

「離線可看」「詳情頁改了資料要回寫列表」「兩個頁面顯示同一份資料要同步」這三種需求在真實 App 大概第三週就會出現。模板用**同一個機制**覆蓋三者,不需要各 feature 自己發明:

- **讀走 `watchItems`** —— 訂閱後立即收到現值(本地快取;無快取時為空清單),之後每次刷新成功再收到一次。永遠不等網路。
- **寫走 `refreshItems`** —— 打遠端,成功才更新快取並廣播;**失敗保留舊快取**(斷網不該清空畫面),錯誤以 `Failure` 回傳給呼叫端決定怎麼呈現。
- **多頁同步靠同一個 repository 單例** —— 所以 repository 必須是 `lazySingleton`、bloc 是 `factory`,且 `dispose` 交給 DI 容器(bloc 生命週期比 repository 短,讓 bloc 去 close 會讓下一個頁面拿到已關閉的 stream)。

分頁採 **cursor** 而非 offset/page(資料變動時不會跳頁或漏項)。四條語意定死:

1. **`refreshItems` 是「回到第一頁」** —— 清掉已載入的後續頁面、游標重設。下拉刷新回到第一頁是使用者的預期行為。
2. **`loadMore` 只往尾端附加**,不動已載入的內容。
3. **只有第一頁寫進本地快取。** 離線時看得到第一頁就夠了;把幾百筆全存進 `KeyValueStore` 會讓啟動時的 JSON decode 變慢——**那是該換 DB 的訊號,而不是把 key-value 撐大**。
4. **`loadMore` 必須防重入** —— 已有進行中的請求就回傳同一個 Future(做法比照 `SessionManager.refreshTokens`)。不防的話使用者快速捲動會同時發出多個同 cursor 的請求,清單出現重複項目。

`loadMore` 的失敗**不清掉清單、也不寫進 `lastError`** —— 已載入的內容必須留著,底部顯示重試列即可。UI 端用 `items.length + (hasMore ? 1 : 0)` 加上 `hasMore && !loadingMore` 守衛做無限捲動,不引入分頁套件(這段邏輯只有十行)。

參考實作:[`features/home/lib/src/domain/repositories/item_repository.dart`](../features/home/lib/src/domain/repositories/item_repository.dart) 與 [`item_repository_impl.dart`](../features/home/lib/src/data/repositories/item_repository_impl.dart)。

```dart
abstract interface class ItemRepository {
 Stream<List<Item>> watchItems;
 Future<Result<void>> refreshItems;
 Future<Result<Item>> fetchItem(String id);
 void dispose;
}
```

三個實作細節不可簡化,理由寫在程式碼註解裡:`watchItems` 用 `Stream.multi` 且**先接廣播再讀快取**(反過來會遺失事件)、`_loadCacheOnce` 的 `??=` 判斷在 `await` **之後**(否則舊快取會覆寫新資料)、以及 `listen` 的 `onDone: controller.close`(少了它 dispose 後外層 stream 永遠不結束)。快取 key 帶版本號(`home.items.v1.cache`),DTO 欄位改動時升版讓舊快取自然失效。

UI 端對應的狀態形狀是 `ItemListReady(items, refreshing, lastError)`:有舊資料 + 正在刷新 + 刷新失敗三者可並存,失敗時用 SnackBar 提示而**不要**整頁換成錯誤畫面。

### 6.2 表單樣板

一律 **`Form` + `TextFormField` + 集中式 `Validators`**,不引入表單套件
(`formz`、`reactive_forms`、`flutter_form_builder` 都要學一套新概念,對
「降低學習成本」是反效果;Flutter 內建的機制已經夠用,而且每個 Flutter
工程師都認得)。

四條規則:

1. **驗證規則集中在 [`Validators`](../packages/core/lib/src/validation/validators.dart),禁止在 page 裡就地寫 `RegExp`。** 多個規則用 `Validators.all(value, [...])`,它回傳**第一個**失敗的 key。
2. **`Validators` 回傳 l10n key 而不是文案**——`core` 不依賴 `localization`。page 端用 `ui` 的 [`localizeValidationError`](../packages/ui/lib/src/forms/validation_messages.dart) 換成當地語言,那個對照表放在 `ui` 而不是各 page 裡,否則每個表單都要抄一次。
3. **`autovalidateMode` 一律用 `onUserInteraction`**:使用者改過的欄位即時顯示錯誤,沒碰過的不要一進頁面就紅一片。
4. **驗證邏輯不進 cubit。** 表單欄位驗證是純函式,放 cubit 只會讓每個表單都要寫一份 state;cubit 只負責送出與送出結果。

參考實作:[`login_page.dart`](../features/auth/lib/src/presentation/pages/login_page.dart)。要加表單頁照它抄。

**email 的 RegExp 刻意寬鬆**(只檢查「有東西@有東西.有東西」)。嚴格的
email regex 是有名的陷阱,會擋掉合法地址;真正的驗證是寄一封信過去。

**`minLength` 適用於註冊與改密碼流程,不適用於登入。** 既有使用者可能持有
較短的舊密碼,在登入頁跟他說「至少 N 個字元」是誤導,而且會擋掉本來該由
後端回「帳密錯誤」的正常失敗路徑。`login_page.dart` 的密碼欄因此只檢查
必填——這是刻意的,有測試釘住。

### 6.3 埋點

- **頁面瀏覽全自動,feature 端零手動呼叫。** `app` 掛了一個 `NavigatorObserver`([`analytics_observer.dart`](../app/lib/src/router/analytics_observer.dart))把路由切換轉成 screen 事件。**不要在任何 page 的 `initState` 加 `trackScreen`** ——漏一頁就少一頁數據,而且沒有任何機制會提醒你漏了。
- **`GoRoute` 一律要設 `name`**,規則:snake_case、不含動態參數、跨 feature 唯一。go_router **不是**「沒設 `name` 就給 null」——沒設時 `settings.name` 拿到的是路由 pattern(`items/:id`),送進報表是髒資料。observer 會過濾含 `:` 的名稱,但正解是把 `name` 補上。
- **自訂事件(`trackEvent`)在 bloc/cubit 裡呼叫,不在 widget 裡。** 事件對應的是業務動作而不是渲染。

### 6.4 權限流程

權限流程是每個 App 都要做、而且**做錯的方式高度一致**的東西。四條規則,
每條都對應一種常見錯誤:

1. **不在 `initState` 直接請求。** 必須由使用者的明確動作觸發(按鈕、進入需要該權限的功能)。否則系統對話框會在使用者不知道為什麼的時候跳出來,**拒絕率大幅上升**,而拒絕兩次就變成永久拒絕。
2. **請求前先 `check`。** 已授權就不要再 `request`。
3. **`permanentlyDenied` 一律導向系統設定**,不要重複 `request` ——那不會跳對話框,使用者會以為 App 壞了。UI 要有一句說明為什麼需要這個權限 + 一顆「前往設定」按鈕。
4. **拒絕不是錯誤。** 不要 `recordError`、不要顯示錯誤畫面。降級提供功能,或顯示一段說明。

介面與 fake 在 [`packages/permissions`](../packages/permissions);活範例是
[`notification_permission_card.dart`](../features/home/lib/src/presentation/widgets/notification_permission_card.dart),
四種狀態都有對應行為與測試。加新權限的步驟見
[`docs/how-to/add-a-permission.md`](how-to/add-a-permission.md)。

**不要把權限狀態存進自己的快取。** 系統設定可能在 App 背景時被改,每次都
`check`。

### 6.5 golden 與 integration test

`tool/check.sh` 擋的全是**結構**。AI agent 最常見的破壞不是結構違規,是
**結構完全合法、畫面壞了**:某個 `Column` 改成 `Row`、某個 padding 改掉、
某個 `switch` 分支渲染成錯的元件。這類回歸只能靠人 review 抓,而 review
AI 產出的 diff 正是人最容易放水的地方。

三張 golden(`app/test/golden/`):登入頁、首頁有資料、`AppErrorView`。
**刻意只有三張**——golden 的維護成本跟數量成正比,拍到二十張之後每次改主題
色都要重拍二十張,團隊就會開始無腦 `--update-goldens`,那時它就失去意義了。
**寧可少而準。**

#### 改了畫面之後

1. 到 Actions 手動觸發 **`update-goldens`** job(`workflow_dispatch`)。
2. 從該次執行的 artifact 下載 png,放進 `app/test/golden/goldens/`,納入同一個 PR。
3. 在 PR 描述說明改了什麼。

**不要在本機跑 `--update-goldens`。** Flutter 的 golden 對平台的字型
rasterization 與 antialiasing 敏感,macOS 產的 png 跟 CI(ubuntu)對不起來
——本機更新會讓 CI 反向變紅,來回兩輪之後就會有人把 golden 從 `check.sh`
拿掉。三個 golden 測試都帶 `skip: !Platform.isLinux`,本機跑會顯示 skipped。

改動 `packages/ui` 的共用元件時,**必須確認三張 golden 都還通過**。新增頁面
不強制加 golden。

字型由 [`app/test/flutter_test_config.dart`](../app/test/flutter_test_config.dart)
從釘選的 Flutter SDK 載入(Roboto 三個字重 + MaterialIcons)。**沒有這一步,
測試環境不帶任何字型,文字與圖示會渲染成實心方塊**——golden 仍抓得到版面與
顏色的退化,但抓不到字型退化,而且 png 無法用肉眼 review。該檔在找不到字型時
會直接丟 `StateError`,不靜默退回無字型狀態。升級 `.fvmrc` 的 Flutter 版本
時字型可能一併變動,**要重新觸發 `update-goldens`**。

#### integration test

`app/integration_test/app_journey_test.dart` 跑一條完整旅程(登入 → 清單 →
詳情 → 返回),走內建假後端。這是唯一能證明「App 真的能跑」的東西——
`check.sh` 擋結構、golden 擋單頁畫面,只有它會把 DI、router、session、
資料層串起來跑。CI 有獨立的 `integration` job(開 emulator 約五到十分鐘)。

## 7. DTO 手寫判準

freezed / codegen 使用準則:DTO 一律 `json_serializable`(欄位少不值 codegen 時可手寫 `fromJson`);entity 預設手寫,欄位多且需要 `copyWith` 時才用 freezed。

範例:[`features/home/lib/src/data/dtos/item_dto.dart`](../features/home/lib/src/data/dtos/item_dto.dart) 手寫 `fromJson`(僅 3 個 `String` 欄位,不值得引入 codegen):

```dart
factory ItemDto.fromJson(Map<String, dynamic> json) => ItemDto(
 id: json['id'] as String,
 title: json['title'] as String,
 description: json['description'] as String,
);
```

缺欄位時 cast 失敗直接向外拋出,由 `ApiClient._send` 收攏為 `ParsingException`(見 §3)。對應 entity [`features/home/lib/src/domain/entities/item.dart`](../features/home/lib/src/domain/entities/item.dart) 亦手寫,不使用 freezed。

## 8. 測試規範

### 8.1 四條規則

1. 提供介面的 package 必須同時從 `lib/testing.dart` 匯出官方 fake;下游測試一律用官方 fake,禁止各自手寫 mock。例:[`packages/core/lib/testing.dart`](../packages/core/lib/testing.dart) 匯出 `FakeTokenRefreshGateway`;[`packages/core/lib/testing.dart`](../packages/core/lib/testing.dart) 匯出 `FakeLogger`。[`features/auth/test/presentation/login_page_test.dart`](../features/auth/test/presentation/login_page_test.dart) 即以 `InMemorySecureStore`(`package:persistence/testing.dart`)+ `FakeTokenRefreshGateway`(`package:session/testing.dart`)+ `FakeLogger`(`package:foundation/testing.dart`)組裝真實 `SessionManager`,而非手寫 mock。
2. 測試替身統一用 **mocktail**(無 code-gen)+ **bloc_test**。工具唯一化,不給選擇。例:`features/home/test/presentation/item_list_bloc_test.dart` 用 `class _MockItemRepository extends Mock implements ItemRepository {}` + `blocTest<ItemListBloc, ItemListState>(...)`。
3. 完成的定義:bloc 事件→狀態轉換、repository 資料轉換與錯誤映射必須有測試;page 至少有 loading/success/error 三態渲染測試。golden、integration 為建議項。四個示範測試檔([`item_list_bloc_test.dart`](../features/home/test/presentation/item_list_bloc_test.dart)、[`item_detail_bloc_test.dart`](../features/home/test/presentation/item_detail_cubit_test.dart)、[`item_repository_impl_test.dart`](../features/home/test/data/item_repository_impl_test.dart)、[`home_pages_test.dart`](../features/home/test/presentation/home_pages_test.dart))即示範此完成度。
4. `tool/new_feature.dart` 連同測試骨架一起產出(見 §12)。

### 8.2 測試文案

測試斷言文案走 `AppLocalizations` 的具體語系實例(如 `AppLocalizationsEn`,見 [`packages/localization/lib/src/generated/app_localizations_en.dart`](../packages/localization/lib/src/generated/app_localizations_en.dart)),不硬編字串常數,避免文案改動時兩處失同步。已統一走 `AppLocalizationsEn` 取值:[`app/test/app_flow_test.dart`](../app/test/app_flow_test.dart) 的 SnackBar 斷言用 `AppLocalizationsEn.authLoginFailed`;[`features/auth/test/presentation/login_page_test.dart`](../features/auth/test/presentation/login_page_test.dart) 同式樣;[`features/home/test/presentation/home_pages_test.dart`](../features/home/test/presentation/home_pages_test.dart) 以模組層級 `final _l10n = AppLocalizationsEn;` 取代 `'Something went wrong. Please try again.'`/`'Retry'`/`'No items yet.'` 等硬編字串,分別對應 ARB key `commonErrorGeneric`/`commonRetry`/`homeEmpty`(見 [`packages/localization/lib/src/arb/app_en.arb`](../packages/localization/lib/src/arb/app_en.arb))。測試取文案一律 `import 'package:localization/testing.dart';` 取用 `AppLocalizationsEn`(測試專用入口,見 [`packages/localization/lib/testing.dart`](../packages/localization/lib/testing.dart);比照其他 package 的 `testing.dart` 慣例,不深層 import `lib/src/`)。

### 8.3 元件選取器

widget 測試點擊/查找元件用 `find.byType(<公開元件型別>)`,不耦合內部實作(如不對 `FilledButton` 這類 `AppPrimaryButton` 的內部渲染細節做選取,改用 `design_system` 匯出的公開型別)。範例:[`app/test/app_flow_test.dart`](../app/test/app_flow_test.dart) 用 `find.byType(AppPrimaryButton)`(`AppPrimaryButton` 為 `design_system` 匯出的公開元件,見 [`packages/ui/lib/src/components/app_primary_button.dart`](../packages/ui/lib/src/components/app_primary_button.dart))點擊送出按鈕,而非耦合其內部 `FilledButton` 實作。

## 9. 取消語意、import 風格、`SessionManager` 生命週期

(a) **請求取消映射**:`error_mapper.dart` 把 `DioExceptionType.cancel` 映射為 `CancelledException`(見 §3 程式碼片段)。**bloc 收到 `CancelledException` 時直接 return,不改變狀態**——不顯示錯誤畫面、不上報。取消是預期中的控制流,不是失敗。這是消費端(bloc)的職責,`error_mapper.dart` 只負責產生正確的例外型別,不負責判斷「是否該忽略」。

取消能力由 [`ApiClient`](../packages/core/lib/src/networking/api_client.dart) 的四個方法提供可選的 `CancelToken` 參數,**止於 data 層**:domain 介面(如 `ItemRepository`)不得出現 `CancelToken`,那是 dio 的型別,讓 domain 知道 HTTP 傳輸細節就破壞了分層。呼叫端可從 `package:core/core.dart` 取得 `CancelToken`,不需直接依賴 dio。

(b) **import house style**:package 內部一律用 `package:x/src/...` 絕對路徑,不用相對路徑。範例遍布全庫,如 [`features/home/lib/src/presentation/pages/home_page.dart`](../features/home/lib/src/presentation/pages/home_page.dart) 內 `import 'package:home/src/presentation/blocs/item_list/item_list_bloc.dart';`。

(c) **`SessionManager` 生命週期**:app 生命週期單例(由 `compose_dependencies.dart` 以 `registerLazySingleton<SessionManager>` 註冊,不提供 dispose),`states` 為無 replay 的 `StreamController<SessionState>.broadcast(sync: true)`(見 [`packages/core/lib/src/session/session_manager.dart`](../packages/core/lib/src/session/session_manager.dart))。訂閱前必須先讀 `state` getter 取得現值,不可假設訂閱後會立刻收到目前狀態。

### 9.1 第三方 plugin 包裝判準

第三方能力是否包成 `packages/` 成員(附 `lib/testing.dart` fake),取決於:

- **需在測試中被替換、或含轉換邏輯** → 包成 `packages/` 成員 + 官方 fake。
 先例:[`packages/core`](../packages/core) 的 `src/persistence`(包 `shared_preferences`)、
 [`packages/integrations`](../packages/integrations)
 (包 `firebase_messaging`,`FcmPushNotifications` 把 `RemoteMessage` 轉為
 `PushTapEvent`/`PushMessage`,`FakePushNotifications` 供下游測試)。
- **純 UI 或一次性工具** → 直接在 feature 內使用,不建 package(過度包裝反而增加間接層)。

## 10. 例外斷言與 ignore 註解

- **例外相等策略**:`AppException` 不實作 `==`/`hashCode`;測試斷言一律用 `isA<ServerException>` 類 matcher,不做例外實例的相等比較。範例:`features/home/test/presentation/item_list_bloc_test.dart` 的 `isA<ItemListReady>.having((s) => s.lastError, ...)` 模式;`packages/core/test/networking/error_mapper_test.dart` 大量使用 `isA<ConnectivityException>` 等。
- **`ignore` 註解格式**:每處逐行 `// ignore: 規則 -- 原因`,`tool/check.sh` 的「ignore 稽核」以 grep 擋無 ` -- 原因` 的 ignore(生成檔 `**/src/generated/**` 豁免,與根 `analysis_options.yaml` 的 `analyzer.exclude` 對齊)。範例:[`packages/core/lib/src/session/token_refresh_gateway.dart`](../packages/core/lib/src/session/token_refresh_gateway.dart) 的 `// ignore: one_member_abstracts -- 契約刻意單方法,依架構規則由 app 提供實作`;[`app/lib/src/bootstrap.dart`](../app/lib/src/bootstrap.dart) 的 `// ignore: discarded_futures -- 上報為 fire-and-forget，不阻塞錯誤呈現流程`。

## 11. 產生器工作流:`new_feature` 之後該做什麼

`dart run tool/new_feature.dart <name>` 依本文件產出完整骨架後,自動完成:

1. 產生完整 feature 骨架(pubspec、barrel、`di.dart`、`routes.dart`、三層目錄、一組會動的範例 bloc + 頁面 + 測試)。
2. 把新 package 加進 workspace 根 `pubspec.yaml`。
3. 在 `app` 的 DI(`compose_dependencies.dart` 的 `// {{feature-registry}}`)與路由(`app_router.dart` 的 `// {{feature-registry}}`)標記區塊插入接線。
4. 在 `navigation` package 的 `// {{route-paths}}` 標記區塊插入路徑常數與 route 類別範本。
5. 在 `app/test/di_smoke_test.dart` 的 `// {{feature-registry}}` 標記區塊插入新 feature 註冊型別的解析呼叫。

產生器之後仍需人工完成的事(不屬產生器範圍):依實際 API 修改 DTO/entity/repository 邏輯;在 `localization` 的 ARB 加入以 feature 前綴命名的文案 key(如 `home*`、`auth*`,見 [`packages/localization/lib/src/arb/app_en.arb`](../packages/localization/lib/src/arb/app_en.arb));視 §4/§6 判準決定是否需要 `usecases/` 或 `sources/`;跑一次 `tool/check.sh` 確認 CI 同構檢查全過(含 §11 的 l10n 漂移檢查)。

## 分支與 PR 規範

本庫採通用 **Git Flow**:

- **`master`**:正式版分支。只接受 `release/*`、`hotfix/*` 合入;每次合入對應一個版本 tag。任何人(含 AI agent)不得直接 push。
- **`develop`**:整合分支,日常 PR 的目標分支。任何人(含 AI agent)不得直接 push。
- **`feature/<name>`**:單一功能/修復的工作分支,從 `develop` 切出,PR 回 `develop`。AI agent 的所有變更一律走此分支。
- **`release/<x.y.z>`**:發版準備分支,從 `develop` 切出;完成後合入 `master`(打 tag)並回併 `develop`。
- **`hotfix/<x.y.z>`**:針對 `master` 上線版本的緊急修復,從 `master` 切出;完成後合入 `master`(打 tag)並回併 `develop`。

流向摘要:`feature/* → develop`;`release/* → master`(+ 回併 `develop`);`hotfix/* → master`(+ 回併 `develop`)。

Release 收尾慣例:`release/*` 或 `hotfix/*` 合入 `master` 時——(1) 於合併 commit 打 annotated tag `vX.Y.Z`(SemVer);(2) 同一 PR 內更新根目錄 [`CHANGELOG.md`](../CHANGELOG.md)(Keep a Changelog 格式,列出 Added/Changed/Fixed);(3) 合併後回併 `develop`。日常 `feature/*` PR 不動 CHANGELOG,由 release PR 彙整。

AI coding agent 的工作方式:一律在 `feature/<name>` 分支上進行變更,不直接在 `master`/`develop` 上 commit;PR 一律以 `develop` 為目標分支(除非任務明確為 hotfix);合併前需 CI 全綠(`tool/guard.sh` + `tool/check.sh`,見 [`.github/workflows/ci.yaml`](../.github/workflows/ci.yaml))且完成 [PR template](../.github/pull_request_template.md) 的「完成的定義」checklist。`tool/`、`analysis_options.yaml`、`.github/`、`docs/adr/`、`.fvmrc` 為護欄相關路徑,異動需 CODEOWNERS(見 [`.github/CODEOWNERS`](../.github/CODEOWNERS))核可。

## 11.1 產生物與漂移

兩類內容由腳本產生,**改了來源就要 regen 並把產物納入同一個 commit**,
否則 `tool/check.sh` 的漂移檢查會擋:

| 改了什麼 | 要跑什麼 | 擋在哪一步 |
|---|---|---|
| `packages/localization` 的 ARB | `(cd packages/localization && fvm flutter gen-l10n)` | 9/12 l10n 漂移檢查 |
| 任何 pubspec 的 workspace 依賴、`name`、`description`、workspace 成員清單 | `fvm dart run tool/gen_arch_docs.dart` | 10/12 架構文件漂移檢查 |

`docs/architecture.md` 的 §1 拓撲表、§2.1 依賴白名單、§2.2 mermaid 依賴圖
包在 `<!-- BEGIN GENERATED: ... -->` 標記之間,**內容請勿手改**。標記本身由
`tool/guard.sh` 斷言保護。

其餘段落(§3 三條關鍵鏈路、§3.4 等)是判斷與敘述,人寫的才有價值,不產生。

## 11.2 文件層級

| 文件 | 定位 |
|---|---|
| [`architecture.md`](architecture.md) | **權威來源**:東西放哪、怎麼連 |
| 本文件 | **權威來源**:怎麼寫 |
| [`adr/`](adr/) | 為什麼是這樣設計。ADR 是歷史紀錄——要修訂是在文末加「後續修訂」段落,**不改寫既有決策內容** |
| [`how-to/`](how-to/) | 操作步驟,用到再查 |
| [`onboarding.md`](onboarding.md) | 新成員的學習路徑 |
| [`../CLAUDE.md`](../CLAUDE.md) | AI agent 的唯一入口([`../AGENTS.md`](../AGENTS.md) 明文指向它),由 `tool/guard.sh` 的正反向斷言釘住不與現實脫節 |
| [`archive/`](archive/) | 模板建立當時的規格與階段計畫,**非現行規則** |

`tool/check.sh` 的 markdown 連結檢查會掃全部 `.md` 的相對連結,指向不存在的
路徑就紅燈(`docs/archive/` 除外)。**這取代了「逐一 `ls` 確認」的人力紀律**
——那正是這個 repo 在其他每個地方都拒絕的東西。

## 12. 相關文件

- workspace 拓撲、依賴方向與關鍵鏈路:[`architecture.md`](architecture.md)
- 架構決策紀錄:[`adr/`](adr/)
