import 'dart:async';

import 'package:core/core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrations/integrations.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockSettings extends Mock implements NotificationSettings {}

void main() {
  late _MockMessaging messaging;
  late StreamController<RemoteMessage> opened;
  late StreamController<RemoteMessage> foreground;

  FcmPushNotifications build() => FcmPushNotifications(
    messaging: messaging,
    openedMessages: opened.stream,
    getInitialMessage: () async => null,
    foregroundRemoteMessages: foreground.stream,
  );

  setUp(() {
    messaging = _MockMessaging();
    opened = StreamController<RemoteMessage>();
    foreground = StreamController<RemoteMessage>();
  });

  tearDown(() {
    // 不 await:單訂閱 StreamController 若從未被 listen(如
    // requestPermission/currentToken 測試),close() 回傳的 Future
    // 要等到有訂閱者才會 complete,await 會導致測試逾時。
    unawaited(opened.close());
    unawaited(foreground.close());
  });

  NotificationSettings settingsFor(AuthorizationStatus status) {
    final settings = _MockSettings();
    when(() => settings.authorizationStatus).thenReturn(status);
    return settings;
  }

  test(
    'requestPermission:authorized/provisional 為 true,denied 為 false',
    () async {
      final push = build();
      when(
        () => messaging.requestPermission(),
      ).thenAnswer((_) async => settingsFor(AuthorizationStatus.authorized));
      expect(await push.requestPermission(), isTrue);

      when(
        () => messaging.requestPermission(),
      ).thenAnswer((_) async => settingsFor(AuthorizationStatus.provisional));
      expect(await push.requestPermission(), isTrue);

      when(
        () => messaging.requestPermission(),
      ).thenAnswer((_) async => settingsFor(AuthorizationStatus.denied));
      expect(await push.requestPermission(), isFalse);
    },
  );

  test('currentToken 轉呼叫 getToken', () async {
    when(() => messaging.getToken()).thenAnswer((_) async => 'tok');
    expect(await build().currentToken(), 'tok');
  });

  test('taps 把 RemoteMessage 映射為 PushTapEvent(route key)', () async {
    final push = build();
    final events = <PushTapEvent>[];
    final sub = push.taps.listen(events.add);

    opened
      ..add(const RemoteMessage(data: {'route': '/home', 'x': '1'}))
      ..add(const RemoteMessage(data: {'x': '2'}));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, hasLength(2));
    expect(events[0].routePath, '/home');
    expect(events[0].data['x'], '1');
    expect(events[1].routePath, isNull);
  });

  test('initialTap:有冷啟動訊息時映射,無則 null', () async {
    final withMessage = FcmPushNotifications(
      messaging: messaging,
      openedMessages: opened.stream,
      getInitialMessage: () async =>
          const RemoteMessage(data: {'route': '/home'}),
      foregroundRemoteMessages: foreground.stream,
    );
    final tap = await withMessage.initialTap();
    expect(tap?.routePath, '/home');

    final without = FcmPushNotifications(
      messaging: messaging,
      openedMessages: opened.stream,
      getInitialMessage: () async => null,
      foregroundRemoteMessages: foreground.stream,
    );
    expect(await without.initialTap(), isNull);
  });

  test('data route 非字串時 routePath 為 null(防禦式)', () async {
    final push = FcmPushNotifications(
      messaging: messaging,
      openedMessages: opened.stream,
      getInitialMessage: () async =>
          const RemoteMessage(data: {'route': 123, 'k': 'v'}),
      foregroundRemoteMessages: foreground.stream,
    );
    final tap = await push.initialTap();
    expect(tap, isNotNull);
    expect(tap!.routePath, isNull);
    expect(tap.data['k'], 'v');
  });

  test(
    'foregroundMessages 把 RemoteMessage 映射為 PushMessage(title/body/data)',
    () async {
      final push = build();
      final events = <PushMessage>[];
      final sub = push.foregroundMessages.listen(events.add);

      foreground.add(
        const RemoteMessage(
          notification: RemoteNotification(title: 'hi', body: 'there'),
          data: {'x': '1'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(1));
      expect(events.single.title, 'hi');
      expect(events.single.body, 'there');
      expect(events.single.data['x'], '1');
    },
  );

  test('foregroundMessages:notification 為 null 時 title/body 為 null', () async {
    final push = build();
    final events = <PushMessage>[];
    final sub = push.foregroundMessages.listen(events.add);

    foreground.add(const RemoteMessage(data: {'x': '1'}));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, hasLength(1));
    expect(events.single.title, isNull);
    expect(events.single.body, isNull);
    expect(events.single.data['x'], '1');
  });
}
