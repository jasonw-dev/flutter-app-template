import 'dart:async';

import 'package:core/src/foundation/exceptions.dart';
import 'package:core/src/foundation/logger.dart';
import 'package:core/src/foundation/result.dart';
import 'package:core/src/networking/token_provider.dart';
import 'package:core/src/persistence/secure_store.dart';
import 'package:core/src/session/auth_tokens.dart';
import 'package:core/src/session/session_state.dart';
import 'package:core/src/session/token_refresh_gateway.dart';

/// 登入狀態的單一真相,並實作 networking 的 [TokenProvider]。
///
/// 生命週期:app bootstrap 建立唯一實例並 `restore()`;
/// auth feature 登入成功後呼叫 [signIn];
/// app 層訂閱 [states] 處理 token 失效導回登入。
///
/// 本類為 app 生命週期單例,不提供 dispose;`states` 無 replay,
/// 訂閱前先讀 [state] 取得現值。
class SessionManager implements TokenProvider {
  /// 以儲存、換發 gateway 與 logger 建立。
  SessionManager({
    required SecureStore store,
    required TokenRefreshGateway gateway,
    required AppLogger logger,
  }) : _store = store,
       _gateway = gateway,
       _logger = logger;

  /// access token 的儲存 key。
  static const accessTokenKey = 'session.access_token';

  /// refresh token 的儲存 key。
  static const refreshTokenKey = 'session.refresh_token';

  final SecureStore _store;
  final TokenRefreshGateway _gateway;
  final AppLogger _logger;

  final StreamController<SessionState> _controller =
      StreamController<SessionState>.broadcast(sync: true);

  AuthTokens? _tokens;
  SessionState _state = const SessionRestoring();
  Future<bool>? _inflightRefresh;

  /// 目前狀態。
  SessionState get state => _state;

  /// 狀態變化的 broadcast stream(僅在改變時發布)。
  ///
  /// 事件為同步派送(sync broadcast);listener 回呼中讀取 [state]
  /// 保證與事件一致,但不得在回呼中同步呼叫 signIn/signOut/restore
  /// 等變更方法(重入風險)。
  Stream<SessionState> get states => _controller.stream;

  /// 從儲存還原登入狀態;儲存損壞時視為未登入,不阻斷啟動。
  Future<void> restore() async {
    try {
      final access = await _store.read(accessTokenKey);
      final refresh = await _store.read(refreshTokenKey);
      if (access != null && refresh != null) {
        _tokens = AuthTokens(accessToken: access, refreshToken: refresh);
        _emit(const SessionAuthenticated());
        return;
      }
    } on StorageException catch (e, st) {
      _logger.error('session restore failed', error: e, stackTrace: st);
    }
    _tokens = null;
    _emit(const SessionUnauthenticated());
  }

  /// 登入成功後保存 tokens 並發布已登入。
  Future<void> signIn(AuthTokens tokens) async {
    await _store.write(accessTokenKey, tokens.accessToken);
    await _store.write(refreshTokenKey, tokens.refreshToken);
    _tokens = tokens;
    _emit(const SessionAuthenticated());
  }

  /// 登出:清除儲存與快取;即使刪除失敗也保證回到未登入。
  Future<void> signOut() async {
    try {
      await _store.delete(accessTokenKey);
      await _store.delete(refreshTokenKey);
    } on StorageException catch (e, st) {
      _logger.error('session signOut cleanup failed', error: e, stackTrace: st);
    }
    _tokens = null;
    _emit(const SessionUnauthenticated());
  }

  @override
  Future<String?> currentAccessToken() async => _tokens?.accessToken;

  @override
  Future<bool> refreshTokens() {
    final inflight = _inflightRefresh;
    if (inflight != null) {
      return inflight;
    }
    final run = _doRefresh().whenComplete(() => _inflightRefresh = null);
    _inflightRefresh = run;
    return run;
  }

  Future<bool> _doRefresh() async {
    final tokensAtStart = _tokens;
    if (tokensAtStart == null) {
      return false;
    }
    final Result<AuthTokens> result;
    try {
      result = await _gateway.refresh(tokensAtStart.refreshToken);
    } on Object catch (e, st) {
      // gateway 契約要求失敗回 Failure,但不可信任第三方實作一定遵守;
      // 視同「非授權失敗」:保留 tokens、不登出。
      _logger.error('token refresh gateway threw', error: e, stackTrace: st);
      return false;
    }
    if (!identical(_tokens, tokensAtStart)) {
      // refresh 進行期間發生 signOut/signIn(世代已變),
      // 丟棄本次結果:不得寫入 store、不得再次 signOut,
      // 避免登出後的 refresh 成功把舊 tokens「復活」。
      return false;
    }
    return result.fold(
      onSuccess: (next) async {
        await _store.write(accessTokenKey, next.accessToken);
        await _store.write(refreshTokenKey, next.refreshToken);
        _tokens = next;
        return true;
      },
      onFailure: (exception) async {
        if (exception is UnauthorizedException) {
          // refresh token 本身失效,唯一真正需要登出的情境。
          _logger.warning('token refresh unauthorized: $exception');
          await signOut();
          return false;
        }
        // Connectivity/Server/… 等暫時性失敗:斷網不得登出,保留 tokens
        // 讓下次連線恢復後仍可重試。
        _logger.warning('token refresh failed (tokens kept): $exception');
        return false;
      },
    );
  }

  void _emit(SessionState next) {
    final changed = next.runtimeType != _state.runtimeType;
    _state = next;
    if (changed) {
      _controller.add(next);
    }
  }
}
