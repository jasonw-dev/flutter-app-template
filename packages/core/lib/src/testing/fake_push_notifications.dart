import 'dart:async';

import 'package:core/src/push/push_notifications.dart';

/// [PushNotifications] 的官方 fake。
class FakePushNotifications implements PushNotifications {
  /// 建立 fake。
  FakePushNotifications({
    this.permissionResult = true,
    this.token = 'fake',
    this.initialTapEvent,
  });

  /// requestPermission 的固定回傳。
  final bool permissionResult;

  /// currentToken 的固定回傳。
  final String? token;

  /// initialTap 的固定回傳(冷啟動點擊事件)。
  final PushTapEvent? initialTapEvent;

  final _tokenController = StreamController<String>.broadcast();
  final _tapController = StreamController<PushTapEvent>.broadcast();
  final _foregroundController = StreamController<PushMessage>.broadcast();

  /// 模擬 token 更新。
  void emitTokenRefresh(String token) => _tokenController.add(token);

  /// 模擬使用者點擊推播。
  void emitTap(PushTapEvent event) => _tapController.add(event);

  /// 模擬前景收到推播訊息。
  void emitForegroundMessage(PushMessage message) =>
      _foregroundController.add(message);

  @override
  Future<bool> requestPermission() async => permissionResult;

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get tokenRefreshes => _tokenController.stream;

  @override
  Stream<PushTapEvent> get taps => _tapController.stream;

  @override
  Future<PushTapEvent?> initialTap() async => initialTapEvent;

  @override
  Stream<PushMessage> get foregroundMessages => _foregroundController.stream;
}
