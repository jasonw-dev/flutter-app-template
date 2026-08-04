import 'package:core/src/foundation/exceptions.dart';
import 'package:core/src/foundation/result.dart';
import 'package:core/src/session/auth_tokens.dart';
import 'package:core/src/session/token_refresh_gateway.dart';

/// [TokenRefreshGateway] 的官方 fake(conventions.md §8.1 第 1 條)。
class FakeTokenRefreshGateway implements TokenRefreshGateway {
  /// 建立 fake;[delay] 用於模擬慢速 refresh(併發測試)。
  FakeTokenRefreshGateway({
    Result<AuthTokens>? result,
    this.delay = Duration.zero,
  }) : _result = result;

  /// refresh 完成前的延遲。
  final Duration delay;

  /// refresh 被呼叫的次數。
  int callCount = 0;

  /// 依序收到的 refresh token 參數。
  final List<String> receivedRefreshTokens = [];

  final Result<AuthTokens>? _result;

  @override
  Future<Result<AuthTokens>> refresh(String refreshToken) async {
    callCount++;
    receivedRefreshTokens.add(refreshToken);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return _result ?? const Result.failure(UnauthorizedException());
  }
}
