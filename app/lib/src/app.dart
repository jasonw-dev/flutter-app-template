import 'dart:async';

import 'package:app/src/router/analytics_observer.dart';
import 'package:app/src/router/app_router.dart';
import 'package:app/src/router/external_route_guard.dart';
import 'package:app/src/router/session_refresh_listenable.dart';
import 'package:app/src/startup/startup_gate_controller.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:localization/localization.dart';
import 'package:ui/ui.dart';

/// App 根 widget:組裝 router、主題、多語系,並處理推播點擊轉路由(architecture.md §3)。
///
/// 推播轉路由只在此處理一次:
/// - [PushNotifications.taps] 的每個事件,`routePath` 非 null 時導向該路由。
/// - 首幀後檢查 [PushNotifications.initialTap]（冷啟動點擊），同樣導向。
/// - 兩者最終都經過 [buildRouter] 的登入守衛評估,未登入會被導回 login。
class App extends StatefulWidget {
  /// 建立 app;[gi] 為已完成組裝的 DI 容器。
  const App({required this.gi, super.key});

  /// DI 容器。
  final GetIt gi;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final SessionRefreshListenable _refreshListenable;
  late final StreamSubscription<PushTapEvent> _tapSubscription;

  @override
  void initState() {
    super.initState();
    final session = widget.gi<SessionManager>();
    _refreshListenable = SessionRefreshListenable(session.states);
    _router = buildRouter(
      session,
      refreshListenable: _refreshListenable,
      observers: [
        AnalyticsNavigatorObserver(widget.gi<AnalyticsTracker>()),
      ],
      gateController: widget.gi<StartupGateController>(),
      onExternalRouteRejected: (rejected) =>
          widget.gi<AppLogger>().warning('deep link rejected: $rejected'),
    );
    // gate 只在 bootstrap 評估一次是不夠的:維護模式若在使用者 session
    // 中途啟動就擋不到。這屬於機制而不是判斷依據,不該推給專案。
    WidgetsBinding.instance.addObserver(this);

    final push = widget.gi<PushNotifications>();
    _tapSubscription = push.taps.listen((event) {
      final raw = event.routePath;
      if (raw == null) {
        return;
      }
      _goIfAllowed(raw);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialTap = await push.initialTap();
      // await 期間 State 可能已被 dispose(_router 已銷毀),必須先檢查。
      if (!mounted) {
        return;
      }
      final raw = initialTap?.routePath;
      if (raw == null) {
        return;
      }
      _goIfAllowed(raw);
    });
  }

  /// 校驗推播帶來的路徑再導向;被拒絕時記 log。
  ///
  /// **被拒一定要 log**:沒有 log 的話「後端打錯字」這個最常見的情境
  /// 依然查不出來——使用者只會看到錯誤頁,客服回報時無從追查。
  void _goIfAllowed(String raw) {
    final resolved = resolveExternalRoute(raw);
    if (resolved == null) {
      widget.gi<AppLogger>().warning('push route rejected: $raw');
      return;
    }
    _router.go(resolved);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.gi<StartupGateController>().evaluate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tapSubscription.cancel());
    _router.dispose();
    _refreshListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepositoryProvider 包在 MaterialApp.router **外層**:go_router 建出的
    // 頁面是 MaterialApp 內部 Navigator 的子樹,包在外層才能讓所有頁面
    // (含 errorBuilder 的錯誤頁)都讀得到容器。
    return RepositoryProvider<GetIt>.value(
      value: widget.gi,
      child: MaterialApp.router(
        routerConfig: _router,
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
