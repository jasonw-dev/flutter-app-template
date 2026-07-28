/// 事件埋點契約;Firebase 實作見 FirebaseAnalyticsTracker。
abstract interface class AnalyticsTracker {
  /// 上報事件。
  ///
  /// [parameters] 的值限 String/num(Firebase 限制),其他型別行為未定義。
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  });

  /// 上報畫面瀏覽。
  Future<void> trackScreen(String screenName);
}
