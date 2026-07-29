import 'package:core/core.dart';

/// login 與 refresh 端點共用的 tokens 回應形狀。
///
/// 兩欄位不值得引入 json_serializable codegen，手寫 `fromJson`
/// （欄位缺漏時直接 cast 失敗，由 `ApiClient` 收攏為 `ParsingException`）。
class AuthTokensDto {
  /// 以已解析欄位建立。
  const AuthTokensDto({required this.accessToken, required this.refreshToken});

  /// 由 JSON map 建立；缺欄位時 cast 失敗並向外拋出。
  factory AuthTokensDto.fromJson(Map<String, dynamic> json) => AuthTokensDto(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );

  /// 短效存取 token。
  final String accessToken;

  /// 用於換發新 token 的長效 token。
  final String refreshToken;

  /// 轉為 domain 型別 [AuthTokens]。
  AuthTokens toTokens() =>
      AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
}
