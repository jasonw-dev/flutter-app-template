import 'package:auth/src/domain/repositories/auth_repository.dart';
import 'package:auth/src/presentation/blocs/login/login_event.dart';
import 'package:auth/src/presentation/blocs/login/login_state.dart';
import 'package:bloc/bloc.dart';
import 'package:core/core.dart';

/// 登入頁的 bloc(spec §4.2 典範實作:純 Dart,不 import Flutter)。
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  /// 以 [repository] 與 [session] 建立。
  LoginBloc({
    required AuthRepository repository,
    required SessionManager session,
  }) : _repository = repository,
       _session = session,
       super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  final AuthRepository _repository;
  final SessionManager _session;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginSubmitting());
    final result = await _repository.login(
      email: event.email,
      password: event.password,
    );
    await result.fold(
      onSuccess: (tokens) async {
        await _session.signIn(tokens);
        emit(const LoginSuccess());
      },
      onFailure: (exception) async {
        emit(LoginFailure(exception));
      },
    );
  }
}
