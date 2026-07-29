/// 表單欄位驗證器。
///
/// 全專案唯一的驗證規則來源——**不要在 page 裡就地寫 `RegExp`**。
/// 每個 validator 回傳 null 代表通過,回傳 String 代表錯誤訊息 key。
///
/// 回傳的是 **l10n key 而不是文案**,因為 `core` 不依賴 `localization`;
/// page 端用 `packages/ui` 的 `localizeValidationError()` 把 key 換成當地
/// 語言(見 docs/conventions.md 表單樣板一節)。
abstract final class Validators {
  /// 必填。
  static String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'validationRequired' : null;

  /// Email 格式。空值視為通過(要必填請與 [required] 併用)。
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return _emailPattern.hasMatch(value) ? null : 'validationEmail';
  }

  /// 最短長度。
  static String? minLength(String? value, int min) =>
      (value ?? '').length < min ? 'validationMinLength' : null;

  /// 依序套用多個驗證器,回傳**第一個**失敗的 key。
  static String? all(String? value, List<String? Function(String?)> rules) {
    for (final rule in rules) {
      final error = rule(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  /// **刻意寬鬆**:只檢查「有東西@有東西.有東西」。
  ///
  /// 嚴格的 email regex 是有名的陷阱,會擋掉合法地址(帶 `+` 標籤、
  /// 新式 TLD、quoted local part 等)。真正的驗證是寄一封信過去。
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
}
