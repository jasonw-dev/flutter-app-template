import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:networking/networking.dart';
import 'package:networking/testing.dart';
import 'package:test/test.dart';

ApiClient _client(List<ResponseBody Function(RequestOptions)> script) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = ScriptedAdapter(script);
  return ApiClient(dio);
}

void main() {
  test('get 成功時回傳 parse 後的 Success', () async {
    final client = _client([(_) => jsonResponse(200, '{"name":"jason"}')]);
    final result = await client.get<String>(
      '/me',
      parse: (data) => (data as Map<String, dynamic>)['name'] as String,
    );
    expect(result, isA<Success<String>>());
    expect((result as Success<String>).value, 'jason');
  });

  test('HTTP 500 回傳 Failure(ServerException)', () async {
    final client = _client([(_) => jsonResponse(500, '{}')]);
    final result = await client.get<void>('/x', parse: (_) {});
    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).exception, isA<ServerException>());
  });

  test('parse 丟例外時回傳 Failure(ParsingException)', () async {
    final client = _client([(_) => jsonResponse(200, '{"a":1}')]);
    final result = await client.get<String>(
      '/x',
      parse: (data) => throw const FormatException('bad'),
    );
    expect(result, isA<Failure<String>>());
    expect((result as Failure<String>).exception, isA<ParsingException>());
  });

  test('post 送出 body 並解析回應', () async {
    late RequestOptions captured;
    final client = _client([
      (options) {
        captured = options;
        return jsonResponse(201, '{"id":7}');
      },
    ]);
    final result = await client.post<int>(
      '/items',
      body: {'name': 'n'},
      parse: (data) => (data as Map<String, dynamic>)['id'] as int,
    );
    expect((result as Success<int>).value, 7);
    expect(captured.method, 'POST');
    expect(captured.data, {'name': 'n'});
  });

  test('put 與 delete 走同一條錯誤路徑', () async {
    final client = _client([(_) => jsonResponse(404, '{"code":"NF"}')]);
    final putResult = await client.put<void>('/x', parse: (_) {});
    expect((putResult as Failure<void>).exception, isA<ApiException>());
    final deleteResult = await client.delete<void>('/x', parse: (_) {});
    expect((deleteResult as Failure<void>).exception, isA<ApiException>());
  });

  test('已取消的 CancelToken → Failure(CancelledException)', () {
    // 用已取消的 token 呼叫,dio 會在送出前就丟 DioExceptionType.cancel。
    final client = _client([(_) => jsonResponse(200, '{"name":"jason"}')]);
    final token = CancelToken()..cancel();

    return client
        .get<String>(
          '/whoami',
          parse: (data) => (data as Map<String, dynamic>)['name'] as String,
          cancelToken: token,
        )
        .then((result) {
          expect(result, isA<Failure<String>>());
          expect(
            (result as Failure<String>).exception,
            isA<CancelledException>(),
          );
        });
  });

  test('cancelToken 亦傳達至 post/put/delete', () async {
    final client = _client([
      (_) => jsonResponse(200, '{}'),
      (_) => jsonResponse(200, '{}'),
      (_) => jsonResponse(200, '{}'),
    ]);
    final token = CancelToken()..cancel();

    for (final call in <Future<Result<void>> Function()>[
      () => client.post<void>('/x', parse: (_) {}, cancelToken: token),
      () => client.put<void>('/x', parse: (_) {}, cancelToken: token),
      () => client.delete<void>('/x', parse: (_) {}, cancelToken: token),
    ]) {
      final result = await call();
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).exception, isA<CancelledException>());
    }
  });
}
