import 'package:flutter/widgets.dart';
import 'package:localization/localization.dart';

/// 把 `Validators` 回傳的 l10n key 換成當地語言文案。
///
/// 放在 `ui` 而不是各 page 裡,否則每個表單都要抄一次同一份 switch。
/// `core` 的 `Validators` 刻意回傳 key 而非文案(它不依賴 `localization`),
/// 這個函式就是兩者之間的橋。
///
/// 用法:
/// ```dart
/// TextFormField(
///   validator: (v) => localizeValidationError(
///     context,
///     Validators.all(v, [Validators.required, Validators.email]),
///   ),
/// )
/// ```
/// [minLength] **刻意沒有預設值**:它必須與呼叫端傳給
/// `Validators.minLength()` 的數字是同一個常數。給預設值的話,兩處會各自
/// 演化成不同的數字,而錯誤文案顯示的長度就會跟實際擋下的長度對不起來——
/// 那種 bug 沒有任何測試會抓到。
String? localizeValidationError(
  BuildContext context,
  String? key, {
  int? minLength,
}) => switch (key) {
  null => null,
  'validationRequired' => context.l10n.validationRequired,
  'validationEmail' => context.l10n.validationEmail,
  'validationMinLength' when minLength != null =>
    context.l10n.validationMinLength(minLength),
  // 用了 minLength 卻沒傳長度,或新增 validator 卻忘了在這裡對應時的兜底。
  // 不讓使用者看到裸 key,也不編一個可能是錯的數字。
  _ => context.l10n.commonErrorGeneric,
};
