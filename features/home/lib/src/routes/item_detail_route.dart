import 'package:core/core.dart';

/// 導向項目詳情頁。
///
/// feature 專屬的型別化路由住在自己的 feature 裡(ADR-0006 / #21):
/// 共用處只留路徑常數與 [AppRoute] 契約,兩個人平行開兩個功能才不會
/// 同時改到同一個共用檔。
class ItemDetailRoute implements AppRoute {
  /// 以 [id] 建立項目詳情頁路由。
  const ItemDetailRoute(this.id);

  /// 項目識別碼。
  final String id;

  @override
  String get location => RoutePaths.homeItemDetail.replaceFirst(':id', id);
}
