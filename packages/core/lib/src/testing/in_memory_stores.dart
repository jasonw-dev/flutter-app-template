import 'package:core/src/persistence/key_value_store.dart';
import 'package:core/src/persistence/secure_store.dart';

/// [KeyValueStore] 的官方 fake(spec §3 規則 1)。
class InMemoryKeyValueStore implements KeyValueStore {
  /// 目前儲存的內容,供測試直接斷言。
  final Map<String, Object> values = {};

  @override
  Future<String?> readString(String key) async => values[key] as String?;

  @override
  Future<void> writeString(String key, String value) async =>
      values[key] = value;

  @override
  Future<bool?> readBool(String key) async => values[key] as bool?;

  @override
  Future<void> writeBool(String key, {required bool value}) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// [SecureStore] 的官方 fake(spec §3 規則 1)。
class InMemorySecureStore implements SecureStore {
  /// 目前儲存的內容,供測試直接斷言。
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
