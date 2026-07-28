import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/src/routes/item_detail_route.dart';

void main() {
  test('ItemDetailRoute 的 location 帶入 id', () {
    expect(const ItemDetailRoute('42').location, '/home/items/42');
    expect(const ItemDetailRoute('42'), isA<AppRoute>());
  });
}
