import 'package:auth/src/presentation/pages/login_page.dart';
import 'package:core/core.dart';
import 'package:go_router/go_router.dart';

/// auth feature 對外提供的路由(供 app 路由表以 `{{feature-registry}}` 插入)。
List<GoRoute> authRoutes() => [
  GoRoute(
    path: RoutePaths.login,
    // name 用於自動 screen tracking(見 app 的 AnalyticsNavigatorObserver)。
    // 命名規則:snake_case、不含動態參數、跨 feature 唯一。
    name: 'login',
    builder: (_, _) => const LoginPage(),
  ),
];
