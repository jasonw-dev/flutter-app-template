import 'package:core/core.dart';

/// [AnalyticsTracker] 的空實作;僅供未配置 Firebase 的出廠狀態使用。
///
/// 一旦專案完成 Firebase 設定並將 `AppConfig.firebaseEnabled` 改為 true，
/// 組裝層會改用 `FirebaseAnalyticsTracker`，此替身不再被使用。
class DisabledAnalyticsTracker implements AnalyticsTracker {
  /// 建立空實作。
  const DisabledAnalyticsTracker();

  @override
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {}

  @override
  Future<void> trackScreen(String screenName) async {}
}

/// [PushNotifications] 的空實作;僅供未配置 Firebase 的出廠狀態使用。
///
/// 一旦專案完成 Firebase 設定並將 `AppConfig.firebaseEnabled` 改為 true，
/// 組裝層會改用 `FcmPushNotifications`，此替身不再被使用。
class DisabledPushNotifications implements PushNotifications {
  /// 建立空實作。
  const DisabledPushNotifications();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<PushTapEvent> get taps => const Stream.empty();

  @override
  Future<PushTapEvent?> initialTap() async => null;

  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();
}
