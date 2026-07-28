/// App 於前景時收到的推播內容。
///
/// 呈現方式(in-app banner、本地通知、靜默處理...)由專案決定；
/// 模板不預綁 `flutter_local_notifications` 等呈現層套件。
class PushMessage {
  /// 建立訊息。
  const PushMessage({this.title, this.body, this.data = const {}});

  /// 通知標題;無 notification payload 時為 null。
  final String? title;

  /// 通知內文;無 notification payload 時為 null。
  final String? body;

  /// 完整 data payload。
  final Map<String, dynamic> data;
}

/// 使用者點擊推播的事件。
class PushTapEvent {
  /// 建立事件。
  const PushTapEvent({this.routePath, this.data = const {}});

  /// 目標路由(取自 FCM data payload 的 `route` key——與後端的契約);
  /// 無此 key 時為 null,由 app 決定預設行為。
  final String? routePath;

  /// 完整 data payload。
  final Map<String, dynamic> data;
}

/// 推播能力契約;FCM 實作見 FcmPushNotifications。
abstract interface class PushNotifications {
  /// 要求推播權限;授權(含 provisional)回 true。
  Future<bool> requestPermission();

  /// 目前裝置 token;不可用時為 null。
  Future<String?> currentToken();

  /// token 更新事件(app 應上報後端)。
  Stream<String> get tokenRefreshes;

  /// 使用者點擊推播的事件(app 訂閱後轉路由)。
  Stream<PushTapEvent> get taps;

  /// 冷啟動點擊:app 由推播點擊啟動時的事件;無則 null。
  /// app 應於首幀後檢查一次並轉路由。
  Future<PushTapEvent?> initialTap();

  /// App 於前景時收到的訊息;呈現方式由專案決定——Android 前景不會
  /// 自動顯示系統通知,iOS 前景亦需專案自行決定是否呈現。
  Stream<PushMessage> get foregroundMessages;
}
