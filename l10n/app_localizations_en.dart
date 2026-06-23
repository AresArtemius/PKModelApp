// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ModelApp';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get registerTitle => 'Sign up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get error => 'Error';

  @override
  String get unknownError => 'Unknown error';
}
