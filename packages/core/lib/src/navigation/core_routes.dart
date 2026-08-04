import 'package:core/src/navigation/route_paths.dart';

/// 導向登入頁。
class LoginRoute {
  /// 建立登入頁路由。
  const LoginRoute();

  /// 完整 location。
  String get location => RoutePaths.login;
}

/// 導向首頁。
class HomeRoute {
  /// 建立首頁路由。
  const HomeRoute();

  /// 完整 location。
  String get location => RoutePaths.home;
}
