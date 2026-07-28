import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('核心路由的 location 對應路徑常數', () {
    expect(const LoginRoute().location, RoutePaths.login);
    expect(const HomeRoute().location, RoutePaths.home);
    expect(const LoginRoute(), isA<AppRoute>());
  });

  test('buildLocation 無 query 時回傳原路徑', () {
    expect(buildLocation('/items'), '/items');
  });

  test('buildLocation 組合並編碼 query', () {
    final location = buildLocation('/items', query: {'q': 'a b', 'page': '2'});
    expect(location, '/items?q=a+b&page=2');
  });
}
