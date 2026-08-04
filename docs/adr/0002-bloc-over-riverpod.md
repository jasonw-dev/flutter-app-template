# 0002. 狀態管理採 Bloc + get_it,排除 Riverpod 與輕量 MVVM

## 狀態

已採用。

## 背景

規格 §1 列出三個曾比較過的路線:

1. **Bloc + get_it**:完整分層(data/domain/presentation)、事件可追溯,適合中大型專案的可控性,但樣板量較大。
2. **Riverpod**:規格明確排除的路線。
3. **輕量 MVVM**:規格明確排除的路線。

規格 §1 定案原文:「選型定案:Bloc + get_it(完整分層、事件可追溯,取其中大型專案的可控性;樣板量由 AI 輔助與程式碼產生器吸收)。已明確排除 Riverpod 路線與輕量 MVVM 路線。」

決定性考量是需求方的使用者輪廓:「需求方本人(medium level mobile developer)為主要維護者,與不同資質的 RD 共同維護」,且「對 AI coding agent 協作友善」為硬性條件(規格 §1)。Bloc 的顯式 event → state 轉換序列,比 Riverpod 的 provider 圖或輕量 MVVM 的隱式綁定更適合工具(lint、產生器、AI)介入與稽核;樣板量的代價則交給 `tool/new_feature.dart` 產生器與 AI 輔助吸收,而非要求人力手寫。

## 決策

- 全專案一律用 `flutter_bloc`(`Bloc`,不用 `Cubit`),不引入 Riverpod、Provider 或其他狀態管理套件。
- Bloc 規範定死、不給選擇(規格 §4.2,六鐵律,詳見 [`docs/conventions.md`](../conventions.md) §2):State 用 `sealed class`、UI exhaustive `switch` 渲染、事件命名「主詞+過去式動詞」、Bloc 之間禁止互相引用、repository 一律回傳 `Result<T>`、Bloc 檔案不 import Flutter。
- DI 用 `get_it`:repository/data source `lazySingleton`,bloc 一律 `factory` 跟隨頁面生命週期(規格 §4.4,見 [`docs/conventions.md`](../conventions.md) §5)。`app/test/di_smoke_test.dart` 逐一解析已註冊型別,把「忘記註冊」在 CI 攔下。
- 範例落地:[`features/home/lib/src/presentation/blocs/item_list/item_list_bloc.dart`](../../features/home/lib/src/presentation/blocs/item_list/item_list_bloc.dart)、[`features/auth/lib/src/presentation/blocs/login/login_bloc.dart`](../../features/auth/lib/src/presentation/blocs/login/login_cubit.dart)。

## 後果

- 好處:event → state 轉換可測(`bloc_test`)、可追溯(每個狀態變化有明確事件觸發);sealed state + exhaustive switch 把「漏處理狀態」升級為編譯錯誤,是規格 §8 護欄總覽中「編譯器級」的具體案例;`get_it` 的顯式註冊配合 `di_smoke_test` 讓「忘記接線」在 CI 失敗而非執行期閃退。
- 代價:比 Riverpod 或輕量 MVVM 樣板量更大(每個使用情境需 bloc/event/state 三檔),此代價由 `tool/new_feature.dart` 產生器與 AI 協作配套(規格 §6.4 的 CLAUDE.md 鐵律清單、任務路由表)吸收,而非要求 RD 手寫。
- 排除項不重新評估:Riverpod 與輕量 MVVM 路線在規格定案時已明確排除,本模板不提供切換路徑;若後續要換,屬於推翻本 ADR 的規模,需重新走設計討論。
