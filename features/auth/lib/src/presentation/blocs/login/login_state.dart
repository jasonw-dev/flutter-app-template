import 'package:core/core.dart';

/// 登入頁的狀態(sealed;UI 端須 exhaustive switch 渲染)。
sealed class LoginState {
  /// 基底建構子,僅供子類 super 呼叫。
  const LoginState();
}

/// 尚未送出表單的初始狀態。
final class LoginInitial extends LoginState {
  /// 建立初始狀態。
  const LoginInitial();
}

/// 登入請求進行中。
final class LoginSubmitting extends LoginState {
  /// 建立送出中狀態。
  const LoginSubmitting();
}

/// 登入成功;session 已 signIn,router redirect 負責導航。
final class LoginSuccess extends LoginState {
  /// 建立成功狀態。
  const LoginSuccess();
}

/// 登入失敗,攜帶失敗原因。
final class LoginFailure extends LoginState {
  /// 以例外建立失敗狀態。
  const LoginFailure(this.exception);

  /// 失敗原因。
  final AppException exception;
}
