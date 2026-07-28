# 0001. 多 package workspace(Dart 3.6+ 原生 pub workspace,不用 melos)

## 狀態

已採用。

## 背景

需求方(medium level mobile developer)與不同資質的 RD 共同維護一個中大型 App,設計原則是「規則由工具(編譯器、lint、CI、產生器)執行,不靠人力紀律」(規格 §1)。模組邊界需要一個機制強制:每個 feature、每個共用能力都獨立成 package,彼此依賴方向明確,才能讓不同資質的人平行開發而不互相踩踏。

規格 §2 明確定案:「模組邊界用 **Dart 3.6+ 原生 pub workspace(多 package)** 強制,不用 melos。」根 [`pubspec.yaml`](../../pubspec.yaml) 的 `workspace:` 清單列出全部 12 個成員(1 個 `app` + 9 個 `packages/*` + 2 個示範 `features/*`),各成員自帶 `pubspec.yaml`(`resolution: workspace`)。

## 決策

- 用 Dart SDK 原生 workspace 支援(`pubspec.yaml` 的 `workspace:` 欄位),不引入 melos 或其他多套件管理工具。
- 依賴方向四條規則(見 [`docs/architecture.md`](../architecture.md) §2):`foundation` 零依賴;`packages/*` 之間單向依賴且明列於依賴圖;`features/*` 只能依賴 `packages/*`/`foundation`,永遠不能依賴其他 feature 或 `app`;`app` 是唯一什麼都能依賴的組裝層。
- 邊界的強制機制精準描述(規格 §2 開頭段落):pub workspace 是共享 resolution,整個 workspace 只有一份 `package_config.json`,因此「未在 pubspec 宣告依賴的 import」**仍然編譯得過**。真正守住依賴邊界的是 analyzer 的 `depend_on_referenced_packages` lint(`very_good_analysis` 已內含,本模板升為 **error** 級,見根 [`analysis_options.yaml`](../../analysis_options.yaml))加上 CI 的 `flutter analyze` 硬性把關,再加上 [`tool/check.sh`](../../tool/check.sh) 第 4 步的 pubspec 依賴稽核腳本(擋「宣告了被禁止的依賴」這半邊,`depend_on_referenced_packages` 擋不住)。

## 後果

- 好處:每個 package 可獨立 `flutter test`(規格 §3);依賴邊界機器可驗證,不靠 code review 記憶力;新增 feature 只需 `tool/new_feature.dart` 產生器 + 加入 workspace 清單,不需額外工具鏈設定。
- 代價:workspace 內所有 package 共享同一份 dependency resolution,版本衝突需整個 workspace 一起解;`depend_on_referenced_packages` 本質是 lint 而非編譯器錯誤,單靠它仍留有「宣告了被禁止依賴」的漏洞,需額外腳本(`tool/check.sh` 第 4 步)補強,屬於工具鏈的複雜度增量。
- 範圍外的取捨:mason brick 形式的產生器暫不採用,先用 Dart script(`tool/new_feature.dart`)驗證後再考慮(規格 §9)。

## 後續修訂

**2026-07-29(ADR-0006)**:成員數由 12 收斂為 4 + N——六個技術基礎設施
package(`foundation`/`networking`/`persistence`/`session`/`observability`/
`navigation`)合併為 `packages/core`,`design_system` 更名為 `ui`,
`push_notifications` 與 Firebase 實作收成可選的 `packages/integrations`。

**本 ADR 的核心決策未變**:仍用 pub workspace 的多 package 結構強制邊界,
`features/*` 之間的物理隔離完全不動。改變的只是「技術基礎設施要拆成幾個
package」這個維度。理由與已知代價見 [ADR-0006](0006-package-consolidation.md)。
