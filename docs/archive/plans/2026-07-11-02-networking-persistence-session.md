# networking + persistence + session 實作計畫(2/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `networking`(dio 封裝 + TokenProvider 契約)、`persistence`(儲存介面 + 實作)、`session`(登入狀態單一真相 + 401 refresh 鏈)三個 package。

**Architecture:** 依 spec §2.3:`networking` 定義 `TokenProvider` 介面但不實作;`session` 依賴 `networking` 與 `persistence` 並實作該介面(含單一飛行 refresh);依賴方向 `session → networking → foundation`、`session → persistence → foundation`,無循環。錯誤一律收攏為 `AppException`(spec §2.4),repository 消費 `ApiClient` 得到 `Result<T>`。

**Tech Stack:** dio ^5.7.0、shared_preferences ^2.3.2、flutter_secure_storage ^9.2.2、mocktail ^1.0.4(僅 dev)、foundation(Plan 1 產物)。

## Global Constraints(所有 task 一體適用)

- 沿用 Plan 1 全部約束:Flutter 3.29.3(fvm)、Dart `^3.7.0`、`publish_to: none` + `resolution: workspace`、conventional commits、每 task 結尾 commit(不 push,Task 10 統一推)。
- lint 基線 very_good_analysis strict;**本計畫的程式碼區塊是「語意規格」**——實作時必須補足 doc comments(繁體中文一行)、排版、trailing comma 使 `fvm flutter analyze` 回報 `No issues found!`,但不得改變任何 API 簽名與語意。
- packages 之間允許的依賴(白名單,超出即違規):`networking → foundation`;`persistence → foundation`;`session → foundation, networking, persistence`。
- 測試替身:一律 mocktail 或手寫 fake;提供介面的 package 必須從 `lib/testing.dart` 匯出官方 fake(spec §3 規則 1);`lib/<package>.dart` barrel 不得匯出 testing 內容。
- 例外不實作 `==`;測試斷言例外一律用 `isA<XxxException>()`(spec §10 第 7 條)。
- foundation 既有 API(直接使用,不得修改):`Result<T>`(`Result.success` / `Result.failure` / `fold({required onSuccess, required onFailure})` / `map`)、`AppException` 八子類(`ConnectivityException`、`ServerException(statusCode:)`、`UnauthorizedException`、`ApiException(code:, message:)`、`ParsingException`、`StorageException`、`NativeException(code:)`、`UnknownException(cause:)`,後者 cause 必填)、`AppLogger` / `FakeLogger`(`package:foundation/testing.dart`)。
- 純 Dart package 用 `fvm dart test`;含 Flutter 依賴的 package 用 `fvm flutter test`(persistence、session 屬後者;networking 為純 Dart)。
- 工作目錄:`<repo>`。

---

### Task 1: networking 骨架 + TokenProvider 契約

**Files:**
- Create: `packages/networking/pubspec.yaml`
- Create: `packages/networking/lib/networking.dart`
- Create: `packages/networking/lib/src/token_provider.dart`
- Create: `packages/networking/lib/src/testing/fake_token_provider.dart`
- Create: `packages/networking/lib/testing.dart`
- Modify: `pubspec.yaml`(根,workspace 成員追加)
- Test: `packages/networking/test/fake_token_provider_test.dart`

**Interfaces:**
- Consumes: foundation(既有)。
- Produces:
  - `abstract interface class TokenProvider`,方法 `Future<String?> currentAccessToken()`、`Future<bool> refreshTokens()`。Task 3 的攔截器與 Task 9 的 SessionManager 都以此簽名為準。
  - `FakeTokenProvider implements TokenProvider`(自 `package:networking/testing.dart` 匯出):建構子 `FakeTokenProvider({String? accessToken, bool refreshResult = false, String? tokenAfterRefresh})`;屬性 `int refreshCallCount`;行為——`currentAccessToken()` 回傳目前 token;`refreshTokens()` 計數加一,若 `refreshResult` 為 true 且 `tokenAfterRefresh` 非 null 則把目前 token 換成 `tokenAfterRefresh`,回傳 `refreshResult`。

- [ ] **Step 1: 建 package 骨架與根 workspace 註冊**

`packages/networking/pubspec.yaml`:

```yaml
name: networking
description: dio 封裝:client 工廠、攔截器、統一錯誤轉換;定義 TokenProvider 契約。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  dio: ^5.7.0
  foundation: any

dev_dependencies:
  test: ^1.25.0
```

根 `pubspec.yaml` 的 workspace 清單改為:

```yaml
workspace:
  - packages/foundation
  - packages/networking
```

Run: `fvm flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: 寫失敗測試**

`packages/networking/test/fake_token_provider_test.dart`:

```dart
import 'package:networking/networking.dart';
import 'package:networking/testing.dart';
import 'package:test/test.dart';

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
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `cd packages/networking && fvm dart test`
Expected: 編譯失敗,`Undefined class 'FakeTokenProvider'` 或 URI 不存在。

- [ ] **Step 4: 最小實作**

`packages/networking/lib/src/token_provider.dart`:

```dart
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
```

`packages/networking/lib/src/testing/fake_token_provider.dart`:

```dart
import 'package:networking/src/token_provider.dart';

/// [TokenProvider] 的官方 fake(spec §3 規則 1)。
class FakeTokenProvider implements TokenProvider {
  /// 建立 fake;[refreshResult] 控制 refresh 成敗,
  /// 成功時 token 換為 [tokenAfterRefresh]。
  FakeTokenProvider({
    String? accessToken,
    this.refreshResult = false,
    this.tokenAfterRefresh,
  }) : _accessToken = accessToken;

  /// refreshTokens 的固定回傳值。
  final bool refreshResult;

  /// refresh 成功後生效的新 token。
  final String? tokenAfterRefresh;

  /// refreshTokens 被呼叫的次數。
  int refreshCallCount = 0;

  String? _accessToken;

  @override
  Future<String?> currentAccessToken() async => _accessToken;

  @override
  Future<bool> refreshTokens() async {
    refreshCallCount++;
    if (refreshResult && tokenAfterRefresh != null) {
      _accessToken = tokenAfterRefresh;
    }
    return refreshResult;
  }
}
```

`packages/networking/lib/networking.dart`:

```dart
/// dio 封裝:client 工廠、攔截器、統一錯誤轉換、TokenProvider 契約。
library;

export 'src/token_provider.dart';
```

`packages/networking/lib/testing.dart`:

```dart
/// 測試專用入口:官方 fake 一律由此匯出(spec §3 規則 1)。
library;

export 'src/testing/fake_token_provider.dart';
```

- [ ] **Step 5: 跑測試與 analyze 確認通過**

Run: `cd packages/networking && fvm dart test && cd ../.. && fvm flutter analyze`
Expected: `All tests passed!` 且 `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(networking): package 骨架與 TokenProvider 契約"
```

---

### Task 2: DioException → AppException 統一錯誤轉換

**Files:**
- Create: `packages/networking/lib/src/error_mapper.dart`
- Modify: `packages/networking/lib/networking.dart`
- Test: `packages/networking/test/error_mapper_test.dart`

**Interfaces:**
- Consumes: foundation 的 `AppException` 子類。
- Produces: `AppException mapDioException(DioException exception)`(頂層函式)。轉換表(spec §2.4 的落地,寫進 doc comment):
  - `connectionTimeout / sendTimeout / receiveTimeout / connectionError` → `ConnectivityException`
  - `badCertificate` → `ConnectivityException`
  - `badResponse` 且 status 401 → `UnauthorizedException`(注意:攔截器先處理 refresh,走到 mapper 的 401 代表 refresh 已失敗或未登入)
  - `badResponse` 且 status >= 500 → `ServerException(statusCode:)`
  - `badResponse` 其餘 4xx → `ApiException(code:, message:)`,code/message 取自回應 body 的 `code`/`message` 欄位(body 非 Map 或欄位缺失時 code 用 statusCode 字串、message 用空字串)
  - `cancel` 與其他 → `UnknownException(cause: exception)`
  - 所有結果都帶 `cause: exception`、`stackTrace: exception.stackTrace`

- [ ] **Step 1: 寫失敗測試**

`packages/networking/test/error_mapper_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:networking/networking.dart';
import 'package:test/test.dart';

DioException _dioError({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
  Object? body,
}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response<Object?>(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
  );
}

void main() {
  test('timeout 與 connectionError 轉 ConnectivityException', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.badCertificate,
    ]) {
      expect(
        mapDioException(_dioError(type: type)),
        isA<ConnectivityException>(),
        reason: '$type',
      );
    }
  });

  test('401 轉 UnauthorizedException', () {
    expect(
      mapDioException(_dioError(statusCode: 401)),
      isA<UnauthorizedException>(),
    );
  });

  test('5xx 轉 ServerException 並攜帶 statusCode', () {
    final e = mapDioException(_dioError(statusCode: 503));
    expect(e, isA<ServerException>());
    expect((e as ServerException).statusCode, 503);
  });

  test('4xx 轉 ApiException,code/message 取自 body', () {
    final e = mapDioException(
      _dioError(
        statusCode: 422,
        body: {'code': 'E42', 'message': 'invalid'},
      ),
    );
    expect(e, isA<ApiException>());
    e as ApiException;
    expect(e.code, 'E42');
    expect(e.message, 'invalid');
  });

  test('4xx body 非 envelope 時 code 用 statusCode 字串', () {
    final e = mapDioException(_dioError(statusCode: 404, body: 'nope'));
    e as ApiException;
    expect(e.code, '404');
    expect(e.message, '');
  });

  test('cancel 轉 UnknownException 並保留 cause', () {
    final source = _dioError(type: DioExceptionType.cancel);
    final e = mapDioException(source);
    expect(e, isA<UnknownException>());
    expect((e as UnknownException).cause, same(source));
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/networking && fvm dart test test/error_mapper_test.dart`
Expected: 編譯失敗,`Undefined name 'mapDioException'`。

- [ ] **Step 3: 最小實作**

`packages/networking/lib/src/error_mapper.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';

/// 把 [DioException] 收攏為 [AppException](spec §2.4 轉換表)。
///
/// 這是 networking 對外的唯一錯誤形狀;repository 與 bloc
/// 永遠不會看到 DioException。
AppException mapDioException(DioException exception) {
  final stackTrace = exception.stackTrace;
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return ConnectivityException(cause: exception, stackTrace: stackTrace);
    case DioExceptionType.badResponse:
      return _mapBadResponse(exception, stackTrace);
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return UnknownException(cause: exception, stackTrace: stackTrace);
  }
}

AppException _mapBadResponse(DioException exception, StackTrace stackTrace) {
  final statusCode = exception.response?.statusCode ?? 0;
  if (statusCode == 401) {
    return UnauthorizedException(cause: exception, stackTrace: stackTrace);
  }
  if (statusCode >= 500) {
    return ServerException(
      statusCode: statusCode,
      cause: exception,
      stackTrace: stackTrace,
    );
  }
  final body = exception.response?.data;
  final envelope = body is Map<dynamic, dynamic> ? body : const {};
  return ApiException(
    code: envelope['code'] is String ? envelope['code'] as String : '$statusCode',
    message: envelope['message'] is String ? envelope['message'] as String : '',
    cause: exception,
    stackTrace: stackTrace,
  );
}
```

`packages/networking/lib/networking.dart` export 追加:

```dart
export 'src/error_mapper.dart';
export 'src/token_provider.dart';
```

- [ ] **Step 4: 跑測試與 analyze 確認通過**

Run: `cd packages/networking && fvm dart test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(networking): DioException→AppException 統一錯誤轉換"
```

---

### Task 3: AuthInterceptor(header 注入 + 401 refresh 單次重試)

**Files:**
- Create: `packages/networking/lib/src/auth_interceptor.dart`
- Create: `packages/networking/test/support/scripted_adapter.dart`
- Modify: `packages/networking/lib/networking.dart`
- Test: `packages/networking/test/auth_interceptor_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `TokenProvider` / `FakeTokenProvider`。
- Produces: `class AuthInterceptor extends QueuedInterceptor`,建構子 `AuthInterceptor({required TokenProvider tokenProvider, required Dio retryClient})`。行為契約:
  - onRequest:token 非 null 時加 `Authorization: Bearer <token>` header。
  - onError:僅處理 401 且未重試過的請求——先 `refreshTokens()`,成功則以新 token 透過 `retryClient` 重送一次並 resolve;失敗或已重試過則原樣往下傳(交給 mapper 成為 `UnauthorizedException`)。
  - **重試必須走獨立的 `retryClient`(不含本攔截器的 Dio)**:`QueuedInterceptor` 會序列化回呼,若重試走同一個 Dio,重試請求的 onRequest 會排在尚未結束的 onError 之後,造成死結。這是本 task 最重要的正確性約束,Task 4 的工廠負責正確組裝。

- [ ] **Step 1: 寫測試支援(腳本化 adapter)**

`packages/networking/test/support/scripted_adapter.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 依序回放腳本回應的測試用 adapter;超出腳本長度時重複最後一項。
class ScriptedAdapter implements HttpClientAdapter {
  /// 以回應腳本建立 adapter。
  ScriptedAdapter(this._script);

  final List<ResponseBody Function(RequestOptions options)> _script;

  /// 實際收到的請求,依序記錄。
  final List<RequestOptions> seen = [];

  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final step = _script[_index < _script.length ? _index : _script.length - 1];
    _index++;
    return step(options);
  }

  @override
  void close({bool force = false}) {}
}

/// 產生 JSON 回應。
ResponseBody jsonResponse(int statusCode, String json) => ResponseBody.fromString(
      json,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
```

- [ ] **Step 2: 寫失敗測試**

`packages/networking/test/auth_interceptor_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:networking/networking.dart';
import 'package:networking/testing.dart';
import 'package:test/test.dart';

import 'support/scripted_adapter.dart';

({Dio dio, ScriptedAdapter adapter}) _harness({
  required List<ResponseBody Function(RequestOptions)> script,
  required TokenProvider tokenProvider,
}) {
  final adapter = ScriptedAdapter(script);
  final options = BaseOptions(baseUrl: 'https://api.test');
  final retryClient = Dio(options)..httpClientAdapter = adapter;
  final dio = Dio(options)
    ..httpClientAdapter = adapter
    ..interceptors.add(
      AuthInterceptor(tokenProvider: tokenProvider, retryClient: retryClient),
    );
  return (dio: dio, adapter: adapter);
}

void main() {
  test('onRequest 注入 Bearer header', () async {
    final h = _harness(
      script: [(_) => jsonResponse(200, '{}')],
      tokenProvider: FakeTokenProvider(accessToken: 't1'),
    );
    await h.dio.get<dynamic>('/me');
    expect(h.adapter.seen.single.headers['Authorization'], 'Bearer t1');
  });

  test('未登入(token null)不注入 header', () async {
    final h = _harness(
      script: [(_) => jsonResponse(200, '{}')],
      tokenProvider: FakeTokenProvider(),
    );
    await h.dio.get<dynamic>('/public');
    expect(h.adapter.seen.single.headers.containsKey('Authorization'), isFalse);
  });

  test('401 → refresh 成功 → 以新 token 重試一次並成功', () async {
    final provider = FakeTokenProvider(
      accessToken: 'old',
      refreshResult: true,
      tokenAfterRefresh: 'new',
    );
    final h = _harness(
      script: [
        (_) => jsonResponse(401, '{}'),
        (_) => jsonResponse(200, '{"ok":true}'),
      ],
      tokenProvider: provider,
    );
    final res = await h.dio.get<dynamic>('/me');
    expect(res.statusCode, 200);
    expect(provider.refreshCallCount, 1);
    expect(h.adapter.seen, hasLength(2));
    expect(h.adapter.seen[1].headers['Authorization'], 'Bearer new');
  });

  test('401 → refresh 失敗 → 原 401 錯誤往下傳且不重試', () async {
    final provider = FakeTokenProvider(accessToken: 'old');
    final h = _harness(
      script: [(_) => jsonResponse(401, '{}')],
      tokenProvider: provider,
    );
    await expectLater(
      h.dio.get<dynamic>('/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(h.adapter.seen, hasLength(1));
  });

  test('重試後仍 401 → 不再重試(單次重試上限)', () async {
    final provider = FakeTokenProvider(
      accessToken: 'old',
      refreshResult: true,
      tokenAfterRefresh: 'new',
    );
    final h = _harness(
      script: [
        (_) => jsonResponse(401, '{}'),
        (_) => jsonResponse(401, '{}'),
      ],
      tokenProvider: provider,
    );
    await expectLater(
      h.dio.get<dynamic>('/me'),
      throwsA(isA<DioException>()),
    );
    expect(h.adapter.seen, hasLength(2));
    expect(provider.refreshCallCount, 1);
  });
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `cd packages/networking && fvm dart test test/auth_interceptor_test.dart`
Expected: 編譯失敗,`Undefined class 'AuthInterceptor'`。

- [ ] **Step 4: 最小實作**

`packages/networking/lib/src/auth_interceptor.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:networking/src/token_provider.dart';

/// 注入 Authorization header,並在 401 時做單次 refresh 重試。
///
/// 重試一律走 [_retryClient](不含本攔截器的獨立 Dio):
/// QueuedInterceptor 序列化回呼,重試若走同一個 Dio 會死結。
class AuthInterceptor extends QueuedInterceptor {
  /// 以 token 來源與重試用 client 建立攔截器。
  AuthInterceptor({
    required TokenProvider tokenProvider,
    required Dio retryClient,
  })  : _tokenProvider = tokenProvider,
        _retryClient = retryClient;

  static const _retriedKey = 'networking.auth_retried';

  final TokenProvider _tokenProvider;
  final Dio _retryClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenProvider.currentAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    final refreshed = await _tokenProvider.refreshTokens();
    if (!refreshed) {
      handler.next(err);
      return;
    }
    final token = await _tokenProvider.currentAccessToken();
    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await _retryClient.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
```

`packages/networking/lib/networking.dart` export 追加 `export 'src/auth_interceptor.dart';`(維持字母排序)。

- [ ] **Step 5: 跑測試與 analyze 確認通過**

Run: `cd packages/networking && fvm dart test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(networking): AuthInterceptor(401 refresh 單次重試)"
```

---

### Task 4: ApiClient 與 createDio 工廠

**Files:**
- Create: `packages/networking/lib/src/api_client.dart`
- Create: `packages/networking/lib/src/create_dio.dart`
- Modify: `packages/networking/lib/networking.dart`
- Test: `packages/networking/test/api_client_test.dart`
- Test: `packages/networking/test/create_dio_test.dart`

**Interfaces:**
- Consumes: Task 2 `mapDioException`、Task 3 `AuthInterceptor`、`ScriptedAdapter`(測試)。
- Produces:
  - `class NetworkingConfig`:`const NetworkingConfig({required String baseUrl, Duration connectTimeout = const Duration(seconds: 10), Duration receiveTimeout = const Duration(seconds: 20)})`,同名欄位。
  - `Dio createDio({required NetworkingConfig config, required TokenProvider tokenProvider, HttpClientAdapter? adapter})`:建 baseOptions(baseUrl 與兩個 timeout)、建獨立 retryClient、掛 `AuthInterceptor`;`adapter` 非 null 時同時設到主 client 與 retryClient(測試用)。
  - `class ApiClient`:`ApiClient(Dio dio)`;方法(全部回傳 `Future<Result<T>>`,`parse` 收 `dynamic` 回 `T`):
    - `Future<Result<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, required T Function(dynamic data) parse})`
    - `Future<Result<T>> post<T>(String path, {Object? body, required T Function(dynamic data) parse})`
    - `Future<Result<T>> put<T>(String path, {Object? body, required T Function(dynamic data) parse})`
    - `Future<Result<T>> delete<T>(String path, {required T Function(dynamic data) parse})`
  - 錯誤語意:DioException → `mapDioException`;`parse` 丟例外 → `ParsingException`;其他例外 → `UnknownException`。repository 由此得到 spec §4.2 第 5 條的單一錯誤路徑。

- [ ] **Step 1: 寫失敗測試**

`packages/networking/test/api_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:networking/networking.dart';
import 'package:test/test.dart';

import 'support/scripted_adapter.dart';

ApiClient _client(List<ResponseBody Function(RequestOptions)> script) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = ScriptedAdapter(script);
  return ApiClient(dio);
}

void main() {
  test('get 成功時回傳 parse 後的 Success', () async {
    final client = _client([(_) => jsonResponse(200, '{"name":"jason"}')]);
    final result = await client.get<String>(
      '/me',
      parse: (data) => (data as Map<String, dynamic>)['name'] as String,
    );
    expect(result, isA<Success<String>>());
    expect((result as Success<String>).value, 'jason');
  });

  test('HTTP 500 回傳 Failure(ServerException)', () async {
    final client = _client([(_) => jsonResponse(500, '{}')]);
    final result = await client.get<void>('/x', parse: (_) {});
    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).exception, isA<ServerException>());
  });

  test('parse 丟例外時回傳 Failure(ParsingException)', () async {
    final client = _client([(_) => jsonResponse(200, '{"a":1}')]);
    final result = await client.get<String>(
      '/x',
      parse: (data) => throw const FormatException('bad'),
    );
    expect(result, isA<Failure<String>>());
    expect((result as Failure<String>).exception, isA<ParsingException>());
  });

  test('post 送出 body 並解析回應', () async {
    late RequestOptions captured;
    final client = _client([
      (options) {
        captured = options;
        return jsonResponse(201, '{"id":7}');
      },
    ]);
    final result = await client.post<int>(
      '/items',
      body: {'name': 'n'},
      parse: (data) => (data as Map<String, dynamic>)['id'] as int,
    );
    expect((result as Success<int>).value, 7);
    expect(captured.method, 'POST');
    expect(captured.data, {'name': 'n'});
  });

  test('put 與 delete 走同一條錯誤路徑', () async {
    final client = _client([(_) => jsonResponse(404, '{"code":"NF"}')]);
    final putResult = await client.put<void>('/x', parse: (_) {});
    expect((putResult as Failure<void>).exception, isA<ApiException>());
    final deleteResult = await client.delete<void>('/x', parse: (_) {});
    expect((deleteResult as Failure<void>).exception, isA<ApiException>());
  });
}
```

`packages/networking/test/create_dio_test.dart`:

```dart
import 'package:networking/networking.dart';
import 'package:networking/testing.dart';
import 'package:test/test.dart';

import 'support/scripted_adapter.dart';

void main() {
  test('createDio 套用 config 並掛上 AuthInterceptor', () async {
    final adapter = ScriptedAdapter([
      (_) => jsonResponse(401, '{}'),
      (_) => jsonResponse(200, '{}'),
    ]);
    final dio = createDio(
      config: const NetworkingConfig(baseUrl: 'https://api.test'),
      tokenProvider: FakeTokenProvider(
        accessToken: 'old',
        refreshResult: true,
        tokenAfterRefresh: 'new',
      ),
      adapter: adapter,
    );
    expect(dio.options.baseUrl, 'https://api.test');
    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 20));

    final res = await dio.get<dynamic>('/me');
    expect(res.statusCode, 200);
    expect(adapter.seen[1].headers['Authorization'], 'Bearer new');
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/networking && fvm dart test test/api_client_test.dart test/create_dio_test.dart`
Expected: 編譯失敗,`Undefined class 'ApiClient'` / `'NetworkingConfig'`。

- [ ] **Step 3: 最小實作**

`packages/networking/lib/src/create_dio.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:networking/src/auth_interceptor.dart';
import 'package:networking/src/token_provider.dart';

/// networking 的環境設定。
class NetworkingConfig {
  /// 建立設定;timeout 有合理預設。
  const NetworkingConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
  });

  /// API 的 base URL。
  final String baseUrl;

  /// 連線逾時。
  final Duration connectTimeout;

  /// 接收逾時。
  final Duration receiveTimeout;
}

/// 建立掛好攔截器的 Dio(app 組裝層唯一入口)。
///
/// [adapter] 僅供測試注入;非 null 時同時套用到主 client 與
/// retry client,確保 401 重試也走測試 adapter。
Dio createDio({
  required NetworkingConfig config,
  required TokenProvider tokenProvider,
  HttpClientAdapter? adapter,
}) {
  final baseOptions = BaseOptions(
    baseUrl: config.baseUrl,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
  );
  final retryClient = Dio(baseOptions);
  final dio = Dio(baseOptions);
  if (adapter != null) {
    retryClient.httpClientAdapter = adapter;
    dio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(
    AuthInterceptor(tokenProvider: tokenProvider, retryClient: retryClient),
  );
  return dio;
}
```

`packages/networking/lib/src/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:networking/src/error_mapper.dart';

/// repository 的唯一 HTTP 入口:所有結果收攏為 Result(spec §4.2)。
class ApiClient {
  /// 以組裝好的 [Dio] 建立 client。
  ApiClient(this._dio);

  final Dio _dio;

  /// GET 請求。
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) parse,
  }) =>
      _send(
        (dio) => dio.get<dynamic>(path, queryParameters: queryParameters),
        parse,
      );

  /// POST 請求。
  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    required T Function(dynamic data) parse,
  }) =>
      _send((dio) => dio.post<dynamic>(path, data: body), parse);

  /// PUT 請求。
  Future<Result<T>> put<T>(
    String path, {
    Object? body,
    required T Function(dynamic data) parse,
  }) =>
      _send((dio) => dio.put<dynamic>(path, data: body), parse);

  /// DELETE 請求。
  Future<Result<T>> delete<T>(
    String path, {
    required T Function(dynamic data) parse,
  }) =>
      _send((dio) => dio.delete<dynamic>(path), parse);

  Future<Result<T>> _send<T>(
    Future<Response<dynamic>> Function(Dio dio) request,
    T Function(dynamic data) parse,
  ) async {
    try {
      final response = await request(_dio);
      try {
        return Result.success(parse(response.data));
      } on Object catch (e, st) {
        return Result.failure(ParsingException(cause: e, stackTrace: st));
      }
    } on DioException catch (e) {
      return Result.failure(mapDioException(e));
    } on Object catch (e, st) {
      return Result.failure(UnknownException(cause: e, stackTrace: st));
    }
  }
}
```

`packages/networking/lib/networking.dart` 最終 export 區塊:

```dart
export 'src/api_client.dart';
export 'src/auth_interceptor.dart';
export 'src/create_dio.dart';
export 'src/error_mapper.dart';
export 'src/token_provider.dart';
```

- [ ] **Step 4: 跑測試與 analyze 確認通過**

Run: `cd packages/networking && fvm dart test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(networking): ApiClient 與 createDio 工廠"
```

---

### Task 5: persistence 介面與官方 in-memory fakes

**Files:**
- Create: `packages/persistence/pubspec.yaml`
- Create: `packages/persistence/lib/persistence.dart`
- Create: `packages/persistence/lib/src/key_value_store.dart`
- Create: `packages/persistence/lib/src/secure_store.dart`
- Create: `packages/persistence/lib/src/testing/in_memory_stores.dart`
- Create: `packages/persistence/lib/testing.dart`
- Modify: `pubspec.yaml`(根,workspace 成員追加)
- Test: `packages/persistence/test/in_memory_stores_test.dart`

**Interfaces:**
- Consumes: foundation(`StorageException` 語意約定)。
- Produces:
  - `abstract interface class KeyValueStore`:`Future<String?> readString(String key)`、`Future<void> writeString(String key, String value)`、`Future<bool?> readBool(String key)`、`Future<void> writeBool(String key, {required bool value})`、`Future<void> remove(String key)`。
  - `abstract interface class SecureStore`:`Future<String?> read(String key)`、`Future<void> write(String key, String value)`、`Future<void> delete(String key)`。
  - 錯誤約定(寫進兩個介面的 doc comment):實作失敗時一律丟 `StorageException`;呼叫端(session、repository 的 data 層)負責 catch 並轉 `Result`。
  - `InMemoryKeyValueStore implements KeyValueStore` 與 `InMemorySecureStore implements SecureStore`(自 `package:persistence/testing.dart` 匯出),各自暴露 `Map<String, Object> values` / `Map<String, String> values` 供測試斷言。

- [ ] **Step 1: 建 package 骨架與根 workspace 註冊**

`packages/persistence/pubspec.yaml`:

```yaml
name: persistence
description: 本地儲存:key-value 與 secure storage 的介面與實作。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter
  flutter_secure_storage: ^9.2.2
  foundation: any
  shared_preferences: ^2.3.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

根 `pubspec.yaml` workspace 清單追加 `- packages/persistence`。

Run: `fvm flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: 寫失敗測試**

`packages/persistence/test/in_memory_stores_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:persistence/persistence.dart';
import 'package:persistence/testing.dart';

void main() {
  group('InMemoryKeyValueStore', () {
    test('write 後可 read,remove 後為 null', () async {
      final store = InMemoryKeyValueStore();
      await store.writeString('k', 'v');
      await store.writeBool('b', value: true);
      expect(await store.readString('k'), 'v');
      expect(await store.readBool('b'), isTrue);
      await store.remove('k');
      expect(await store.readString('k'), isNull);
    });

    test('未寫入的 key 回傳 null', () async {
      final store = InMemoryKeyValueStore();
      expect(await store.readString('none'), isNull);
      expect(await store.readBool('none'), isNull);
    });

    test('可當 KeyValueStore 注入', () {
      expect(InMemoryKeyValueStore(), isA<KeyValueStore>());
    });
  });

  group('InMemorySecureStore', () {
    test('write/read/delete 循環', () async {
      final store = InMemorySecureStore();
      await store.write('token', 'abc');
      expect(await store.read('token'), 'abc');
      await store.delete('token');
      expect(await store.read('token'), isNull);
    });

    test('可當 SecureStore 注入', () {
      expect(InMemorySecureStore(), isA<SecureStore>());
    });
  });
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `cd packages/persistence && fvm flutter test`
Expected: 編譯失敗,介面與 fake 未定義。

- [ ] **Step 4: 最小實作**

`packages/persistence/lib/src/key_value_store.dart`:

```dart
/// 非機密的 key-value 儲存契約。
///
/// 錯誤約定:實作失敗時一律丟 StorageException(foundation);
/// 呼叫端負責 catch 並轉 Result。
abstract interface class KeyValueStore {
  /// 讀字串;不存在時回 null。
  Future<String?> readString(String key);

  /// 寫字串。
  Future<void> writeString(String key, String value);

  /// 讀布林;不存在時回 null。
  Future<bool?> readBool(String key);

  /// 寫布林。
  Future<void> writeBool(String key, {required bool value});

  /// 移除指定 key。
  Future<void> remove(String key);
}
```

`packages/persistence/lib/src/secure_store.dart`:

```dart
/// 機密資料(token 等)的加密儲存契約。
///
/// 錯誤約定:實作失敗時一律丟 StorageException(foundation);
/// 呼叫端負責 catch 並轉 Result。
abstract interface class SecureStore {
  /// 讀取;不存在時回 null。
  Future<String?> read(String key);

  /// 寫入。
  Future<void> write(String key, String value);

  /// 刪除指定 key。
  Future<void> delete(String key);
}
```

`packages/persistence/lib/src/testing/in_memory_stores.dart`:

```dart
import 'package:persistence/src/key_value_store.dart';
import 'package:persistence/src/secure_store.dart';

/// [KeyValueStore] 的官方 fake(spec §3 規則 1)。
class InMemoryKeyValueStore implements KeyValueStore {
  /// 目前儲存的內容,供測試直接斷言。
  final Map<String, Object> values = {};

  @override
  Future<String?> readString(String key) async => values[key] as String?;

  @override
  Future<void> writeString(String key, String value) async =>
      values[key] = value;

  @override
  Future<bool?> readBool(String key) async => values[key] as bool?;

  @override
  Future<void> writeBool(String key, {required bool value}) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// [SecureStore] 的官方 fake(spec §3 規則 1)。
class InMemorySecureStore implements SecureStore {
  /// 目前儲存的內容,供測試直接斷言。
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
```

`packages/persistence/lib/persistence.dart`:

```dart
/// 本地儲存:key-value 與 secure storage 的介面與實作。
library;

export 'src/key_value_store.dart';
export 'src/secure_store.dart';
```

`packages/persistence/lib/testing.dart`:

```dart
/// 測試專用入口:官方 fake 一律由此匯出(spec §3 規則 1)。
library;

export 'src/testing/in_memory_stores.dart';
```

- [ ] **Step 5: 跑測試與 analyze 確認通過**

Run: `cd packages/persistence && fvm flutter test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(persistence): 儲存介面與官方 in-memory fakes"
```

---

### Task 6: persistence 正式實作(SharedPreferences / FlutterSecureStorage)

**Files:**
- Create: `packages/persistence/lib/src/shared_preferences_store.dart`
- Create: `packages/persistence/lib/src/secure_storage_store.dart`
- Modify: `packages/persistence/lib/persistence.dart`
- Test: `packages/persistence/test/shared_preferences_store_test.dart`
- Test: `packages/persistence/test/secure_storage_store_test.dart`

**Interfaces:**
- Consumes: Task 5 的兩個介面;foundation 的 `StorageException`。
- Produces:
  - `class SharedPreferencesStore implements KeyValueStore`:`SharedPreferencesStore(SharedPreferences prefs)`。
  - `class SecureStorageStore implements SecureStore`:`SecureStorageStore(FlutterSecureStorage storage)`。
  - 兩者所有方法把底層例外包成 `StorageException(cause: e, stackTrace: st)` 後丟出。Plan 4 的 app 組裝層負責建構底層實例並註冊。

- [ ] **Step 1: 寫失敗測試**

`packages/persistence/test/shared_preferences_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:persistence/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('write 後可 read,remove 後為 null', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesStore(await SharedPreferences.getInstance());
    await store.writeString('k', 'v');
    await store.writeBool('b', value: true);
    expect(await store.readString('k'), 'v');
    expect(await store.readBool('b'), isTrue);
    await store.remove('k');
    expect(await store.readString('k'), isNull);
  });

  test('讀取既有初始值', () async {
    SharedPreferences.setMockInitialValues({'seed': 's1'});
    final store = SharedPreferencesStore(await SharedPreferences.getInstance());
    expect(await store.readString('seed'), 's1');
  });
}
```

`packages/persistence/test/secure_storage_store_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:persistence/persistence.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage inner;
  late SecureStorageStore store;

  setUp(() {
    inner = _MockSecureStorage();
    store = SecureStorageStore(inner);
  });

  test('read/write/delete 轉呼叫底層', () async {
    when(() => inner.read(key: 'k')).thenAnswer((_) async => 'v');
    when(() => inner.write(key: 'k', value: 'v')).thenAnswer((_) async {});
    when(() => inner.delete(key: 'k')).thenAnswer((_) async {});

    expect(await store.read('k'), 'v');
    await store.write('k', 'v');
    await store.delete('k');

    verify(() => inner.write(key: 'k', value: 'v')).called(1);
    verify(() => inner.delete(key: 'k')).called(1);
  });

  test('底層丟例外時包成 StorageException', () async {
    when(() => inner.read(key: 'k')).thenThrow(Exception('boom'));
    await expectLater(store.read('k'), throwsA(isA<StorageException>()));
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/persistence && fvm flutter test`
Expected: 編譯失敗,兩個實作類未定義。

- [ ] **Step 3: 最小實作**

`packages/persistence/lib/src/shared_preferences_store.dart`:

```dart
import 'package:foundation/foundation.dart';
import 'package:persistence/src/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [KeyValueStore] 的 SharedPreferences 實作。
class SharedPreferencesStore implements KeyValueStore {
  /// 以既有的 [SharedPreferences] 實例建立(由 app 組裝層提供)。
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> readString(String key) =>
      _guard(() async => _prefs.getString(key));

  @override
  Future<void> writeString(String key, String value) =>
      _guard(() => _prefs.setString(key, value));

  @override
  Future<bool?> readBool(String key) =>
      _guard(() async => _prefs.getBool(key));

  @override
  Future<void> writeBool(String key, {required bool value}) =>
      _guard(() => _prefs.setBool(key, value));

  @override
  Future<void> remove(String key) => _guard(() => _prefs.remove(key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e, st) {
      throw StorageException(cause: e, stackTrace: st);
    }
  }
}
```

`packages/persistence/lib/src/secure_storage_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foundation/foundation.dart';
import 'package:persistence/src/secure_store.dart';

/// [SecureStore] 的 flutter_secure_storage 實作。
class SecureStorageStore implements SecureStore {
  /// 以既有的 [FlutterSecureStorage] 實例建立(由 app 組裝層提供)。
  SecureStorageStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) =>
      _guard(() => _storage.delete(key: key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e, st) {
      throw StorageException(cause: e, stackTrace: st);
    }
  }
}
```

`packages/persistence/lib/persistence.dart` 最終 export:

```dart
export 'src/key_value_store.dart';
export 'src/secure_storage_store.dart';
export 'src/secure_store.dart';
export 'src/shared_preferences_store.dart';
```

- [ ] **Step 4: 跑測試與 analyze 確認通過**

Run: `cd packages/persistence && fvm flutter test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(persistence): SharedPreferences 與 SecureStorage 實作"
```

---

### Task 7: session 骨架(AuthTokens / SessionState / TokenRefreshGateway)

**Files:**
- Create: `packages/session/pubspec.yaml`
- Create: `packages/session/lib/session.dart`
- Create: `packages/session/lib/src/auth_tokens.dart`
- Create: `packages/session/lib/src/session_state.dart`
- Create: `packages/session/lib/src/token_refresh_gateway.dart`
- Create: `packages/session/lib/src/testing/fake_token_refresh_gateway.dart`
- Create: `packages/session/lib/testing.dart`
- Modify: `pubspec.yaml`(根,workspace 成員追加)
- Test: `packages/session/test/session_types_test.dart`

**Interfaces:**
- Consumes: foundation 的 `Result`。
- Produces:
  - `class AuthTokens`:`const AuthTokens({required this.accessToken, required this.refreshToken})`,兩個 `String` 欄位同名。
  - `sealed class SessionState` 與三個 const final 子類:`SessionRestoring`、`SessionAuthenticated`、`SessionUnauthenticated`。
  - `abstract interface class TokenRefreshGateway`:`Future<Result<AuthTokens>> refresh(String refreshToken)`。doc 注明:實作由 app/auth feature 提供(refresh API 是應用專屬的),且實作**必須走不含 AuthInterceptor 的 client**(否則 401 會遞迴觸發 refresh)。
  - `FakeTokenRefreshGateway implements TokenRefreshGateway`(自 `package:session/testing.dart` 匯出):建構子 `FakeTokenRefreshGateway({Result<AuthTokens>? result, Duration delay = Duration.zero})`;屬性 `int callCount`、`List<String> receivedRefreshTokens`;`refresh` 記錄參數、延遲 `delay`、回傳 `result`(未設定時回 `Result.failure(UnauthorizedException())`)。`delay` 是 Task 9 併發測試的關鍵。

- [ ] **Step 1: 建 package 骨架與根 workspace 註冊**

`packages/session/pubspec.yaml`:

```yaml
name: session
description: 登入狀態單一真相:token 儲存、SessionState stream、TokenProvider 實作。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter
  foundation: any
  networking: any
  persistence: any

dev_dependencies:
  flutter_test:
    sdk: flutter
```

根 `pubspec.yaml` workspace 清單追加 `- packages/session`。

Run: `fvm flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: 寫失敗測試**

`packages/session/test/session_types_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:session/session.dart';
import 'package:session/testing.dart';

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
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `cd packages/session && fvm flutter test`
Expected: 編譯失敗,型別未定義。

- [ ] **Step 4: 最小實作**

`packages/session/lib/src/auth_tokens.dart`:

```dart
/// 一組登入憑證。
class AuthTokens {
  /// 以 access/refresh token 建立。
  const AuthTokens({required this.accessToken, required this.refreshToken});

  /// 短效存取 token。
  final String accessToken;

  /// 用於換發新 token 的長效 token。
  final String refreshToken;
}
```

`packages/session/lib/src/session_state.dart`:

```dart
/// 登入狀態(單一真相,由 SessionManager 發布)。
sealed class SessionState {
  const SessionState();
}

/// 啟動中,尚未完成從儲存還原。
final class SessionRestoring extends SessionState {
  /// 建立還原中狀態。
  const SessionRestoring();
}

/// 已登入。
final class SessionAuthenticated extends SessionState {
  /// 建立已登入狀態。
  const SessionAuthenticated();
}

/// 未登入(含登出與 token 失效)。
final class SessionUnauthenticated extends SessionState {
  /// 建立未登入狀態。
  const SessionUnauthenticated();
}
```

`packages/session/lib/src/token_refresh_gateway.dart`:

```dart
import 'package:foundation/foundation.dart';
import 'package:session/src/auth_tokens.dart';

/// 以 refresh token 換發新 tokens 的契約。
///
/// 實作由 app / auth feature 提供(refresh API 是應用專屬的),
/// 且實作必須走「不含 AuthInterceptor 的 client」,
/// 否則 401 會遞迴觸發 refresh。
abstract interface class TokenRefreshGateway {
  /// 換發新 tokens;失敗回傳 failure(通常為 UnauthorizedException)。
  Future<Result<AuthTokens>> refresh(String refreshToken);
}
```

`packages/session/lib/src/testing/fake_token_refresh_gateway.dart`:

```dart
import 'package:foundation/foundation.dart';
import 'package:session/src/auth_tokens.dart';
import 'package:session/src/token_refresh_gateway.dart';

/// [TokenRefreshGateway] 的官方 fake(spec §3 規則 1)。
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
```

`packages/session/lib/session.dart`:

```dart
/// 登入狀態單一真相:token 儲存、SessionState stream、TokenProvider 實作。
library;

export 'src/auth_tokens.dart';
export 'src/session_state.dart';
export 'src/token_refresh_gateway.dart';
```

`packages/session/lib/testing.dart`:

```dart
/// 測試專用入口:官方 fake 一律由此匯出(spec §3 規則 1)。
library;

export 'src/testing/fake_token_refresh_gateway.dart';
```

- [ ] **Step 5: 跑測試與 analyze 確認通過**

Run: `cd packages/session && fvm flutter test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(session): 骨架型別與 TokenRefreshGateway 契約"
```

---

### Task 8: SessionManager 核心(restore / signIn / signOut / states)

**Files:**
- Create: `packages/session/lib/src/session_manager.dart`
- Modify: `packages/session/lib/session.dart`
- Test: `packages/session/test/session_manager_test.dart`

**Interfaces:**
- Consumes: Task 5–7 的 `SecureStore` / `InMemorySecureStore` / `AuthTokens` / `SessionState` / `TokenRefreshGateway`;foundation 的 `AppLogger` / `FakeLogger`。
- Produces: `class SessionManager implements TokenProvider`(TokenProvider 部分本 task 先以 `currentAccessToken` 實作、`refreshTokens` 暫回 false,Task 9 完成):
  - 建構子 `SessionManager({required SecureStore store, required TokenRefreshGateway gateway, required AppLogger logger})`
  - `SessionState get state`(初始 `SessionRestoring`)
  - `Stream<SessionState> get states`(broadcast,僅在狀態改變時發布)
  - `Future<void> restore()`:讀 `session.access_token` / `session.refresh_token` 兩個 key;都非 null → 快取 tokens、狀態 `SessionAuthenticated`;否則 `SessionUnauthenticated`;`StorageException` → logger.error + `SessionUnauthenticated`(啟動不可被儲存壞檔卡死)。
  - `Future<void> signIn(AuthTokens tokens)`:寫入兩 key、快取、發布 `SessionAuthenticated`。
  - `Future<void> signOut()`:刪兩 key、清快取、發布 `SessionUnauthenticated`;刪除失敗仍要清快取並發布(登出必須成功)。
  - `Future<String?> currentAccessToken()`:回快取的 accessToken。
  - 儲存 key 常數:`session.access_token`、`session.refresh_token`(寫成 `static const`,測試直接引用)。

- [ ] **Step 1: 寫失敗測試**

`packages/session/test/session_manager_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/testing.dart';
import 'package:persistence/testing.dart';
import 'package:session/session.dart';
import 'package:session/testing.dart';

void main() {
  late InMemorySecureStore store;
  late FakeTokenRefreshGateway gateway;
  late FakeLogger logger;

  SessionManager build() => SessionManager(
        store: store,
        gateway: gateway,
        logger: logger,
      );

  setUp(() {
    store = InMemorySecureStore();
    gateway = FakeTokenRefreshGateway();
    logger = FakeLogger();
  });

  test('初始狀態為 SessionRestoring', () {
    expect(build().state, isA<SessionRestoring>());
  });

  test('restore:儲存有完整 tokens → Authenticated 並可取 access token',
      () async {
    store.values[SessionManager.accessTokenKey] = 'a1';
    store.values[SessionManager.refreshTokenKey] = 'r1';
    final manager = build();
    await manager.restore();
    expect(manager.state, isA<SessionAuthenticated>());
    expect(await manager.currentAccessToken(), 'a1');
  });

  test('restore:儲存缺 token → Unauthenticated', () async {
    final manager = build();
    await manager.restore();
    expect(manager.state, isA<SessionUnauthenticated>());
    expect(await manager.currentAccessToken(), isNull);
  });

  test('signIn 寫入儲存並發布 Authenticated', () async {
    final manager = build();
    final emitted = <SessionState>[];
    final sub = manager.states.listen(emitted.add);
    await manager.signIn(
      const AuthTokens(accessToken: 'a2', refreshToken: 'r2'),
    );
    await sub.cancel();
    expect(store.values[SessionManager.accessTokenKey], 'a2');
    expect(store.values[SessionManager.refreshTokenKey], 'r2');
    expect(manager.state, isA<SessionAuthenticated>());
    expect(emitted.single, isA<SessionAuthenticated>());
  });

  test('signOut 清除儲存與快取並發布 Unauthenticated', () async {
    final manager = build();
    await manager.signIn(
      const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    await manager.signOut();
    expect(store.values, isEmpty);
    expect(manager.state, isA<SessionUnauthenticated>());
    expect(await manager.currentAccessToken(), isNull);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/session && fvm flutter test test/session_manager_test.dart`
Expected: 編譯失敗,`SessionManager` 未定義。

- [ ] **Step 3: 最小實作**

`packages/session/lib/src/session_manager.dart`:

```dart
import 'dart:async';

import 'package:foundation/foundation.dart';
import 'package:networking/networking.dart';
import 'package:persistence/persistence.dart';
import 'package:session/src/auth_tokens.dart';
import 'package:session/src/session_state.dart';
import 'package:session/src/token_refresh_gateway.dart';

/// 登入狀態的單一真相,並實作 networking 的 [TokenProvider]。
///
/// 生命週期:app bootstrap 建立唯一實例並 `restore()`;
/// auth feature 登入成功後呼叫 [signIn];
/// app 層訂閱 [states] 處理 token 失效導回登入。
class SessionManager implements TokenProvider {
  /// 以儲存、換發 gateway 與 logger 建立。
  SessionManager({
    required SecureStore store,
    required TokenRefreshGateway gateway,
    required AppLogger logger,
  })  : _store = store,
        _gateway = gateway,
        _logger = logger;

  /// access token 的儲存 key。
  static const accessTokenKey = 'session.access_token';

  /// refresh token 的儲存 key。
  static const refreshTokenKey = 'session.refresh_token';

  final SecureStore _store;
  final TokenRefreshGateway _gateway;
  final AppLogger _logger;

  final _controller = StreamController<SessionState>.broadcast();

  AuthTokens? _tokens;
  SessionState _state = const SessionRestoring();

  /// 目前狀態。
  SessionState get state => _state;

  /// 狀態變化的 broadcast stream(僅在改變時發布)。
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
  Future<bool> refreshTokens() async => false; // Task 9 完成實作。

  void _emit(SessionState next) {
    if (next.runtimeType == _state.runtimeType) {
      _state = next;
      return;
    }
    _state = next;
    _controller.add(next);
  }
}
```

`packages/session/lib/session.dart` export 追加 `export 'src/session_manager.dart';`。

- [ ] **Step 4: 跑測試與 analyze 確認通過**

Run: `cd packages/session && fvm flutter test && cd ../.. && fvm flutter analyze`
Expected: 全綠 + `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(session): SessionManager 核心(restore/signIn/signOut/states)"
```

---

### Task 9: refreshTokens 單一飛行 + TokenProvider 整合

**Files:**
- Modify: `packages/session/lib/src/session_manager.dart`
- Test: `packages/session/test/session_refresh_test.dart`

**Interfaces:**
- Consumes: Task 7 `FakeTokenRefreshGateway(delay:)`、Task 8 `SessionManager`。
- Produces: `SessionManager.refreshTokens()` 完整語意:
  - 未登入(無快取 tokens)→ 直接 `false`,不呼叫 gateway。
  - 成功 → 持久化並快取新 tokens、回 `true`(狀態維持 Authenticated,不重複發布)。
  - 失敗 → 執行 `signOut()`(清儲存、發布 `SessionUnauthenticated`)、回 `false`。app 層訂閱 states 即得到「token 失效登出」(spec §5.3)。
  - **單一飛行**:並發呼叫共享同一個進行中的 refresh,gateway 只被呼叫一次,所有呼叫者拿到同一結果。

- [ ] **Step 1: 寫失敗測試**

`packages/session/test/session_refresh_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/testing.dart';
import 'package:persistence/testing.dart';
import 'package:session/session.dart';
import 'package:session/testing.dart';

void main() {
  late InMemorySecureStore store;
  late FakeLogger logger;

  SessionManager build(FakeTokenRefreshGateway gateway) => SessionManager(
        store: store,
        gateway: gateway,
        logger: logger,
      );

  setUp(() {
    store = InMemorySecureStore();
    logger = FakeLogger();
  });

  Future<SessionManager> signedIn(FakeTokenRefreshGateway gateway) async {
    final manager = build(gateway);
    await manager.signIn(
      const AuthTokens(accessToken: 'a0', refreshToken: 'r0'),
    );
    return manager;
  }

  test('未登入時 refresh 直接 false 且不打 gateway', () async {
    final gateway = FakeTokenRefreshGateway();
    final manager = build(gateway);
    expect(await manager.refreshTokens(), isFalse);
    expect(gateway.callCount, 0);
  });

  test('成功:換新 tokens、持久化、回 true', () async {
    final gateway = FakeTokenRefreshGateway(
      result: const Result.success(
        AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
      ),
    );
    final manager = await signedIn(gateway);
    expect(await manager.refreshTokens(), isTrue);
    expect(await manager.currentAccessToken(), 'a1');
    expect(store.values[SessionManager.refreshTokenKey], 'r1');
    expect(gateway.receivedRefreshTokens, ['r0']);
    expect(manager.state, isA<SessionAuthenticated>());
  });

  test('失敗:登出並發布 Unauthenticated、回 false', () async {
    final gateway = FakeTokenRefreshGateway();
    final manager = await signedIn(gateway);
    final emitted = <SessionState>[];
    final sub = manager.states.listen(emitted.add);
    expect(await manager.refreshTokens(), isFalse);
    await sub.cancel();
    expect(manager.state, isA<SessionUnauthenticated>());
    expect(emitted.single, isA<SessionUnauthenticated>());
    expect(store.values, isEmpty);
  });

  test('單一飛行:並發呼叫只打一次 gateway,結果共享', () async {
    final gateway = FakeTokenRefreshGateway(
      result: const Result.success(
        AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
      ),
      delay: const Duration(milliseconds: 50),
    );
    final manager = await signedIn(gateway);
    final results = await Future.wait([
      manager.refreshTokens(),
      manager.refreshTokens(),
      manager.refreshTokens(),
    ]);
    expect(results, [true, true, true]);
    expect(gateway.callCount, 1);
  });

  test('refresh 完成後可再次 refresh(飛行旗標有重置)', () async {
    final gateway = FakeTokenRefreshGateway(
      result: const Result.success(
        AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
      ),
    );
    final manager = await signedIn(gateway);
    expect(await manager.refreshTokens(), isTrue);
    expect(await manager.refreshTokens(), isTrue);
    expect(gateway.callCount, 2);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/session && fvm flutter test test/session_refresh_test.dart`
Expected: FAIL——`refreshTokens` 目前恆回 false(Task 8 的暫時實作),成功案例與單一飛行案例失敗。

- [ ] **Step 3: 實作**

`packages/session/lib/src/session_manager.dart` 修改:新增欄位與完整 `refreshTokens`:

```dart
  Future<bool>? _inflightRefresh;
```

```dart
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
    final tokens = _tokens;
    if (tokens == null) {
      return false;
    }
    final result = await _gateway.refresh(tokens.refreshToken);
    return result.fold(
      onSuccess: (next) async {
        await _store.write(accessTokenKey, next.accessToken);
        await _store.write(refreshTokenKey, next.refreshToken);
        _tokens = next;
        return true;
      },
      onFailure: (exception) async {
        _logger.warning('token refresh failed: $exception');
        await signOut();
        return false;
      },
    );
  }
```

注意:`fold` 的兩個分支回傳 `Future<bool>`,所以 `_doRefresh` 對 fold 結果需 `await`(`return await result.fold(...)` 或以中間變數承接)——實作時以 analyze/測試為準調整,語意不得變。

- [ ] **Step 4: 跑全部測試與 analyze 確認通過**

Run: `cd packages/session && fvm flutter test && cd ../.. && fvm flutter analyze`
Expected: session 全部測試綠 + `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(session): 單一飛行 refresh 與 TokenProvider 完整實作"
```

---

### Task 10: 全 workspace 收尾與 CI

**Files:**
- Modify: 無新檔;驗證與推送。

**Interfaces:**
- Consumes: Task 1–9 全部產出。
- Produces: main 分支上三個新 package 全綠的狀態;CI success。

- [ ] **Step 1: 全 workspace 檢查**

Run: `./tool/check.sh`
Expected: pub get → format → ignore 稽核 → analyze → foundation/networking/persistence/session 四個 package 測試依序全綠,結尾 `✓ all checks passed`。若 format 段修改了檔案,將變更納入下一步的 commit。

- [ ] **Step 2: 依賴白名單抽查**

Run: `grep -A5 "^dependencies:" packages/networking/pubspec.yaml packages/persistence/pubspec.yaml packages/session/pubspec.yaml`
Expected: 與 Global Constraints 白名單一致(networking 僅 dio+foundation;persistence 僅 flutter+兩個外掛+foundation;session 僅 flutter+foundation+networking+persistence)。

- [ ] **Step 3: Commit(如有殘餘變更)並推送**

```bash
git add -A
git diff --cached --quiet || git commit -m "chore: Plan 2 收尾(format 殘餘)"
git push origin main
```

- [ ] **Step 4: 確認 CI 綠**

Run: `gh run list --repo hey-jason404/flutter-app-template --limit 1 --json databaseId,status,conclusion`
Expected: 最新 run `conclusion: success`。失敗則讀 log 修到綠(僅限腳本/workflow/測試環境問題;package 程式碼問題回報 controller)。

---

## 完成定義(本計畫)

- [ ] `./tool/check.sh` 全綠(四個 package);CI 綠。
- [ ] networking:`TokenProvider`、`mapDioException`、`AuthInterceptor`(401 單次重試、獨立 retryClient)、`ApiClient`、`createDio`;fake 僅由 testing.dart 匯出。
- [ ] persistence:兩介面 + in-memory fakes + 兩實作,錯誤一律 `StorageException`。
- [ ] session:`SessionManager` 實作 `TokenProvider`,單一飛行 refresh,失敗自動登出並發布狀態。
- [ ] 依賴白名單無違規(Step 2 抽查 + `depend_on_referenced_packages` 全程把關)。

## 後續計畫

3. design_system、localization、navigation、observability、push_notifications
4. app 組裝層(config/bootstrap/DI/router/shell + di_smoke_test 標記區塊)
5. 示範 features(auth、home)+ 假後端定案 + integration test
6. tool 產生器 + CLAUDE.md + docs/how-to + ADR(吸收 spec §10 待辦)
