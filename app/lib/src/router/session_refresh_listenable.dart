import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// 將 [SessionManager.states] 轉為 go_router 的 `refreshListenable`。
///
/// 每次收到事件即 `notifyListeners()`,讓 go_router 重新評估 redirect。
class SessionRefreshListenable extends ChangeNotifier {
  /// 訂閱 [states] 並在每次事件時通知監聽者。
  SessionRefreshListenable(Stream<SessionState> states) {
    _subscription = states.listen((_) => notifyListeners());
  }

  late final StreamSubscription<SessionState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
