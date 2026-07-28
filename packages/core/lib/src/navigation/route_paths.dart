/// 全 app 的路由路徑常數(單一真相;app 的路由表與 features 都取用這裡)。
abstract final class RoutePaths {
  /// 登入頁。
  static const login = '/login';

  /// 首頁。
  static const home = '/home';

  /// 首頁項目詳情。
  static const homeItemDetail = '/home/items/:id';

  // {{route-paths}} -- tool/new_feature.dart 於此插入新 feature 的路徑常數
}
