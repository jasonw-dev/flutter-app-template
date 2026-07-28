import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

String _label(SessionState state) => switch (state) {
  SessionRestoring() => 'restoring',
  SessionAuthenticated() => 'authenticated',
  SessionUnauthenticated() => 'unauthenticated',
};

void main() {
  test('SessionState 為 sealed,可 exhaustive switch', () {
    expect(_label(const SessionRestoring()), 'restoring');
    expect(_label(const SessionAuthenticated()), 'authenticated');
    expect(_label(const SessionUnauthenticated()), 'unauthenticated');
  });

  test('FakeTokenRefreshGateway 記錄參數並回傳設定的結果', () async {
    const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');
    final gateway = FakeTokenRefreshGateway(
      result: const Result.success(tokens),
    );
    final result = await gateway.refresh('old-refresh');
    expect((result as Success<AuthTokens>).value.accessToken, 'a');
    expect(gateway.callCount, 1);
    expect(gateway.receivedRefreshTokens, ['old-refresh']);
  });

  test('未設定 result 時回傳 UnauthorizedException failure', () async {
    final gateway = FakeTokenRefreshGateway();
    final result = await gateway.refresh('r');
    expect(
      (result as Failure<AuthTokens>).exception,
      isA<UnauthorizedException>(),
    );
  });
}
