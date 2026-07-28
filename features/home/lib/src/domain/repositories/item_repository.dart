import 'package:foundation/foundation.dart';
import 'package:home/src/domain/entities/item.dart';

/// 首頁功能的 domain 契約。
///
/// 快取樣板(模板參考實作):讀走 [watchItems](永遠先給本地快取,
/// 不等網路),寫走 [refreshItems](打遠端、成功才更新快取並廣播)。
/// 這樣「離線可看」與「多頁同步」是同一個機制,不需要各 feature 自己發明。
abstract interface class ItemRepository {
  /// 項目清單的持續觀察。
  ///
  /// 訂閱後**立即**收到一次現值(本地快取;沒有快取時為空清單),
  /// 之後每次 [refreshItems] 成功都會再收到一次。
  Stream<List<Item>> watchItems();

  /// 從遠端重抓並更新快取,成功後透過 [watchItems] 廣播。
  ///
  /// 失敗時**保留舊快取**(斷網不該清空畫面),錯誤以 Failure 回傳給
  /// 呼叫端決定怎麼呈現。
  Future<Result<void>> refreshItems();

  /// 以 [id] 取得單一項目(不快取,詳情頁每次都打遠端)。
  Future<Result<Item>> fetchItem(String id);

  /// 釋放內部的 StreamController。由 DI 容器在 reset 時呼叫。
  void dispose();
}
