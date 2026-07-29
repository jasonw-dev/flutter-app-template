/// crash 上報契約;Firebase 實作見 CrashlyticsCrashReporter。
abstract interface class CrashReporter {
  /// 上報錯誤;[fatal] 標記是否為致命錯誤。
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  });

  /// 設定(或以 null 清除)使用者識別。
  Future<void> setUserId(String? userId);

  /// 附掛除錯訊息到下一次 crash 報告。
  Future<void> log(String message);
}
