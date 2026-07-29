import 'package:app/src/config/app_config.dart';
import 'package:app/src/demo/demo_backend_adapter.dart';
import 'package:app/src/di/disabled_services.dart';
import 'package:app/src/startup/startup_gate.dart';
import 'package:app/src/startup/startup_gate_controller.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';
import 'package:integrations/integrations.dart';
import 'package:permissions/permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 組裝全部依賴到 [gi](app 生命週期單例);註冊順序即依賴順序。
///
/// Firebase 相關一律 lazy 注册，未啟用（`config.firebaseEnabled == false`）
/// 時不會觸碰 Firebase API。
///
/// [secureStoreOverride] 僅供測試注入(取代真實 `flutter_secure_storage`
/// plugin——測試環境無平台實作,直接呼叫會丟例外);正式啟動一律傳 null,
/// 走 [SecureStorageStore]。
Future<void> composeDependencies(
  GetIt gi,
  AppConfig config, {
  SecureStore? secureStoreOverride,
}) async {
  final adapter = config.useFakeBackend
      ? DemoBackendAdapter(latency: config.demoBackendLatency)
      : null;
  gi
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<BufferingCrashReporter>(BufferingCrashReporter())
    ..registerLazySingleton<CrashReporter>(() => gi<BufferingCrashReporter>())
    ..registerLazySingleton<AppLogger>(
      () => config.environment == AppEnvironment.prod
          ? CrashReportingLogger(
              inner: ConsoleLogger(),
              reporter: gi<CrashReporter>(),
            )
          : ConsoleLogger(),
    )
    ..registerSingletonAsync<SharedPreferences>(SharedPreferences.getInstance)
    ..registerLazySingleton<KeyValueStore>(
      () => SharedPreferencesStore(gi<SharedPreferences>()),
    )
    ..registerLazySingleton<SecureStore>(
      () =>
          secureStoreOverride ??
          SecureStorageStore(const FlutterSecureStorage()),
    )
    ..registerLazySingleton<TokenRefreshGateway>(
      () => AuthTokenRefreshGateway(
        ApiClient(
          createPlainDio(
            config: NetworkingConfig(baseUrl: config.apiBaseUrl),
            adapter: adapter,
          ),
        ),
      ),
    )
    ..registerLazySingleton<SessionManager>(
      () => SessionManager(
        store: gi<SecureStore>(),
        gateway: gi<TokenRefreshGateway>(),
        logger: gi<AppLogger>(),
      ),
    )
    ..registerLazySingleton<TokenProvider>(() => gi<SessionManager>())
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        createDio(
          config: NetworkingConfig(baseUrl: config.apiBaseUrl),
          tokenProvider: gi<TokenProvider>(),
          adapter: adapter,
        ),
      ),
    )
    ..registerLazySingleton<AnalyticsTracker>(
      () => config.firebaseEnabled
          ? createFirebaseAnalyticsTracker()
          : const DisabledAnalyticsTracker(),
    )
    ..registerLazySingleton<PushNotifications>(
      () => config.firebaseEnabled
          ? createFcmPushNotifications()
          : const DisabledPushNotifications(),
    )
    // 出貨永遠放行的 gate;專案接上真實判斷依據時只換這一行,
    // 不必改 bootstrap 或 router(見 docs/how-to/add-force-update.md)。
    ..registerLazySingleton<Permissions>(PermissionHandlerPermissions.new)
    ..registerLazySingleton<StartupGate>(AlwaysAllowedStartupGate.new)
    ..registerLazySingleton<StartupGateController>(
      () => StartupGateController(gi<StartupGate>()),
    );
  registerAuthFeature(gi);
  registerHomeFeature(gi);
  // {{feature-registry}} -- tool/new_feature.dart 於此插入 feature 註冊
}
