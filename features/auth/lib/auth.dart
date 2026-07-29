/// 登入功能對外入口。
library;

export 'src/data/auth_token_refresh_gateway.dart';
export 'src/di.dart';
// 以下匯出供組裝層(app)註冊驗證與路由測試;features 之間仍禁止互相依賴
// (pubspec 白名單擋住)。
export 'src/domain/repositories/auth_repository.dart';
export 'src/presentation/blocs/login/login_cubit.dart';
export 'src/presentation/blocs/login/login_state.dart';
export 'src/presentation/pages/login_page.dart';
export 'src/routes.dart';
