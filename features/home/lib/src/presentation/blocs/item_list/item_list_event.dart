/// 項目清單頁的事件(sealed;命名採「主詞+過去式」)。
sealed class ItemListEvent {
  /// 基底建構子,僅供子類 super 呼叫。
  const ItemListEvent();
}

/// 請求載入項目清單(進入頁面時送出一次)。
final class ItemListRequested extends ItemListEvent {
  /// 建立請求事件。
  const ItemListRequested();
}

/// 請求重新抓取(下拉刷新)。
final class ItemListRefreshRequested extends ItemListEvent {
  /// 建立刷新事件。
  const ItemListRefreshRequested();
}
