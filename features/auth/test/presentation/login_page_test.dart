import 'package:auth/src/domain/repositories/auth_repository.dart';
import 'package:auth/src/presentation/blocs/login/login_bloc.dart';
import 'package:auth/src/presentation/pages/login_page.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:localization/localization.dart';
import 'package:localization/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ui/ui.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// 用獨立容器包住待測頁面(見 docs/conventions.md §5 DI 規範)。
Widget _app(GetIt gi) => RepositoryProvider<GetIt>.value(
  value: gi,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: LoginPage(),
  ),
);

void main() {
  late _MockAuthRepository repository;
  late SessionManager session;
  final gi = GetIt.asNewInstance();

  setUp(() {
    repository = _MockAuthRepository();
    session = SessionManager(
      store: InMemorySecureStore(),
      gateway: FakeTokenRefreshGateway(),
      logger: FakeLogger(),
    );
    gi.registerFactory<LoginBloc>(
      () => LoginBloc(repository: repository, session: session),
    );
  });

  tearDown(() async {
    await gi.reset();
  });

  testWidgets('輸入帳密點按鈕 → repository 收到正確參數', (tester) async {
    when(() => repository.login(email: 'a@b.com', password: 'pw')).thenAnswer(
      (_) async => const Result.success(
        AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
      ),
    );

    await tester.pumpWidget(_app(gi));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'a@b.com',
    );
    await tester.enterText(find.byKey(const Key('login_password_field')), 'pw');
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump();

    verify(() => repository.login(email: 'a@b.com', password: 'pw')).called(1);
  });

  testWidgets('Submitting 時按鈕顯示 loading indicator', (tester) async {
    when(() => repository.login(email: 'a@b.com', password: 'pw')).thenAnswer((
      _,
    ) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Result.success(
        AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
      );
    });

    await tester.pumpWidget(_app(gi));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'a@b.com',
    );
    await tester.enterText(find.byKey(const Key('login_password_field')), 'pw');
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('登入失敗顯示 SnackBar 文案', (tester) async {
    when(
      () => repository.login(email: 'a@b.com', password: 'wrong'),
    ).thenAnswer((_) async => const Result.failure(UnauthorizedException()));

    await tester.pumpWidget(_app(gi));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'a@b.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrong',
    );
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump();
    await tester.pump();

    expect(find.text(AppLocalizationsEn().authLoginFailed), findsOneWidget);
  });
}
