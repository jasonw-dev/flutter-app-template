// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get authEmailLabel => '電子郵件';

  @override
  String get authLoginButton => '登入';

  @override
  String get authLoginFailed => '登入失敗,請確認帳號密碼。';

  @override
  String get authLoginTitle => '登入';

  @override
  String get authPasswordLabel => '密碼';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonErrorGeneric => '發生錯誤,請再試一次。';

  @override
  String get commonLoading => '載入中…';

  @override
  String get commonRetry => '重試';

  @override
  String get homeDetailTitle => '詳情';

  @override
  String get homeEmpty => '目前沒有項目。';

  @override
  String get homeTitle => '首頁';

  @override
  String get permissionBlockedBody => '通知已關閉。請到系統設定開啟,才能收到更新。';

  @override
  String get permissionEnable => '開啟';

  @override
  String get permissionLater => '稍後';

  @override
  String get permissionNotificationBody => '第一時間收到訂單更新。';

  @override
  String get permissionNotificationTitle => '開啟通知';

  @override
  String get permissionOpenSettings => '前往設定';

  @override
  String get startupBlockedTitle => '暫時無法使用';

  @override
  String get startupMaintenanceMessage => '系統維護中,請稍後再試。';

  @override
  String get startupUpdateAction => '前往更新';

  @override
  String get startupUpdateMessage => '需要更新到新版才能繼續使用。';

  @override
  String get validationEmail => '請輸入有效的電子郵件地址。';

  @override
  String validationMinLength(int min) {
    return '至少需要 $min 個字元。';
  }

  @override
  String get validationRequired => '此欄位為必填。';
}
