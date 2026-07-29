# Workspace 基盤 + foundation Package 實作計畫(1/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 pub workspace 根骨架、lint 執法基線、`foundation` package(Result / AppException / logger)、與 CI 同構的 check.sh。

**Architecture:** Dart 3.7 原生 pub workspace(不用 melos);`foundation` 為純 Dart 零依賴 package,承載全專案的錯誤模型與共用型別;依賴邊界由 `depend_on_referenced_packages`(error 級)+ CI 強制。詳見 spec:`docs/superpowers/specs/2026-07-11-flutter-app-template-design.md`。

**Tech Stack:** Flutter 3.29.3(FVM 鎖定)/ Dart ^3.7.0、very_good_analysis、package:test。

## Global Constraints(所有 task 一體適用)

- Flutter 版本一律 `3.29.3`(`.fvmrc` 鎖定);Dart SDK 約束一律 `^3.7.0`。
- 所有 package `publish_to: none`、`resolution: workspace`。
- lint 基線:`very_good_analysis` + `strict-casts / strict-inference / strict-raw-types`;`depend_on_referenced_packages` 為 **error** 級;任何 `// ignore:` 必須帶 ` -- 原因`。
- `foundation` 不得依賴任何套件(含 Flutter);dev_dependencies 僅允許 `test`。
- 測試替身不用 mock 套件,`foundation` 的 fake 一律手寫並從 `lib/testing.dart` 匯出。
- 每個 task 結束必須 commit;commit message 用 conventional commits(`feat:` / `chore:` / `test:` / `ci:`)。
- 工作目錄:`<repo>`(git repo 已存在,遠端 `origin/main`)。

---

### Task 1: Workspace 根骨架

**Files:**
- Create: `pubspec.yaml`(workspace 根)
- Create: `.fvmrc`
- Create: `.gitignore`
- Create: `analysis_options.yaml`
- Create: `packages/foundation/pubspec.yaml`
- Create: `packages/foundation/lib/foundation.dart`

**Interfaces:**
- Consumes: 無(第一個 task)。
- Produces: workspace 根與 `foundation` 空 package;後續所有 task 在此之上工作。`flutter pub get` 於根目錄可解析整個 workspace。

- [ ] **Step 1: 建立 `.fvmrc` 與 `.gitignore`**

`.fvmrc`:

```json
{
  "flutter": "3.29.3"
}
```

`.gitignore`:

```gitignore
.DS_Store
.dart_tool/
build/
.idea/
*.iml
.vscode/
.fvm/
pubspec.lock
env/secrets.json
coverage/
```

(模板是給人 clone 的 library-like repo,`pubspec.lock` 不進版控;建出的實際專案可自行改回。)

- [ ] **Step 2: 建立 workspace 根 `pubspec.yaml`**

```yaml
name: workspace_root
description: flutter-app-template workspace root.
publish_to: none

environment:
  sdk: ^3.7.0

workspace:
  - packages/foundation

dev_dependencies:
  very_good_analysis: ^7.0.0
```

- [ ] **Step 3: 建立根 `analysis_options.yaml`**

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    depend_on_referenced_packages: error
```

- [ ] **Step 4: 建立 `foundation` 空 package**

`packages/foundation/pubspec.yaml`:

```yaml
name: foundation
description: 純 Dart 基礎型別:Result、AppException、logger 介面。零依賴。
publish_to: none
resolution: workspace

environment:
  sdk: ^3.7.0

dev_dependencies:
  test: ^1.25.0
```

`packages/foundation/lib/foundation.dart`(暫時只有 library 宣告,後續 task 逐步加 export):

```dart
/// 純 Dart 基礎型別:Result、AppException、logger 介面。
library;
```

- [ ] **Step 5: 驗證 workspace 解析**

Run: `cd <repo> && fvm use 3.29.3 && fvm flutter pub get`
Expected: 成功輸出 `Got dependencies!`,且根目錄產生單一 `.dart_tool/package_config.json`(workspace 共享 resolution 的證明)。若 `fvm` 未安裝,先執行 `brew install fvm`(或 `dart pub global activate fvm`)。

Run: `ls packages/foundation/.dart_tool 2>/dev/null || echo "no local package_config (correct)"`
Expected: `no local package_config (correct)`(成員 package 不各自 resolve;若有殘留目錄僅含 pub 暫存檔,無 `package_config.json` 即正確)。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: workspace 根骨架(pub workspace + FVM 鎖版 + lint 基線)"
```

---

### Task 2: AppException 錯誤模型(TDD)

**Files:**
- Create: `packages/foundation/lib/src/exceptions.dart`
- Modify: `packages/foundation/lib/foundation.dart`
- Test: `packages/foundation/test/exceptions_test.dart`

**Interfaces:**
- Consumes: Task 1 的 package 骨架。
- Produces: `sealed class AppException`(欄位 `Object? cause`、`StackTrace? stackTrace`)與八個 final 子類:`ConnectivityException`、`ServerException(statusCode)`、`UnauthorizedException`、`ApiException(code, message)`、`ParsingException`、`StorageException`、`NativeException(code)`、`UnknownException`。所有子類建構子皆為 `const`、具名參數。Task 3 的 `Result` 與後續計畫的 networking/persistence 都依賴這組型別。

- [ ] **Step 1: 寫失敗測試**

`packages/foundation/test/exceptions_test.dart`:

```dart
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

/// sealed class 的核心價值:exhaustive switch。
/// 這個函式若少列任何子類,是編譯錯誤——測試本身就是護欄的驗證。
String describe(AppException e) => switch (e) {
      ConnectivityException() => 'connectivity',
      ServerException(:final statusCode) => 'server:$statusCode',
      UnauthorizedException() => 'unauthorized',
      ApiException(:final code, :final message) => 'api:$code:$message',
      ParsingException() => 'parsing',
      StorageException() => 'storage',
      NativeException(:final code) => 'native:$code',
      UnknownException() => 'unknown',
    };

void main() {
  test('exhaustive switch 覆蓋所有子類', () {
    expect(describe(const ConnectivityException()), 'connectivity');
    expect(describe(const ServerException(statusCode: 503)), 'server:503');
    expect(describe(const UnauthorizedException()), 'unauthorized');
    expect(
      describe(const ApiException(code: 'E001', message: 'bad request')),
      'api:E001:bad request',
    );
    expect(describe(const ParsingException()), 'parsing');
    expect(describe(const StorageException()), 'storage');
    expect(describe(const NativeException(code: 'CAMERA_DENIED')),
        'native:CAMERA_DENIED');
    expect(describe(const UnknownException()), 'unknown');
  });

  test('cause 與 stackTrace 可攜帶原始錯誤', () {
    final cause = FormatException('bad json');
    final st = StackTrace.current;
    final e = ParsingException(cause: cause, stackTrace: st);
    expect(e.cause, same(cause));
    expect(e.stackTrace, same(st));
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/foundation && fvm dart test`
Expected: 編譯失敗,錯誤含 `Undefined class 'AppException'`(或同義的 URI/型別未定義錯誤)。

- [ ] **Step 3: 最小實作**

`packages/foundation/lib/src/exceptions.dart`:

```dart
/// 全專案唯一的例外體系(spec §2.4)。
///
/// 規則:repository 一律回傳 Result 且 failure 端只能是 AppException 子類;
/// 各 feature 不得自創例外型別。轉換責任:networking 攔截器產生前四類,
/// data 層產生 ParsingException,persistence 產生 StorageException,
/// packages/native 產生 NativeException。
sealed class AppException implements Exception {
  const AppException({this.cause, this.stackTrace});

  /// 原始錯誤(如 DioException),僅供 observability 記錄,UI 不得使用。
  final Object? cause;
  final StackTrace? stackTrace;
}

/// 無網路、DNS 失敗、連線逾時。
final class ConnectivityException extends AppException {
  const ConnectivityException({super.cause, super.stackTrace});
}

/// HTTP 5xx。
final class ServerException extends AppException {
  const ServerException({required this.statusCode, super.cause, super.stackTrace});

  final int statusCode;
}

/// 401,且 token refresh 失敗(觸發 session 過期流程)。
final class UnauthorizedException extends AppException {
  const UnauthorizedException({super.cause, super.stackTrace});
}

/// HTTP 4xx 業務錯誤,攜帶後端錯誤碼與訊息。
final class ApiException extends AppException {
  const ApiException({
    required this.code,
    required this.message,
    super.cause,
    super.stackTrace,
  });

  final String code;
  final String message;
}

/// JSON 解析或 DTO 轉換失敗。
final class ParsingException extends AppException {
  const ParsingException({super.cause, super.stackTrace});
}

/// 本地儲存讀寫失敗。
final class StorageException extends AppException {
  const StorageException({super.cause, super.stackTrace});
}

/// 原生能力呼叫失敗,code 為 pigeon 介面定義的錯誤碼。
final class NativeException extends AppException {
  const NativeException({required this.code, super.cause, super.stackTrace});

  final String code;
}

/// 以上皆非的兜底。出現即代表有未收攏的錯誤來源,應追查 cause。
final class UnknownException extends AppException {
  const UnknownException({super.cause, super.stackTrace});
}
```

`packages/foundation/lib/foundation.dart` 改為:

```dart
/// 純 Dart 基礎型別:Result、AppException、logger 介面。
library;

export 'src/exceptions.dart';
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd packages/foundation && fvm dart test`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -A packages/foundation
git commit -m "feat(foundation): AppException sealed 錯誤體系(spec §2.4)"
```

---

### Task 3: Result<T>(TDD)

**Files:**
- Create: `packages/foundation/lib/src/result.dart`
- Modify: `packages/foundation/lib/foundation.dart`
- Test: `packages/foundation/test/result_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `AppException`。
- Produces: `sealed class Result<T>`,子類 `Success<T>(value)`、`Failure<T>(exception)`;工廠 `Result.success(T)` / `Result.failure(AppException)`;方法 `R fold<R>({required R Function(T) onSuccess, required R Function(AppException) onFailure})`、`Result<R> map<R>(R Function(T))`。後續所有 repository 的回傳型別。

- [ ] **Step 1: 寫失敗測試**

`packages/foundation/test/result_test.dart`:

```dart
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

void main() {
  test('success 走 onSuccess 分支', () {
    const Result<int> r = Result.success(42);
    final out = r.fold(onSuccess: (v) => 'ok:$v', onFailure: (e) => 'ng');
    expect(out, 'ok:42');
  });

  test('failure 走 onFailure 分支並保留例外型別', () {
    const Result<int> r = Result.failure(UnauthorizedException());
    final out = r.fold(
      onSuccess: (v) => 'ok',
      onFailure: (e) => switch (e) {
        UnauthorizedException() => 'unauthorized',
        _ => 'other',
      },
    );
    expect(out, 'unauthorized');
  });

  test('map 轉換 success 值', () {
    const Result<int> r = Result.success(2);
    final mapped = r.map((v) => 'v$v');
    expect((mapped as Success<String>).value, 'v2');
  });

  test('map 對 failure 是 no-op,例外原樣傳遞', () {
    const exception = ServerException(statusCode: 500);
    const Result<int> r = Result.failure(exception);
    final mapped = r.map((v) => 'v$v');
    expect((mapped as Failure<String>).exception, same(exception));
  });

  test('可對 Result 做 exhaustive switch(sealed)', () {
    const Result<int> r = Result.success(1);
    final label = switch (r) {
      Success<int>(:final value) => 'success:$value',
      Failure<int>() => 'failure',
    };
    expect(label, 'success:1');
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/foundation && fvm dart test test/result_test.dart`
Expected: 編譯失敗,錯誤含 `Undefined class 'Result'`。

- [ ] **Step 3: 最小實作**

`packages/foundation/lib/src/result.dart`:

```dart
import 'package:foundation/src/exceptions.dart';

/// repository 的唯一回傳形狀(spec §4.2 第 5 條):
/// 成功為 [Success],失敗為 [Failure] 且僅攜帶 [AppException]。
/// bloc 端以 fold 或 exhaustive switch 消費,禁止 try/catch。
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;

  const factory Result.failure(AppException exception) = Failure<T>;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppException exception) onFailure,
  }) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Failure<T>(:final exception) => onFailure(exception),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Result.success(transform(value)),
        Failure<T>(:final exception) => Result.failure(exception),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.exception);

  final AppException exception;
}
```

`packages/foundation/lib/foundation.dart` 的 export 區塊改為:

```dart
export 'src/exceptions.dart';
export 'src/result.dart';
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd packages/foundation && fvm dart test`
Expected: `All tests passed!`(exceptions_test 與 result_test 皆綠)

- [ ] **Step 5: Commit**

```bash
git add -A packages/foundation
git commit -m "feat(foundation): Result<T> sealed 型別與 fold/map"
```

---

### Task 4: AppLogger 介面 + FakeLogger(TDD)

**Files:**
- Create: `packages/foundation/lib/src/logger.dart`
- Create: `packages/foundation/lib/src/testing/fake_logger.dart`
- Create: `packages/foundation/lib/testing.dart`
- Modify: `packages/foundation/lib/foundation.dart`
- Test: `packages/foundation/test/fake_logger_test.dart`

**Interfaces:**
- Consumes: 無新依賴。
- Produces:
  - `enum LogLevel { debug, info, warning, error }`
  - `abstract interface class AppLogger`,方法:`void debug(String message)`、`void info(String message)`、`void warning(String message)`、`void error(String message, {Object? error, StackTrace? stackTrace})`。observability(計畫 3)提供正式實作。
  - `package:foundation/testing.dart` 匯出 `FakeLogger implements AppLogger`,屬性 `List<LogRecord> records`;`LogRecord` 欄位:`LogLevel level`、`String message`、`Object? error`、`StackTrace? stackTrace`。這是「官方 fake 從 lib/testing.dart 匯出」慣例(spec §3)的第一個範例。

- [ ] **Step 1: 寫失敗測試**

`packages/foundation/test/fake_logger_test.dart`:

```dart
import 'package:foundation/foundation.dart';
import 'package:foundation/testing.dart';
import 'package:test/test.dart';

void main() {
  test('FakeLogger 依序記錄各層級', () {
    final logger = FakeLogger();
    logger.debug('d');
    logger.info('i');
    logger.warning('w');
    logger.error('e', error: 'boom');

    expect(logger.records, hasLength(4));
    expect(logger.records[0].level, LogLevel.debug);
    expect(logger.records[1].level, LogLevel.info);
    expect(logger.records[2].level, LogLevel.warning);
    expect(logger.records[3].level, LogLevel.error);
    expect(logger.records[3].message, 'e');
    expect(logger.records[3].error, 'boom');
  });

  test('FakeLogger 可當 AppLogger 注入', () {
    final AppLogger logger = FakeLogger();
    logger.info('polymorphic');
    expect((logger as FakeLogger).records.single.message, 'polymorphic');
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd packages/foundation && fvm dart test test/fake_logger_test.dart`
Expected: 編譯失敗,錯誤含 `Undefined class 'FakeLogger'`(或 testing.dart URI 不存在)。

- [ ] **Step 3: 最小實作**

`packages/foundation/lib/src/logger.dart`:

```dart
enum LogLevel { debug, info, warning, error }

/// 全專案的 log 介面。正式實作在 observability package
/// (console + crash 上報),foundation 只定義契約。
abstract interface class AppLogger {
  void debug(String message);

  void info(String message);

  void warning(String message);

  void error(String message, {Object? error, StackTrace? stackTrace});
}
```

`packages/foundation/lib/src/testing/fake_logger.dart`:

```dart
import 'package:foundation/src/logger.dart';

/// [AppLogger] 的官方 fake(spec §3 規則 1)。
/// 下游測試一律使用本類,禁止各自手寫 logger mock。
class FakeLogger implements AppLogger {
  final List<LogRecord> records = [];

  @override
  void debug(String message) => records.add(LogRecord(LogLevel.debug, message));

  @override
  void info(String message) => records.add(LogRecord(LogLevel.info, message));

  @override
  void warning(String message) =>
      records.add(LogRecord(LogLevel.warning, message));

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      records.add(
        LogRecord(LogLevel.error, message, error: error, stackTrace: stackTrace),
      );
}

class LogRecord {
  const LogRecord(this.level, this.message, {this.error, this.stackTrace});

  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}
```

`packages/foundation/lib/testing.dart`:

```dart
/// 測試專用入口:官方 fake 一律由此匯出(spec §3 規則 1)。
library;

export 'src/testing/fake_logger.dart';
```

`packages/foundation/lib/foundation.dart` 的 export 區塊改為:

```dart
export 'src/exceptions.dart';
export 'src/logger.dart';
export 'src/result.dart';
```

(注意:`foundation.dart` **不**匯出 testing;fake 只走 `testing.dart` 入口。)

- [ ] **Step 4: 跑測試確認通過**

Run: `cd packages/foundation && fvm dart test`
Expected: `All tests passed!`(三個測試檔皆綠)

- [ ] **Step 5: Commit**

```bash
git add -A packages/foundation
git commit -m "feat(foundation): AppLogger 介面與官方 FakeLogger(testing.dart 慣例)"
```

---

### Task 5: 依賴邊界執法驗證

**Files:**
- Create(暫時): `packages/foundation/lib/src/tmp_boundary_probe.dart`(驗證後刪除)

**Interfaces:**
- Consumes: Task 1 的 analysis_options。
- Produces: 無程式碼產出;產出「lint 執法確實生效」的驗證證據。此 task 目的是確認 spec §2 的邊界機制不是紙上談兵——若本 task 失敗,代表 lint 設定有誤,必須回頭修 Task 1,不得跳過。

- [ ] **Step 1: 製造違規——lib/ 引用未宣告依賴**

`packages/foundation/lib/src/tmp_boundary_probe.dart`:

```dart
// 蓄意違規:test 只是 dev_dependency,lib/ 引用它必須被
// depend_on_referenced_packages(error 級)攔下。驗證後即刪除本檔。
// ignore_for_file: unused_import
import 'package:test/test.dart';
```

- [ ] **Step 2: 確認 analyze 以 error 攔截**

Run: `cd <repo> && fvm flutter analyze 2>&1 | grep depend_on_referenced_packages`
Expected: 輸出一行以 `error` 開頭(非 `info`/`warning`)、規則名為 `depend_on_referenced_packages` 的訊息,指向 `tmp_boundary_probe.dart`。若層級不是 error,回頭檢查根 `analysis_options.yaml` 的 `analyzer.errors` 設定。

- [ ] **Step 3: 移除違規檔,確認 analyze 全綠**

```bash
rm packages/foundation/lib/src/tmp_boundary_probe.dart
```

Run: `fvm flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit(記錄驗證事實)**

```bash
git add -A
git commit -m "test: 驗證 depend_on_referenced_packages 以 error 級執法" --allow-empty
```

(檔案已刪,working tree 可能無變化,用 `--allow-empty` 留下驗證紀錄。)

---

### Task 6: tool/check.sh 與 CI

**Files:**
- Create: `tool/check.sh`(chmod +x)
- Create: `.github/workflows/ci.yaml`

**Interfaces:**
- Consumes: Task 1–5 的全部產出。
- Produces: `./tool/check.sh` 一鍵跑 format → ignore 稽核 → analyze → 逐 package 測試;CI 在 PR 與 main push 時跑同一支腳本(同構保證,spec §6.2)。後續所有計畫的每個 task 完成前都必須讓 `./tool/check.sh` 通過。

- [ ] **Step 1: 寫 check.sh**

`tool/check.sh`:

```bash
#!/usr/bin/env bash
# 與 CI 完全同構的本機檢查(spec §6.2)。本機過了,CI 就會過。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "── 1/4 format ──"
fvm dart format --set-exit-if-changed .

echo "── 2/4 ignore 稽核(// ignore: 必須附 ' -- 原因')──"
violations=$(grep -rn "// ignore" --include="*.dart" packages app features tool 2>/dev/null | grep -v -- " -- " || true)
if [ -n "$violations" ]; then
  echo "✗ 未附原因的 ignore:"
  echo "$violations"
  exit 1
fi

echo "── 3/4 analyze ──"
fvm flutter analyze

echo "── 4/4 tests(逐 package)──"
for dir in packages/* features/* app; do
  [ -d "$dir/test" ] || continue
  echo "→ $dir"
  if grep -q "sdk: flutter" "$dir/pubspec.yaml"; then
    (cd "$dir" && fvm flutter test)
  else
    (cd "$dir" && fvm dart test)
  fi
done

echo "✓ all checks passed"
```

```bash
chmod +x tool/check.sh
```

- [ ] **Step 2: 本機跑通**

Run: `./tool/check.sh`
Expected: 四段依序輸出,最後 `✓ all checks passed`。foundation 的三個測試檔在第 4 段執行。

- [ ] **Step 3: 寫 CI workflow**

`.github/workflows/ci.yaml`:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Read Flutter version from .fvmrc
        id: fvm
        run: echo "version=$(jq -r .flutter .fvmrc)" >> "$GITHUB_OUTPUT"

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ steps.fvm.outputs.version }}
          cache: true

      # CI 上沒有 fvm,以 shim 讓 check.sh 的 `fvm <cmd>` 直通系統 flutter/dart,
      # 維持「單一腳本、兩處執行」的同構性。
      - name: Shim fvm
        run: |
          sudo tee /usr/local/bin/fvm > /dev/null <<'EOF'
          #!/usr/bin/env bash
          exec "$@"
          EOF
          sudo chmod +x /usr/local/bin/fvm

      - run: flutter pub get
      - run: ./tool/check.sh
```

- [ ] **Step 4: Commit 並推送,確認 CI 綠**

```bash
git add -A
git commit -m "ci: check.sh 與 GitHub Actions(本機/CI 同構)"
git push origin main
```

Run: `gh run watch --repo hey-jason404/flutter-app-template $(gh run list --repo hey-jason404/flutter-app-template --limit 1 --json databaseId -q '.[0].databaseId')`(或稍後 `gh run list` 查看)
Expected: workflow `CI` 結論 `success`。若失敗,讀 log 修到綠為止,不得帶紅結束本 task。

---

## 完成定義(本計畫)

- [ ] `fvm flutter pub get` 於根目錄成功,workspace 單一 resolution。
- [ ] `./tool/check.sh` 本機全綠;GitHub Actions CI 綠。
- [ ] `foundation` 對外 API:`AppException` 八子類、`Result<T>`、`AppLogger`;fake 僅由 `testing.dart` 匯出。
- [ ] `depend_on_referenced_packages` 經實測為 error 級。

## 後續計畫(依序,前一份完成後才撰寫)

2. networking、persistence、session(TokenProvider/401 refresh 鏈)
3. design_system、localization、navigation、observability、push_notifications
4. app 組裝層(config/bootstrap/DI/router/shell + di_smoke_test 標記區塊)
5. 示範 features(auth、home)+ 假後端定案 + integration test
6. tool 產生器(new_feature/rename_project)+ CLAUDE.md + docs/how-to + ADR(吸收 spec §10 待辦)
