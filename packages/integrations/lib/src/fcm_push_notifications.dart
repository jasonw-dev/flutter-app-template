import 'package:core/core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

PushTapEvent _toTapEvent(RemoteMessage message) {
  final route = message.data['route'];
  return PushTapEvent(
    routePath: route is String ? route : null,
    data: message.data,
  );
}

PushMessage _toPushMessage(RemoteMessage message) => PushMessage(
  title: message.notification?.title,
  body: message.notification?.body,
  data: message.data,
);

/// [PushNotifications] 的 FCM 實作。
///
/// openedMessages 由 app 傳入 `FirebaseMessaging.onMessageOpenedApp`、
/// foregroundRemoteMessages 由 app 傳入 `FirebaseMessaging.onMessage`
/// (static stream 無法注入替身,故由組裝層提供)。
class FcmPushNotifications implements PushNotifications {
  /// 以注入的 messaging 實例與事件來源建立。
  FcmPushNotifications({
    required FirebaseMessaging messaging,
    required Stream<RemoteMessage> openedMessages,
    required Future<RemoteMessage?> Function() getInitialMessage,
    required Stream<RemoteMessage> foregroundRemoteMessages,
    Stream<String>? tokenRefreshes,
  }) : _messaging = messaging,
       _openedMessages = openedMessages,
       _getInitialMessage = getInitialMessage,
       _foregroundRemoteMessages = foregroundRemoteMessages,
       _tokenRefreshes = tokenRefreshes;

  final FirebaseMessaging _messaging;
  final Stream<RemoteMessage> _openedMessages;
  final Future<RemoteMessage?> Function() _getInitialMessage;
  final Stream<RemoteMessage> _foregroundRemoteMessages;
  final Stream<String>? _tokenRefreshes;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> currentToken() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes =>
      _tokenRefreshes ?? _messaging.onTokenRefresh;

  @override
  Stream<PushTapEvent> get taps => _openedMessages.map(_toTapEvent);

  @override
  Future<PushTapEvent?> initialTap() async {
    final message = await _getInitialMessage();
    return message == null ? null : _toTapEvent(message);
  }

  @override
  Stream<PushMessage> get foregroundMessages =>
      _foregroundRemoteMessages.map(_toPushMessage);
}
