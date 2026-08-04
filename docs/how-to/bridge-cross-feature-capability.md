# 讓一個 feature 用到另一個 feature 的業務資料

規則來源:[`architecture.md` §3.5](../architecture.md)。本文是操作步驟。

> 模板出廠沒有這個範例的活程式碼——`auth` 與 `home` 之間沒有這種關係。以下
> 程式碼是可直接照抄的形狀,但要有你自己的兩個 feature 才跑得起來。

## 先確認你真的需要

三個問題,任何一個答「是」就不要用本文的做法:

| 問題 | 答是的話 |
|---|---|
| 這是技術能力(HTTP、儲存、log、原生)? | 放 `packages/core` 或 `packages/native/*` |
| 這是共用 UI 元件? | 放 `packages/ui` |
| 兩邊其實是同一個業務領域,只是被硬切成兩個 feature? | 合併,不要橋接 |

貫穿本文的例子:`features/member` 擁有會員資料,`features/payment` 結帳前要
知道「這個會員綁手機了沒」。

## 做法:consumer 定義 port,`app` 寫 adapter

```text
app ──> member          member  ─X─> payment
app ──> payment         payment ─X─> member
```

**1. 消費端定義自己要的窄 port**(放在 payment 裡,描述「payment 需要知道
什麼」,不是「member 能提供什麼」),並從 barrel 匯出:

```dart
// features/payment/lib/src/domain/ports/phone_binding_status_reader.dart
abstract interface class PhoneBindingStatusReader {
  Future<Result<PhoneBindingStatus>> read();
}

enum PhoneBindingStatus { bound, notBound, unknown }
```

**2. 生產端匯出公開讀取契約**,回傳自己的 domain 型別。**DTO 不外流**——
DTO 是 data 層的實作細節,外流之後後端改欄位的爆炸範圍就不止於 member:

```dart
// features/member/lib/src/domain/repositories/member_profile_reader.dart
abstract interface class MemberProfileReader {
  Future<Result<MemberProfile>> getCurrentMember();
}
```

**3. `app/lib/src/bridges/` 寫 adapter**,只做讀取與型別翻譯:

```dart
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

`Result.map` 只轉換成功值,failure 側原樣往上傳——**技術失敗不會被 bridge
吃掉**。

**4. 在 `composeDependencies` 註冊**;忘記註冊會被 `di_smoke_test` 在 CI 擋下:

```dart
gi.registerLazySingleton<PhoneBindingStatusReader>(
  () => MemberPhoneBindingBridge(gi<MemberProfileReader>()),
);
```

**5. 業務規則留在消費端**:

```dart
// features/payment 的 cubit
switch (await _phoneBinding.read()) {
  case Failure(:final exception): emit(CheckoutError(exception));
  case Success(value: PhoneBindingStatus.notBound): emit(const CheckoutNeedsPhoneBinding());
  case Success(): await _submit();
}
```

判準一句話:**「綁手機了才能結帳」屬於 payment,所以留在 payment;「怎麼拿到
綁定狀態」是接線,所以在 `app`。**

前端檢查只是為了不讓使用者白填一輪表單,**後端仍然是最終權威**。

## 多結果的流程(OTP)

「需要 OTP」是**業務上預期的分支**,不是失敗。用 feature 自己的 sealed
outcome,走 `Result` 的 success 側(規則見
[`conventions.md` §3.3](../conventions.md)):

```dart
sealed class PaymentOutcome {}
final class PaymentApproved extends PaymentOutcome { ... }
final class PaymentRequiresOtp extends PaymentOutcome { ... }
```

連不上後端是 `Result.failure(ConnectivityException(...))`,後端說要 OTP 是
`Result.success(PaymentRequiresOtp(...))`。

## 多個消費端要同一個 feature 的資料

**不要**把 `app` 變成「每個欄位一個方法」的中央介面。生產端出**一個內聚的
reader**,多個 bridge 共用它的實例與快取(透過 DI),各自映射成自己要的窄型別。

port 依**使用情境**定義而非依欄位:`PaymentMemberPrerequisitesReader` 好過
`getMemberName` / `getMemberPhone` / `getMemberBalance`。分組依**業務歸屬**而
非後端某支 API 的回應形狀——手機驗證狀態屬於 member,錢包餘額屬於 wallet,
即使後端塞在同一包回傳。

## 測試

用 fake 生產端測四個案例:綁了、沒綁、**生產端失敗要原樣傳遞不得被吞掉或翻譯
成業務結果**(最重要的一條)、狀態改變後重讀拿到新值。

## 禁止事項

| 不要 | 誰擋 |
|---|---|
| 開 `features/shared` / `common` / `utils` | `tool/new_feature.dart` 擋名字、`tool/guard.sh` 擋手動建的目錄 |
| payment 的 pubspec 依賴 member | `check.sh` 的 pubspec 依賴稽核 |
| 把業務資料搬進 `core` 或新開業務 `packages/*` | code review |
| bridge 裡寫「金額大於一萬要 OTP」 | code review(那是 payment 的規則) |
| bridge 自己發網路請求 | code review(要透過生產端契約,共用快取) |

## 什麼時候該重新考慮

bridge 數量成長是預期中的,但它只該是機械的轉接。如果開始出現「好幾個 bridge
反覆消費同一組業務能力,改一次要動很多檔」,那是要不要引入 `domains/*` 這一層
的訊號——**那是改變 workspace 拓撲的決定,需要新的 ADR 加對應護欄,不能默默
長出來**。
