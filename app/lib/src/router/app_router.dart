import 'package:app/src/router/external_route_guard.dart';
import 'package:app/src/router/session_refresh_listenable.dart';
import 'package:app/src/shell/app_shell.dart';
import 'package:app/src/startup/startup_blocked_page.dart';
import 'package:app/src/startup/startup_gate.dart';
import 'package:app/src/startup/startup_gate_controller.dart';
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
/// [initialLocation] 對應冷啟動的初始路由;真實 App 由平台傳入(deep link),
/// 測試用它模擬外部進入。
/// [onExternalRouteRejected] 在冷啟動的初始路由(可能來自 deep link)未通過
/// [ExternalAllowedRoutes] 白名單時被呼叫,呼叫端負責記 log。
/// [gateController] 同理用 nullable 而非 required——用 required 會直接打爆
/// 既有 router 測試的全部呼叫;為 null 時跳過 gate 判斷,走原本的登入守衛。
GoRouter buildRouter(
  SessionManager session, {
  Listenable? refreshListenable,
  List<NavigatorObserver> observers = const [],
  StartupGateController? gateController,
  void Function(String rejected)? onExternalRouteRejected,
  String initialLocation = RoutePaths.home,
}) {
  final sessionListenable =
      refreshListenable ?? SessionRefreshListenable(session.states);
  // **只校驗第一次導航。** 冷啟動的初始路由可能來自 deep link;之後的導航
  // 幾乎都是 App 內部的 context.go()。
  //
  // 刻意不用啟發式去猜「這次導航是不是外部來的」——猜錯會誤擋內部導航,
  // 那是比漏擋更難查的 bug。取捨與已知缺口見
  // docs/how-to/configure-deep-links.md。
  var externalEntryChecked = false;
  return GoRouter(
    initialLocation: initialLocation,
    observers: observers,
    // 兩個來源都要能觸發重新評估:session 狀態與啟動 gate。
    refreshListenable: gateController == null
        ? sessionListenable
        : Listenable.merge([sessionListenable, gateController]),
    redirect: (context, state) {
      if (!externalEntryChecked) {
        externalEntryChecked = true;
        final incoming = state.uri.toString();
        if (incoming != '/' && resolveExternalRoute(incoming) == null) {
          onExternalRouteRejected?.call(incoming);
          return RoutePaths.home;
        }
      }

      // **最高優先層**:強制更新／維護模式擋在登入判斷之前,未登入使用者
      // 也要被擋。順序反過來的話,維護模式對未登入的人無效。
      final gate = gateController?.state;
      final onGatePage = state.matchedLocation == RoutePaths.startupBlocked;
      if (gate != null && gate is! StartupAllowed) {
        return onGatePage ? null : RoutePaths.startupBlocked;
      }
      if (onGatePage) {
        return RoutePaths.home;
      }

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
      // 放在 ShellRoute **之外**,跟 login 同層——被擋住的使用者不該看到
      // 底部導覽列。
      if (gateController != null)
        GoRoute(
          path: RoutePaths.startupBlocked,
          name: 'startup_blocked',
          builder: (_, _) => StartupBlockedPage(controller: gateController),
        ),
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
