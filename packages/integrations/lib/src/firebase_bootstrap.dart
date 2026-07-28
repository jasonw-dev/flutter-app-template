import 'package:core/core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:integrations/src/crashlytics_crash_reporter.dart';
import 'package:integrations/src/fcm_push_notifications.dart';
import 'package:integrations/src/firebase_analytics_tracker.dart';

/// 初始化 Firebase 並把緩衝中的 crash reporter 接上 Crashlytics。
///
/// 由 `app` 的 bootstrap 在 `firebaseEnabled == true` 時呼叫;移除 Firebase
/// 的專案連同這個 package 一起刪掉即可(見 docs/how-to/remove-firebase.md)。
Future<void> initializeFirebase(BufferingCrashReporter buffer) async {
  await Firebase.initializeApp();
  await buffer.attach(CrashlyticsCrashReporter(FirebaseCrashlytics.instance));
}

/// 建立以 Firebase Analytics 為後端的埋點實作。
AnalyticsTracker createFirebaseAnalyticsTracker() =>
    FirebaseAnalyticsTracker(FirebaseAnalytics.instance);

/// 建立以 FCM 為後端的推播實作。
PushNotifications createFcmPushNotifications() => FcmPushNotifications(
  messaging: FirebaseMessaging.instance,
  openedMessages: FirebaseMessaging.onMessageOpenedApp,
  getInitialMessage: () => FirebaseMessaging.instance.getInitialMessage(),
  foregroundRemoteMessages: FirebaseMessaging.onMessage,
);
