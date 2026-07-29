import 'package:app/src/startup/startup_gate.dart';
import 'package:flutter/foundation.dart';

/// 持有啟動 gate 判定結果的 app 生命週期單例,並作為 go_router 的
/// `refreshListenable` 來源之一。
class StartupGateController extends ChangeNotifier {
  /// 以 [StartupGate] 實作建立;初值為放行。
  StartupGateController(this._gate);

  final StartupGate _gate;

  StartupGateState _state = const StartupAllowed();

  /// 目前的判定結果。
  StartupGateState get state => _state;

  Future<void>? _inflight;

  /// 執行一次啟動檢查並更新狀態。
  ///
  /// 防重入:已有進行中的評估就回傳同一個 Future(做法比照
  /// `SessionManager.refreshTokens()`)。回前景時可能與啟動時的評估重疊。
  Future<void> evaluate() => _inflight ??= _evaluate().whenComplete(() {
    _inflight = null;
  });

  Future<void> _evaluate() async {
    // gate 的實作理應自己吞掉失敗並回傳 StartupAllowed,但實作是專案寫的,
    // 這裡再兜一層:**gate 丟例外絕不能讓 App 開不起來**。
    try {
      // **無條件通知,不做去重。** 理由同 #24 對 SessionManager._emit 的修正:
      // StartupUpdateRequired 已經帶 storeUrl 欄位,用 runtimeType 比較會在
      // 「同型別但商店連結換了」時靜默漏發。redirect 是純函式且冪等,多評估
      // 幾次沒有副作用。
      _state = await _gate.evaluate();
      notifyListeners();
    } on Object {
      // 維持現值(初值為放行)。
    }
  }
}
