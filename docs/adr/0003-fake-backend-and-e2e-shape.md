# 0003. 假後端形態與 e2e 測試的形狀

## 狀態

已採用。

## 背景

規格 §3 要求「測試跟著 package 走,每個 package 可獨立測試,不需模擬器、Firebase、真後端」,並在 `app/integration_test/` 保留「假後端啟動 app,跑登入→首頁關鍵路徑(nightly)」的位置(規格 §3)。規格 §10 第 2 條把「示範 feature 與 integration_test 共用的假後端形態(dio mock adapter / 本機 HTTP server 擇一)」列為實作規劃須定案的待辦。

## 決策

- 假後端採 **dio mock adapter** 路線,不啟本機 HTTP server:[`app/lib/src/demo/demo_backend_adapter.dart`](../../app/lib/src/demo/demo_backend_adapter.dart) 的 `DemoBackendAdapter implements HttpClientAdapter`,是 demo API 契約的記憶體實作。契約涵蓋 `POST /auth/login`、`POST /auth/refresh`、`GET /items`、`GET /items/<id>`,含固定的成功/401/404 分支(如 `password == 'wrong'` → 401 `AUTH_INVALID`)。
- `AppConfig.useFakeBackend`(見 [`app/lib/src/config/app_config.dart`](../../app/lib/src/config/app_config.dart))出廠預設 `true`,讓範本開箱即可跑;接上真後端後改為 `false`。`main_prod.dart` 需顯式意識到這個預設值(規格 §10 第 24 條:prod 靜默走假後端為模板陷阱,`main_prod.dart` 需加註解提醒)。
- `composeDependencies()`([`app/lib/src/di/compose_dependencies.dart`](../../app/lib/src/di/compose_dependencies.dart))依 `config.useFakeBackend` 決定是否把 `DemoBackendAdapter` 同時套用到 `createDio`(主 client)與 `createPlainDio`(refresh gateway 用的 plain client),確保 401 重試與 token 換發也走同一個假後端。
- e2e 測試的實際落地形狀是 **app 層 widget flow test**,而非獨立的 `integration_test/` 目錄:[`app/test/app_flow_test.dart`](../../app/test/app_flow_test.dart) 以真實 `composeDependencies()` 組裝完整 DI(僅 `secureStoreOverride` 替換 `flutter_secure_storage` 因測試環境無平台實作)+ 內建假後端 + 完整 `App` widget,涵蓋「login 頁輸入/送出 → home 列表 → 詳情頁」與「登入失敗分支(SnackBar 提示、仍留在 login 頁)」兩條路徑。該檔案頂端註明:「本範本的『integration test』形態——真實 DI 組裝 + 內建假後端 + 完整 App,CI 可跑,不需真後端。」

## 後果

- 好處:不需啟動本機 HTTP server 或額外行程,`flutter test` 即可跑完整登入→列表→詳情路徑,CI 友善、無額外基礎設施依賴;假後端契約集中在單一檔案,示範 feature 與 e2e 測試共用同一份契約,不會分裂成兩套假資料。
- 代價:`DemoBackendAdapter` 的 URL 前綴需與 `ApiClient` 的 `baseUrl` 精確對齊(路徑前綴陷阱,規格 §10 第 24 條要求文件加註說明),否則假後端會回 404 而不易察覺是路徑問題還是邏輯問題。
- 待補(**已於後續修訂解決,見文末**):規格原定位的 `app/integration_test/`(nightly、不擋 PR)在本模板現況尚未建立獨立目錄;目前的 `app/test/app_flow_test.dart` 承擔了「假後端跑關鍵路徑」的角色,但納入一般 `flutter test`(擋 PR),與規格 §3 描述的 nightly-only integration test 定位不完全一致,後續如需真正的 nightly job 需另行規劃。

## 後續修訂(#32,PR #75)

`app/integration_test/app_journey_test.dart` 已建立,在 CI 的獨立 `integration`
job 上以 Android emulator 執行(冷啟動 → 登入 → 清單 → 詳情 → 返回),同樣走
`DemoBackendAdapter`。上節「待補」一條因此結案。

**兩者並存,分工不同**:`app/test/app_flow_test.dart` 是 widget 層的快速 flow
test(每次 `flutter test` 都跑),`app/integration_test/` 是真機/模擬器層的
端到端驗證(獨立 job,開 emulator 約五到十分鐘)。前者證明組裝正確,後者證明
**裝上去打得開**。

同一批變更另加入三張 golden(`app/test/golden/`),補上「結構合法但畫面壞掉」
這類回歸的防線。golden 更新流程見
[`conventions.md` §6.5](../conventions.md)。
