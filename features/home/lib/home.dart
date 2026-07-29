/// 首頁功能對外入口。
library;

export 'src/di.dart';
// 以下匯出供組裝層(app)註冊驗證與路由測試;features 之間仍禁止互相依賴
// (pubspec 白名單擋住)。
export 'src/domain/entities/item.dart';
export 'src/domain/repositories/item_repository.dart';
export 'src/presentation/blocs/item_detail/item_detail_cubit.dart';
export 'src/presentation/blocs/item_detail/item_detail_state.dart';
export 'src/presentation/blocs/item_list/item_list_bloc.dart';
export 'src/presentation/blocs/item_list/item_list_event.dart';
export 'src/presentation/blocs/item_list/item_list_state.dart';
export 'src/presentation/pages/home_page.dart';
export 'src/presentation/pages/item_detail_page.dart';
export 'src/routes.dart';
export 'src/routes/item_detail_route.dart';
