import 'package:app/src/router/push_route_guard.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('出廠白名單(exact: [/home],subtrees: 空)', () {
    test('/home → 放行', () {
      expect(resolvePushRoute(RoutePaths.home), RoutePaths.home);
    });

    test('/home/items/1 → 拒絕(子路徑不自動放行)', () {
      // 這條是本 issue 的核心:前綴比對會讓白名單對它自己舉的威脅例子失效
      // ——現有全部已登入頁都掛在 /home 底下。
      expect(resolvePushRoute('/home/items/1'), isNull);
    });

    test('/login → 拒絕(不在白名單)', () {
      expect(resolvePushRoute(RoutePaths.login), isNull);
    });

    test('完整 URL → 拒絕(不以 / 開頭)', () {
      expect(resolvePushRoute('https://evil.example.com/home'), isNull);
    });

    test('/home?debug=true → 放行但 query 被丟棄', () {
      final resolved = resolvePushRoute('/home?debug=true');
      expect(resolved, RoutePaths.home);
      expect(resolved, isNot(contains('?')));
      expect(resolved, isNot(contains('debug')));
    });

    test('空字串與 // → 拒絕,不丟例外', () {
      expect(resolvePushRoute(''), isNull);
      expect(resolvePushRoute('//'), isNull);
    });

    test('/home/../login → 拒絕(正規化後是 /login,不在白名單)', () {
      expect(resolvePushRoute('/home/../login'), isNull);
    });
  });

  group('子樹設定', () {
    test('/home/items 列入 subtrees → /home/items/1 放行', () {
      expect(
        resolvePushRoute('/home/items/1', subtrees: const ['/home/items']),
        '/home/items/1',
      );
    });

    test('/home 列入 subtrees → /homework 仍被拒絕', () {
      // 驗證比對用的是 startsWith('$allowed/') 而不是 startsWith(allowed)：
      // 子樹比對必須是完整 segment。
      expect(
        resolvePushRoute(
          '/homework',
          exact: const [],
          subtrees: const ['/home'],
        ),
        isNull,
      );
      expect(
        resolvePushRoute('/home/x', exact: const [], subtrees: const ['/home']),
        '/home/x',
      );
    });
  });
}
