/// 第三方服務整合(Firebase)的單一入口。
///
/// **可選成員**:不用 Firebase 的專案把整個 package 移出 workspace 即可,
/// 步驟見 `docs/how-to/remove-firebase.md`。介面留在 `core`,這裡只有實作。
library;

export 'src/crashlytics_crash_reporter.dart';
export 'src/fcm_push_notifications.dart';
export 'src/firebase_analytics_tracker.dart';
export 'src/firebase_bootstrap.dart';
