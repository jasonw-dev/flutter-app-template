// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authLoginButton => 'Sign in';

  @override
  String get authLoginFailed => 'Sign-in failed. Check your credentials.';

  @override
  String get authLoginTitle => 'Login';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonRetry => 'Retry';

  @override
  String get homeDetailTitle => 'Detail';

  @override
  String get homeEmpty => 'No items yet.';

  @override
  String get homeTitle => 'Home';

  @override
  String get permissionBlockedBody =>
      'Notifications are turned off. Enable them in Settings to get updates.';

  @override
  String get permissionEnable => 'Turn on';

  @override
  String get permissionLater => 'Later';

  @override
  String get permissionNotificationBody =>
      'Get order updates the moment they happen.';

  @override
  String get permissionNotificationTitle => 'Turn on notifications';

  @override
  String get permissionOpenSettings => 'Open settings';

  @override
  String get startupBlockedTitle => 'Unavailable';

  @override
  String get startupMaintenanceMessage =>
      'We\'re doing some maintenance. Please try again shortly.';

  @override
  String get startupUpdateAction => 'Update now';

  @override
  String get startupUpdateMessage => 'A newer version is required to continue.';

  @override
  String get validationEmail => 'Enter a valid email address.';

  @override
  String validationMinLength(int min) {
    return 'Must be at least $min characters.';
  }

  @override
  String get validationRequired => 'This field is required.';
}
