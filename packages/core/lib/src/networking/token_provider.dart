/// 提供存取 token 的契約(spec §2.3)。
///
/// networking 只定義、不實作;由 session package 實作並在 app 組裝時注入。
abstract interface class TokenProvider {
  /// 目前的 access token;未登入時為 null。
  Future<String?> currentAccessToken();

  /// 嘗試刷新 token。成功回傳 true(新 token 可由
  /// [currentAccessToken] 取得);失敗回傳 false。
  Future<bool> refreshTokens();
}
