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

  @override
  String get networkConnectionError =>
      'No connection to Supabase. Check internet, VPN/proxy, DNS, or SUPABASE_URL.';

  @override
  String get catalogUpper => 'CATALOG';

  @override
  String get signInUpper => 'SIGN IN';

  @override
  String get registerUpper => 'SIGN UP';

  @override
  String get noAccount => 'No account? ';

  @override
  String get enterEmail => 'Enter email';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get passwordMin6 => 'Password must be at least 6 characters';

  @override
  String get signInUserIdMissing => 'Sign-in error: userId is missing';

  @override
  String get signInGenericError => 'Sign-in failed. Please try again.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get continueWith => 'or';

  @override
  String get continueWithPhone => 'CONTINUE BY PHONE';

  @override
  String get continueWithGoogle => 'CONTINUE WITH GOOGLE';

  @override
  String get continueWithApple => 'CONTINUE WITH APPLE';

  @override
  String get oauthOpenFailed => 'Couldn’t open sign-in. Please try again.';

  @override
  String get oauthProviderDisabled =>
      'This sign-in method is not enabled in Supabase yet.';

  @override
  String get phoneProviderDisabled =>
      'Phone sign-in is not enabled in Supabase yet.';

  @override
  String get phoneLoginTitle => 'Phone sign-in';

  @override
  String get phoneNumber => 'Phone';

  @override
  String get phoneInternationalHint =>
      'Choose a country code and enter the phone number';

  @override
  String get phoneOtpCode => 'SMS code';

  @override
  String get phoneOtpSend => 'SEND CODE';

  @override
  String get phoneOtpVerify => 'SIGN IN';

  @override
  String get phoneOtpEnterCode => 'Enter the SMS code';

  @override
  String get phoneOtpSendFailed => 'Couldn’t send the code. Please try again.';

  @override
  String get phoneOtpVerifyFailed =>
      'Couldn’t verify the code. Please try again.';

  @override
  String get signInEmailNotConfirmed =>
      'Email is not confirmed yet. Check your inbox and open the confirmation link.';

  @override
  String get emailRateLimitExceeded =>
      'Too many emails were sent in a short time. Wait a few minutes and try again.';

  @override
  String get continueSignUpWithPhone => 'CONTINUE BY PHONE';

  @override
  String get continueSignUpWithGoogle => 'CONTINUE WITH GOOGLE';

  @override
  String get continueSignUpWithApple => 'CONTINUE WITH APPLE';

  @override
  String get emailVerificationTitle => 'Confirm your email';

  @override
  String emailVerificationSubtitle(String email) {
    return 'We sent an email to $email. Open the link to activate your account.';
  }

  @override
  String get emailVerificationSubtitleNoEmail =>
      'Check your inbox and open the link to activate your account.';

  @override
  String get emailVerificationExpires =>
      'The link should be valid for 24 hours if this is enabled in Supabase Auth settings.';

  @override
  String get emailVerificationGoLoginUpper => 'I CONFIRMED, SIGN IN';

  @override
  String get emailVerificationResendUpper => 'SEND AGAIN';

  @override
  String get emailVerificationResent => 'Confirmation email sent again.';

  @override
  String get emailVerificationChecking => 'Checking email confirmation...';

  @override
  String get emailVerificationStillPending =>
      'Email is not confirmed yet. Open the Supabase email link, then tap the button again.';

  @override
  String get emailVerificationLoginManually =>
      'Couldn’t check automatically: the app was restarted or the sign-up details were not kept. Sign in manually after confirming your email.';

  @override
  String get guestUpper => 'GUEST';

  @override
  String get accountUpper => 'ACCOUNT';

  @override
  String get catalogSearchHintUpper => 'SEARCH IN CATALOG';

  @override
  String get catalogLoadError => 'Failed to load catalog';

  @override
  String get savedSearchFashion1825 => 'fashion 18-25';

  @override
  String get savedSearchKids => 'kids';

  @override
  String get savedSearchCommercial => 'commercial';

  @override
  String get savedSearchSports => 'sports';

  @override
  String get savedSearchSaveCurrent => 'SAVE';

  @override
  String get savedSearchSaveTitle => 'SAVE SEARCH';

  @override
  String get savedSearchNameHint => 'Search name';

  @override
  String get savedSearchNameRequired => 'Enter a name';

  @override
  String get savedSearchSaved => 'Search saved';

  @override
  String get savedSearchDeleted => 'Search deleted';

  @override
  String get noApprovedProfilesYet => 'No approved profiles yet';

  @override
  String get city => 'City';

  @override
  String get age => 'Age';

  @override
  String get height => 'Height';

  @override
  String get cm => 'cm';

  @override
  String get advancedSearchUpper => 'ADVANCED SEARCH';

  @override
  String get resetUpper => 'RESET';

  @override
  String get applyUpper => 'APPLY';

  @override
  String get signOutConfirmTitleUpper => 'SIGN OUT?';

  @override
  String get signOutConfirmGuestStay =>
      'You will stay in the catalog as a guest.';

  @override
  String get deleteAccountUpper => 'DELETE ACCOUNT';

  @override
  String get deleteAccountSubtitle =>
      'Remove your profile, listings, and access';

  @override
  String get deleteAccountConfirmTitleUpper => 'DELETE ACCOUNT?';

  @override
  String get deleteAccountConfirmMessage =>
      'Your account, profiles, selections, messages, and related data will be permanently deleted.';

  @override
  String get deleteAccountConfirmActionUpper => 'DELETE';

  @override
  String get deleteAccountSetupRequired =>
      'Account deletion will work after applying delete_my_account.sql in Supabase.';

  @override
  String get deleteAccountFailed =>
      'Couldn’t delete the account. Please try again.';

  @override
  String rangeFromTo(int from, int to) {
    return 'from $from to $to';
  }

  @override
  String get shoeSize => 'Shoe size';

  @override
  String get shoeSizeHint => 'e.g. 39';

  @override
  String get bust => 'Bust';

  @override
  String get bustHint => 'e.g. 90';

  @override
  String get waist => 'Waist';

  @override
  String get waistHint => 'e.g. 60';

  @override
  String get hips => 'Hips';

  @override
  String get hipsHint => 'e.g. 90';

  @override
  String get eyeColor => 'Eye color';

  @override
  String get eyeColorHint => 'e.g. brown';

  @override
  String get hairColor => 'Hair color';

  @override
  String get hairColorHint => 'e.g. blonde';

  @override
  String get country => 'Country';

  @override
  String get countryHint => 'e.g. Australia';

  @override
  String get cityHint => 'e.g. Sydney';

  @override
  String get date => 'Date';

  @override
  String get weekdayMonUpper => 'MON';

  @override
  String get weekdayTueUpper => 'TUE';

  @override
  String get weekdayWedUpper => 'WED';

  @override
  String get weekdayThuUpper => 'THU';

  @override
  String get weekdayFriUpper => 'FRI';

  @override
  String get weekdaySatUpper => 'SAT';

  @override
  String get weekdaySunUpper => 'SUN';

  @override
  String get monthJanuaryUpper => 'JANUARY';

  @override
  String get monthFebruaryUpper => 'FEBRUARY';

  @override
  String get monthMarchUpper => 'MARCH';

  @override
  String get monthAprilUpper => 'APRIL';

  @override
  String get monthMayUpper => 'MAY';

  @override
  String get monthJuneUpper => 'JUNE';

  @override
  String get monthJulyUpper => 'JULY';

  @override
  String get monthAugustUpper => 'AUGUST';

  @override
  String get monthSeptemberUpper => 'SEPTEMBER';

  @override
  String get monthOctoberUpper => 'OCTOBER';

  @override
  String get monthNovemberUpper => 'NOVEMBER';

  @override
  String get monthDecemberUpper => 'DECEMBER';

  @override
  String get castingsUpper => 'CASTINGS';

  @override
  String get castingsTab => 'Castings';

  @override
  String get catalogTab => 'Catalog';

  @override
  String get invitationsTab => 'Invites';

  @override
  String get myProfileTab => 'My account';

  @override
  String get adminTab => 'Admin';

  @override
  String get billingTitleUpper => 'PLANS';

  @override
  String get billingAccountEntrySubtitle => 'Current plan and limits';

  @override
  String get billingCurrentUpper => 'CURRENT';

  @override
  String get billingPlanActive => 'ACTIVE PLAN';

  @override
  String get billingPlanFreeStatus => 'CURRENT PLAN';

  @override
  String get billingPlanFree => 'Basic';

  @override
  String get billingPlanModelPro => 'Model Pro';

  @override
  String get billingPlanCastingAgentPro => 'Casting Agent Pro';

  @override
  String get billingPlanAgencyAdmin => 'Administrator';

  @override
  String get billingFreeSubtitle =>
      'Catalog presence without active communication with clients.';

  @override
  String get billingModelProSubtitle =>
      'Invitations, chat, and profile promotion for active work.';

  @override
  String get billingCastingProSubtitle =>
      'Professional tools for casting agents and client selections.';

  @override
  String get billingAgencySubtitle =>
      'Team access, exports, and analytics for agencies.';

  @override
  String get billingBasicCatalog => 'Catalog publishing and profile tools';

  @override
  String billingProfileLimit(int limit) {
    return 'Up to $limit profiles';
  }

  @override
  String get billingUnlimitedProfiles => 'Unlimited profiles';

  @override
  String get billingInvitationsPreview =>
      'See when you are invited or added to a selection';

  @override
  String get billingChatRequiresPro => 'Open chat and reply with Model Pro';

  @override
  String get billingChatAndInvitations => 'Full access to invitations and chat';

  @override
  String billingProfileBoostsIncluded(int count) {
    return '$count profile boosts per month';
  }

  @override
  String get billingBasicAnalytics => 'Basic view statistics';

  @override
  String get billingBoostOneTime => 'One-time profile boost';

  @override
  String get billingBoostOneTimeSubtitle =>
      'Can be bought separately without Pro.';

  @override
  String get billingBoostOneTimeFeature =>
      'Move a selected profile higher in the catalog';

  @override
  String get billingUpgradeRequiredTitle => 'Model Pro required';

  @override
  String get billingUpgradeRequiredMessage =>
      'You can see the invitation, but opening chat and replying requires Model Pro.';

  @override
  String get billingUpgradeActionUpper => 'VIEW PLANS';

  @override
  String billingSelectionSizeLimit(int limit) {
    return 'Up to $limit models in one selection';
  }

  @override
  String billingSelectionCountLimit(int limit) {
    return 'Up to $limit active selections';
  }

  @override
  String get billingUnlimitedSelectionSize => 'Unlimited models in selections';

  @override
  String get billingUnlimitedSelections => 'Unlimited selections';

  @override
  String get billingProfileBoost => 'Profile boost';

  @override
  String get billingExpandedMedia => 'Expanded media gallery';

  @override
  String get billingProBadge => 'Pro badge';

  @override
  String get billingBrandedPdf => 'Branded PDF export';

  @override
  String get billingFoldersAndNotes => 'Folders and private notes';

  @override
  String get billingTeamAccess => 'Team access';

  @override
  String get billingAnalytics => 'Analytics';

  @override
  String get billingExports => 'Extended exports';

  @override
  String get billingPaymentsSoon =>
      'Payments are not connected yet. This screen shows the tariff structure; Stripe or RevenueCat can be connected next.';

  @override
  String get onboardingTitle => 'How will you use ModelApp?';

  @override
  String get onboardingSubtitle =>
      'Choose your role once, and the app will open the right workflow first.';

  @override
  String get onboardingModelTitle => 'I am a model';

  @override
  String get onboardingModelSubtitle =>
      'Create a profile, add media, respond to castings, and track invitations.';

  @override
  String get onboardingActorTitle => 'I am an actor';

  @override
  String get onboardingActorSubtitle =>
      'Create an acting profile, add media, and respond to castings and projects.';

  @override
  String get onboardingCastingTitle => 'I am a casting agent';

  @override
  String get onboardingCastingSubtitle =>
      'Search models, create selections, export PDFs, and manage client projects.';

  @override
  String get onboardingBrandTitle => 'I am a brand';

  @override
  String get onboardingBrandSubtitle =>
      'Find faces for campaigns, build selections, and review candidates with your team.';

  @override
  String get onboardingPhotographerTitle => 'I am a photographer';

  @override
  String get onboardingPhotographerSubtitle =>
      'Find models for shoots, tests, campaigns, and creative projects.';

  @override
  String get onboardingVideographerTitle => 'I am a videographer';

  @override
  String get onboardingVideographerSubtitle =>
      'Find models and actors for video, reels, ads, and production work.';

  @override
  String get onboardingStylistTitle => 'I am a stylist';

  @override
  String get onboardingStylistSubtitle =>
      'Build teams for shoots, shows, lookbooks, and commercial projects.';

  @override
  String get onboardingMakeupArtistTitle => 'I am a makeup artist';

  @override
  String get onboardingMakeupArtistSubtitle =>
      'Find models for beauty shoots, tests, portfolio work, and client projects.';

  @override
  String get onboardingHairStylistTitle => 'I am a hair stylist';

  @override
  String get onboardingHairStylistSubtitle =>
      'Find models for hair shoots, color work, tests, and creative projects.';

  @override
  String get onboardingChooseUpper => 'CHOOSE';

  @override
  String get onboardingSaveFailed =>
      'Couldn’t save your role. Please try again.';

  @override
  String get addProfileUpper => 'ADD NEW PROFILE';

  @override
  String get logoutUpper => 'LOG OUT';

  @override
  String get registerFillBelow => 'Fill in the details';

  @override
  String get accountTypeUpper => 'ACCOUNT TYPE';

  @override
  String get accountTypeUser => 'REGULAR';

  @override
  String get accountTypeCastingAgent => 'CASTING AGENT';

  @override
  String get passwordRepeat => 'Repeat password';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get signUpGenericError => 'Sign up failed. Please try again.';

  @override
  String get signUpDatabaseError =>
      'Supabase failed while creating the user. Run auth_signup_trigger_hard_reset.sql and try a new email.';

  @override
  String get notRegisteredTitle => 'YOU ARE NOT REGISTERED';

  @override
  String get notRegisteredMessage =>
      'To open “My profile”, you need to sign in or sign up.';

  @override
  String get adminExitUpper => 'EXIT';

  @override
  String get adminCreateCastingUpper => 'CREATE CASTING';

  @override
  String get adminModelsCatalogUpper => 'MODELS CATALOG';

  @override
  String get adminModerationUpper => 'MODERATION';

  @override
  String get adminAgentApplicationsUpper => 'AGENT REQUESTS';

  @override
  String get adminAgentApplicationsEmpty => 'NO REQUESTS';

  @override
  String get agentApplicationApproveUpper => 'APPROVE';

  @override
  String get agentApplicationRejectUpper => 'REJECT';

  @override
  String get adminOnlyUpper => 'THIS PAGE IS FOR ADMINS ONLY';

  @override
  String get moderationRejectTitle => 'Rejection reason';

  @override
  String get moderationRejectHint => 'Comment for the model';

  @override
  String get moderationRejectRequired => 'Choose or write a reason';

  @override
  String get moderationRejectActionUpper => 'REJECT';

  @override
  String get moderationRejectPoorPhotos => 'Low-quality photos';

  @override
  String get moderationRejectFaceNotVisible => 'Face is not visible';

  @override
  String get moderationRejectIncompleteData => 'Incomplete details';

  @override
  String get moderationRejectInvalidMedia => 'Unsuitable media';

  @override
  String get moderationRejectSuspicious => 'Suspicious profile';

  @override
  String get castingTitle => 'Casting title';

  @override
  String get projectDescription => 'Project description';

  @override
  String get rights => 'Rights';

  @override
  String get fee => 'Fee';

  @override
  String get dates => 'Dates';

  @override
  String get backUpper => 'BACK';

  @override
  String get profileCreateUpper => 'CREATE PROFILE';

  @override
  String get profileTypeUpper => 'PROFILE TYPE';

  @override
  String get profileTypeModel => 'Model';

  @override
  String get profileTypeActor => 'Actor';

  @override
  String get profileTypePhotographer => 'Photographer';

  @override
  String get profileTypeVideographer => 'Videographer';

  @override
  String get profileTypeStylist => 'Stylist';

  @override
  String get profileTypeMakeupArtist => 'Makeup artist';

  @override
  String get profileTypeHairStylist => 'Hair stylist';

  @override
  String get profileTypeSelectTitle => 'Who are you adding?';

  @override
  String get profileTypeSelectSubtitle =>
      'Choose the profile type. One account can manage several different profiles.';

  @override
  String get profilePhysicalDetailsUpper => 'PHYSICAL DETAILS';

  @override
  String get profileProfessionalInfoUpper => 'PROFESSIONAL INFO';

  @override
  String get profileSurname => 'Surname';

  @override
  String get profileName => 'Name';

  @override
  String get profileAge => 'Age';

  @override
  String get profileHeightCm => 'Height (cm)';

  @override
  String get profileBustCm => 'Bust (cm)';

  @override
  String get profileWaistCm => 'Waist (cm)';

  @override
  String get profileHipsCm => 'Hips (cm)';

  @override
  String get profileShoeSize => 'Shoe size';

  @override
  String get profileEyeColor => 'Eye color';

  @override
  String get profileHairColor => 'Hair color';

  @override
  String get profileCountry => 'Country';

  @override
  String get profileCity => 'City';

  @override
  String get profileAboutHint => 'About you (experience, skills, links)';

  @override
  String get profileMediaUpper => 'MEDIA';

  @override
  String get profileResumeUpper => 'RESUME';

  @override
  String get profileCalendarUpper => 'CALENDAR';

  @override
  String get profileSubmitUpper => 'SUBMIT FOR REVIEW';

  @override
  String get profileSaveUpper => 'SAVE';

  @override
  String get profileDeleteUpper => 'DELETE PROFILE';

  @override
  String get profileAddPhotoUpper => 'ADD PHOTO';

  @override
  String get profileAddVideoUpper => 'ADD VIDEO';

  @override
  String get profileMediaEmpty => 'No photos/videos yet';

  @override
  String profileQualityComplete(int percent) {
    return 'Profile completed $percent%';
  }

  @override
  String get profileQualityReady =>
      'Looks good: the profile is ready for moderation.';

  @override
  String get profileQualityRequiredFields =>
      'Fill in required measurements and location fields';

  @override
  String get profileQualityPortraitPhoto => 'Add a clear portrait photo';

  @override
  String get profileQualityFullBodyPhoto => 'Add a full-height photo';

  @override
  String get profileQualityProfessionalInfo =>
      'Add experience, services, genres, or skills';

  @override
  String get profileQualityAbout =>
      'Add a short description: experience, skills, links';

  @override
  String get profileQualityVideo => 'Add a video intro if you have one';

  @override
  String get profileExperience => 'Experience, clients, publications';

  @override
  String get profileActingExperience =>
      'Acting experience, projects, education';

  @override
  String get profileSkills => 'Skills and specialization';

  @override
  String get profileActorSkills => 'Skills: languages, sport, dance, voice';

  @override
  String get profileServices => 'Services';

  @override
  String get profileActorRoles => 'Types and roles';

  @override
  String get profileActingGenres => 'Genres: film, commercial, theatre';

  @override
  String get profilePhotoGenres => 'Shoot genres';

  @override
  String get profileVideoGenres => 'Video and production genres';

  @override
  String get profileWorkGenres => 'Work directions';

  @override
  String get profileEquipment => 'Equipment / studio / locations';

  @override
  String get profileVideo => 'Video';

  @override
  String get profileVideoSelected => 'Video selected';

  @override
  String get profileVideoUploaded => 'Video uploaded';

  @override
  String get profileStatusPendingUpper => 'PENDING REVIEW';

  @override
  String get profileStatusPendingSubtitle =>
      'Profile submitted and awaiting review';

  @override
  String get profileStatusApprovedUpper => 'APPROVED';

  @override
  String get profileStatusApprovedSubtitle => 'Profile is live in the catalog';

  @override
  String get profileStatusRejectedUpper => 'REJECTED';

  @override
  String get profileStatusRejectedSubtitleDefault =>
      'Fix the details and submit again';

  @override
  String get profileStatusDraftUpper => 'DRAFT';

  @override
  String get profileStatusDraftSubtitle =>
      'Fill in the profile and submit for review';

  @override
  String get profileVerifiedUpper => 'PROFILE VERIFIED';

  @override
  String get profileVerifiedSubtitle =>
      'This profile was confirmed by an administrator';

  @override
  String get profileVerificationAvailableUpper => 'VERIFICATION';

  @override
  String get profileVerificationAvailableSubtitle =>
      'Request review to receive a trust mark';

  @override
  String get profileVerificationPendingUpper => 'VERIFICATION PENDING';

  @override
  String get profileVerificationPendingSubtitle =>
      'An administrator will review the profile and add the mark';

  @override
  String get profileVerificationRejectedUpper => 'VERIFICATION REJECTED';

  @override
  String get profileVerificationRejectedSubtitle =>
      'Check the details and request verification again';

  @override
  String get profileVerificationRequestUpper => 'REQUEST';

  @override
  String get profileVerificationRequestFailed =>
      'Couldn’t request verification. Please try again.';

  @override
  String get profileErrorSurnameRequired => 'Enter your surname';

  @override
  String get profileErrorNameRequired => 'Enter your name';

  @override
  String get profileErrorSaveFailed => 'Couldn’t save. Please try again.';

  @override
  String get profileErrorDeleteFailed => 'Couldn’t delete. Please try again.';

  @override
  String get profileErrorLimitReached =>
      'Your current plan profile limit is reached. Upgrade to Model Pro or remove an extra profile.';

  @override
  String get profileErrorNoUser => 'No user';

  @override
  String get profileErrorFullNameRequired =>
      'Fill in your full name before submitting';

  @override
  String get profileErrorAgeRequired => 'Add birth date';

  @override
  String get profileErrorAgeRange => 'Check birth date';

  @override
  String get profileErrorHeightRequired => 'Add height';

  @override
  String get profileErrorHeightRange => 'Height must be 120–220 cm';

  @override
  String get profileErrorBustRequired => 'Add bust measurements';

  @override
  String get profileErrorBustRange => 'Bust must be 40–140 cm';

  @override
  String get profileErrorWaistRequired => 'Add waist measurements';

  @override
  String get profileErrorWaistRange => 'Waist must be 40–140 cm';

  @override
  String get profileErrorHipsRequired => 'Add hips measurements';

  @override
  String get profileErrorHipsRange => 'Hips must be 40–140 cm';

  @override
  String profileLoadError(Object error) {
    return 'Failed to load profile: $error';
  }

  @override
  String get profileMediaPreviewPlaceholder =>
      'Photo/video previews will appear here';

  @override
  String get bootstrapErrorMessage =>
      'Failed to initialize the application.\nPlease check Supabase configuration and restart.';

  @override
  String get retryButton => 'Restart';

  @override
  String get bootstrapConfigErrorTitle => 'Configuration error';

  @override
  String get bootstrapConfigErrorMessage =>
      'Supabase is not configured.\n\nRun the app with:\n--dart-define=SUPABASE_URL=...\n--dart-define=SUPABASE_ANON_KEY=...';

  @override
  String get bootstrapInitErrorTitle => 'Startup error';

  @override
  String get bootstrapInitErrorMessage => 'Failed to initialize Supabase:';

  @override
  String get loadingDots => '...';

  @override
  String get respondUpper => 'RESPOND';

  @override
  String get respondAuthRequiredTitle => 'SIGN IN REQUIRED';

  @override
  String get respondAuthRequiredMessage =>
      'To respond to a casting, please sign in or create an account.';

  @override
  String get respondSentMessage => 'RESPONSE SENT';

  @override
  String get respondChooseProfilesTitle => 'CHOOSE PROFILES';

  @override
  String get respondChooseProfilesMessage =>
      'You have multiple profiles. Select one or more to respond.';

  @override
  String get respondNoProfilesTitle => 'NO PROFILES';

  @override
  String get respondNoProfilesMessage =>
      'To respond, create a profile first in the Profile section.';

  @override
  String get castingResponseStatusSubmitted => 'SUBMITTED';

  @override
  String get castingResponseStatusViewed => 'VIEWED';

  @override
  String get castingResponseStatusInvited => 'INVITED';

  @override
  String get castingResponseStatusRejected => 'REJECTED';

  @override
  String get goToProfileUpper => 'GO TO PROFILE';

  @override
  String get profileUpper => 'PROFILE';

  @override
  String get selectionUpper => 'SELECTION';

  @override
  String get selectionStatusUpper => 'SELECTION STATUS';

  @override
  String get selectionStatusDraft => 'Draft';

  @override
  String get selectionStatusSent => 'Sent to client';

  @override
  String get selectionStatusViewed => 'Client viewed';

  @override
  String get selectionStatusSelected => 'Selected';

  @override
  String get selectionStatusRejected => 'Rejected';

  @override
  String get responsesUpper => 'RESPONSES';

  @override
  String get noCastingsMessage => 'NO CASTINGS';

  @override
  String get noResponsesMessage => 'NO RESPONSES';

  @override
  String get errorUpper => 'ERROR';

  @override
  String get ageShort => 'age';

  @override
  String get heightShort => 'height';

  @override
  String get profileMinHourlyRate => 'Min. hourly rate';

  @override
  String get profileMinDailyFee => 'Min. daily fee';

  @override
  String get profileDetailsUpper => 'DETAILS';

  @override
  String get profileNoName => 'No name';

  @override
  String get profileResumeEmpty => 'Resume will be added later.';

  @override
  String get profileNotFoundUpper => 'PROFILE NOT FOUND';

  @override
  String get retryUpper => 'RETRY';

  @override
  String get noCastingsYetUpper => 'NO CASTINGS YET';

  @override
  String get profileNotFoundSubtitle =>
      'It may not be approved yet or may have been deleted.';

  @override
  String get advancedMinHourlyRateUpper => 'MIN. HOURLY RATE';

  @override
  String get advancedMinDailyFeeUpper => 'MIN. DAILY FEE';

  @override
  String get selectedUpper => 'SELECTED';

  @override
  String get selectUpper => 'SELECT';

  @override
  String get projectTitleUpper => 'PROJECT TITLE';

  @override
  String get enterProjectTitleHint => 'Enter title';

  @override
  String get enterProjectTitleError => 'Enter project title';

  @override
  String get cancelUpper => 'CANCEL';

  @override
  String get saveUpper => 'SAVE';

  @override
  String get pdfOptionPhoto => 'Photo';

  @override
  String get pdfOptionFullName => 'Full name';

  @override
  String get pdfOptionMeasurements => 'Measurements';

  @override
  String get pdfOptionModelLink => 'Model link';

  @override
  String deleteSelectedItemsConfirm(int count) {
    return 'Delete selected items ($count)?';
  }

  @override
  String get profileTitleUpper => 'Questionnaire';

  @override
  String get profileDeleteMediaConfirmTitle => 'Delete media';

  @override
  String get profileDeleteMediaConfirmMessage =>
      'Are you sure you want to delete this file?';

  @override
  String get profileDeleteMediaDontAskAgain => 'Don\'t ask again';

  @override
  String get yesUpper => 'YES';

  @override
  String get noUpper => 'NO';

  @override
  String get profileSubmitRequiredTitle => 'Submission required';

  @override
  String get profileSubmitRequiredMessage =>
      'You added new photos or videos. To apply these changes, the profile must be sent for moderation.';

  @override
  String get okUpper => 'OK';

  @override
  String get countryRussia => 'Russia';

  @override
  String get countryAustralia => 'Australia';

  @override
  String get countryAustria => 'Austria';

  @override
  String get countryBelarus => 'Belarus';

  @override
  String get countryBelgium => 'Belgium';

  @override
  String get countryBulgaria => 'Bulgaria';

  @override
  String get countryUnitedKingdom => 'United Kingdom';

  @override
  String get countryGermany => 'Germany';

  @override
  String get countryGreece => 'Greece';

  @override
  String get countryGeorgia => 'Georgia';

  @override
  String get countrySpain => 'Spain';

  @override
  String get countryItaly => 'Italy';

  @override
  String get countryKazakhstan => 'Kazakhstan';

  @override
  String get countryCanada => 'Canada';

  @override
  String get countryCyprus => 'Cyprus';

  @override
  String get countryNetherlands => 'Netherlands';

  @override
  String get countryUae => 'UAE';

  @override
  String get countryPoland => 'Poland';

  @override
  String get countryPortugal => 'Portugal';

  @override
  String get countryUsa => 'USA';

  @override
  String get countryTurkey => 'Turkey';

  @override
  String get countryUzbekistan => 'Uzbekistan';

  @override
  String get countryFrance => 'France';

  @override
  String get countryCzechia => 'Czechia';

  @override
  String get countrySwitzerland => 'Switzerland';

  @override
  String get cityMoscow => 'Moscow';

  @override
  String get citySaintPetersburg => 'Saint Petersburg';

  @override
  String get cityKazan => 'Kazan';

  @override
  String get cityYekaterinburg => 'Yekaterinburg';

  @override
  String get cityNovosibirsk => 'Novosibirsk';

  @override
  String get citySochi => 'Sochi';

  @override
  String get cityKrasnodar => 'Krasnodar';

  @override
  String get cityRostovOnDon => 'Rostov-on-Don';

  @override
  String get cityNizhnyNovgorod => 'Nizhny Novgorod';

  @override
  String get citySamara => 'Samara';

  @override
  String get cityUfa => 'Ufa';

  @override
  String get cityVladivostok => 'Vladivostok';

  @override
  String get citySydney => 'Sydney';

  @override
  String get cityMelbourne => 'Melbourne';

  @override
  String get cityBrisbane => 'Brisbane';

  @override
  String get cityPerth => 'Perth';

  @override
  String get cityAdelaide => 'Adelaide';

  @override
  String get cityGoldCoast => 'Gold Coast';

  @override
  String get cityCanberra => 'Canberra';

  @override
  String get cityVienna => 'Vienna';

  @override
  String get citySalzburg => 'Salzburg';

  @override
  String get cityGraz => 'Graz';

  @override
  String get cityInnsbruck => 'Innsbruck';

  @override
  String get cityLinz => 'Linz';

  @override
  String get cityMinsk => 'Minsk';

  @override
  String get cityBrest => 'Brest';

  @override
  String get cityGrodno => 'Grodno';

  @override
  String get cityVitebsk => 'Vitebsk';

  @override
  String get cityGomel => 'Gomel';

  @override
  String get cityBrussels => 'Brussels';

  @override
  String get cityAntwerp => 'Antwerp';

  @override
  String get cityGhent => 'Ghent';

  @override
  String get cityBruges => 'Bruges';

  @override
  String get cityLiege => 'Liege';

  @override
  String get citySofia => 'Sofia';

  @override
  String get cityVarna => 'Varna';

  @override
  String get cityBurgas => 'Burgas';

  @override
  String get cityPlovdiv => 'Plovdiv';

  @override
  String get cityLondon => 'London';

  @override
  String get cityManchester => 'Manchester';

  @override
  String get cityLiverpool => 'Liverpool';

  @override
  String get cityBirmingham => 'Birmingham';

  @override
  String get cityEdinburgh => 'Edinburgh';

  @override
  String get cityGlasgow => 'Glasgow';

  @override
  String get cityBerlin => 'Berlin';

  @override
  String get cityMunich => 'Munich';

  @override
  String get cityHamburg => 'Hamburg';

  @override
  String get cityFrankfurt => 'Frankfurt';

  @override
  String get cityCologne => 'Cologne';

  @override
  String get cityDusseldorf => 'Dusseldorf';

  @override
  String get cityStuttgart => 'Stuttgart';

  @override
  String get cityAthens => 'Athens';

  @override
  String get cityThessaloniki => 'Thessaloniki';

  @override
  String get cityHeraklion => 'Heraklion';

  @override
  String get cityPatras => 'Patras';

  @override
  String get cityTbilisi => 'Tbilisi';

  @override
  String get cityBatumi => 'Batumi';

  @override
  String get cityKutaisi => 'Kutaisi';

  @override
  String get cityMadrid => 'Madrid';

  @override
  String get cityBarcelona => 'Barcelona';

  @override
  String get cityValencia => 'Valencia';

  @override
  String get citySeville => 'Seville';

  @override
  String get cityMalaga => 'Malaga';

  @override
  String get cityAlicante => 'Alicante';

  @override
  String get cityIbiza => 'Ibiza';

  @override
  String get cityRome => 'Rome';

  @override
  String get cityMilan => 'Milan';

  @override
  String get cityFlorence => 'Florence';

  @override
  String get cityVenice => 'Venice';

  @override
  String get cityNaples => 'Naples';

  @override
  String get cityTurin => 'Turin';

  @override
  String get cityBologna => 'Bologna';

  @override
  String get cityAlmaty => 'Almaty';

  @override
  String get cityAstana => 'Astana';

  @override
  String get cityShymkent => 'Shymkent';

  @override
  String get cityKaraganda => 'Karaganda';

  @override
  String get cityAtyrau => 'Atyrau';

  @override
  String get cityToronto => 'Toronto';

  @override
  String get cityVancouver => 'Vancouver';

  @override
  String get cityMontreal => 'Montreal';

  @override
  String get cityCalgary => 'Calgary';

  @override
  String get cityOttawa => 'Ottawa';

  @override
  String get cityNicosia => 'Nicosia';

  @override
  String get cityLimassol => 'Limassol';

  @override
  String get cityLarnaca => 'Larnaca';

  @override
  String get cityPaphos => 'Paphos';

  @override
  String get cityAmsterdam => 'Amsterdam';

  @override
  String get cityRotterdam => 'Rotterdam';

  @override
  String get cityTheHague => 'The Hague';

  @override
  String get cityUtrecht => 'Utrecht';

  @override
  String get cityEindhoven => 'Eindhoven';

  @override
  String get cityDubai => 'Dubai';

  @override
  String get cityAbuDhabi => 'Abu Dhabi';

  @override
  String get citySharjah => 'Sharjah';

  @override
  String get cityAjman => 'Ajman';

  @override
  String get cityWarsaw => 'Warsaw';

  @override
  String get cityKrakow => 'Krakow';

  @override
  String get cityWroclaw => 'Wroclaw';

  @override
  String get cityGdansk => 'Gdansk';

  @override
  String get cityPoznan => 'Poznan';

  @override
  String get cityLisbon => 'Lisbon';

  @override
  String get cityPorto => 'Porto';

  @override
  String get cityFaro => 'Faro';

  @override
  String get cityBraga => 'Braga';

  @override
  String get cityNewYork => 'New York';

  @override
  String get cityLosAngeles => 'Los Angeles';

  @override
  String get cityMiami => 'Miami';

  @override
  String get cityChicago => 'Chicago';

  @override
  String get cityLasVegas => 'Las Vegas';

  @override
  String get citySanFrancisco => 'San Francisco';

  @override
  String get cityBoston => 'Boston';

  @override
  String get cityHouston => 'Houston';

  @override
  String get cityIstanbul => 'Istanbul';

  @override
  String get cityAnkara => 'Ankara';

  @override
  String get cityIzmir => 'Izmir';

  @override
  String get cityAntalya => 'Antalya';

  @override
  String get cityBodrum => 'Bodrum';

  @override
  String get cityTashkent => 'Tashkent';

  @override
  String get citySamarkand => 'Samarkand';

  @override
  String get cityBukhara => 'Bukhara';

  @override
  String get cityParis => 'Paris';

  @override
  String get cityNice => 'Nice';

  @override
  String get cityLyon => 'Lyon';

  @override
  String get cityMarseille => 'Marseille';

  @override
  String get cityCannes => 'Cannes';

  @override
  String get cityBordeaux => 'Bordeaux';

  @override
  String get cityPrague => 'Prague';

  @override
  String get cityBrno => 'Brno';

  @override
  String get cityOstrava => 'Ostrava';

  @override
  String get cityKarlovyVary => 'Karlovy Vary';

  @override
  String get cityZurich => 'Zurich';

  @override
  String get cityGeneva => 'Geneva';

  @override
  String get cityBasel => 'Basel';

  @override
  String get cityLausanne => 'Lausanne';

  @override
  String get cityBern => 'Bern';

  @override
  String get deleteUpper => 'DELETE';

  @override
  String get invitationsUpper => 'INVITATIONS';

  @override
  String get noInvitationsUpper => 'NO INVITATIONS';

  @override
  String get noInvitationsMessage =>
      'When your profile is added to a casting selection, the message will appear here.';

  @override
  String get consideredForCastingMessage =>
      'YOU ARE BEING CONSIDERED FOR A CASTING';

  @override
  String get requestVideoIntro => 'Request video intro';

  @override
  String get videoIntroRequirementsHint => 'Video intro requirements';

  @override
  String get videoIntroRequiredMessage => 'VIDEO INTRO REQUIRED';

  @override
  String get openChatUpper => 'OPEN CHAT';

  @override
  String get chatUpper => 'CHAT';

  @override
  String get chatEmptyMessage => 'No messages yet. Send the first message.';

  @override
  String get messageHint => 'Message';

  @override
  String get copyPublicLinkUpper => 'COPY LINK';

  @override
  String get publicLinkCopied => 'Link copied';

  @override
  String get publicSelectionEnable => 'Publish selection';

  @override
  String get publicSelectionDisable => 'Hide selection';

  @override
  String get publicSelectionLinkUpper => 'PUBLIC LINK';

  @override
  String get publicSelectionCopyLink => 'Copy link';

  @override
  String get publicSelectionLinkCopied => 'Selection link copied';

  @override
  String get publicSelectionUnavailable =>
      'This selection is unavailable or no longer public.';

  @override
  String get publicSelectionClientTitle =>
      'Review the models in this selection';

  @override
  String get publicSelectionClientSubtitle =>
      'Like or reject each model and leave notes for the agent.';

  @override
  String get clientFeedbackLike => 'Like';

  @override
  String get clientFeedbackReject => 'Reject';

  @override
  String get clientFeedbackCommentHint => 'Comment for the agent';

  @override
  String get clientFeedbackSaveComment => 'Save';

  @override
  String get clientFeedbackSaved => 'Response saved';

  @override
  String get clientFeedbackEmpty => 'No client feedback yet';

  @override
  String clientFeedbackLikesCount(int count) {
    return 'Likes: $count';
  }

  @override
  String clientFeedbackRejectsCount(int count) {
    return 'Rejects: $count';
  }

  @override
  String get agentWorkspaceUpper => 'AGENT WORKSPACE';

  @override
  String get agentFoldersUpper => 'FOLDERS';

  @override
  String get agentFolderCreateUpper => 'NEW';

  @override
  String get agentFolderCreateTitle => 'New folder';

  @override
  String get agentFolderName => 'Folder name';

  @override
  String get agentNoFolders => 'No folders yet';

  @override
  String get agentMyFoldersUpper => 'MY FOLDERS';

  @override
  String get agentFolderEmpty => 'There are no models in this folder yet';

  @override
  String get agentFavoriteFolderTitle => 'Favorites';

  @override
  String get quickAddTitleUpper => 'QUICK ADD';

  @override
  String get quickAddFavorite => 'Favorite';

  @override
  String get quickAddSelection => 'Selection';

  @override
  String get quickAddFolder => 'Add to folder';

  @override
  String get quickAddCreateFolder => 'New folder';

  @override
  String get quickAddFavoriteDone => 'Model added to favorites';

  @override
  String quickAddFolderDone(String folder) {
    return 'Model added to “$folder”';
  }

  @override
  String quickAddSelectionDone(String selection) {
    return 'Selection “$selection” created';
  }

  @override
  String get agentPrivateNoteUpper => 'PRIVATE NOTE';

  @override
  String get agentPrivateNoteEmpty => 'No note yet';

  @override
  String get agentEditNoteUpper => 'EDIT';

  @override
  String get agentNoteHint => 'Only you can see this note';

  @override
  String selectionProfileLimitMessage(int limit) {
    return 'Free plan allows up to $limit models in one selection.';
  }

  @override
  String selectionCountLimitMessage(int limit) {
    return 'Free plan allows up to $limit selections. Upgrade to Pro for more.';
  }

  @override
  String get notificationsUpper => 'NOTIFICATIONS';

  @override
  String get notificationsAccountEntrySubtitle =>
      'Selection, message, and profile events';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get analyticsUpper => 'ANALYTICS';

  @override
  String get analyticsAccountEntrySubtitle =>
      'Profile views, selections, and invitations';

  @override
  String get analyticsProfiles => 'Profiles';

  @override
  String get analyticsProfileViews => 'Profile views';

  @override
  String get analyticsSelectionAdds => 'Selection adds';

  @override
  String get analyticsInvitations => 'Invitations';

  @override
  String get analyticsHint =>
      'Data will appear after applying SQL and new app activity.';

  @override
  String get safetyAdminUpper => 'SAFETY';

  @override
  String get safetyReportsEmpty => 'No reports yet';

  @override
  String get reportProfileUpper => 'REPORT';

  @override
  String get blockUserUpper => 'BLOCK';

  @override
  String get reportReasonSpam => 'Spam or scam';

  @override
  String get reportReasonFake => 'Fake profile';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get profileReportSent => 'Report sent';

  @override
  String get profileReportSetupRequired =>
      'Reports will work after applying SQL.';

  @override
  String get profileBlocked => 'User blocked';

  @override
  String get profileBlockSetupRequired =>
      'Blocks will work after applying SQL.';

  @override
  String get projectClientHint => 'Client';

  @override
  String get projectBrandHint => 'Brand';

  @override
  String get projectBudgetHint => 'Budget';

  @override
  String get projectLocationHint => 'Location';

  @override
  String get projectDatesHint => 'Project dates';

  @override
  String get projectRolesHint => 'Roles and tasks: model, actor, stylist...';

  @override
  String get projectCampaignUpper => 'CAMPAIGN';

  @override
  String get projectClient => 'Client';

  @override
  String get projectBrand => 'Brand';

  @override
  String get projectBudget => 'Budget';

  @override
  String get projectLocation => 'Location';

  @override
  String get projectDates => 'Dates';

  @override
  String get projectRoles => 'Roles';
}
