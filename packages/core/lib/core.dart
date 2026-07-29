/// 技術基礎設施的單一入口。
///
/// 六個原本獨立的 package(foundation / networking / persistence / session /
/// observability / navigation)在 ADR-0006 收斂為此成員。心智模型:
/// **技術基礎設施放 `core`,共用 UI 元件放 `ui`,文案放 `localization`,
/// 其餘都在自己的 feature 裡。**
library;

export 'package:dio/dio.dart' show CancelToken;
export 'src/foundation/exceptions.dart';
export 'src/foundation/logger.dart';
export 'src/foundation/result.dart';
export 'src/navigation/app_route.dart';
export 'src/navigation/core_routes.dart';
export 'src/navigation/route_paths.dart';
export 'src/networking/api_client.dart';
export 'src/networking/auth_interceptor.dart';
export 'src/networking/create_dio.dart';
export 'src/networking/error_mapper.dart';
export 'src/networking/retry_interceptor.dart';
export 'src/networking/retry_policy.dart';
export 'src/networking/token_provider.dart';
export 'src/observability/analytics_tracker.dart';
export 'src/observability/buffering_crash_reporter.dart';
export 'src/observability/console_logger.dart';
export 'src/observability/crash_reporter.dart';
export 'src/observability/crash_reporting_logger.dart';
export 'src/persistence/key_value_store.dart';
export 'src/persistence/secure_storage_store.dart';
export 'src/persistence/secure_store.dart';
export 'src/persistence/shared_preferences_store.dart';
export 'src/push/push_notifications.dart';
export 'src/session/auth_tokens.dart';
export 'src/session/session_manager.dart';
export 'src/session/session_state.dart';
export 'src/session/token_refresh_gateway.dart';
export 'src/validation/validators.dart';
