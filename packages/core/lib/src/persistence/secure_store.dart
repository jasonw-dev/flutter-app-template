/// 機密資料(token 等)的加密儲存契約。
///
/// 錯誤約定:實作失敗時一律丟 StorageException(foundation);
/// 呼叫端負責 catch 並轉 Result。
abstract interface class SecureStore {
  /// 讀取;不存在時回 null。
  Future<String?> read(String key);

  /// 寫入。
  Future<void> write(String key, String value);

  /// 刪除指定 key。
  Future<void> delete(String key);
}
