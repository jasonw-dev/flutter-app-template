import 'package:auth/src/domain/repositories/auth_repository.dart';
import 'package:auth/src/presentation/blocs/login/login_state.dart';
import 'package:bloc/bloc.dart';
import 'package:core/core.dart';

/// 登入頁的 cubit。
///
/// 用 Cubit 而非 Bloc 的理由(conventions §2 第 1 條):狀態只有**單一觸發
/// 來源**——使用者按下送出鍵。若日後登入頁需要同時反應 session stream 或
/// 做輸入 debounce,再升級為 Bloc;那是預期中的演進,不是設計失誤。
class LoginCubit extends Cubit<LoginState> {
  /// 以 [repository] 與 [session] 建立。
  LoginCubit({
    required AuthRepository repository,
    required SessionManager session,
  }) : _repository = repository,
       _session = session,
       super(const LoginInitial());

  final AuthRepository _repository;
  final SessionManager _session;

  /// 送出登入。
  Future<void> submit({
    required String email,
    required String password,
  }) async {
    emit(const LoginSubmitting());
    final result = await _repository.login(email: email, password: password);
    await result.fold(
      onSuccess: (tokens) async {
        await _session.signIn(tokens);
        emit(const LoginSuccess());
      },
      onFailure: (exception) async => emit(LoginFailure(exception)),
    );
  }
}
