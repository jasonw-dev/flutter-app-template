import 'package:auth/src/domain/repositories/auth_repository.dart';
import 'package:auth/src/presentation/blocs/login/login_cubit.dart';
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
    gi.registerFactory<LoginCubit>(
      () => LoginCubit(repository: repository, session: session),
    );
  });

  tearDown(() async {
    await gi.reset();
  });

  testWidgets('輸入帳密點按鈕 → repository 收到正確參數', (tester) async {
    when(
      () => repository.login(email: 'a@b.com', password: 'pw'),
    ).thenAnswer(
      (_) async => const Result.success(
        AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
      ),
    );

    await tester.pumpWidget(_app(gi));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'a@b.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'pw',
    );
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump();

    verify(
      () => repository.login(email: 'a@b.com', password: 'pw'),
    ).called(1);
  });

  testWidgets('Submitting 時按鈕顯示 loading indicator', (tester) async {
    when(
      () => repository.login(email: 'a@b.com', password: 'pw'),
    ).thenAnswer((
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
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'pw',
    );
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

  testWidgets('空白送出 → 不呼叫 submit,顯示必填錯誤', (tester) async {
    await tester.pumpWidget(_app(gi));
    await tester.tap(find.text(AppLocalizationsEn().authLoginButton));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().validationRequired), findsWidgets);
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('email 填 abc 送出 → 不呼叫 submit,顯示格式錯誤', (tester) async {
    await tester.pumpWidget(_app(gi));
    await tester.enterText(find.byKey(const Key('login_email_field')), 'abc');
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'pw',
    );
    await tester.tap(find.text(AppLocalizationsEn().authLoginButton));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().validationEmail), findsOneWidget);
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('登入表單不檢查密碼長度——短密碼仍會送出', (tester) async {
    // 釘住一個刻意的決定:長度規則屬於註冊/改密碼流程。既有使用者可能持有
    // 較短的舊密碼,在登入頁擋下來是誤導,而且會擋掉後端該回「帳密錯誤」的
    // 正常失敗路徑(假後端正是用 5 個字元的 `wrong` 觸發失敗)。
    when(
      () => repository.login(email: 'a@b.com', password: 'abc'),
    ).thenAnswer((_) async => const Result.failure(UnauthorizedException()));

    await tester.pumpWidget(_app(gi));
    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'a@b.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'abc',
    );
    await tester.tap(find.text(AppLocalizationsEn().authLoginButton));
    await tester.pumpAndSettle();

    verify(() => repository.login(email: 'a@b.com', password: 'abc')).called(1);
  });
}
