/// 非機密的 key-value 儲存契約。
///
/// 錯誤約定:實作失敗時一律丟 StorageException(foundation);
/// 呼叫端負責 catch 並轉 Result。
abstract interface class KeyValueStore {
  /// 讀字串;不存在時回 null。
  Future<String?> readString(String key);

  /// 寫字串。
  Future<void> writeString(String key, String value);

  /// 讀布林;不存在時回 null。
  Future<bool?> readBool(String key);

  /// 寫布林。
  Future<void> writeBool(String key, {required bool value});

  /// 移除指定 key。
  Future<void> remove(String key);
}
