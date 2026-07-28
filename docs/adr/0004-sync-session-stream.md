# 0004. `SessionManager.states` 用同步 broadcast stream,`_emit` 先賦值後發布

## 狀態

已採用。

## 背景

`SessionManager`([`packages/core/lib/src/session/session_manager.dart`](../../packages/core/lib/src/session/session_manager.dart))是登入狀態的單一真相(規格 §2.3),同時驅動兩個全域行為(見 [`docs/architecture.md`](../architecture.md) §3.3):`app_router.dart` 的 `redirect` 讀 `session.state` 做登入守衛,以及 `SessionRefreshListenable` 訂閱 `states` 觸發 go_router 重新評估。這兩處都要求「收到事件當下讀 `state`,值必須已經是新值」,否則 redirect 會用到過期狀態,導致守衛判斷落後一輪。

## 決策

- `_controller` 宣告為同步 broadcast stream:

  ```dart
  final StreamController<SessionState> _controller =
      StreamController<SessionState>.broadcast(sync: true);
  ```

- `_emit()` 契約:**先賦值 `_state`,再視情況 `_controller.add(next)`**,且只在 `runtimeType` 改變時才真正發布(不 replay 相同型別的狀態):

  ```dart
  void _emit(SessionState next) {
    final changed = next.runtimeType != _state.runtimeType;
    _state = next;
    if (changed) {
      _controller.add(next);
    }
  }
  ```

- `states` getter 的文件註明契約與重入警告(同檔):「事件為同步派送(sync broadcast);listener 回呼中讀取 `state` 保證與事件一致,但不得在回呼中同步呼叫 `signIn`/`signOut`/`restore` 等變更方法(重入風險)。」
- `states` 無 replay:新訂閱者不會收到過去已發生的事件,訂閱前必須先讀 `state` getter 取得現值(規格 §10 第 13 條 c 款,見 [`docs/conventions.md`](../conventions.md) §9)。
- app 生命週期單例、不提供 `dispose()`——`SessionManager` 存活與 app 進程等長,不會有「訂閱後 controller 已關閉」的問題。

## 後果

- 好處:`_emit` 先賦值保證任何同步讀 `state` 的 listener(如 router 的 `redirect`)拿到的值與剛發布的事件一致,不會有「事件已到但 state 還沒更新」的競態窗口;`runtimeType` 比對避免同型別重覆狀態(如兩次 `SessionAuthenticated`)造成多餘的 router 重新評估。
- 代價/風險:同步 broadcast 意味著 `_controller.add()` 呼叫期間會**同步**執行所有 listener 回呼;若某個 listener 在回呼中同步呼叫 `signIn`/`signOut`/`restore`,會在 `_emit` 尚未返回時重入 `SessionManager`,狀態機行為未定義——這是刻意保留給呼叫端遵守的契約(文件警告),而非程式碼層面阻擋,消費端(如未來新增的 listener)需自行避免同步重入,必要時改用 `scheduleMicrotask` 或等到下一輪事件循環再呼叫變更方法。
- 無 replay 的取捨:簡化了 `StreamController` 實作(不需 `onListen` 補送邏輯),但要求所有消費端(`SessionRefreshListenable`、未來新增的訂閱者)在訂閱前主動讀一次 `state`,若遺漏這一步會錯過啟動時的初始狀態,已在 §9 慣例文件與本 ADR 中明確記載以降低遺漏風險。
