import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createDio 套用 config 並掛上 AuthInterceptor', () async {
    final adapter = ScriptedAdapter([
      (_) => jsonResponse(401, '{}'),
      (_) => jsonResponse(200, '{}'),
    ]);
    final dio = createDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
      tokenProvider: FakeTokenProvider(
        accessToken: 'old',
        refreshResult: true,
        tokenAfterRefresh: 'new',
      ),
      adapter: adapter,
    );
    expect(dio.options.baseUrl, 'https://api.test');
    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 20));

    final res = await dio.get<dynamic>('/me');
    expect(res.statusCode, 200);
    expect(adapter.seen[1].headers['Authorization'], 'Bearer new');
  });

  test('createPlainDio 不含任何攔截器且套用 config', () {
    final dio = createPlainDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
    );
    expect(dio.options.baseUrl, 'https://api.test');
    expect(dio.interceptors.whereType<AuthInterceptor>(), isEmpty);
  });

  test('extraInterceptors 掛在 auth 之後', () {
    final marker = InterceptorsWrapper();
    final dio = createDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
      tokenProvider: FakeTokenProvider(),
      extraInterceptors: [marker],
    );
    final authIndex = dio.interceptors.indexWhere((i) => i is AuthInterceptor);
    expect(dio.interceptors.indexOf(marker), greaterThan(authIndex));
  });
}
