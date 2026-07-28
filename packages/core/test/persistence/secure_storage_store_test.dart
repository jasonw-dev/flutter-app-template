import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage inner;
  late SecureStorageStore store;

  setUp(() {
    inner = _MockSecureStorage();
    store = SecureStorageStore(inner);
  });

  test('read/write/delete 轉呼叫底層', () async {
    when(() => inner.read(key: 'k')).thenAnswer((_) async => 'v');
    when(() => inner.write(key: 'k', value: 'v')).thenAnswer((_) async {});
    when(() => inner.delete(key: 'k')).thenAnswer((_) async {});

    expect(await store.read('k'), 'v');
    await store.write('k', 'v');
    await store.delete('k');

    verify(() => inner.write(key: 'k', value: 'v')).called(1);
    verify(() => inner.delete(key: 'k')).called(1);
  });

  test('底層丟例外時包成 StorageException', () async {
    when(() => inner.read(key: 'k')).thenThrow(Exception('boom'));
    await expectLater(store.read('k'), throwsA(isA<StorageException>()));
  });
}
