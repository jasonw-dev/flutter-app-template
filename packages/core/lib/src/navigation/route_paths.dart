/// 全 app 的路由路徑常數(單一真相;app 的路由表與 features 都取用這裡)。
abstract final class RoutePaths {
  /// 登入頁。
  static const login = '/login';

  /// 首頁。
  static const home = '/home';

  /// 首頁項目詳情。
  static const homeItemDetail = '/home/items/:id';

  /// 啟動 gate 擋下時顯示的頁(強制更新 / 維護中)。
  static const startupBlocked = '/startup-blocked';

  // {{route-paths}} -- tool/new_feature.dart 於此插入新 feature 的路徑常數
}

/// 允許由**外部**直接導向的路由(推播點擊與 deep link 共用同一份)。
///
/// 只有列在這裡的路由能被推播 payload 的 `routePath` 或 deep link 的 URL 導向。
/// 新增頁面時**預設不加**——需要從推播進入才加,並在 PR 說明用途。
/// 敏感操作頁(刪除、付款、確認類)一律不得列入。
///
/// 校驗邏輯見 `app/lib/src/router/external_route_guard.dart`。
abstract final class ExternalAllowedRoutes {
  /// 精確比對:只有完全相同的路徑放行。
  static const exact = <String>[RoutePaths.home];

  /// 子樹放行:該路徑本身與其所有子路徑都放行。
  ///
  /// **加進這裡等於放行整個子樹**,新增前先確認子樹底下不會出現敏感操作頁。
  /// 目前刻意留空。
  static const subtrees = <String>[];
}
