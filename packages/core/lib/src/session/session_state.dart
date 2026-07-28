/// 登入狀態(單一真相,由 SessionManager 發布)。
sealed class SessionState {
  const SessionState();
}

/// 啟動中,尚未完成從儲存還原。
final class SessionRestoring extends SessionState {
  /// 建立還原中狀態。
  const SessionRestoring();
}

/// 已登入。
final class SessionAuthenticated extends SessionState {
  /// 建立已登入狀態。
  const SessionAuthenticated();
}

/// 未登入(含登出與 token 失效)。
final class SessionUnauthenticated extends SessionState {
  /// 建立未登入狀態。
  const SessionUnauthenticated();
}
