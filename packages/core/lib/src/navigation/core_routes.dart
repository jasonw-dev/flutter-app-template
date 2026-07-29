import 'package:core/src/navigation/app_route.dart';
import 'package:core/src/navigation/route_paths.dart';

/// 導向登入頁。
class LoginRoute implements AppRoute {
  /// 建立登入頁路由。
  const LoginRoute();

  @override
  String get location => RoutePaths.login;
}

/// 導向首頁。
class HomeRoute implements AppRoute {
  /// 建立首頁路由。
  const HomeRoute();

  @override
  String get location => RoutePaths.home;
}
