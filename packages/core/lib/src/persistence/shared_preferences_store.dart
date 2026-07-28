import 'package:core/src/foundation/exceptions.dart';
import 'package:core/src/persistence/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [KeyValueStore] 的 SharedPreferences 實作。
class SharedPreferencesStore implements KeyValueStore {
  /// 以既有的 [SharedPreferences] 實例建立(由 app 組裝層提供)。
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> readString(String key) =>
      _guard(() async => _prefs.getString(key));

  @override
  Future<void> writeString(String key, String value) =>
      _guard(() => _prefs.setString(key, value));

  @override
  Future<bool?> readBool(String key) => _guard(() async => _prefs.getBool(key));

  @override
  Future<void> writeBool(String key, {required bool value}) =>
      _guard(() => _prefs.setBool(key, value));

  @override
  Future<void> remove(String key) => _guard(() => _prefs.remove(key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e, st) {
      throw StorageException(cause: e, stackTrace: st);
    }
  }
}
