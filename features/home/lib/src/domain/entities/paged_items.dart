import 'package:home/src/domain/entities/item.dart';

/// 一頁項目與下一頁游標。
class PagedItems {
  /// 以本頁項目與下一頁游標建立。
  const PagedItems({required this.items, required this.nextCursor});

  /// 本頁項目。
  final List<Item> items;

  /// 下一頁的游標;null 代表已是最後一頁。
  final String? nextCursor;
}
