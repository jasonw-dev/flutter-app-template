# 讓一個 feature 用到另一個 feature 的業務資料

> 規則的權威來源是 [`architecture.md` §3.5](../architecture.md) 與
> [`conventions.md` §3.3](../conventions.md)。本文是操作步驟。
>
> **本模板出廠沒有這個範例的活程式碼**——`features/auth` 與 `features/home`
> 之間沒有這種關係,硬造一組出來等於為了示範多養兩個 feature。以下的程式碼是
> 完整、可直接照抄的形狀,但需要你的專案真的有這兩個 feature 才跑得起來。

## 什麼時候需要這篇

一個 feature 需要另一個 feature 擁有的**業務事實**,而 `features/*` 之間永遠
不能互相依賴(`tool/check.sh` 的 pubspec 依賴稽核會擋)。

貫穿本文的例子:

- `features/member` 擁有會員資料 API 與手機綁定流程。
- `features/payment` 結帳前必須知道「這個會員綁手機了沒」,某些金額還要求先過
  OTP。

**先確認你真的需要這篇。** 三個問題,任何一個答「是」就不要用本文的做法:

| 問題 | 答「是」的話 |
|---|---|
| 這是技術能力(HTTP、儲存、log、原生)嗎? | 放 `packages/core` 或 `packages/native/*` |
| 這是共用的 UI 元件嗎? | 放 `packages/ui` |
| 兩邊其實是同一個業務領域,只是被硬切成兩個 feature? | 合併成一個 feature,不要橋接 |

## 步驟 1:消費端定義自己要的 port

**放在消費端 feature 裡**,描述「payment 需要知道什麼」,不是「member 能提供
什麼」。刻意做窄。

`features/payment/lib/src/domain/ports/phone_binding_status_reader.dart`:

```dart
import 'package:core/core.dart';

/// payment 結帳前需要的手機綁定狀態。
///
/// **這個介面屬於 payment**——它描述 payment 需要什麼,不是 member 提供什麼。
/// 實作由 `app` 的 bridge 提供(見 docs/architecture.md §3.5),payment 自己
/// 不知道資料來自哪個 feature。
abstract interface class PhoneBindingStatusReader {
  Future<Result<PhoneBindingStatus>> read();
}

/// 綁定狀態。刻意只有 payment 需要的資訊,不是完整的會員資料。
enum PhoneBindingStatus { bound, notBound, unknown }
```

從 payment 的 barrel 匯出這個 port(`app` 要 import 它來寫 adapter):

```dart
// features/payment/lib/payment.dart
export 'src/domain/ports/phone_binding_status_reader.dart';
```

## 步驟 2:生產端匯出公開讀取契約

**回傳自己的 domain 型別,DTO 不外流。** DTO 是 data 層的實作細節,外流之後
後端改欄位的爆炸範圍就不再止於 member。

`features/member/lib/src/domain/repositories/member_profile_reader.dart`:

```dart
import 'package:core/core.dart';
import 'package:member/src/domain/entities/member_profile.dart';

/// member 對外的公開讀取契約。
///
/// **一個內聚的 reader,不是每個欄位一個方法。** 多個 bridge 共用同一個實例
/// 與它的快取(見本文「多個消費端」一節)。
abstract interface class MemberProfileReader {
  Future<Result<MemberProfile>> getCurrentMember();
}
```

`features/member/lib/member.dart`:

```dart
export 'src/domain/entities/member_profile.dart';
export 'src/domain/repositories/member_profile_reader.dart';
```

## 步驟 3:`app` 寫 adapter

`app/lib/src/bridges/member_phone_binding_bridge.dart`:

```dart
import 'package:core/core.dart';
import 'package:member/member.dart';
import 'package:payment/payment.dart';

/// 把 member 的公開契約翻譯成 payment 自己的 port。
///
/// **只做讀取與型別翻譯。** 不得含業務判斷、UI、儲存,或自己發網路請求——
/// 那些屬於 payment 或 member,不屬於組裝層(docs/architecture.md §3.5)。
class MemberPhoneBindingBridge implements PhoneBindingStatusReader {
  const MemberPhoneBindingBridge(this._reader);

  final MemberProfileReader _reader;

  @override
  Future<Result<PhoneBindingStatus>> read() async {
    final result = await _reader.getCurrentMember();
    return result.map(
      (profile) => profile.phoneNumber == null
          ? PhoneBindingStatus.notBound
          : PhoneBindingStatus.bound,
    );
  }
}
```

`Result.map` 只轉換成功值,failure 側原樣往上傳——**技術失敗不會被 bridge 吃掉
或改寫**。

## 步驟 4:註冊

`app/lib/src/di/compose_dependencies.dart`:

```dart
gi.registerLazySingleton<PhoneBindingStatusReader>(
  () => MemberPhoneBindingBridge(gi<MemberProfileReader>()),
);
```

`app/test/di_smoke_test.dart` 會逐一解析已註冊型別,**忘記註冊會在 CI 失敗**,
不會等到執行期才閃退。

## 步驟 5:業務規則留在消費端

判準一句話:**「綁手機了才能結帳」這條規則屬於 payment,所以它留在 payment。
「怎麼拿到綁定狀態」是接線,所以它在 `app`。**

```dart
// features/payment 的 cubit —— 業務判斷在這裡,不在 bridge
final status = await _phoneBinding.read();
switch (status) {
  case Failure(:final exception):
    emit(CheckoutError(exception));
  case Success(value: PhoneBindingStatus.notBound):
    emit(const CheckoutNeedsPhoneBinding());
  case Success():
    await _submit();
}
```

**後端仍然是最終權威。** 前端的檢查是為了不讓使用者白填一輪表單,不是安全邊界
——後端一定要自己再驗一次綁定狀態、OTP、額度。

## 多結果的流程(OTP)

付款送出後,「需要 OTP」是**業務上預期的分支**,不是失敗。用 feature 自己的
sealed outcome,不要塞進 `AppException`(規則見
[`conventions.md` §3.3](../conventions.md)):

```dart
sealed class PaymentOutcome {}

final class PaymentApproved extends PaymentOutcome {
  const PaymentApproved(this.receiptId);
  final String receiptId;
}

final class PaymentRequiresOtp extends PaymentOutcome {
  const PaymentRequiresOtp(this.challengeId);
  final String challengeId;
}
```

repository 簽章是 `Future<Result<PaymentOutcome>>`:**連不上後端**是
`Result.failure(ConnectivityException(...))`,**後端說要 OTP** 是
`Result.success(PaymentRequiresOtp(...))`。前者該提示網路或重試,後者該導去輸入
驗證碼——混在一起 bloc 就分不出來。

## 多個消費端需要同一個 feature 的資料

**不要**把 `app` 變成一個「每個欄位一個方法」的中央介面。`app` 不擁有會員查詢,
它只負責把消費端的 port 接到生產端。

```text
PaymentPhoneStatusReader ─┐
HomeMemberSummaryReader  ─┼─ app bridges ──> 同一個 MemberProfileReader
OrderMemberNameReader    ─┘
```

四條規則:

1. **port 依消費端的使用情境定義,不依欄位。** `PaymentMemberPrerequisitesReader` 好過在 `app` 上長出 `getMemberName` / `getMemberPhone` / `getMemberBalance`。
2. **完整的 API 回應與 DTO 留在 member 內部私有。** 每個 bridge 各自映射成消費端要的窄型別。
3. **共用同一個 repository、同一份快取與 refresh 政策**(透過 DI)。不要讓每個 bridge 各自打一次端點。
4. **依業務歸屬分組,不依後端某支 API 的回應形狀。** 顯示名稱與手機驗證狀態屬於 member/profile;錢包餘額與凍結金額屬於 wallet/accounting——即使後端目前把它們塞在同一包回傳。

## 測試

bridge 是純轉接,用 fake 生產端測,四個案例:

```dart
test('綁了手機 → bound', () async { /* ... */ });
test('沒綁手機 → notBound', () async { /* ... */ });
test('生產端失敗 → 原樣傳遞 AppException,不改寫', () async { /* ... */ });
test('member 狀態改變後重讀 → 拿到新值', () async { /* ... */ });
```

第三個最重要:**bridge 不得把技術失敗吞掉或翻譯成業務結果**。連不上後端跟
「查到了、沒綁」是兩件事,消費端要能分辨。

## 禁止事項

| 不要 | 改成 |
|---|---|
| 開 `features/shared` / `common` / `utils` | 本文的做法。`tool/new_feature.dart` 擋名字、`tool/guard.sh` 擋手動建立的目錄 |
| 讓 payment 的 pubspec 依賴 member | 本文的做法。`check.sh` 的 pubspec 依賴稽核會擋 |
| 把會員資料搬進 `core` 或新開一個業務 `packages/*` | 本文的做法。`packages/*` 是技術能力、共用 UI、多語系、原生能力、第三方 SDK 轉接 |
| bridge 裡寫「金額大於一萬要 OTP」 | 那是 payment 的業務規則,放 payment |
| bridge 自己發網路請求 | 透過生產端的公開契約拿,共用它的快取 |
| 生產端 barrel 匯出 DTO | 匯出 domain 型別 |

## 什麼時候該重新考慮這個模式

bridge 數量成長是預期中的,**但它只該是機械的轉接與接線**。如果開始出現「好幾個
bridge 反覆消費同一組業務能力,而且改一次要動很多檔」,那是「要不要引入
`domains/*` 這一層」的訊號。

那是**改變 workspace 拓撲**的決定,需要一份新的 ADR 加上對應的護欄與工具改動
(見 [`adr/0006`](../adr/0006-package-consolidation.md) 的先例),**不能默默長
出來**。

## 相關文件

- [`architecture.md` §3.5](../architecture.md) —— 規則與依賴圖
- [`conventions.md` §3.2](../conventions.md) —— 回傳型別矩陣
- [`conventions.md` §3.3](../conventions.md) —— 技術失敗 vs feature 業務結果
- [`add-a-feature.md`](add-a-feature.md) —— 新增 feature 的完整流程
