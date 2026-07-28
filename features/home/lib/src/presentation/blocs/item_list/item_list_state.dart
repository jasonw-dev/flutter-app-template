import 'package:core/core.dart';
import 'package:home/src/domain/entities/item.dart';

/// 項目清單頁的狀態(sealed;UI 端須 exhaustive switch 渲染)。
sealed class ItemListState {
  /// 基底建構子,僅供子類 super 呼叫。
  const ItemListState();
}

/// 尚未收到任何資料(含快取)的初始狀態。
final class ItemListInitial extends ItemListState {
  /// 建立初始狀態。
  const ItemListInitial();
}

/// 已有資料可顯示(可能來自快取)。
///
/// [refreshing] 為 true 時代表背景正在重抓;[lastError] 非 null 代表
/// 最近一次重抓失敗,但 [items] 仍是可用的舊資料——UI 應該同時顯示
/// 清單與一個不遮蔽內容的錯誤提示(如 SnackBar),不要整頁換成錯誤畫面。
final class ItemListReady extends ItemListState {
  /// 建立已有資料的狀態。
  const ItemListReady({
    required this.items,
    this.refreshing = false,
    this.lastError,
  });

  /// 目前可顯示的項目清單(可能為空)。
  final List<Item> items;

  /// 是否正在背景重抓。
  final bool refreshing;

  /// 最近一次重抓的失敗原因;成功後回到 null。
  final AppException? lastError;
}
