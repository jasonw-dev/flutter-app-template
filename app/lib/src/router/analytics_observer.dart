import 'package:core/core.dart';
import 'package:flutter/widgets.dart';

/// 把路由切換自動轉成 screen 事件送給 [AnalyticsTracker]。
///
/// 掛在 go_router 的 `observers`,**所有頁面自動涵蓋**,feature 不需要在
/// 每頁的 `initState` 手動呼叫 `trackScreen`——漏一頁就少一頁數據,而且
/// 沒有任何機制會提醒你漏了。
class AnalyticsNavigatorObserver extends NavigatorObserver {
  /// 以埋點實作建立。
  AnalyticsNavigatorObserver(this._tracker);

  final AnalyticsTracker _tracker;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // pop 之後使用者看到的是 previousRoute,要記的是它。
    _track(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _track(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _track(previousRoute);
  }

  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) {
      return;
    }
    // go_router 在沒設 `name` 時會塞**路由 pattern** 進來(見 builder.dart
    // 的 `name: state.name ?? state.path`),子路由會是 `items/:id` 這種帶
    // 參數佔位符的字串。送進報表只會製造髒資料,直接濾掉。
    if (name.contains(':')) {
      return;
    }
    // ignore: discarded_futures -- 埋點為 fire-and-forget,不阻塞導航
    _tracker.trackScreen(name);
  }
}
