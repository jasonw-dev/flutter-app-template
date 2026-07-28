import 'package:core/src/foundation/exceptions.dart';
import 'package:core/src/persistence/secure_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecureStore] 的 flutter_secure_storage 實作。
class SecureStorageStore implements SecureStore {
  /// 以既有的 [FlutterSecureStorage] 實例建立(由 app 組裝層提供)。
  SecureStorageStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _guard(() => _storage.delete(key: key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e, st) {
      throw StorageException(cause: e, stackTrace: st);
    }
  }
}
