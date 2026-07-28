import 'package:core/src/foundation/exceptions.dart';
import 'package:dio/dio.dart';

/// 把 [DioException] 收攏為 [AppException](spec §2.4 轉換表)。
///
/// 這是 networking 對外的唯一錯誤形狀;repository 與 bloc
/// 永遠不會看到 DioException。
///
/// dio 5.10 新增的 transformTimeout 視為 timeout 家族,歸
/// ConnectivityException(controller 裁定,spec §2.4 轉換表未列)。
///
/// badCertificate 歸 ConnectivityException(controller 裁定:對呼叫端
/// 等同網路層不可用;spec §2.4 未列)。
AppException mapDioException(DioException exception) {
  final stackTrace = exception.stackTrace;
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
    case DioExceptionType.transformTimeout:
      return ConnectivityException(cause: exception, stackTrace: stackTrace);
    case DioExceptionType.badResponse:
      return _mapBadResponse(exception, stackTrace);
    case DioExceptionType.cancel:
      // 取消不是失敗:拆成獨立型別,消費端才能跟真正的未知錯誤區分。
      return CancelledException(cause: exception, stackTrace: stackTrace);
    case DioExceptionType.unknown:
      return UnknownException(cause: exception, stackTrace: stackTrace);
  }
}

AppException _mapBadResponse(DioException exception, StackTrace stackTrace) {
  final statusCode = exception.response?.statusCode ?? 0;
  if (statusCode == 401) {
    return UnauthorizedException(cause: exception, stackTrace: stackTrace);
  }
  if (statusCode >= 500) {
    return ServerException(
      statusCode: statusCode,
      cause: exception,
      stackTrace: stackTrace,
    );
  }
  final body = exception.response?.data;
  final envelope = body is Map<dynamic, dynamic>
      ? body
      : const <dynamic, dynamic>{};
  final code = envelope['code'] is String
      ? envelope['code'] as String
      : '$statusCode';
  final message = envelope['message'] is String
      ? envelope['message'] as String
      : '';
  return ApiException(
    code: code,
    message: message,
    cause: exception,
    stackTrace: stackTrace,
  );
}
