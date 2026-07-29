# 接上強制更新／維護模式

模板出貨的是**機制**,判斷依據留成一個明確的擴充點。你只需要實作一個介面
並換掉 DI 的一行——**不必改 `bootstrap.dart` 或 `app_router.dart`**。

## 現況

- 契約:[`app/lib/src/startup/startup_gate.dart`](../../app/lib/src/startup/startup_gate.dart)
- 出廠實作:`AlwaysAllowedStartupGate`(永遠放行)
- 攔截位置:`app_router.dart` 的 `redirect` **最高優先層**,排在登入守衛之前
- 檢查時機:`bootstrap.dart` 第 4d 步(`runApp` 之前),以及每次 App 回到前景

## 步驟

### 1. 實作 `StartupGate`

```dart
class RemoteConfigStartupGate implements StartupGate {
  RemoteConfigStartupGate(this._client);

  final ApiClient _client;

  @override
  Future<StartupGateState> evaluate() async {
    final result = await _client.get<Map<String, dynamic>>(
      '/app-status',
      parse: (data) => data as Map<String, dynamic>,
    );
    return result.fold(
      // **失敗一律放行。** 把使用者鎖在門外的代價遠大於漏擋一次。
      onFailure: (_) => const StartupAllowed(),
      onSuccess: (json) {
        if (json['maintenance'] == true) {
          return StartupUnderMaintenance(message: json['message'] as String?);
        }
        if (json['minVersion'] != null && _isOutdated(json)) {
          return StartupUpdateRequired(storeUrl: json['storeUrl'] as String);
        }
        return const StartupAllowed();
      },
    );
  }
}
```

**實作必須自己處理逾時與失敗**,不要讓例外往外拋。`StartupGateController`
雖然有兜底的 try/catch,但那是最後一道保險,不是設計上的依賴。

### 2. 換掉 DI 註冊

`app/lib/src/di/compose_dependencies.dart`,把

```dart
..registerLazySingleton<StartupGate>(AlwaysAllowedStartupGate.new)
```

換成你的實作。**只有這一行。**

### 3. 調整被擋住時的畫面(可選)

[`startup_blocked_page.dart`](../../app/lib/src/startup/startup_blocked_page.dart)
依 `StartupGateState` 分支渲染,文案走
[`packages/localization`](../../packages/localization) 的 `startup*` key。
要改視覺就改這個檔;要改文案就改 ARB 並 `gen-l10n`。

## 三個不要

- **不要讓 gate 檢查失敗時擋住使用者。** 後端掛掉時把全部使用者鎖在門外,
  比漏擋一次舊版嚴重得多。
- **不要建第二個 `redirect` 機制。** 必須跟登入守衛共用同一個 `redirect`
  函式依序判斷,這是 `docs/architecture.md` §3.4 已定的決策。
- **不要在 gate 裡做導航。** gate 只回傳判定結果,導向由 router 負責。

## 為什麼機制不留給專案自己寫

「介面形狀因專案而異」這個理由只對**判斷依據**成立(版本比對 API vs
feature flag vs 遠端 config),對**攔截機制**不成立——攔截機制是固定的,
而且正是最容易寫錯的部分。寫錯的典型後果有兩種:維護模式擋不住未登入
使用者(把 gate 放在登入守衛之後),或是斷網時把所有人鎖在門外。
