import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ModelApp'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get registerTitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @networkConnectionError.
  ///
  /// In en, this message translates to:
  /// **'No connection to Supabase. Check internet, VPN/proxy, DNS, or SUPABASE_URL.'**
  String get networkConnectionError;

  /// No description provided for @catalogUpper.
  ///
  /// In en, this message translates to:
  /// **'CATALOG'**
  String get catalogUpper;

  /// No description provided for @signInUpper.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signInUpper;

  /// No description provided for @registerUpper.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get registerUpper;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account? '**
  String get noAccount;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter email'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @passwordMin6.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMin6;

  /// No description provided for @signInUserIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Sign-in error: userId is missing'**
  String get signInUserIdMissing;

  /// No description provided for @signInGenericError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInGenericError;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @continueWith.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get continueWith;

  /// No description provided for @continueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE BY PHONE'**
  String get continueWithPhone;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WITH GOOGLE'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WITH APPLE'**
  String get continueWithApple;

  /// No description provided for @oauthOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open sign-in. Please try again.'**
  String get oauthOpenFailed;

  /// No description provided for @oauthProviderDisabled.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not enabled in Supabase yet.'**
  String get oauthProviderDisabled;

  /// No description provided for @phoneProviderDisabled.
  ///
  /// In en, this message translates to:
  /// **'Phone sign-in is not enabled in Supabase yet.'**
  String get phoneProviderDisabled;

  /// No description provided for @phoneLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone sign-in'**
  String get phoneLoginTitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneNumber;

  /// No description provided for @phoneInternationalHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a country code and enter the phone number'**
  String get phoneInternationalHint;

  /// No description provided for @phoneOtpCode.
  ///
  /// In en, this message translates to:
  /// **'SMS code'**
  String get phoneOtpCode;

  /// No description provided for @phoneOtpSend.
  ///
  /// In en, this message translates to:
  /// **'SEND CODE'**
  String get phoneOtpSend;

  /// No description provided for @phoneOtpVerify.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get phoneOtpVerify;

  /// No description provided for @phoneOtpEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the SMS code'**
  String get phoneOtpEnterCode;

  /// No description provided for @phoneOtpSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t send the code. Please try again.'**
  String get phoneOtpSendFailed;

  /// No description provided for @phoneOtpVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t verify the code. Please try again.'**
  String get phoneOtpVerifyFailed;

  /// No description provided for @signInEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email is not confirmed yet. Check your inbox and open the confirmation link.'**
  String get signInEmailNotConfirmed;

  /// No description provided for @emailRateLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Too many emails were sent in a short time. Wait a few minutes and try again.'**
  String get emailRateLimitExceeded;

  /// No description provided for @continueSignUpWithPhone.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE BY PHONE'**
  String get continueSignUpWithPhone;

  /// No description provided for @continueSignUpWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WITH GOOGLE'**
  String get continueSignUpWithGoogle;

  /// No description provided for @continueSignUpWithApple.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WITH APPLE'**
  String get continueSignUpWithApple;

  /// No description provided for @emailVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get emailVerificationTitle;

  /// No description provided for @emailVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent an email to {email}. Open the link to activate your account.'**
  String emailVerificationSubtitle(String email);

  /// No description provided for @emailVerificationSubtitleNoEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox and open the link to activate your account.'**
  String get emailVerificationSubtitleNoEmail;

  /// No description provided for @emailVerificationExpires.
  ///
  /// In en, this message translates to:
  /// **'The link should be valid for 24 hours if this is enabled in Supabase Auth settings.'**
  String get emailVerificationExpires;

  /// No description provided for @emailVerificationGoLoginUpper.
  ///
  /// In en, this message translates to:
  /// **'I CONFIRMED, SIGN IN'**
  String get emailVerificationGoLoginUpper;

  /// No description provided for @emailVerificationResendUpper.
  ///
  /// In en, this message translates to:
  /// **'SEND AGAIN'**
  String get emailVerificationResendUpper;

  /// No description provided for @emailVerificationResent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent again.'**
  String get emailVerificationResent;

  /// No description provided for @emailVerificationChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking email confirmation...'**
  String get emailVerificationChecking;

  /// No description provided for @emailVerificationStillPending.
  ///
  /// In en, this message translates to:
  /// **'Email is not confirmed yet. Open the Supabase email link, then tap the button again.'**
  String get emailVerificationStillPending;

  /// No description provided for @emailVerificationLoginManually.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check automatically: the app was restarted or the sign-up details were not kept. Sign in manually after confirming your email.'**
  String get emailVerificationLoginManually;

  /// No description provided for @guestUpper.
  ///
  /// In en, this message translates to:
  /// **'GUEST'**
  String get guestUpper;

  /// No description provided for @accountUpper.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get accountUpper;

  /// No description provided for @catalogSearchHintUpper.
  ///
  /// In en, this message translates to:
  /// **'SEARCH IN CATALOG'**
  String get catalogSearchHintUpper;

  /// No description provided for @catalogLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load catalog'**
  String get catalogLoadError;

  /// No description provided for @savedSearchFashion1825.
  ///
  /// In en, this message translates to:
  /// **'fashion 18-25'**
  String get savedSearchFashion1825;

  /// No description provided for @savedSearchKids.
  ///
  /// In en, this message translates to:
  /// **'kids'**
  String get savedSearchKids;

  /// No description provided for @savedSearchCommercial.
  ///
  /// In en, this message translates to:
  /// **'commercial'**
  String get savedSearchCommercial;

  /// No description provided for @savedSearchSports.
  ///
  /// In en, this message translates to:
  /// **'sports'**
  String get savedSearchSports;

  /// No description provided for @savedSearchSaveCurrent.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get savedSearchSaveCurrent;

  /// No description provided for @savedSearchSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'SAVE SEARCH'**
  String get savedSearchSaveTitle;

  /// No description provided for @savedSearchNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search name'**
  String get savedSearchNameHint;

  /// No description provided for @savedSearchNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get savedSearchNameRequired;

  /// No description provided for @savedSearchSaved.
  ///
  /// In en, this message translates to:
  /// **'Search saved'**
  String get savedSearchSaved;

  /// No description provided for @savedSearchDeleted.
  ///
  /// In en, this message translates to:
  /// **'Search deleted'**
  String get savedSearchDeleted;

  /// No description provided for @noApprovedProfilesYet.
  ///
  /// In en, this message translates to:
  /// **'No approved profiles yet'**
  String get noApprovedProfilesYet;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @cm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get cm;

  /// No description provided for @advancedSearchUpper.
  ///
  /// In en, this message translates to:
  /// **'ADVANCED SEARCH'**
  String get advancedSearchUpper;

  /// No description provided for @resetUpper.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get resetUpper;

  /// No description provided for @applyUpper.
  ///
  /// In en, this message translates to:
  /// **'APPLY'**
  String get applyUpper;

  /// No description provided for @signOutConfirmTitleUpper.
  ///
  /// In en, this message translates to:
  /// **'SIGN OUT?'**
  String get signOutConfirmTitleUpper;

  /// No description provided for @signOutConfirmGuestStay.
  ///
  /// In en, this message translates to:
  /// **'You will stay in the catalog as a guest.'**
  String get signOutConfirmGuestStay;

  /// No description provided for @deleteAccountUpper.
  ///
  /// In en, this message translates to:
  /// **'DELETE ACCOUNT'**
  String get deleteAccountUpper;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove your profile, listings, and access'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountConfirmTitleUpper.
  ///
  /// In en, this message translates to:
  /// **'DELETE ACCOUNT?'**
  String get deleteAccountConfirmTitleUpper;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account, profiles, selections, messages, and related data will be permanently deleted.'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @deleteAccountConfirmActionUpper.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAccountConfirmActionUpper;

  /// No description provided for @deleteAccountSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Account deletion will work after applying delete_my_account.sql in Supabase.'**
  String get deleteAccountSetupRequired;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t delete the account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @rangeFromTo.
  ///
  /// In en, this message translates to:
  /// **'from {from} to {to}'**
  String rangeFromTo(int from, int to);

  /// No description provided for @shoeSize.
  ///
  /// In en, this message translates to:
  /// **'Shoe size'**
  String get shoeSize;

  /// No description provided for @shoeSizeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 39'**
  String get shoeSizeHint;

  /// No description provided for @bust.
  ///
  /// In en, this message translates to:
  /// **'Bust'**
  String get bust;

  /// No description provided for @bustHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 90'**
  String get bustHint;

  /// No description provided for @waist.
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get waist;

  /// No description provided for @waistHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 60'**
  String get waistHint;

  /// No description provided for @hips.
  ///
  /// In en, this message translates to:
  /// **'Hips'**
  String get hips;

  /// No description provided for @hipsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 90'**
  String get hipsHint;

  /// No description provided for @eyeColor.
  ///
  /// In en, this message translates to:
  /// **'Eye color'**
  String get eyeColor;

  /// No description provided for @eyeColorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. brown'**
  String get eyeColorHint;

  /// No description provided for @hairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair color'**
  String get hairColor;

  /// No description provided for @hairColorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. blonde'**
  String get hairColorHint;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Australia'**
  String get countryHint;

  /// No description provided for @cityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sydney'**
  String get cityHint;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @weekdayMonUpper.
  ///
  /// In en, this message translates to:
  /// **'MON'**
  String get weekdayMonUpper;

  /// No description provided for @weekdayTueUpper.
  ///
  /// In en, this message translates to:
  /// **'TUE'**
  String get weekdayTueUpper;

  /// No description provided for @weekdayWedUpper.
  ///
  /// In en, this message translates to:
  /// **'WED'**
  String get weekdayWedUpper;

  /// No description provided for @weekdayThuUpper.
  ///
  /// In en, this message translates to:
  /// **'THU'**
  String get weekdayThuUpper;

  /// No description provided for @weekdayFriUpper.
  ///
  /// In en, this message translates to:
  /// **'FRI'**
  String get weekdayFriUpper;

  /// No description provided for @weekdaySatUpper.
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get weekdaySatUpper;

  /// No description provided for @weekdaySunUpper.
  ///
  /// In en, this message translates to:
  /// **'SUN'**
  String get weekdaySunUpper;

  /// No description provided for @monthJanuaryUpper.
  ///
  /// In en, this message translates to:
  /// **'JANUARY'**
  String get monthJanuaryUpper;

  /// No description provided for @monthFebruaryUpper.
  ///
  /// In en, this message translates to:
  /// **'FEBRUARY'**
  String get monthFebruaryUpper;

  /// No description provided for @monthMarchUpper.
  ///
  /// In en, this message translates to:
  /// **'MARCH'**
  String get monthMarchUpper;

  /// No description provided for @monthAprilUpper.
  ///
  /// In en, this message translates to:
  /// **'APRIL'**
  String get monthAprilUpper;

  /// No description provided for @monthMayUpper.
  ///
  /// In en, this message translates to:
  /// **'MAY'**
  String get monthMayUpper;

  /// No description provided for @monthJuneUpper.
  ///
  /// In en, this message translates to:
  /// **'JUNE'**
  String get monthJuneUpper;

  /// No description provided for @monthJulyUpper.
  ///
  /// In en, this message translates to:
  /// **'JULY'**
  String get monthJulyUpper;

  /// No description provided for @monthAugustUpper.
  ///
  /// In en, this message translates to:
  /// **'AUGUST'**
  String get monthAugustUpper;

  /// No description provided for @monthSeptemberUpper.
  ///
  /// In en, this message translates to:
  /// **'SEPTEMBER'**
  String get monthSeptemberUpper;

  /// No description provided for @monthOctoberUpper.
  ///
  /// In en, this message translates to:
  /// **'OCTOBER'**
  String get monthOctoberUpper;

  /// No description provided for @monthNovemberUpper.
  ///
  /// In en, this message translates to:
  /// **'NOVEMBER'**
  String get monthNovemberUpper;

  /// No description provided for @monthDecemberUpper.
  ///
  /// In en, this message translates to:
  /// **'DECEMBER'**
  String get monthDecemberUpper;

  /// No description provided for @castingsUpper.
  ///
  /// In en, this message translates to:
  /// **'CASTINGS'**
  String get castingsUpper;

  /// No description provided for @castingsTab.
  ///
  /// In en, this message translates to:
  /// **'Castings'**
  String get castingsTab;

  /// No description provided for @catalogTab.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalogTab;

  /// No description provided for @invitationsTab.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get invitationsTab;

  /// No description provided for @myProfileTab.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get myProfileTab;

  /// No description provided for @adminTab.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminTab;

  /// No description provided for @billingTitleUpper.
  ///
  /// In en, this message translates to:
  /// **'PLANS'**
  String get billingTitleUpper;

  /// No description provided for @billingAccountEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current plan and limits'**
  String get billingAccountEntrySubtitle;

  /// No description provided for @billingCurrentUpper.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get billingCurrentUpper;

  /// No description provided for @billingPlanActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PLAN'**
  String get billingPlanActive;

  /// No description provided for @billingPlanFreeStatus.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PLAN'**
  String get billingPlanFreeStatus;

  /// No description provided for @billingPlanFree.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get billingPlanFree;

  /// No description provided for @billingPlanModelPro.
  ///
  /// In en, this message translates to:
  /// **'Model Pro'**
  String get billingPlanModelPro;

  /// No description provided for @billingPlanCastingAgentPro.
  ///
  /// In en, this message translates to:
  /// **'Casting Agent Pro'**
  String get billingPlanCastingAgentPro;

  /// No description provided for @billingPlanAgencyAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get billingPlanAgencyAdmin;

  /// No description provided for @billingFreeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog presence without active communication with clients.'**
  String get billingFreeSubtitle;

  /// No description provided for @billingModelProSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invitations, chat, and profile promotion for active work.'**
  String get billingModelProSubtitle;

  /// No description provided for @billingCastingProSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Professional tools for casting agents and client selections.'**
  String get billingCastingProSubtitle;

  /// No description provided for @billingAgencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Team access, exports, and analytics for agencies.'**
  String get billingAgencySubtitle;

  /// No description provided for @billingBasicCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog publishing and profile tools'**
  String get billingBasicCatalog;

  /// No description provided for @billingProfileLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {limit} profiles'**
  String billingProfileLimit(int limit);

  /// No description provided for @billingUnlimitedProfiles.
  ///
  /// In en, this message translates to:
  /// **'Unlimited profiles'**
  String get billingUnlimitedProfiles;

  /// No description provided for @billingInvitationsPreview.
  ///
  /// In en, this message translates to:
  /// **'See when you are invited or added to a selection'**
  String get billingInvitationsPreview;

  /// No description provided for @billingChatRequiresPro.
  ///
  /// In en, this message translates to:
  /// **'Open chat and reply with Model Pro'**
  String get billingChatRequiresPro;

  /// No description provided for @billingChatAndInvitations.
  ///
  /// In en, this message translates to:
  /// **'Full access to invitations and chat'**
  String get billingChatAndInvitations;

  /// No description provided for @billingProfileBoostsIncluded.
  ///
  /// In en, this message translates to:
  /// **'{count} profile boosts per month'**
  String billingProfileBoostsIncluded(int count);

  /// No description provided for @billingBasicAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Basic view statistics'**
  String get billingBasicAnalytics;

  /// No description provided for @billingBoostOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time profile boost'**
  String get billingBoostOneTime;

  /// No description provided for @billingBoostOneTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can be bought separately without Pro.'**
  String get billingBoostOneTimeSubtitle;

  /// No description provided for @billingBoostOneTimeFeature.
  ///
  /// In en, this message translates to:
  /// **'Move a selected profile higher in the catalog'**
  String get billingBoostOneTimeFeature;

  /// No description provided for @billingUpgradeRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Model Pro required'**
  String get billingUpgradeRequiredTitle;

  /// No description provided for @billingUpgradeRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'You can see the invitation, but opening chat and replying requires Model Pro.'**
  String get billingUpgradeRequiredMessage;

  /// No description provided for @billingUpgradeActionUpper.
  ///
  /// In en, this message translates to:
  /// **'VIEW PLANS'**
  String get billingUpgradeActionUpper;

  /// No description provided for @billingSelectionSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {limit} models in one selection'**
  String billingSelectionSizeLimit(int limit);

  /// No description provided for @billingSelectionCountLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {limit} active selections'**
  String billingSelectionCountLimit(int limit);

  /// No description provided for @billingUnlimitedSelectionSize.
  ///
  /// In en, this message translates to:
  /// **'Unlimited models in selections'**
  String get billingUnlimitedSelectionSize;

  /// No description provided for @billingUnlimitedSelections.
  ///
  /// In en, this message translates to:
  /// **'Unlimited selections'**
  String get billingUnlimitedSelections;

  /// No description provided for @billingProfileBoost.
  ///
  /// In en, this message translates to:
  /// **'Profile boost'**
  String get billingProfileBoost;

  /// No description provided for @billingExpandedMedia.
  ///
  /// In en, this message translates to:
  /// **'Expanded media gallery'**
  String get billingExpandedMedia;

  /// No description provided for @billingProBadge.
  ///
  /// In en, this message translates to:
  /// **'Pro badge'**
  String get billingProBadge;

  /// No description provided for @billingBrandedPdf.
  ///
  /// In en, this message translates to:
  /// **'Branded PDF export'**
  String get billingBrandedPdf;

  /// No description provided for @billingFoldersAndNotes.
  ///
  /// In en, this message translates to:
  /// **'Folders and private notes'**
  String get billingFoldersAndNotes;

  /// No description provided for @billingTeamAccess.
  ///
  /// In en, this message translates to:
  /// **'Team access'**
  String get billingTeamAccess;

  /// No description provided for @billingAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get billingAnalytics;

  /// No description provided for @billingExports.
  ///
  /// In en, this message translates to:
  /// **'Extended exports'**
  String get billingExports;

  /// No description provided for @billingPaymentsSoon.
  ///
  /// In en, this message translates to:
  /// **'Payments are not connected yet. This screen shows the tariff structure; Stripe or RevenueCat can be connected next.'**
  String get billingPaymentsSoon;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'How will you use ModelApp?'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your role once, and the app will open the right workflow first.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingModelTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a model'**
  String get onboardingModelTitle;

  /// No description provided for @onboardingModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a profile, add media, respond to castings, and track invitations.'**
  String get onboardingModelSubtitle;

  /// No description provided for @onboardingActorTitle.
  ///
  /// In en, this message translates to:
  /// **'I am an actor'**
  String get onboardingActorTitle;

  /// No description provided for @onboardingActorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an acting profile, add media, and respond to castings and projects.'**
  String get onboardingActorSubtitle;

  /// No description provided for @onboardingCastingTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a casting agent'**
  String get onboardingCastingTitle;

  /// No description provided for @onboardingCastingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search models, create selections, export PDFs, and manage client projects.'**
  String get onboardingCastingSubtitle;

  /// No description provided for @onboardingBrandTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a brand'**
  String get onboardingBrandTitle;

  /// No description provided for @onboardingBrandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find faces for campaigns, build selections, and review candidates with your team.'**
  String get onboardingBrandSubtitle;

  /// No description provided for @onboardingPhotographerTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a photographer'**
  String get onboardingPhotographerTitle;

  /// No description provided for @onboardingPhotographerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find models for shoots, tests, campaigns, and creative projects.'**
  String get onboardingPhotographerSubtitle;

  /// No description provided for @onboardingVideographerTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a videographer'**
  String get onboardingVideographerTitle;

  /// No description provided for @onboardingVideographerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find models and actors for video, reels, ads, and production work.'**
  String get onboardingVideographerSubtitle;

  /// No description provided for @onboardingStylistTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a stylist'**
  String get onboardingStylistTitle;

  /// No description provided for @onboardingStylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build teams for shoots, shows, lookbooks, and commercial projects.'**
  String get onboardingStylistSubtitle;

  /// No description provided for @onboardingMakeupArtistTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a makeup artist'**
  String get onboardingMakeupArtistTitle;

  /// No description provided for @onboardingMakeupArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find models for beauty shoots, tests, portfolio work, and client projects.'**
  String get onboardingMakeupArtistSubtitle;

  /// No description provided for @onboardingHairStylistTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a hair stylist'**
  String get onboardingHairStylistTitle;

  /// No description provided for @onboardingHairStylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find models for hair shoots, color work, tests, and creative projects.'**
  String get onboardingHairStylistSubtitle;

  /// No description provided for @onboardingChooseUpper.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE'**
  String get onboardingChooseUpper;

  /// No description provided for @onboardingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save your role. Please try again.'**
  String get onboardingSaveFailed;

  /// No description provided for @addProfileUpper.
  ///
  /// In en, this message translates to:
  /// **'ADD NEW PROFILE'**
  String get addProfileUpper;

  /// No description provided for @logoutUpper.
  ///
  /// In en, this message translates to:
  /// **'LOG OUT'**
  String get logoutUpper;

  /// No description provided for @registerFillBelow.
  ///
  /// In en, this message translates to:
  /// **'Fill in the details'**
  String get registerFillBelow;

  /// No description provided for @accountTypeUpper.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT TYPE'**
  String get accountTypeUpper;

  /// No description provided for @accountTypeUser.
  ///
  /// In en, this message translates to:
  /// **'REGULAR'**
  String get accountTypeUser;

  /// No description provided for @accountTypeCastingAgent.
  ///
  /// In en, this message translates to:
  /// **'CASTING AGENT'**
  String get accountTypeCastingAgent;

  /// No description provided for @passwordRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get passwordRepeat;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDontMatch;

  /// No description provided for @signUpGenericError.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please try again.'**
  String get signUpGenericError;

  /// No description provided for @signUpDatabaseError.
  ///
  /// In en, this message translates to:
  /// **'Supabase failed while creating the user. Run auth_signup_trigger_hard_reset.sql and try a new email.'**
  String get signUpDatabaseError;

  /// No description provided for @notRegisteredTitle.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE NOT REGISTERED'**
  String get notRegisteredTitle;

  /// No description provided for @notRegisteredMessage.
  ///
  /// In en, this message translates to:
  /// **'To open “My profile”, you need to sign in or sign up.'**
  String get notRegisteredMessage;

  /// No description provided for @adminExitUpper.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get adminExitUpper;

  /// No description provided for @adminCreateCastingUpper.
  ///
  /// In en, this message translates to:
  /// **'CREATE CASTING'**
  String get adminCreateCastingUpper;

  /// No description provided for @adminModelsCatalogUpper.
  ///
  /// In en, this message translates to:
  /// **'MODELS CATALOG'**
  String get adminModelsCatalogUpper;

  /// No description provided for @adminModerationUpper.
  ///
  /// In en, this message translates to:
  /// **'MODERATION'**
  String get adminModerationUpper;

  /// No description provided for @adminAgentApplicationsUpper.
  ///
  /// In en, this message translates to:
  /// **'AGENT REQUESTS'**
  String get adminAgentApplicationsUpper;

  /// No description provided for @adminAgentApplicationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO REQUESTS'**
  String get adminAgentApplicationsEmpty;

  /// No description provided for @agentApplicationApproveUpper.
  ///
  /// In en, this message translates to:
  /// **'APPROVE'**
  String get agentApplicationApproveUpper;

  /// No description provided for @agentApplicationRejectUpper.
  ///
  /// In en, this message translates to:
  /// **'REJECT'**
  String get agentApplicationRejectUpper;

  /// No description provided for @adminOnlyUpper.
  ///
  /// In en, this message translates to:
  /// **'THIS PAGE IS FOR ADMINS ONLY'**
  String get adminOnlyUpper;

  /// No description provided for @moderationRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get moderationRejectTitle;

  /// No description provided for @moderationRejectHint.
  ///
  /// In en, this message translates to:
  /// **'Comment for the model'**
  String get moderationRejectHint;

  /// No description provided for @moderationRejectRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose or write a reason'**
  String get moderationRejectRequired;

  /// No description provided for @moderationRejectActionUpper.
  ///
  /// In en, this message translates to:
  /// **'REJECT'**
  String get moderationRejectActionUpper;

  /// No description provided for @moderationRejectPoorPhotos.
  ///
  /// In en, this message translates to:
  /// **'Low-quality photos'**
  String get moderationRejectPoorPhotos;

  /// No description provided for @moderationRejectFaceNotVisible.
  ///
  /// In en, this message translates to:
  /// **'Face is not visible'**
  String get moderationRejectFaceNotVisible;

  /// No description provided for @moderationRejectIncompleteData.
  ///
  /// In en, this message translates to:
  /// **'Incomplete details'**
  String get moderationRejectIncompleteData;

  /// No description provided for @moderationRejectInvalidMedia.
  ///
  /// In en, this message translates to:
  /// **'Unsuitable media'**
  String get moderationRejectInvalidMedia;

  /// No description provided for @moderationRejectSuspicious.
  ///
  /// In en, this message translates to:
  /// **'Suspicious profile'**
  String get moderationRejectSuspicious;

  /// No description provided for @castingTitle.
  ///
  /// In en, this message translates to:
  /// **'Casting title'**
  String get castingTitle;

  /// No description provided for @projectDescription.
  ///
  /// In en, this message translates to:
  /// **'Project description'**
  String get projectDescription;

  /// No description provided for @rights.
  ///
  /// In en, this message translates to:
  /// **'Rights'**
  String get rights;

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// No description provided for @dates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get dates;

  /// No description provided for @backUpper.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get backUpper;

  /// No description provided for @profileCreateUpper.
  ///
  /// In en, this message translates to:
  /// **'CREATE PROFILE'**
  String get profileCreateUpper;

  /// No description provided for @profileTypeUpper.
  ///
  /// In en, this message translates to:
  /// **'PROFILE TYPE'**
  String get profileTypeUpper;

  /// No description provided for @profileTypeModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get profileTypeModel;

  /// No description provided for @profileTypeActor.
  ///
  /// In en, this message translates to:
  /// **'Actor'**
  String get profileTypeActor;

  /// No description provided for @profileTypePhotographer.
  ///
  /// In en, this message translates to:
  /// **'Photographer'**
  String get profileTypePhotographer;

  /// No description provided for @profileTypeVideographer.
  ///
  /// In en, this message translates to:
  /// **'Videographer'**
  String get profileTypeVideographer;

  /// No description provided for @profileTypeStylist.
  ///
  /// In en, this message translates to:
  /// **'Stylist'**
  String get profileTypeStylist;

  /// No description provided for @profileTypeMakeupArtist.
  ///
  /// In en, this message translates to:
  /// **'Makeup artist'**
  String get profileTypeMakeupArtist;

  /// No description provided for @profileTypeHairStylist.
  ///
  /// In en, this message translates to:
  /// **'Hair stylist'**
  String get profileTypeHairStylist;

  /// No description provided for @profileTypeSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Who are you adding?'**
  String get profileTypeSelectTitle;

  /// No description provided for @profileTypeSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the profile type. One account can manage several different profiles.'**
  String get profileTypeSelectSubtitle;

  /// No description provided for @profilePhysicalDetailsUpper.
  ///
  /// In en, this message translates to:
  /// **'PHYSICAL DETAILS'**
  String get profilePhysicalDetailsUpper;

  /// No description provided for @profileProfessionalInfoUpper.
  ///
  /// In en, this message translates to:
  /// **'PROFESSIONAL INFO'**
  String get profileProfessionalInfoUpper;

  /// No description provided for @profileSurname.
  ///
  /// In en, this message translates to:
  /// **'Surname'**
  String get profileSurname;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get profileAge;

  /// No description provided for @profileHeightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get profileHeightCm;

  /// No description provided for @profileBustCm.
  ///
  /// In en, this message translates to:
  /// **'Bust (cm)'**
  String get profileBustCm;

  /// No description provided for @profileWaistCm.
  ///
  /// In en, this message translates to:
  /// **'Waist (cm)'**
  String get profileWaistCm;

  /// No description provided for @profileHipsCm.
  ///
  /// In en, this message translates to:
  /// **'Hips (cm)'**
  String get profileHipsCm;

  /// No description provided for @profileShoeSize.
  ///
  /// In en, this message translates to:
  /// **'Shoe size'**
  String get profileShoeSize;

  /// No description provided for @profileEyeColor.
  ///
  /// In en, this message translates to:
  /// **'Eye color'**
  String get profileEyeColor;

  /// No description provided for @profileHairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair color'**
  String get profileHairColor;

  /// No description provided for @profileCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get profileCountry;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profileAboutHint.
  ///
  /// In en, this message translates to:
  /// **'About you (experience, skills, links)'**
  String get profileAboutHint;

  /// No description provided for @profileMediaUpper.
  ///
  /// In en, this message translates to:
  /// **'MEDIA'**
  String get profileMediaUpper;

  /// No description provided for @profileResumeUpper.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get profileResumeUpper;

  /// No description provided for @profileCalendarUpper.
  ///
  /// In en, this message translates to:
  /// **'CALENDAR'**
  String get profileCalendarUpper;

  /// No description provided for @profileSubmitUpper.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT FOR REVIEW'**
  String get profileSubmitUpper;

  /// No description provided for @profileSaveUpper.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get profileSaveUpper;

  /// No description provided for @profileDeleteUpper.
  ///
  /// In en, this message translates to:
  /// **'DELETE PROFILE'**
  String get profileDeleteUpper;

  /// No description provided for @profileAddPhotoUpper.
  ///
  /// In en, this message translates to:
  /// **'ADD PHOTO'**
  String get profileAddPhotoUpper;

  /// No description provided for @profileAddVideoUpper.
  ///
  /// In en, this message translates to:
  /// **'ADD VIDEO'**
  String get profileAddVideoUpper;

  /// No description provided for @profileMediaEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos/videos yet'**
  String get profileMediaEmpty;

  /// No description provided for @profileQualityComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile completed {percent}%'**
  String profileQualityComplete(int percent);

  /// No description provided for @profileQualityReady.
  ///
  /// In en, this message translates to:
  /// **'Looks good: the profile is ready for moderation.'**
  String get profileQualityReady;

  /// No description provided for @profileQualityRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Fill in required measurements and location fields'**
  String get profileQualityRequiredFields;

  /// No description provided for @profileQualityPortraitPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a clear portrait photo'**
  String get profileQualityPortraitPhoto;

  /// No description provided for @profileQualityFullBodyPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a full-height photo'**
  String get profileQualityFullBodyPhoto;

  /// No description provided for @profileQualityProfessionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Add experience, services, genres, or skills'**
  String get profileQualityProfessionalInfo;

  /// No description provided for @profileQualityAbout.
  ///
  /// In en, this message translates to:
  /// **'Add a short description: experience, skills, links'**
  String get profileQualityAbout;

  /// No description provided for @profileQualityVideo.
  ///
  /// In en, this message translates to:
  /// **'Add a video intro if you have one'**
  String get profileQualityVideo;

  /// No description provided for @profileExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience, clients, publications'**
  String get profileExperience;

  /// No description provided for @profileActingExperience.
  ///
  /// In en, this message translates to:
  /// **'Acting experience, projects, education'**
  String get profileActingExperience;

  /// No description provided for @profileSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills and specialization'**
  String get profileSkills;

  /// No description provided for @profileActorSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills: languages, sport, dance, voice'**
  String get profileActorSkills;

  /// No description provided for @profileServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get profileServices;

  /// No description provided for @profileActorRoles.
  ///
  /// In en, this message translates to:
  /// **'Types and roles'**
  String get profileActorRoles;

  /// No description provided for @profileActingGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres: film, commercial, theatre'**
  String get profileActingGenres;

  /// No description provided for @profilePhotoGenres.
  ///
  /// In en, this message translates to:
  /// **'Shoot genres'**
  String get profilePhotoGenres;

  /// No description provided for @profileVideoGenres.
  ///
  /// In en, this message translates to:
  /// **'Video and production genres'**
  String get profileVideoGenres;

  /// No description provided for @profileWorkGenres.
  ///
  /// In en, this message translates to:
  /// **'Work directions'**
  String get profileWorkGenres;

  /// No description provided for @profileEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment / studio / locations'**
  String get profileEquipment;

  /// No description provided for @profileVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get profileVideo;

  /// No description provided for @profileVideoSelected.
  ///
  /// In en, this message translates to:
  /// **'Video selected'**
  String get profileVideoSelected;

  /// No description provided for @profileVideoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Video uploaded'**
  String get profileVideoUploaded;

  /// No description provided for @profileStatusPendingUpper.
  ///
  /// In en, this message translates to:
  /// **'PENDING REVIEW'**
  String get profileStatusPendingUpper;

  /// No description provided for @profileStatusPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile submitted and awaiting review'**
  String get profileStatusPendingSubtitle;

  /// No description provided for @profileStatusApprovedUpper.
  ///
  /// In en, this message translates to:
  /// **'APPROVED'**
  String get profileStatusApprovedUpper;

  /// No description provided for @profileStatusApprovedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile is live in the catalog'**
  String get profileStatusApprovedSubtitle;

  /// No description provided for @profileStatusRejectedUpper.
  ///
  /// In en, this message translates to:
  /// **'REJECTED'**
  String get profileStatusRejectedUpper;

  /// No description provided for @profileStatusRejectedSubtitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Fix the details and submit again'**
  String get profileStatusRejectedSubtitleDefault;

  /// No description provided for @profileStatusDraftUpper.
  ///
  /// In en, this message translates to:
  /// **'DRAFT'**
  String get profileStatusDraftUpper;

  /// No description provided for @profileStatusDraftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in the profile and submit for review'**
  String get profileStatusDraftSubtitle;

  /// No description provided for @profileVerifiedUpper.
  ///
  /// In en, this message translates to:
  /// **'PROFILE VERIFIED'**
  String get profileVerifiedUpper;

  /// No description provided for @profileVerifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This profile was confirmed by an administrator'**
  String get profileVerifiedSubtitle;

  /// No description provided for @profileVerificationAvailableUpper.
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION'**
  String get profileVerificationAvailableUpper;

  /// No description provided for @profileVerificationAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request review to receive a trust mark'**
  String get profileVerificationAvailableSubtitle;

  /// No description provided for @profileVerificationPendingUpper.
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION PENDING'**
  String get profileVerificationPendingUpper;

  /// No description provided for @profileVerificationPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An administrator will review the profile and add the mark'**
  String get profileVerificationPendingSubtitle;

  /// No description provided for @profileVerificationRejectedUpper.
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION REJECTED'**
  String get profileVerificationRejectedUpper;

  /// No description provided for @profileVerificationRejectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check the details and request verification again'**
  String get profileVerificationRejectedSubtitle;

  /// No description provided for @profileVerificationRequestUpper.
  ///
  /// In en, this message translates to:
  /// **'REQUEST'**
  String get profileVerificationRequestUpper;

  /// No description provided for @profileVerificationRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t request verification. Please try again.'**
  String get profileVerificationRequestFailed;

  /// No description provided for @profileErrorSurnameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your surname'**
  String get profileErrorSurnameRequired;

  /// No description provided for @profileErrorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get profileErrorNameRequired;

  /// No description provided for @profileErrorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save. Please try again.'**
  String get profileErrorSaveFailed;

  /// No description provided for @profileErrorDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t delete. Please try again.'**
  String get profileErrorDeleteFailed;

  /// No description provided for @profileErrorLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Your current plan profile limit is reached. Upgrade to Model Pro or remove an extra profile.'**
  String get profileErrorLimitReached;

  /// No description provided for @profileErrorNoUser.
  ///
  /// In en, this message translates to:
  /// **'No user'**
  String get profileErrorNoUser;

  /// No description provided for @profileErrorFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in your full name before submitting'**
  String get profileErrorFullNameRequired;

  /// No description provided for @profileErrorAgeRequired.
  ///
  /// In en, this message translates to:
  /// **'Add age'**
  String get profileErrorAgeRequired;

  /// No description provided for @profileErrorAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age must be 14–70'**
  String get profileErrorAgeRange;

  /// No description provided for @profileErrorHeightRequired.
  ///
  /// In en, this message translates to:
  /// **'Add height'**
  String get profileErrorHeightRequired;

  /// No description provided for @profileErrorHeightRange.
  ///
  /// In en, this message translates to:
  /// **'Height must be 120–220 cm'**
  String get profileErrorHeightRange;

  /// No description provided for @profileErrorBustRequired.
  ///
  /// In en, this message translates to:
  /// **'Add bust measurements'**
  String get profileErrorBustRequired;

  /// No description provided for @profileErrorBustRange.
  ///
  /// In en, this message translates to:
  /// **'Bust must be 40–140 cm'**
  String get profileErrorBustRange;

  /// No description provided for @profileErrorWaistRequired.
  ///
  /// In en, this message translates to:
  /// **'Add waist measurements'**
  String get profileErrorWaistRequired;

  /// No description provided for @profileErrorWaistRange.
  ///
  /// In en, this message translates to:
  /// **'Waist must be 40–140 cm'**
  String get profileErrorWaistRange;

  /// No description provided for @profileErrorHipsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add hips measurements'**
  String get profileErrorHipsRequired;

  /// No description provided for @profileErrorHipsRange.
  ///
  /// In en, this message translates to:
  /// **'Hips must be 40–140 cm'**
  String get profileErrorHipsRange;

  /// No description provided for @profileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile: {error}'**
  String profileLoadError(Object error);

  /// No description provided for @profileMediaPreviewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Photo/video previews will appear here'**
  String get profileMediaPreviewPlaceholder;

  /// No description provided for @bootstrapErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize the application.\nPlease check Supabase configuration and restart.'**
  String get bootstrapErrorMessage;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get retryButton;

  /// No description provided for @bootstrapConfigErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration error'**
  String get bootstrapConfigErrorTitle;

  /// No description provided for @bootstrapConfigErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Supabase is not configured.\n\nRun the app with:\n--dart-define=SUPABASE_URL=...\n--dart-define=SUPABASE_ANON_KEY=...'**
  String get bootstrapConfigErrorMessage;

  /// No description provided for @bootstrapInitErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Startup error'**
  String get bootstrapInitErrorTitle;

  /// No description provided for @bootstrapInitErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize Supabase:'**
  String get bootstrapInitErrorMessage;

  /// No description provided for @loadingDots.
  ///
  /// In en, this message translates to:
  /// **'...'**
  String get loadingDots;

  /// No description provided for @respondUpper.
  ///
  /// In en, this message translates to:
  /// **'RESPOND'**
  String get respondUpper;

  /// No description provided for @respondAuthRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN REQUIRED'**
  String get respondAuthRequiredTitle;

  /// No description provided for @respondAuthRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'To respond to a casting, please sign in or create an account.'**
  String get respondAuthRequiredMessage;

  /// No description provided for @respondSentMessage.
  ///
  /// In en, this message translates to:
  /// **'RESPONSE SENT'**
  String get respondSentMessage;

  /// No description provided for @respondChooseProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE PROFILES'**
  String get respondChooseProfilesTitle;

  /// No description provided for @respondChooseProfilesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have multiple profiles. Select one or more to respond.'**
  String get respondChooseProfilesMessage;

  /// No description provided for @respondNoProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'NO PROFILES'**
  String get respondNoProfilesTitle;

  /// No description provided for @respondNoProfilesMessage.
  ///
  /// In en, this message translates to:
  /// **'To respond, create a profile first in the Profile section.'**
  String get respondNoProfilesMessage;

  /// No description provided for @castingResponseStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'SUBMITTED'**
  String get castingResponseStatusSubmitted;

  /// No description provided for @castingResponseStatusViewed.
  ///
  /// In en, this message translates to:
  /// **'VIEWED'**
  String get castingResponseStatusViewed;

  /// No description provided for @castingResponseStatusInvited.
  ///
  /// In en, this message translates to:
  /// **'INVITED'**
  String get castingResponseStatusInvited;

  /// No description provided for @castingResponseStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'REJECTED'**
  String get castingResponseStatusRejected;

  /// No description provided for @goToProfileUpper.
  ///
  /// In en, this message translates to:
  /// **'GO TO PROFILE'**
  String get goToProfileUpper;

  /// No description provided for @profileUpper.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileUpper;

  /// No description provided for @selectionUpper.
  ///
  /// In en, this message translates to:
  /// **'SELECTION'**
  String get selectionUpper;

  /// No description provided for @selectionStatusUpper.
  ///
  /// In en, this message translates to:
  /// **'SELECTION STATUS'**
  String get selectionStatusUpper;

  /// No description provided for @selectionStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get selectionStatusDraft;

  /// No description provided for @selectionStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to client'**
  String get selectionStatusSent;

  /// No description provided for @selectionStatusViewed.
  ///
  /// In en, this message translates to:
  /// **'Client viewed'**
  String get selectionStatusViewed;

  /// No description provided for @selectionStatusSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selectionStatusSelected;

  /// No description provided for @selectionStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get selectionStatusRejected;

  /// No description provided for @responsesUpper.
  ///
  /// In en, this message translates to:
  /// **'RESPONSES'**
  String get responsesUpper;

  /// No description provided for @noCastingsMessage.
  ///
  /// In en, this message translates to:
  /// **'NO CASTINGS'**
  String get noCastingsMessage;

  /// No description provided for @noResponsesMessage.
  ///
  /// In en, this message translates to:
  /// **'NO RESPONSES'**
  String get noResponsesMessage;

  /// No description provided for @errorUpper.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get errorUpper;

  /// No description provided for @ageShort.
  ///
  /// In en, this message translates to:
  /// **'age'**
  String get ageShort;

  /// No description provided for @heightShort.
  ///
  /// In en, this message translates to:
  /// **'height'**
  String get heightShort;

  /// No description provided for @profileMinHourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Min. hourly rate'**
  String get profileMinHourlyRate;

  /// No description provided for @profileMinDailyFee.
  ///
  /// In en, this message translates to:
  /// **'Min. daily fee'**
  String get profileMinDailyFee;

  /// No description provided for @profileDetailsUpper.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get profileDetailsUpper;

  /// No description provided for @profileNoName.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get profileNoName;

  /// No description provided for @profileResumeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Resume will be added later.'**
  String get profileResumeEmpty;

  /// No description provided for @profileNotFoundUpper.
  ///
  /// In en, this message translates to:
  /// **'PROFILE NOT FOUND'**
  String get profileNotFoundUpper;

  /// No description provided for @retryUpper.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get retryUpper;

  /// No description provided for @noCastingsYetUpper.
  ///
  /// In en, this message translates to:
  /// **'NO CASTINGS YET'**
  String get noCastingsYetUpper;

  /// No description provided for @profileNotFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It may not be approved yet or may have been deleted.'**
  String get profileNotFoundSubtitle;

  /// No description provided for @advancedMinHourlyRateUpper.
  ///
  /// In en, this message translates to:
  /// **'MIN. HOURLY RATE'**
  String get advancedMinHourlyRateUpper;

  /// No description provided for @advancedMinDailyFeeUpper.
  ///
  /// In en, this message translates to:
  /// **'MIN. DAILY FEE'**
  String get advancedMinDailyFeeUpper;

  /// No description provided for @selectedUpper.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get selectedUpper;

  /// No description provided for @selectUpper.
  ///
  /// In en, this message translates to:
  /// **'SELECT'**
  String get selectUpper;

  /// No description provided for @projectTitleUpper.
  ///
  /// In en, this message translates to:
  /// **'PROJECT TITLE'**
  String get projectTitleUpper;

  /// No description provided for @enterProjectTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter title'**
  String get enterProjectTitleHint;

  /// No description provided for @enterProjectTitleError.
  ///
  /// In en, this message translates to:
  /// **'Enter project title'**
  String get enterProjectTitleError;

  /// No description provided for @cancelUpper.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelUpper;

  /// No description provided for @saveUpper.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get saveUpper;

  /// No description provided for @pdfOptionPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get pdfOptionPhoto;

  /// No description provided for @pdfOptionFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get pdfOptionFullName;

  /// No description provided for @pdfOptionMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get pdfOptionMeasurements;

  /// No description provided for @pdfOptionModelLink.
  ///
  /// In en, this message translates to:
  /// **'Model link'**
  String get pdfOptionModelLink;

  /// No description provided for @deleteSelectedItemsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete selected items ({count})?'**
  String deleteSelectedItemsConfirm(int count);

  /// No description provided for @profileTitleUpper.
  ///
  /// In en, this message translates to:
  /// **'Questionnaire'**
  String get profileTitleUpper;

  /// No description provided for @profileDeleteMediaConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete media'**
  String get profileDeleteMediaConfirmTitle;

  /// No description provided for @profileDeleteMediaConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this file?'**
  String get profileDeleteMediaConfirmMessage;

  /// No description provided for @profileDeleteMediaDontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get profileDeleteMediaDontAskAgain;

  /// No description provided for @yesUpper.
  ///
  /// In en, this message translates to:
  /// **'YES'**
  String get yesUpper;

  /// No description provided for @noUpper.
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get noUpper;

  /// No description provided for @profileSubmitRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Submission required'**
  String get profileSubmitRequiredTitle;

  /// No description provided for @profileSubmitRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'You added new photos or videos. To apply these changes, the profile must be sent for moderation.'**
  String get profileSubmitRequiredMessage;

  /// No description provided for @okUpper.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okUpper;

  /// No description provided for @countryRussia.
  ///
  /// In en, this message translates to:
  /// **'Russia'**
  String get countryRussia;

  /// No description provided for @countryAustralia.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get countryAustralia;

  /// No description provided for @countryAustria.
  ///
  /// In en, this message translates to:
  /// **'Austria'**
  String get countryAustria;

  /// No description provided for @countryBelarus.
  ///
  /// In en, this message translates to:
  /// **'Belarus'**
  String get countryBelarus;

  /// No description provided for @countryBelgium.
  ///
  /// In en, this message translates to:
  /// **'Belgium'**
  String get countryBelgium;

  /// No description provided for @countryBulgaria.
  ///
  /// In en, this message translates to:
  /// **'Bulgaria'**
  String get countryBulgaria;

  /// No description provided for @countryUnitedKingdom.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get countryUnitedKingdom;

  /// No description provided for @countryGermany.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get countryGermany;

  /// No description provided for @countryGreece.
  ///
  /// In en, this message translates to:
  /// **'Greece'**
  String get countryGreece;

  /// No description provided for @countryGeorgia.
  ///
  /// In en, this message translates to:
  /// **'Georgia'**
  String get countryGeorgia;

  /// No description provided for @countrySpain.
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get countrySpain;

  /// No description provided for @countryItaly.
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get countryItaly;

  /// No description provided for @countryKazakhstan.
  ///
  /// In en, this message translates to:
  /// **'Kazakhstan'**
  String get countryKazakhstan;

  /// No description provided for @countryCanada.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get countryCanada;

  /// No description provided for @countryCyprus.
  ///
  /// In en, this message translates to:
  /// **'Cyprus'**
  String get countryCyprus;

  /// No description provided for @countryNetherlands.
  ///
  /// In en, this message translates to:
  /// **'Netherlands'**
  String get countryNetherlands;

  /// No description provided for @countryUae.
  ///
  /// In en, this message translates to:
  /// **'UAE'**
  String get countryUae;

  /// No description provided for @countryPoland.
  ///
  /// In en, this message translates to:
  /// **'Poland'**
  String get countryPoland;

  /// No description provided for @countryPortugal.
  ///
  /// In en, this message translates to:
  /// **'Portugal'**
  String get countryPortugal;

  /// No description provided for @countryUsa.
  ///
  /// In en, this message translates to:
  /// **'USA'**
  String get countryUsa;

  /// No description provided for @countryTurkey.
  ///
  /// In en, this message translates to:
  /// **'Turkey'**
  String get countryTurkey;

  /// No description provided for @countryUzbekistan.
  ///
  /// In en, this message translates to:
  /// **'Uzbekistan'**
  String get countryUzbekistan;

  /// No description provided for @countryFrance.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get countryFrance;

  /// No description provided for @countryCzechia.
  ///
  /// In en, this message translates to:
  /// **'Czechia'**
  String get countryCzechia;

  /// No description provided for @countrySwitzerland.
  ///
  /// In en, this message translates to:
  /// **'Switzerland'**
  String get countrySwitzerland;

  /// No description provided for @cityMoscow.
  ///
  /// In en, this message translates to:
  /// **'Moscow'**
  String get cityMoscow;

  /// No description provided for @citySaintPetersburg.
  ///
  /// In en, this message translates to:
  /// **'Saint Petersburg'**
  String get citySaintPetersburg;

  /// No description provided for @cityKazan.
  ///
  /// In en, this message translates to:
  /// **'Kazan'**
  String get cityKazan;

  /// No description provided for @cityYekaterinburg.
  ///
  /// In en, this message translates to:
  /// **'Yekaterinburg'**
  String get cityYekaterinburg;

  /// No description provided for @cityNovosibirsk.
  ///
  /// In en, this message translates to:
  /// **'Novosibirsk'**
  String get cityNovosibirsk;

  /// No description provided for @citySochi.
  ///
  /// In en, this message translates to:
  /// **'Sochi'**
  String get citySochi;

  /// No description provided for @cityKrasnodar.
  ///
  /// In en, this message translates to:
  /// **'Krasnodar'**
  String get cityKrasnodar;

  /// No description provided for @cityRostovOnDon.
  ///
  /// In en, this message translates to:
  /// **'Rostov-on-Don'**
  String get cityRostovOnDon;

  /// No description provided for @cityNizhnyNovgorod.
  ///
  /// In en, this message translates to:
  /// **'Nizhny Novgorod'**
  String get cityNizhnyNovgorod;

  /// No description provided for @citySamara.
  ///
  /// In en, this message translates to:
  /// **'Samara'**
  String get citySamara;

  /// No description provided for @cityUfa.
  ///
  /// In en, this message translates to:
  /// **'Ufa'**
  String get cityUfa;

  /// No description provided for @cityVladivostok.
  ///
  /// In en, this message translates to:
  /// **'Vladivostok'**
  String get cityVladivostok;

  /// No description provided for @citySydney.
  ///
  /// In en, this message translates to:
  /// **'Sydney'**
  String get citySydney;

  /// No description provided for @cityMelbourne.
  ///
  /// In en, this message translates to:
  /// **'Melbourne'**
  String get cityMelbourne;

  /// No description provided for @cityBrisbane.
  ///
  /// In en, this message translates to:
  /// **'Brisbane'**
  String get cityBrisbane;

  /// No description provided for @cityPerth.
  ///
  /// In en, this message translates to:
  /// **'Perth'**
  String get cityPerth;

  /// No description provided for @cityAdelaide.
  ///
  /// In en, this message translates to:
  /// **'Adelaide'**
  String get cityAdelaide;

  /// No description provided for @cityGoldCoast.
  ///
  /// In en, this message translates to:
  /// **'Gold Coast'**
  String get cityGoldCoast;

  /// No description provided for @cityCanberra.
  ///
  /// In en, this message translates to:
  /// **'Canberra'**
  String get cityCanberra;

  /// No description provided for @cityVienna.
  ///
  /// In en, this message translates to:
  /// **'Vienna'**
  String get cityVienna;

  /// No description provided for @citySalzburg.
  ///
  /// In en, this message translates to:
  /// **'Salzburg'**
  String get citySalzburg;

  /// No description provided for @cityGraz.
  ///
  /// In en, this message translates to:
  /// **'Graz'**
  String get cityGraz;

  /// No description provided for @cityInnsbruck.
  ///
  /// In en, this message translates to:
  /// **'Innsbruck'**
  String get cityInnsbruck;

  /// No description provided for @cityLinz.
  ///
  /// In en, this message translates to:
  /// **'Linz'**
  String get cityLinz;

  /// No description provided for @cityMinsk.
  ///
  /// In en, this message translates to:
  /// **'Minsk'**
  String get cityMinsk;

  /// No description provided for @cityBrest.
  ///
  /// In en, this message translates to:
  /// **'Brest'**
  String get cityBrest;

  /// No description provided for @cityGrodno.
  ///
  /// In en, this message translates to:
  /// **'Grodno'**
  String get cityGrodno;

  /// No description provided for @cityVitebsk.
  ///
  /// In en, this message translates to:
  /// **'Vitebsk'**
  String get cityVitebsk;

  /// No description provided for @cityGomel.
  ///
  /// In en, this message translates to:
  /// **'Gomel'**
  String get cityGomel;

  /// No description provided for @cityBrussels.
  ///
  /// In en, this message translates to:
  /// **'Brussels'**
  String get cityBrussels;

  /// No description provided for @cityAntwerp.
  ///
  /// In en, this message translates to:
  /// **'Antwerp'**
  String get cityAntwerp;

  /// No description provided for @cityGhent.
  ///
  /// In en, this message translates to:
  /// **'Ghent'**
  String get cityGhent;

  /// No description provided for @cityBruges.
  ///
  /// In en, this message translates to:
  /// **'Bruges'**
  String get cityBruges;

  /// No description provided for @cityLiege.
  ///
  /// In en, this message translates to:
  /// **'Liege'**
  String get cityLiege;

  /// No description provided for @citySofia.
  ///
  /// In en, this message translates to:
  /// **'Sofia'**
  String get citySofia;

  /// No description provided for @cityVarna.
  ///
  /// In en, this message translates to:
  /// **'Varna'**
  String get cityVarna;

  /// No description provided for @cityBurgas.
  ///
  /// In en, this message translates to:
  /// **'Burgas'**
  String get cityBurgas;

  /// No description provided for @cityPlovdiv.
  ///
  /// In en, this message translates to:
  /// **'Plovdiv'**
  String get cityPlovdiv;

  /// No description provided for @cityLondon.
  ///
  /// In en, this message translates to:
  /// **'London'**
  String get cityLondon;

  /// No description provided for @cityManchester.
  ///
  /// In en, this message translates to:
  /// **'Manchester'**
  String get cityManchester;

  /// No description provided for @cityLiverpool.
  ///
  /// In en, this message translates to:
  /// **'Liverpool'**
  String get cityLiverpool;

  /// No description provided for @cityBirmingham.
  ///
  /// In en, this message translates to:
  /// **'Birmingham'**
  String get cityBirmingham;

  /// No description provided for @cityEdinburgh.
  ///
  /// In en, this message translates to:
  /// **'Edinburgh'**
  String get cityEdinburgh;

  /// No description provided for @cityGlasgow.
  ///
  /// In en, this message translates to:
  /// **'Glasgow'**
  String get cityGlasgow;

  /// No description provided for @cityBerlin.
  ///
  /// In en, this message translates to:
  /// **'Berlin'**
  String get cityBerlin;

  /// No description provided for @cityMunich.
  ///
  /// In en, this message translates to:
  /// **'Munich'**
  String get cityMunich;

  /// No description provided for @cityHamburg.
  ///
  /// In en, this message translates to:
  /// **'Hamburg'**
  String get cityHamburg;

  /// No description provided for @cityFrankfurt.
  ///
  /// In en, this message translates to:
  /// **'Frankfurt'**
  String get cityFrankfurt;

  /// No description provided for @cityCologne.
  ///
  /// In en, this message translates to:
  /// **'Cologne'**
  String get cityCologne;

  /// No description provided for @cityDusseldorf.
  ///
  /// In en, this message translates to:
  /// **'Dusseldorf'**
  String get cityDusseldorf;

  /// No description provided for @cityStuttgart.
  ///
  /// In en, this message translates to:
  /// **'Stuttgart'**
  String get cityStuttgart;

  /// No description provided for @cityAthens.
  ///
  /// In en, this message translates to:
  /// **'Athens'**
  String get cityAthens;

  /// No description provided for @cityThessaloniki.
  ///
  /// In en, this message translates to:
  /// **'Thessaloniki'**
  String get cityThessaloniki;

  /// No description provided for @cityHeraklion.
  ///
  /// In en, this message translates to:
  /// **'Heraklion'**
  String get cityHeraklion;

  /// No description provided for @cityPatras.
  ///
  /// In en, this message translates to:
  /// **'Patras'**
  String get cityPatras;

  /// No description provided for @cityTbilisi.
  ///
  /// In en, this message translates to:
  /// **'Tbilisi'**
  String get cityTbilisi;

  /// No description provided for @cityBatumi.
  ///
  /// In en, this message translates to:
  /// **'Batumi'**
  String get cityBatumi;

  /// No description provided for @cityKutaisi.
  ///
  /// In en, this message translates to:
  /// **'Kutaisi'**
  String get cityKutaisi;

  /// No description provided for @cityMadrid.
  ///
  /// In en, this message translates to:
  /// **'Madrid'**
  String get cityMadrid;

  /// No description provided for @cityBarcelona.
  ///
  /// In en, this message translates to:
  /// **'Barcelona'**
  String get cityBarcelona;

  /// No description provided for @cityValencia.
  ///
  /// In en, this message translates to:
  /// **'Valencia'**
  String get cityValencia;

  /// No description provided for @citySeville.
  ///
  /// In en, this message translates to:
  /// **'Seville'**
  String get citySeville;

  /// No description provided for @cityMalaga.
  ///
  /// In en, this message translates to:
  /// **'Malaga'**
  String get cityMalaga;

  /// No description provided for @cityAlicante.
  ///
  /// In en, this message translates to:
  /// **'Alicante'**
  String get cityAlicante;

  /// No description provided for @cityIbiza.
  ///
  /// In en, this message translates to:
  /// **'Ibiza'**
  String get cityIbiza;

  /// No description provided for @cityRome.
  ///
  /// In en, this message translates to:
  /// **'Rome'**
  String get cityRome;

  /// No description provided for @cityMilan.
  ///
  /// In en, this message translates to:
  /// **'Milan'**
  String get cityMilan;

  /// No description provided for @cityFlorence.
  ///
  /// In en, this message translates to:
  /// **'Florence'**
  String get cityFlorence;

  /// No description provided for @cityVenice.
  ///
  /// In en, this message translates to:
  /// **'Venice'**
  String get cityVenice;

  /// No description provided for @cityNaples.
  ///
  /// In en, this message translates to:
  /// **'Naples'**
  String get cityNaples;

  /// No description provided for @cityTurin.
  ///
  /// In en, this message translates to:
  /// **'Turin'**
  String get cityTurin;

  /// No description provided for @cityBologna.
  ///
  /// In en, this message translates to:
  /// **'Bologna'**
  String get cityBologna;

  /// No description provided for @cityAlmaty.
  ///
  /// In en, this message translates to:
  /// **'Almaty'**
  String get cityAlmaty;

  /// No description provided for @cityAstana.
  ///
  /// In en, this message translates to:
  /// **'Astana'**
  String get cityAstana;

  /// No description provided for @cityShymkent.
  ///
  /// In en, this message translates to:
  /// **'Shymkent'**
  String get cityShymkent;

  /// No description provided for @cityKaraganda.
  ///
  /// In en, this message translates to:
  /// **'Karaganda'**
  String get cityKaraganda;

  /// No description provided for @cityAtyrau.
  ///
  /// In en, this message translates to:
  /// **'Atyrau'**
  String get cityAtyrau;

  /// No description provided for @cityToronto.
  ///
  /// In en, this message translates to:
  /// **'Toronto'**
  String get cityToronto;

  /// No description provided for @cityVancouver.
  ///
  /// In en, this message translates to:
  /// **'Vancouver'**
  String get cityVancouver;

  /// No description provided for @cityMontreal.
  ///
  /// In en, this message translates to:
  /// **'Montreal'**
  String get cityMontreal;

  /// No description provided for @cityCalgary.
  ///
  /// In en, this message translates to:
  /// **'Calgary'**
  String get cityCalgary;

  /// No description provided for @cityOttawa.
  ///
  /// In en, this message translates to:
  /// **'Ottawa'**
  String get cityOttawa;

  /// No description provided for @cityNicosia.
  ///
  /// In en, this message translates to:
  /// **'Nicosia'**
  String get cityNicosia;

  /// No description provided for @cityLimassol.
  ///
  /// In en, this message translates to:
  /// **'Limassol'**
  String get cityLimassol;

  /// No description provided for @cityLarnaca.
  ///
  /// In en, this message translates to:
  /// **'Larnaca'**
  String get cityLarnaca;

  /// No description provided for @cityPaphos.
  ///
  /// In en, this message translates to:
  /// **'Paphos'**
  String get cityPaphos;

  /// No description provided for @cityAmsterdam.
  ///
  /// In en, this message translates to:
  /// **'Amsterdam'**
  String get cityAmsterdam;

  /// No description provided for @cityRotterdam.
  ///
  /// In en, this message translates to:
  /// **'Rotterdam'**
  String get cityRotterdam;

  /// No description provided for @cityTheHague.
  ///
  /// In en, this message translates to:
  /// **'The Hague'**
  String get cityTheHague;

  /// No description provided for @cityUtrecht.
  ///
  /// In en, this message translates to:
  /// **'Utrecht'**
  String get cityUtrecht;

  /// No description provided for @cityEindhoven.
  ///
  /// In en, this message translates to:
  /// **'Eindhoven'**
  String get cityEindhoven;

  /// No description provided for @cityDubai.
  ///
  /// In en, this message translates to:
  /// **'Dubai'**
  String get cityDubai;

  /// No description provided for @cityAbuDhabi.
  ///
  /// In en, this message translates to:
  /// **'Abu Dhabi'**
  String get cityAbuDhabi;

  /// No description provided for @citySharjah.
  ///
  /// In en, this message translates to:
  /// **'Sharjah'**
  String get citySharjah;

  /// No description provided for @cityAjman.
  ///
  /// In en, this message translates to:
  /// **'Ajman'**
  String get cityAjman;

  /// No description provided for @cityWarsaw.
  ///
  /// In en, this message translates to:
  /// **'Warsaw'**
  String get cityWarsaw;

  /// No description provided for @cityKrakow.
  ///
  /// In en, this message translates to:
  /// **'Krakow'**
  String get cityKrakow;

  /// No description provided for @cityWroclaw.
  ///
  /// In en, this message translates to:
  /// **'Wroclaw'**
  String get cityWroclaw;

  /// No description provided for @cityGdansk.
  ///
  /// In en, this message translates to:
  /// **'Gdansk'**
  String get cityGdansk;

  /// No description provided for @cityPoznan.
  ///
  /// In en, this message translates to:
  /// **'Poznan'**
  String get cityPoznan;

  /// No description provided for @cityLisbon.
  ///
  /// In en, this message translates to:
  /// **'Lisbon'**
  String get cityLisbon;

  /// No description provided for @cityPorto.
  ///
  /// In en, this message translates to:
  /// **'Porto'**
  String get cityPorto;

  /// No description provided for @cityFaro.
  ///
  /// In en, this message translates to:
  /// **'Faro'**
  String get cityFaro;

  /// No description provided for @cityBraga.
  ///
  /// In en, this message translates to:
  /// **'Braga'**
  String get cityBraga;

  /// No description provided for @cityNewYork.
  ///
  /// In en, this message translates to:
  /// **'New York'**
  String get cityNewYork;

  /// No description provided for @cityLosAngeles.
  ///
  /// In en, this message translates to:
  /// **'Los Angeles'**
  String get cityLosAngeles;

  /// No description provided for @cityMiami.
  ///
  /// In en, this message translates to:
  /// **'Miami'**
  String get cityMiami;

  /// No description provided for @cityChicago.
  ///
  /// In en, this message translates to:
  /// **'Chicago'**
  String get cityChicago;

  /// No description provided for @cityLasVegas.
  ///
  /// In en, this message translates to:
  /// **'Las Vegas'**
  String get cityLasVegas;

  /// No description provided for @citySanFrancisco.
  ///
  /// In en, this message translates to:
  /// **'San Francisco'**
  String get citySanFrancisco;

  /// No description provided for @cityBoston.
  ///
  /// In en, this message translates to:
  /// **'Boston'**
  String get cityBoston;

  /// No description provided for @cityHouston.
  ///
  /// In en, this message translates to:
  /// **'Houston'**
  String get cityHouston;

  /// No description provided for @cityIstanbul.
  ///
  /// In en, this message translates to:
  /// **'Istanbul'**
  String get cityIstanbul;

  /// No description provided for @cityAnkara.
  ///
  /// In en, this message translates to:
  /// **'Ankara'**
  String get cityAnkara;

  /// No description provided for @cityIzmir.
  ///
  /// In en, this message translates to:
  /// **'Izmir'**
  String get cityIzmir;

  /// No description provided for @cityAntalya.
  ///
  /// In en, this message translates to:
  /// **'Antalya'**
  String get cityAntalya;

  /// No description provided for @cityBodrum.
  ///
  /// In en, this message translates to:
  /// **'Bodrum'**
  String get cityBodrum;

  /// No description provided for @cityTashkent.
  ///
  /// In en, this message translates to:
  /// **'Tashkent'**
  String get cityTashkent;

  /// No description provided for @citySamarkand.
  ///
  /// In en, this message translates to:
  /// **'Samarkand'**
  String get citySamarkand;

  /// No description provided for @cityBukhara.
  ///
  /// In en, this message translates to:
  /// **'Bukhara'**
  String get cityBukhara;

  /// No description provided for @cityParis.
  ///
  /// In en, this message translates to:
  /// **'Paris'**
  String get cityParis;

  /// No description provided for @cityNice.
  ///
  /// In en, this message translates to:
  /// **'Nice'**
  String get cityNice;

  /// No description provided for @cityLyon.
  ///
  /// In en, this message translates to:
  /// **'Lyon'**
  String get cityLyon;

  /// No description provided for @cityMarseille.
  ///
  /// In en, this message translates to:
  /// **'Marseille'**
  String get cityMarseille;

  /// No description provided for @cityCannes.
  ///
  /// In en, this message translates to:
  /// **'Cannes'**
  String get cityCannes;

  /// No description provided for @cityBordeaux.
  ///
  /// In en, this message translates to:
  /// **'Bordeaux'**
  String get cityBordeaux;

  /// No description provided for @cityPrague.
  ///
  /// In en, this message translates to:
  /// **'Prague'**
  String get cityPrague;

  /// No description provided for @cityBrno.
  ///
  /// In en, this message translates to:
  /// **'Brno'**
  String get cityBrno;

  /// No description provided for @cityOstrava.
  ///
  /// In en, this message translates to:
  /// **'Ostrava'**
  String get cityOstrava;

  /// No description provided for @cityKarlovyVary.
  ///
  /// In en, this message translates to:
  /// **'Karlovy Vary'**
  String get cityKarlovyVary;

  /// No description provided for @cityZurich.
  ///
  /// In en, this message translates to:
  /// **'Zurich'**
  String get cityZurich;

  /// No description provided for @cityGeneva.
  ///
  /// In en, this message translates to:
  /// **'Geneva'**
  String get cityGeneva;

  /// No description provided for @cityBasel.
  ///
  /// In en, this message translates to:
  /// **'Basel'**
  String get cityBasel;

  /// No description provided for @cityLausanne.
  ///
  /// In en, this message translates to:
  /// **'Lausanne'**
  String get cityLausanne;

  /// No description provided for @cityBern.
  ///
  /// In en, this message translates to:
  /// **'Bern'**
  String get cityBern;

  /// No description provided for @deleteUpper.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteUpper;

  /// No description provided for @invitationsUpper.
  ///
  /// In en, this message translates to:
  /// **'INVITATIONS'**
  String get invitationsUpper;

  /// No description provided for @noInvitationsUpper.
  ///
  /// In en, this message translates to:
  /// **'NO INVITATIONS'**
  String get noInvitationsUpper;

  /// No description provided for @noInvitationsMessage.
  ///
  /// In en, this message translates to:
  /// **'When your profile is added to a casting selection, the message will appear here.'**
  String get noInvitationsMessage;

  /// No description provided for @consideredForCastingMessage.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE BEING CONSIDERED FOR A CASTING'**
  String get consideredForCastingMessage;

  /// No description provided for @requestVideoIntro.
  ///
  /// In en, this message translates to:
  /// **'Request video intro'**
  String get requestVideoIntro;

  /// No description provided for @videoIntroRequirementsHint.
  ///
  /// In en, this message translates to:
  /// **'Video intro requirements'**
  String get videoIntroRequirementsHint;

  /// No description provided for @videoIntroRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'VIDEO INTRO REQUIRED'**
  String get videoIntroRequiredMessage;

  /// No description provided for @openChatUpper.
  ///
  /// In en, this message translates to:
  /// **'OPEN CHAT'**
  String get openChatUpper;

  /// No description provided for @chatUpper.
  ///
  /// In en, this message translates to:
  /// **'CHAT'**
  String get chatUpper;

  /// No description provided for @chatEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Send the first message.'**
  String get chatEmptyMessage;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @copyPublicLinkUpper.
  ///
  /// In en, this message translates to:
  /// **'COPY LINK'**
  String get copyPublicLinkUpper;

  /// No description provided for @publicLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get publicLinkCopied;

  /// No description provided for @publicSelectionEnable.
  ///
  /// In en, this message translates to:
  /// **'Publish selection'**
  String get publicSelectionEnable;

  /// No description provided for @publicSelectionDisable.
  ///
  /// In en, this message translates to:
  /// **'Hide selection'**
  String get publicSelectionDisable;

  /// No description provided for @publicSelectionLinkUpper.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC LINK'**
  String get publicSelectionLinkUpper;

  /// No description provided for @publicSelectionCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get publicSelectionCopyLink;

  /// No description provided for @publicSelectionLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Selection link copied'**
  String get publicSelectionLinkCopied;

  /// No description provided for @publicSelectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This selection is unavailable or no longer public.'**
  String get publicSelectionUnavailable;

  /// No description provided for @publicSelectionClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Review the models in this selection'**
  String get publicSelectionClientTitle;

  /// No description provided for @publicSelectionClientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Like or reject each model and leave notes for the agent.'**
  String get publicSelectionClientSubtitle;

  /// No description provided for @clientFeedbackLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get clientFeedbackLike;

  /// No description provided for @clientFeedbackReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get clientFeedbackReject;

  /// No description provided for @clientFeedbackCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Comment for the agent'**
  String get clientFeedbackCommentHint;

  /// No description provided for @clientFeedbackSaveComment.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get clientFeedbackSaveComment;

  /// No description provided for @clientFeedbackSaved.
  ///
  /// In en, this message translates to:
  /// **'Response saved'**
  String get clientFeedbackSaved;

  /// No description provided for @clientFeedbackEmpty.
  ///
  /// In en, this message translates to:
  /// **'No client feedback yet'**
  String get clientFeedbackEmpty;

  /// No description provided for @clientFeedbackLikesCount.
  ///
  /// In en, this message translates to:
  /// **'Likes: {count}'**
  String clientFeedbackLikesCount(int count);

  /// No description provided for @clientFeedbackRejectsCount.
  ///
  /// In en, this message translates to:
  /// **'Rejects: {count}'**
  String clientFeedbackRejectsCount(int count);

  /// No description provided for @agentWorkspaceUpper.
  ///
  /// In en, this message translates to:
  /// **'AGENT WORKSPACE'**
  String get agentWorkspaceUpper;

  /// No description provided for @agentFoldersUpper.
  ///
  /// In en, this message translates to:
  /// **'FOLDERS'**
  String get agentFoldersUpper;

  /// No description provided for @agentFolderCreateUpper.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get agentFolderCreateUpper;

  /// No description provided for @agentFolderCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get agentFolderCreateTitle;

  /// No description provided for @agentFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get agentFolderName;

  /// No description provided for @agentNoFolders.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get agentNoFolders;

  /// No description provided for @agentMyFoldersUpper.
  ///
  /// In en, this message translates to:
  /// **'MY FOLDERS'**
  String get agentMyFoldersUpper;

  /// No description provided for @agentFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no models in this folder yet'**
  String get agentFolderEmpty;

  /// No description provided for @agentFavoriteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get agentFavoriteFolderTitle;

  /// No description provided for @quickAddTitleUpper.
  ///
  /// In en, this message translates to:
  /// **'QUICK ADD'**
  String get quickAddTitleUpper;

  /// No description provided for @quickAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get quickAddFavorite;

  /// No description provided for @quickAddSelection.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get quickAddSelection;

  /// No description provided for @quickAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add to folder'**
  String get quickAddFolder;

  /// No description provided for @quickAddCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get quickAddCreateFolder;

  /// No description provided for @quickAddFavoriteDone.
  ///
  /// In en, this message translates to:
  /// **'Model added to favorites'**
  String get quickAddFavoriteDone;

  /// No description provided for @quickAddFolderDone.
  ///
  /// In en, this message translates to:
  /// **'Model added to “{folder}”'**
  String quickAddFolderDone(String folder);

  /// No description provided for @quickAddSelectionDone.
  ///
  /// In en, this message translates to:
  /// **'Selection “{selection}” created'**
  String quickAddSelectionDone(String selection);

  /// No description provided for @agentPrivateNoteUpper.
  ///
  /// In en, this message translates to:
  /// **'PRIVATE NOTE'**
  String get agentPrivateNoteUpper;

  /// No description provided for @agentPrivateNoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No note yet'**
  String get agentPrivateNoteEmpty;

  /// No description provided for @agentEditNoteUpper.
  ///
  /// In en, this message translates to:
  /// **'EDIT'**
  String get agentEditNoteUpper;

  /// No description provided for @agentNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this note'**
  String get agentNoteHint;

  /// No description provided for @selectionProfileLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'Free plan allows up to {limit} models in one selection.'**
  String selectionProfileLimitMessage(int limit);

  /// No description provided for @selectionCountLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'Free plan allows up to {limit} selections. Upgrade to Pro for more.'**
  String selectionCountLimitMessage(int limit);

  /// No description provided for @notificationsUpper.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get notificationsUpper;

  /// No description provided for @notificationsAccountEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selection, message, and profile events'**
  String get notificationsAccountEntrySubtitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @analyticsUpper.
  ///
  /// In en, this message translates to:
  /// **'ANALYTICS'**
  String get analyticsUpper;

  /// No description provided for @analyticsAccountEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile views, selections, and invitations'**
  String get analyticsAccountEntrySubtitle;

  /// No description provided for @analyticsProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get analyticsProfiles;

  /// No description provided for @analyticsProfileViews.
  ///
  /// In en, this message translates to:
  /// **'Profile views'**
  String get analyticsProfileViews;

  /// No description provided for @analyticsSelectionAdds.
  ///
  /// In en, this message translates to:
  /// **'Selection adds'**
  String get analyticsSelectionAdds;

  /// No description provided for @analyticsInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get analyticsInvitations;

  /// No description provided for @analyticsHint.
  ///
  /// In en, this message translates to:
  /// **'Data will appear after applying SQL and new app activity.'**
  String get analyticsHint;

  /// No description provided for @safetyAdminUpper.
  ///
  /// In en, this message translates to:
  /// **'SAFETY'**
  String get safetyAdminUpper;

  /// No description provided for @safetyReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get safetyReportsEmpty;

  /// No description provided for @reportProfileUpper.
  ///
  /// In en, this message translates to:
  /// **'REPORT'**
  String get reportProfileUpper;

  /// No description provided for @blockUserUpper.
  ///
  /// In en, this message translates to:
  /// **'BLOCK'**
  String get blockUserUpper;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonFake.
  ///
  /// In en, this message translates to:
  /// **'Fake profile'**
  String get reportReasonFake;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// No description provided for @profileReportSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get profileReportSent;

  /// No description provided for @profileReportSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Reports will work after applying SQL.'**
  String get profileReportSetupRequired;

  /// No description provided for @profileBlocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get profileBlocked;

  /// No description provided for @profileBlockSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Blocks will work after applying SQL.'**
  String get profileBlockSetupRequired;

  /// No description provided for @projectClientHint.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get projectClientHint;

  /// No description provided for @projectBrandHint.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get projectBrandHint;

  /// No description provided for @projectBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get projectBudgetHint;

  /// No description provided for @projectLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get projectLocationHint;

  /// No description provided for @projectDatesHint.
  ///
  /// In en, this message translates to:
  /// **'Project dates'**
  String get projectDatesHint;

  /// No description provided for @projectRolesHint.
  ///
  /// In en, this message translates to:
  /// **'Roles and tasks: model, actor, stylist...'**
  String get projectRolesHint;

  /// No description provided for @projectCampaignUpper.
  ///
  /// In en, this message translates to:
  /// **'CAMPAIGN'**
  String get projectCampaignUpper;

  /// No description provided for @projectClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get projectClient;

  /// No description provided for @projectBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get projectBrand;

  /// No description provided for @projectBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get projectBudget;

  /// No description provided for @projectLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get projectLocation;

  /// No description provided for @projectDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get projectDates;

  /// No description provided for @projectRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get projectRoles;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
