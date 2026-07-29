import 'package:app/src/router/session_refresh_listenable.dart';
import 'package:app/src/shell/app_shell.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home/home.dart';
import 'package:localization/localization.dart';
import 'package:ui/ui.dart';

/// 建立 app 的路由表:登入守衛 + refreshListenable(spec §5.3)。
///
/// 未登入且目標非 login → 導向 login;已登入且目標為 login → 導向 home;
/// 其餘不重導向。`refreshListenable` 讓 [SessionManager.states] 的每次事件
/// 觸發 go_router 重新評估 redirect(如 token 失效自動導回登入)。
///
/// 已登入區域(目前僅 home)包在 [ShellRoute] 內套用 [AppShell];
/// login 留在 shell 外(未登入不應看到底部導覽列)。
/// [refreshListenable] 可由呼叫端注入以掌控其生命週期(見 `App`);
/// 未提供時內部建立一份供獨立使用(如既有 router 測試)。
/// [observers] 用預設空清單,既有 router 測試不傳就完全不受影響。
GoRouter buildRouter(
  SessionManager session, {
  Listenable? refreshListenable,
  List<NavigatorObserver> observers = const [],
}) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    observers: observers,
    refreshListenable:
        refreshListenable ?? SessionRefreshListenable(session.states),
    redirect: (context, state) {
      final loggedIn = session.state is SessionAuthenticated;
      final goingToLogin = state.matchedLocation == RoutePaths.login;
      if (!loggedIn && !goingToLogin) {
        return RoutePaths.login;
      }
      if (loggedIn && goingToLogin) {
        return RoutePaths.home;
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: AppErrorView(
        message: context.l10n.commonErrorGeneric,
        onRetry: () => context.go(RoutePaths.home),
        retryLabel: context.l10n.homeTitle,
      ),
    ),
    routes: [
      ...authRoutes(),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          ...homeRoutes(),
          // {{feature-registry}}
        ],
      ),
    ],
  );
}
