import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success 走 onSuccess 分支', () {
    const r = Result.success(42);
    final out = r.fold(onSuccess: (v) => 'ok:$v', onFailure: (e) => 'ng');
    expect(out, 'ok:42');
  });

  test('failure 走 onFailure 分支並保留例外型別', () {
    const r = Result<int>.failure(UnauthorizedException());
    final out = r.fold(
      onSuccess: (v) => 'ok',
      onFailure: (e) => switch (e) {
        UnauthorizedException() => 'unauthorized',
        _ => 'other',
      },
    );
    expect(out, 'unauthorized');
  });

  test('map 轉換 success 值', () {
    const r = Result.success(2);
    final mapped = r.map((v) => 'v$v');
    expect((mapped as Success<String>).value, 'v2');
  });

  test('map 對 failure 是 no-op,例外原樣傳遞', () {
    const exception = ServerException(statusCode: 500);
    const r = Result<int>.failure(exception);
    final mapped = r.map((v) => 'v$v');
    expect((mapped as Failure<String>).exception, same(exception));
  });

  test('可對 Result 做 exhaustive switch(sealed)', () {
    const r = Result.success(1);
    final label = switch (r) {
      Success<int>(:final value) => 'success:$value',
      Failure<int>() => 'failure',
    };
    expect(label, 'success:1');
  });
}
