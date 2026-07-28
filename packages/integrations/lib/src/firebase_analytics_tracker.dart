import 'package:core/core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// [AnalyticsTracker] 的 Firebase Analytics 實作;實例由 app 組裝層注入。
class FirebaseAnalyticsTracker implements AnalyticsTracker {
  /// 以既有的 [FirebaseAnalytics] 建立。
  FirebaseAnalyticsTracker(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) {
    final filtered = <String, Object>{
      for (final entry in parameters.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    return _analytics.logEvent(name: name, parameters: filtered);
  }

  @override
  Future<void> trackScreen(String screenName) =>
      _analytics.logScreenView(screenName: screenName);
}
