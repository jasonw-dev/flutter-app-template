import 'package:core/core.dart';
import 'package:home/src/domain/entities/item.dart';

/// 首頁功能的 domain 契約。
///
/// 快取 + 分頁樣板(模板參考實作):讀走 [watchItems](永遠先給本地快取,
/// 不等網路),寫走 [refreshItems](回到第一頁)與 [loadMore](往後附加)。
/// 這樣「離線可看」「多頁同步」「無限捲動」是同一個機制,不需要各 feature
/// 自己發明。四條語意見 docs/conventions.md §6.1。
abstract interface class ItemRepository {
  /// 項目清單的持續觀察。
  ///
  /// 訂閱後**立即**收到一次現值(本地快取;沒有快取時為空清單),
  /// 之後每次 [refreshItems] 成功都會再收到一次。
  Stream<List<Item>> watchItems();

  /// 重抓**第一頁**並更新快取,成功後透過 [watchItems] 廣播。
  ///
  /// 語意是「回到第一頁」:清掉已載入的後續頁面、游標重設。下拉刷新回到
  /// 第一頁是使用者的預期行為。
  ///
  /// 失敗時**保留舊快取**(斷網不該清空畫面),錯誤以 Failure 回傳給
  /// 呼叫端決定怎麼呈現。
  Future<Result<void>> refreshItems();

  /// 載入下一頁並附加到 [watchItems] 的清單尾端。
  ///
  /// 已在最後一頁時直接回 success 且不做任何事。呼叫端不需要自己判斷,
  /// 但 UI 通常會用 [hasMore] 決定要不要顯示底部的載入指示。
  Future<Result<void>> loadMore();

  /// 是否還有下一頁。
  bool get hasMore;

  /// 以 [id] 取得單一項目(不快取,詳情頁每次都打遠端)。
  Future<Result<Item>> fetchItem(String id);

  /// 釋放內部的 StreamController。由 DI 容器在 reset 時呼叫。
  void dispose();
}
