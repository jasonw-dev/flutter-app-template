import 'package:core/core.dart';
import 'package:go_router/go_router.dart';
import 'package:home/src/presentation/pages/home_page.dart';
import 'package:home/src/presentation/pages/item_detail_page.dart';

/// home feature 對外提供的路由(供 app 路由表以 `{{feature-registry}}` 插入)。
List<RouteBase> homeRoutes() => [
  GoRoute(
    path: RoutePaths.home,
    // name 用於自動 screen tracking(見 app 的 AnalyticsNavigatorObserver)。
    // 命名規則:snake_case、不含動態參數、跨 feature 唯一。
    name: 'home',
    builder: (_, _) => const HomePage(),
    routes: [
      GoRoute(
        path: 'items/:id',
        name: 'item_detail',
        builder: (_, state) => ItemDetailPage(id: state.pathParameters['id']!),
      ),
    ],
  ),
];

/// 導向項目詳情頁。
///
/// feature 專屬的型別化路由住在自己的 feature 裡(ADR-0006):共用處只留
/// 路徑常數,兩個人平行開兩個功能才不會同時改到同一個共用檔。
class ItemDetailRoute {
  /// 以 [id] 建立項目詳情頁路由。
  const ItemDetailRoute(this.id);

  /// 項目識別碼。
  final String id;

  /// 完整 location。
  String get location => RoutePaths.homeItemDetail.replaceFirst(':id', id);
}
