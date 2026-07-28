import 'package:app/src/config/app_config.dart';
import 'package:app/src/di/compose_dependencies.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetIt gi;

  setUp(() {
    gi = GetIt.asNewInstance();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => gi.reset());

  test('組裝 dev 設定後,所有核心依賴皆可解析', () async {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: 'https://test.example.com',
    );

    await composeDependencies(gi, config);
    await gi.allReady();

    expect(gi<AppConfig>(), isA<AppConfig>());
    expect(gi<AppLogger>(), isA<AppLogger>());
    expect(gi<CrashReporter>(), isA<CrashReporter>());
    expect(gi<BufferingCrashReporter>(), isA<BufferingCrashReporter>());
    expect(gi<KeyValueStore>(), isA<KeyValueStore>());
    expect(gi<SecureStore>(), isA<SecureStore>());
    expect(gi<TokenRefreshGateway>(), isA<AuthTokenRefreshGateway>());
    expect(gi<SessionManager>(), isA<SessionManager>());
    expect(gi<TokenProvider>(), isA<TokenProvider>());
    expect(gi<ApiClient>(), isA<ApiClient>());
    expect(gi<AnalyticsTracker>(), isA<AnalyticsTracker>());
    expect(gi<PushNotifications>(), isA<PushNotifications>());

    expect(gi<AuthRepository>(), isA<AuthRepository>());
    expect(gi<LoginBloc>(), isA<LoginBloc>());
    expect(gi<ItemRepository>(), isA<ItemRepository>());
    expect(gi<ItemListBloc>(), isA<ItemListBloc>());
    expect(gi<ItemDetailBloc>(), isA<ItemDetailBloc>());
    // {{feature-registry}} -- tool/new_feature.dart 於此插入 feature 驗證
  });

  test('組裝 prod 設定後,AppLogger 為 CrashReportingLogger', () async {
    const config = AppConfig(
      environment: AppEnvironment.prod,
      apiBaseUrl: 'https://test.example.com',
    );

    await composeDependencies(gi, config);
    await gi.allReady();

    expect(gi<AppLogger>(), isA<CrashReportingLogger>());
  });
}
