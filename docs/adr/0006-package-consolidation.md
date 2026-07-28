# 0006. workspace 成員由 12 個收斂為 4 + N

- 狀態:已採納
- 日期:2026-07-29
- 相關:[ADR-0001](0001-multi-package-workspace.md)(原始的多 package 決策)

## 背景

ADR-0001 決定用 pub workspace 的多 package 結構強制邊界。實際使用一段時間後,
入門門檻最主要的來源不是「多 package」這件事本身,而是**成員數量**:新人要
建立的心智模型是「十二個盒子,每個裝什麼」。

而那十二個裡有六個(`foundation`、`networking`、`persistence`、`session`、
`observability`、`navigation`)本質上是同一件事:與業務無關的技術基礎設施。
它們之間的依賴單向、穩定、幾乎不會變動,拆開來並沒有換到實際的隔離價值——
沒有人會「不小心讓 networking 依賴 session」,因為那在設計上就不會發生。

## 決策

收斂為 **4 + N**:

```
app/                   組裝層
packages/core/         ← foundation + networking + persistence + session
                         + observability + navigation + 推播介面
packages/ui/           ← design_system 更名
packages/localization/ (不變)
packages/integrations/ ← push_notifications + Firebase 實作,**可選成員**
features/auth          (不變)
features/home          (不變)
```

心智模型一句話講得完:**技術基礎設施放 `core`,共用 UI 元件放 `ui`,
文案放 `localization`,其餘都在自己的 feature 裡。**

**不退回單一 package。** `features/*` 之間由 pubspec 強制的物理隔離是這個
模板唯一無可取代的資產,那是真正會出事的地方(兩個功能互相 import 是實際
會發生的錯誤,而且事後拆解成本極高)。本次收斂完全不動它。

## 三個一併處理的決定

### 1. 不要把切線說成「不碰 Flutter 的放 core」

合併後的 `core` 含 `flutter`、`flutter_secure_storage`、`shared_preferences`,
那句話是假的。切線是「**技術基礎設施 vs 業務功能**」。

### 2. 保留 `TokenProvider` 介面反轉

原本考慮過:既然 networking 與 session 同居,那層介面反轉可以拿掉。**經檢視
後決定保留。** 拿掉之後 `AuthInterceptor` 必須直接依賴 `SessionManager`,而
`SessionManager` 又要用 `ApiClient`,`core` 內部會出現 networking 與 session
互相 import 的環。介面保留成本只有一個小檔案,環的代價高得多。

### 3. feature 專屬 route 類別下放到各 feature

`ItemDetailRoute` 原本住在共用的 `navigation`,使得該 package 累積了每一個
feature 的知識。實際痛點是:兩個人平行開兩個功能,一定會同時改到同一個共用
檔,是模板裡少數幾個必然的 merge conflict 熱點之一。

切開成兩層:**路徑常數與 `AppRoute` 契約留在 `core`,型別化 route 類別下放到
各 feature 的 `lib/src/routes/`。** 跨 feature 導航因此降級成使用路徑常數
(字串),這是換掉 conflict 熱點的代價——跨 feature 導航本來就少,而且路徑
常數仍是單一真相,改路徑仍然只要改一處。

## 已知代價(刻意接受,不是疏忽)

### `foundation` 失去「純 Dart 零依賴」的性質

收斂前 `packages/foundation` 沒有任何 runtime dependency,`Result` 與
`AppException` 可以在完全沒有 Flutter 的環境(純 Dart server 或 CLI)使用與
測試。合併進含 `flutter` 的 `core` 之後這個性質消失。

連帶的實際影響:原本用 `package:test/test.dart` 的 9 個測試檔改為
`flutter_test`(API 相容,斷言不需要改)。

### `core` 內部的分層邊界降級為資料夾自律

原本由 pubspec 強制的「networking 不得 import session」這類邊界,收斂後只剩
資料夾慣例。緩解方式是後續補一條 grep 檢查,不在本次範圍。

**`features/*` 之間的隔離完全不動**——那才是真正會出事的地方。

## 替代方案

- **退回單一 package**:丟掉最有價值的東西(feature 隔離)去換一點入門順暢,
  不採用。
- **維持 12 個成員、只改文件**:文件寫得再好也改變不了「要記十二個盒子」這件
  事,不採用。
