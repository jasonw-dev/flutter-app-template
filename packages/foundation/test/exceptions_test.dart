import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

/// sealed class 的核心價值:exhaustive switch。
/// 這個函式若少列任何子類,是編譯錯誤——測試本身就是護欄的驗證。
String describe(AppException e) => switch (e) {
  ConnectivityException() => 'connectivity',
  ServerException(:final statusCode) => 'server:$statusCode',
  UnauthorizedException() => 'unauthorized',
  ApiException(:final code, :final message) => 'api:$code:$message',
  ParsingException() => 'parsing',
  StorageException() => 'storage',
  NativeException(:final code) => 'native:$code',
  CancelledException() => 'cancelled',
  UnknownException() => 'unknown',
};

void main() {
  test('exhaustive switch 覆蓋所有子類', () {
    expect(describe(const ConnectivityException()), 'connectivity');
    expect(describe(const ServerException(statusCode: 503)), 'server:503');
    expect(describe(const UnauthorizedException()), 'unauthorized');
    expect(
      describe(const ApiException(code: 'E001', message: 'bad request')),
      'api:E001:bad request',
    );
    expect(describe(const ParsingException()), 'parsing');
    expect(describe(const StorageException()), 'storage');
    expect(
      describe(const NativeException(code: 'CAMERA_DENIED')),
      'native:CAMERA_DENIED',
    );
    expect(describe(const CancelledException()), 'cancelled');
    expect(describe(const UnknownException(cause: 'boom')), 'unknown');
  });

  test('cause 與 stackTrace 可攜帶原始錯誤', () {
    const cause = FormatException('bad json');
    final st = StackTrace.current;
    final e = ParsingException(cause: cause, stackTrace: st);
    expect(e.cause, same(cause));
    expect(e.stackTrace, same(st));
  });

  test('toString 包含類別名稱、欄位與 cause', () {
    expect(
      const ServerException(statusCode: 503, cause: 'network down').toString(),
      'ServerException(statusCode: 503, cause: network down)',
    );
    expect(
      const ApiException(code: 'E001', message: 'bad request').toString(),
      'ApiException(code: E001, message: bad request)',
    );
    expect(const ConnectivityException().toString(), 'ConnectivityException()');
  });
}
