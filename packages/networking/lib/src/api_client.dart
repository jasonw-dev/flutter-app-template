import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:networking/src/error_mapper.dart';

/// repository 的唯一 HTTP 入口:所有結果收攏為 Result(spec §4.2)。
///
/// 四個方法都接受可選的 [CancelToken];取消後的請求會轉成
/// `Failure(CancelledException)`。**取消能力止於 data 層**——domain 介面
/// (如 `ItemRepository`)不得出現 `CancelToken`,那是 dio 的型別,
/// 讓 domain 知道 HTTP 傳輸細節就破壞了分層。
class ApiClient {
  /// 以組裝好的 [Dio] 建立 client。
  ApiClient(this._dio);

  final Dio _dio;

  /// GET 請求。
  Future<Result<T>> get<T>(
    String path, {
    required T Function(dynamic data) parse,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => _send(
    (dio) => dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    ),
    parse,
  );

  /// POST 請求。
  Future<Result<T>> post<T>(
    String path, {
    required T Function(dynamic data) parse,
    Object? body,
    CancelToken? cancelToken,
  }) => _send(
    (dio) => dio.post<dynamic>(path, data: body, cancelToken: cancelToken),
    parse,
  );

  /// PUT 請求。
  Future<Result<T>> put<T>(
    String path, {
    required T Function(dynamic data) parse,
    Object? body,
    CancelToken? cancelToken,
  }) => _send(
    (dio) => dio.put<dynamic>(path, data: body, cancelToken: cancelToken),
    parse,
  );

  /// DELETE 請求。
  Future<Result<T>> delete<T>(
    String path, {
    required T Function(dynamic data) parse,
    CancelToken? cancelToken,
  }) => _send(
    (dio) => dio.delete<dynamic>(path, cancelToken: cancelToken),
    parse,
  );

  Future<Result<T>> _send<T>(
    Future<Response<dynamic>> Function(Dio dio) request,
    T Function(dynamic data) parse,
  ) async {
    try {
      final response = await request(_dio);
      try {
        return Result.success(parse(response.data));
      } on Object catch (e, st) {
        return Result.failure(ParsingException(cause: e, stackTrace: st));
      }
    } on DioException catch (e) {
      return Result.failure(mapDioException(e));
    } on Object catch (e, st) {
      return Result.failure(UnknownException(cause: e, stackTrace: st));
    }
  }
}
