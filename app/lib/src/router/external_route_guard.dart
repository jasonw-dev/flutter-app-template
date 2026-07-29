import 'package:core/core.dart';

/// 驗證**外部進入**的路徑是否允許導向,允許則回傳正規化後的路徑,否則 null。
///
/// App 有兩個外部進入點——推播點擊與 deep link(Android App Links /
/// iOS Universal Links)——**共用這一份白名單**。安全防護只蓋住一半等於
/// 沒蓋:#25 建立的推播白名單,只要專案一開啟 deep link 就會被繞過。
///
/// 規則:
/// 1. 必須是以 `/` 開頭的相對路徑(擋掉 `https://…` 這種完整 URL)。
/// 2. 路徑先正規化,再比對:命中 [ExternalAllowedRoutes.exact] 才放行;
///    只有 [ExternalAllowedRoutes.subtrees] 內的項目才允許「該路徑或其子路徑」。
/// 3. **query 與 fragment 一律丟棄**——推播不得夾帶參數控制 App 內部狀態。
///
/// 為什麼預設是精確比對而不是前綴比對:現有全部已登入頁面都掛在
/// `app_router.dart` 的 `ShellRoute`(也就是 `/home`)底下,白名單放 `/home`
/// 做前綴比對就等於放行整個 App——防禦對「未來加了刪除帳號確認頁」這種
/// 威脅完全無效。**預設精確比對、子樹要明確 opt-in,才是真的白名單。**
///
/// [exact] 與 [subtrees] 預設取 [ExternalAllowedRoutes] 的正式白名單;開放它們
/// 是為了讓測試能驗證**兩種設定**(精確 vs 子樹)的行為差異——白名單本身
/// 是 compile-time 常數,不開參數就只驗得到出廠那一組。正式呼叫端一律不傳。
String? resolveExternalRoute(
  String raw, {
  List<String> exact = ExternalAllowedRoutes.exact,
  List<String> subtrees = ExternalAllowedRoutes.subtrees,
}) {
  if (!raw.startsWith('/')) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return null;
  }
  // 正規化:把 `.` 與 `..` 解掉,避免 `/home/../login` 這種繞過。
  final path = uri.normalizePath().path;
  if (path.contains('..')) {
    return null;
  }
  if (exact.contains(path)) {
    return path;
  }
  for (final allowed in subtrees) {
    // 必須是完整 segment:`startsWith(allowed)` 會讓 `/homework` 通過 `/home`。
    if (path == allowed || path.startsWith('$allowed/')) {
      return path;
    }
  }
  return null;
}
