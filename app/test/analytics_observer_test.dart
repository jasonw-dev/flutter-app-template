import 'dart:async';

import 'package:app/src/router/analytics_observer.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late FakeAnalyticsTracker tracker;
  late AnalyticsNavigatorObserver observer;

  setUp(() {
    tracker = FakeAnalyticsTracker();
    observer = AnalyticsNavigatorObserver(tracker);
  });

  GoRouter buildTestRouter() => GoRouter(
    observers: [observer],
    initialLocation: '/a',
    routes: [
      GoRoute(
        path: '/a',
        name: 'a',
        builder: (_, _) => const Scaffold(body: Text('A')),
        routes: [
          GoRoute(
            path: 'b',
            name: 'b',
            builder: (_, _) => const Scaffold(body: Text('B')),
          ),
          // 刻意不設 name:go_router 會塞路由 pattern 進 settings.name。
          GoRoute(
            path: 'items/:id',
            builder: (_, _) => const Scaffold(body: Text('Item')),
          ),
        ],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('push 時記錄該路由的 name', (tester) async {
    final router = buildTestRouter();
    addTearDown(router.dispose);
    await pump(tester, router);

    expect(tracker.screens, ['a']);

    router.go('/a/b');
    await tester.pumpAndSettle();

    expect(tracker.screens, ['a', 'b']);
  });

  testWidgets('pop 後記錄的是父路由,不是被 pop 掉的那個', (tester) async {
    final router = buildTestRouter();
    addTearDown(router.dispose);
    await pump(tester, router);
    router.go('/a/b');
    await tester.pumpAndSettle();
    tracker.screens.clear();

    router.pop();
    await tester.pumpAndSettle();

    expect(tracker.screens, ['a']);
  });

  testWidgets('settings.name 含 : 的路由不產生事件', (tester) async {
    // go_router **不是**「沒設 name 就給 null」——沒設時 settings.name 拿到的
    // 是路由 pattern(`items/:id`)。所以不能寫成「沒有 name 就不產生事件」
    // 那種測試,對 go_router 建出的頁面它必然失敗。
    final router = buildTestRouter();
    addTearDown(router.dispose);
    await pump(tester, router);
    tracker.screens.clear();

    router.go('/a/items/42');
    await tester.pumpAndSettle();

    expect(tracker.screens, isEmpty);
  });

  testWidgets('settings.name 為 null 的路由不產生事件也不丟例外', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('root')),
      ),
    );
    tracker.screens.clear();

    // 手動建的 MaterialPageRoute 沒有 settings.name。
    // **不可 await 這個 push** —— 它回傳的 Future 要等到該 route 被 pop 才
    // 完成,await 下去測試會直接掛住。
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('anon')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tracker.screens, isEmpty);
  });

  testWidgets('feature 端零手動呼叫:整趟導航的事件全部來自 observer', (tester) async {
    final router = buildTestRouter();
    addTearDown(router.dispose);
    await pump(tester, router);
    router.go('/a/b');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(tracker.screens, ['a', 'b', 'a']);
    expect(tracker.events, isEmpty, reason: 'observer 只發 screen,不發自訂事件');
  });
}
