import 'dart:math';

import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 固定回同一值的 Random,讓 jitter 可預測。
class _FixedRandom implements Random {
  @override
  double nextDouble() => 1;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

void main() {
  late List<Duration> waited;

  setUp(() => waited = []);

  /// 建立掛好 RetryInterceptor 的 Dio;delay 不真的等待,只記錄。
  Dio buildDio(
    ScriptedAdapter adapter, {
    RetryPolicy policy = const RetryPolicy(),
  }) {
    final options = BaseOptions(baseUrl: 'https://api.test');
    final retryClient = Dio(options)..httpClientAdapter = adapter;
    final dio = Dio(options)..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(
        policy: policy,
        retryClient: retryClient,
        delay: (d) async => waited.add(d),
        random: _FixedRandom(),
      ),
    );
    return dio;
  }

  ResponseBody Function(RequestOptions) failWith(DioExceptionType type) =>
      (options) => throw DioException(requestOptions: options, type: type);

  test('GET 連兩次連線失敗、第三次成功 → 成功且共送出 3 次', () async {
    final adapter = ScriptedAdapter([
      failWith(DioExceptionType.connectionError),
      failWith(DioExceptionType.connectionError),
      (_) => jsonResponse(200, '{"ok":true}'),
    ]);
    final dio = buildDio(adapter);

    final response = await dio.get<dynamic>('/x');

    expect(response.statusCode, 200);
    expect(adapter.seen.length, 3);
  });

  test('GET 連三次失敗 → 失敗且只送出 3 次(maxAttempts 含第一次)', () async {
    final adapter = ScriptedAdapter([
      failWith(DioExceptionType.connectionError),
      failWith(DioExceptionType.connectionError),
      failWith(DioExceptionType.connectionError),
    ]);
    final dio = buildDio(adapter);

    await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seen.length, 3, reason: '不是 4 次');
  });

  test('POST 失敗 → 只送出 1 次(非冪等一律不重試)', () async {
    // 這條最重要:「送出訂單逾時後重試」等於重複下單。
    final adapter = ScriptedAdapter([
      failWith(DioExceptionType.connectionError),
    ]);
    final dio = buildDio(adapter);

    await expectLater(dio.post<dynamic>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seen.length, 1);
  });

  test('POST 明確 opt-in 為冪等 → 會重試', () async {
    final adapter = ScriptedAdapter([
      failWith(DioExceptionType.connectionError),
      (_) => jsonResponse(200, '{}'),
    ]);
    final dio = buildDio(adapter);

    await dio.post<dynamic>(
      '/x',
      options: Options(extra: {RetryInterceptor.idempotentKey: true}),
    );

    expect(adapter.seen.length, 2);
  });

  test('GET 回 400 → 只送出 1 次(4xx 不會自己變好)', () async {
    final adapter = ScriptedAdapter([(_) => jsonResponse(400, '{}')]);
    final dio = buildDio(adapter);

    await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seen.length, 1);
  });

  test('GET 回 500 → 有重試', () async {
    final adapter = ScriptedAdapter([
      (_) => jsonResponse(500, '{}'),
      (_) => jsonResponse(200, '{}'),
    ]);
    final dio = buildDio(adapter);

    await dio.get<dynamic>('/x');

    expect(adapter.seen.length, 2);
  });

  test('429 帶 Retry-After: 2 → 等待剛好 2 秒,不用自己算的退避', () async {
    final adapter = ScriptedAdapter([
      (_) => ResponseBody.fromString(
        '{}',
        429,
        headers: {
          'retry-after': ['2'],
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      (_) => jsonResponse(200, '{}'),
    ]);
    final dio = buildDio(adapter);

    await dio.get<dynamic>('/x');

    expect(adapter.seen.length, 2);
    expect(waited.single, const Duration(seconds: 2));
  });

  test('RetryPolicy.none → 不重試', () async {
    final adapter = ScriptedAdapter([
      failWith(DioExceptionType.connectionError),
    ]);
    final dio = buildDio(adapter, policy: RetryPolicy.none);

    await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seen.length, 1);
    expect(waited, isEmpty);
  });

  test('等待退避期間被取消 → 不再重送', () async {
    // 釘住「等完退避要再檢查一次 cancelToken」這一步:使用者已經離開頁面
    // 了,重試沒有意義。
    final adapter = ScriptedAdapter([
      failWith(DioExceptionType.connectionError),
      (_) => jsonResponse(200, '{}'),
    ]);
    final token = CancelToken();
    final options = BaseOptions(baseUrl: 'https://api.test');
    final retryClient = Dio(options)..httpClientAdapter = adapter;
    final dio = Dio(options)..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(
        policy: const RetryPolicy(),
        retryClient: retryClient,
        // 退避期間使用者離開頁面。
        delay: (d) async {
          waited.add(d);
          token.cancel();
        },
        random: _FixedRandom(),
      ),
    );

    await expectLater(
      dio.get<dynamic>('/x', cancelToken: token),
      throwsA(isA<DioException>()),
    );

    expect(adapter.seen.length, 1, reason: '第二次不得送出');
    expect(waited.length, 1);
  });

  test('DioExceptionType.cancel 不重試', () async {
    final adapter = ScriptedAdapter([failWith(DioExceptionType.cancel)]);
    final dio = buildDio(adapter);

    await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seen.length, 1);
    expect(waited, isEmpty, reason: '連退避都不該等');
  });

  test('退避是指數的且套用 jitter 上限', () async {
    final adapter = ScriptedAdapter([
      failWith(DioExceptionType.connectionError),
      failWith(DioExceptionType.connectionError),
      failWith(DioExceptionType.connectionError),
    ]);
    final dio = buildDio(adapter);

    await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));

    // jitter 固定為 1.0(見 _FixedRandom),所以等於純指數退避。
    expect(waited, [
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 600),
    ]);
  });
}
