import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryKeyValueStore', () {
    test('write 後可 read,remove 後為 null', () async {
      final store = InMemoryKeyValueStore();
      await store.writeString('k', 'v');
      await store.writeBool('b', value: true);
      expect(await store.readString('k'), 'v');
      expect(await store.readBool('b'), isTrue);
      await store.remove('k');
      expect(await store.readString('k'), isNull);
    });

    test('未寫入的 key 回傳 null', () async {
      final store = InMemoryKeyValueStore();
      expect(await store.readString('none'), isNull);
      expect(await store.readBool('none'), isNull);
    });

    test('可當 KeyValueStore 注入', () {
      expect(InMemoryKeyValueStore(), isA<KeyValueStore>());
    });
  });

  group('InMemorySecureStore', () {
    test('write/read/delete 循環', () async {
      final store = InMemorySecureStore();
      await store.write('token', 'abc');
      expect(await store.read('token'), 'abc');
      await store.delete('token');
      expect(await store.read('token'), isNull);
    });

    test('可當 SecureStore 注入', () {
      expect(InMemorySecureStore(), isA<SecureStore>());
    });
  });
}
