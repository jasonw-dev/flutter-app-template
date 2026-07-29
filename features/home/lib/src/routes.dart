import 'package:core/core.dart';
import 'package:go_router/go_router.dart';
import 'package:home/src/presentation/pages/home_page.dart';
import 'package:home/src/presentation/pages/item_detail_page.dart';

/// home feature 對外提供的路由(供 app 路由表以 `{{feature-registry}}` 插入)。
List<RouteBase> homeRoutes() => [
  GoRoute(
    path: RoutePaths.home,
    builder: (_, _) => const HomePage(),
    routes: [
      GoRoute(
        path: 'items/:id',
        builder: (_, state) => ItemDetailPage(id: state.pathParameters['id']!),
      ),
    ],
  ),
];
