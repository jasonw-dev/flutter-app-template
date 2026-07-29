import 'package:auth/src/data/repositories/auth_repository_impl.dart';
import 'package:auth/src/domain/repositories/auth_repository.dart';
import 'package:auth/src/presentation/blocs/login/login_cubit.dart';
import 'package:core/core.dart';
import 'package:get_it/get_it.dart';

/// 註冊 auth feature 的依賴(供 app 以 `{{feature-registry}}` 插入)。
///
/// `AuthTokenRefreshGateway` 由 app 層以「無 AuthInterceptor 的 plain
/// client」組裝並註冊為 `TokenRefreshGateway`,不在此處註冊。
void registerAuthFeature(GetIt gi) {
  gi
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(gi<ApiClient>()),
    )
    ..registerFactory<LoginCubit>(
      () => LoginCubit(
        repository: gi<AuthRepository>(),
        session: gi<SessionManager>(),
      ),
    );
}
