# 0005. `BufferingCrashReporter`:啟動期緩衝、排水後切換、單筆失敗不中斷

## 狀態

已採用。

## 背景

`bootstrap()`(見 [`docs/architecture.md`](../architecture.md) §3.2)在第 3 步就掛上全域錯誤捕捉(`FlutterError.onError` + `PlatformDispatcher.instance.onError`),但 Firebase 要到第 4b 步 `Firebase.initializeApp()` 之後才可用,因此存在一段「已在捕捉錯誤,但真正的 crash reporter(`CrashlyticsCrashReporter`)還沒 ready」的視窗。規格 §10 第 3 條要求:「bootstrap 時序的 crash 上報語義:Firebase init(第 4 步)前發生的錯誤,observability 需先緩衝、init 後補送;做不到則明確降級為僅本地 log,文件同步說明。」本模板選擇實作緩衝,而非降級。

## 決策

`BufferingCrashReporter`([`packages/core/lib/src/observability/buffering_crash_reporter.dart`](../../packages/core/lib/src/observability/buffering_crash_reporter.dart))實作 `CrashReporter` 介面,內部維護一個容量 100 的 replay closure 佇列:

```dart
class BufferingCrashReporter implements CrashReporter {
  static const _capacity = 100;
  final List<Future<void> Function(CrashReporter r)> _buffer = [];
  CrashReporter? _delegate;
  ...
}
```

- **排水後切換**:`attach(delegate)` 依序(`while (_buffer.isNotEmpty)`)把緩衝的呼叫重播到真正的 `delegate`,**排水完成後才把 `_delegate` 設為非 null**;`attach()` 只能呼叫一次(`assert(_delegate == null, ...)`)。`recordError`/`setUserId`/`log` 三個方法都先檢查 `_delegate`:非 null 直通真正的 reporter,null 則 `_push` 進緩衝佇列。這代表「排水期間新到的呼叫」仍會先進緩衝(因為 `_delegate` 尚未設定),`attach()` 的 `while` 迴圈會繼續處理到佇列清空為止,再切換旗標——不會有「排水一半又漏接」的窗口。
- **單筆失敗不中斷**:排水迴圈用 `try { await replay(delegate); } on Object { /* 補送失敗不得中斷排水與啟動;上報遺失可接受。 */ }` 包住每一筆重播,任何一筆補送失敗只記錄式地跳過,不影響其餘筆數的補送,也不阻斷 `bootstrap()` 後續步驟。
- **一次性 attach**:`attach()` 只能呼叫一次,對應 `bootstrap()` 只在 `config.firebaseEnabled` 為真時呼叫一次 `gi<BufferingCrashReporter>().attach(CrashlyticsCrashReporter(FirebaseCrashlytics.instance))`。若 `firebaseEnabled` 為 false,則永遠不 `attach`,`BufferingCrashReporter` 永久停留在緩衝模式(容量 100,超過時 FIFO 丟棄最舊項目)——等同規格所稱的「明確降級為僅本地 log」的替代路徑,但以緩衝佇列的形式保留最近 100 筆,而非完全丟棄。
- 組裝順序:`compose_dependencies.dart` 將 `CrashReporter` 註冊為指向同一個 `BufferingCrashReporter` 單例(`registerLazySingleton<CrashReporter>(() => gi<BufferingCrashReporter>())`),`bootstrap()` 的 `installErrorHooks()` 拿到的即是這個緩衝實例,第 3 步掛上的 hook 與第 4b 步的 `attach()` 操作的是同一個物件。

## 後果

- 好處:啟動期(第 3 步到第 4b 步之間)發生的錯誤不會靜默遺失,而是緩衝後於 Firebase 就緒時補送;單筆補送失敗有隔離,不會因為某一筆上報失敗就讓後續筆數或 app 啟動一併卡住。
- 代價:緩衝佇列容量固定 100,超量時 FIFO 丟棄最舊項目,極端情況(啟動期短時間內大量錯誤)仍可能遺失最早的幾筆;`attach()` 的「只能呼叫一次」用 `assert` 而非 release 期會執行的檢查,重覆呼叫在 release build 不會拋錯,依賴呼叫端(`bootstrap()` 只呼叫一次)自律遵守。
- 一致性:`firebaseEnabled == false` 的環境(如尚未設定 Firebase 專案的模板初始狀態)不會呼叫 `attach()`,`BufferingCrashReporter` 便長期停留在緩衝模式,行為等同「僅本地緩衝、不真正上報」,對應規格允許的降級路線,行為已在本 ADR 與程式碼註解中說明,不需額外的旗標分支。
