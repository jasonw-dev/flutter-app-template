import 'package:core/src/networking/token_provider.dart';

/// [TokenProvider] 的官方 fake(spec §3 規則 1)。
class FakeTokenProvider implements TokenProvider {
  /// 建立 fake;[refreshResult] 控制 refresh 成敗,
  /// 成功時 token 換為 [tokenAfterRefresh];
  /// [clearTokenOnRefresh] 為 true 時,refresh 成功後改把 token 設為
  /// null(用於模擬「refresh 回報成功但拿不到新 token」的邊界案例)。
  FakeTokenProvider({
    this.accessToken,
    this.refreshResult = false,
    this.tokenAfterRefresh,
    this.clearTokenOnRefresh = false,
  });

  /// 目前的 token;測試可直接賦值,模擬「已被另一次併發 refresh 換新」。
  String? accessToken;

  /// refreshTokens 的固定回傳值。
  final bool refreshResult;

  /// refresh 成功後生效的新 token。
  final String? tokenAfterRefresh;

  /// refresh 成功後是否改把 token 清為 null(見建構子說明)。
  final bool clearTokenOnRefresh;

  /// refreshTokens 被呼叫的次數。
  int refreshCallCount = 0;

  @override
  Future<String?> currentAccessToken() async => accessToken;

  @override
  Future<bool> refreshTokens() async {
    refreshCallCount++;
    if (refreshResult) {
      if (clearTokenOnRefresh) {
        accessToken = null;
      } else if (tokenAfterRefresh != null) {
        accessToken = tokenAfterRefresh;
      }
    }
    return refreshResult;
  }
}
