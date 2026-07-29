/// 重試策略。預設值適用大多數 App,需要時可在 `NetworkingConfig` 覆寫。
class RetryPolicy {
  /// 建立策略。
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
  });

  /// 含第一次在內的總嘗試次數。1 代表不重試。
  ///
  /// **不要把這個數字開大。** 3 次已涵蓋絕大多數暫時性失敗,再多只是讓
  /// 使用者對著轉圈等更久。
  final int maxAttempts;

  /// 指數退避的基數:第 n 次重試等待 `baseDelay * 2^(n-1)`,上限 [maxDelay]。
  final Duration baseDelay;

  /// 單次等待的上限。
  final Duration maxDelay;

  /// 完全不重試的策略,供 token refresh 與測試使用。
  static const none = RetryPolicy(maxAttempts: 1);
}
