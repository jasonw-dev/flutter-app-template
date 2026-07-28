import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('write 後可 read,remove 後為 null', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesStore(await SharedPreferences.getInstance());
    await store.writeString('k', 'v');
    await store.writeBool('b', value: true);
    expect(await store.readString('k'), 'v');
    expect(await store.readBool('b'), isTrue);
    await store.remove('k');
    expect(await store.readString('k'), isNull);
  });

  test('讀取既有初始值', () async {
    SharedPreferences.setMockInitialValues({'seed': 's1'});
    final store = SharedPreferencesStore(await SharedPreferences.getInstance());
    expect(await store.readString('seed'), 's1');
  });
}
