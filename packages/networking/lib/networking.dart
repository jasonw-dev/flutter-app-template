/// dio 封裝:client 工廠、攔截器、統一錯誤轉換、TokenProvider 契約。
library;

// 呼叫端要能建立 CancelToken,但不該為此直接依賴 dio。
export 'package:dio/dio.dart' show CancelToken;

export 'src/api_client.dart';
export 'src/auth_interceptor.dart';
export 'src/create_dio.dart';
export 'src/error_mapper.dart';
export 'src/token_provider.dart';
