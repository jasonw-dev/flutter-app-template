import 'package:core/core.dart';
import 'package:home/src/domain/entities/item.dart';

/// 項目詳情頁的狀態(sealed;UI 端須 exhaustive switch 渲染)。
sealed class ItemDetailState {
  /// 基底建構子,僅供子類 super 呼叫。
  const ItemDetailState();
}

/// 載入中(初始狀態)。
final class ItemDetailLoading extends ItemDetailState {
  /// 建立載入中狀態。
  const ItemDetailLoading();
}

/// 載入成功,攜帶項目。
final class ItemDetailLoaded extends ItemDetailState {
  /// 以項目建立成功狀態。
  const ItemDetailLoaded(this.item);

  /// 項目。
  final Item item;
}

/// 載入失敗,攜帶失敗原因。
final class ItemDetailError extends ItemDetailState {
  /// 以例外建立失敗狀態。
  const ItemDetailError(this.exception);

  /// 失敗原因。
  final AppException exception;
}
