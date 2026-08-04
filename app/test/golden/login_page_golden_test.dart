import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '_golden_harness.dart';

void main() {
  testWidgets(
    'LoginPage 初始狀態',
    (tester) async {
      final gi = GetIt.asNewInstance();
      addTearDown(gi.reset);
      final session = SessionManager(
        store: InMemorySecureStore(),
        gateway: FakeTokenRefreshGateway(),
        logger: FakeLogger(),
      );
      await session.restore();
      gi
        ..registerSingleton<SessionManager>(session)
        ..registerSingleton<ApiClient>(
          ApiClient(
            createPlainDio(
              config: const NetworkingConfig(baseUrl: 'https://api.test'),
              adapter: ScriptedAdapter([]),
            ),
          ),
        );
      registerAuthFeature(gi);

      await pumpGolden(
        tester,
        RepositoryProvider<GetIt>.value(value: gi, child: const LoginPage()),
      );

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_page.png'),
      );
    },
    skip: skipOffLinux,
  );
}
