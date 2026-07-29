import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dioError({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
  Object? body,
}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response<Object?>(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
  );
}

void main() {
  test('timeout 與 connectionError 轉 ConnectivityException', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.badCertificate,
      DioExceptionType.transformTimeout,
    ]) {
      expect(
        mapDioException(_dioError(type: type)),
        isA<ConnectivityException>(),
        reason: '$type',
      );
    }
  });

  test('401 轉 UnauthorizedException', () {
    expect(
      mapDioException(_dioError(statusCode: 401)),
      isA<UnauthorizedException>(),
    );
  });

  test('5xx 轉 ServerException 並攜帶 statusCode', () {
    final e = mapDioException(_dioError(statusCode: 503));
    expect(e, isA<ServerException>());
    expect((e as ServerException).statusCode, 503);
  });

  test('4xx 轉 ApiException,code/message 取自 body', () {
    final e = mapDioException(
      _dioError(statusCode: 422, body: {'code': 'E42', 'message': 'invalid'}),
    );
    expect(e, isA<ApiException>());
    e as ApiException;
    expect(e.code, 'E42');
    expect(e.message, 'invalid');
  });

  test('4xx body 非 envelope 時 code 用 statusCode 字串', () {
    final e = mapDioException(_dioError(statusCode: 404, body: 'nope'));
    e as ApiException;
    expect(e.code, '404');
    expect(e.message, '');
  });

  test('cancel 轉 CancelledException 並保留 cause', () {
    final source = _dioError(type: DioExceptionType.cancel);
    final e = mapDioException(source);
    expect(e, isA<CancelledException>());
    expect((e as CancelledException).cause, same(source));
  });
}
