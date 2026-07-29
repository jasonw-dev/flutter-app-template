import 'package:auth/src/domain/repositories/auth_repository.dart';
import 'package:auth/src/presentation/blocs/login/login_cubit.dart';
import 'package:auth/src/presentation/blocs/login/login_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late InMemorySecureStore store;
  late SessionManager session;

  setUp(() async {
    repository = _MockAuthRepository();
    store = InMemorySecureStore();
    session = SessionManager(
      store: store,
      gateway: FakeTokenRefreshGateway(),
      logger: FakeLogger(),
    );
    // 先 restore 到確定的未登入基準狀態，避免預設 SessionRestoring 誤判。
    await session.restore();
  });

  group('LoginCubit', () {
    blocTest<LoginCubit, LoginState>(
      '登入成功 → [LoginSubmitting, LoginSuccess] 且 session 已登入',
      setUp: () {
        when(
          () => repository.login(email: 'a@b.com', password: 'pw'),
        ).thenAnswer(
          (_) async => const Result.success(
            AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
          ),
        );
      },
      build: () => LoginCubit(repository: repository, session: session),
      act: (cubit) => cubit.submit(email: 'a@b.com', password: 'pw'),
      expect: () => const [LoginSubmitting(), LoginSuccess()],
      verify: (_) {
        expect(session.state, isA<SessionAuthenticated>());
        expect(store.values[SessionManager.accessTokenKey], 'a1');
        expect(store.values[SessionManager.refreshTokenKey], 'r1');
      },
    );

    blocTest<LoginCubit, LoginState>(
      '登入失敗 → [LoginSubmitting, LoginFailure] 且 session 仍未登入',
      setUp: () {
        when(
          () => repository.login(email: 'a@b.com', password: 'wrong'),
        ).thenAnswer(
          (_) async => const Result.failure(UnauthorizedException()),
        );
      },
      build: () => LoginCubit(repository: repository, session: session),
      act: (cubit) => cubit.submit(email: 'a@b.com', password: 'wrong'),
      expect: () => [
        const LoginSubmitting(),
        isA<LoginFailure>().having(
          (s) => s.exception,
          'exception',
          isA<UnauthorizedException>(),
        ),
      ],
      verify: (_) {
        expect(session.state, isA<SessionUnauthenticated>());
      },
    );
  });
}
