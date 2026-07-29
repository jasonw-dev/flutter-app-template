import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentAccessToken 回傳建構時的 token', () async {
    final provider = FakeTokenProvider(accessToken: 't1');
    expect(await provider.currentAccessToken(), 't1');
  });

  test('refreshTokens 成功時換新 token 並計數', () async {
    final provider = FakeTokenProvider(
      accessToken: 'old',
      refreshResult: true,
      tokenAfterRefresh: 'new',
    );
    expect(await provider.refreshTokens(), isTrue);
    expect(await provider.currentAccessToken(), 'new');
    expect(provider.refreshCallCount, 1);
  });

  test('refreshTokens 失敗時 token 不變', () async {
    final provider = FakeTokenProvider(accessToken: 'old');
    expect(await provider.refreshTokens(), isFalse);
    expect(await provider.currentAccessToken(), 'old');
  });

  test('FakeTokenProvider 可當 TokenProvider 注入', () {
    expect(FakeTokenProvider(), isA<TokenProvider>());
  });
}
