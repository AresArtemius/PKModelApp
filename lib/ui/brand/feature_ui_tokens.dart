import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'brand_theme.dart';

// ===============================================================
// AUTH (LOGIN / REGISTER) — shared tokens
// ===============================================================

/// Animations
const Duration kAnim200 = Duration(milliseconds: 200);

/// Auth validation
const int kPasswordMinLen = 6;

/// Auth error text
const TextStyle kAuthErrorTextStyle = TextStyle(color: kTextDanger);

// ===============================================================
// AUTH REQUIRED PAGE — page-specific layout tokens
// ===============================================================

/// Page padding
const EdgeInsets kAuthRequiredPagePad = EdgeInsets.fromLTRB(
  kPagePadH,
  16,
  kPagePadH,
  30,
);

/// Card inner padding
const EdgeInsets kAuthRequiredCardPad = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 18,
);

/// Title text style
final TextStyle kAuthRequiredTitleStyle = BrandTheme.pillText.copyWith(
  fontWeight: FontWeight.w700,
  letterSpacing: 1.5,
  fontSize: 18,
  color: kTextTitle,
);

/// Message text style
final TextStyle kAuthRequiredMessageStyle = BrandTheme.pillText.copyWith(
  fontSize: 14,
  letterSpacing: 0.15,
  fontWeight: FontWeight.w600,
  color: kTextMid,
  height: 1.25,
);

// ===============================================================
// LOGIN PAGE — page-specific layout tokens
// ===============================================================

/// Login page paddings
const EdgeInsets kLoginPagePad = EdgeInsets.fromLTRB(
  kPagePadH,
  32,
  kPagePadH,
  24,
);

/// Logo size on login page
const double kLoginLogoH = 160.0;

/// Standard button height on login page
const double kLoginButtonH = 56.0;

/// Gaps on login page
const double kLoginGapAfterLogo = 28.0;
const double kLoginGapButtons = 12.0;
const double kLoginGapSection = 18.0;
const double kLoginGapFields = 12.0;
const double kLoginGapActions = 16.0;
const double kLoginGapBottomRow = 14.0;

/// Language toggle chip
const double kLangToggleRadius = 20.0;
const EdgeInsets kLangTogglePad = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 6,
);

/// Login card
const EdgeInsets kLoginCardPad = EdgeInsets.all(16);
const double kLoginCardWhiteOpacity = 0.95;
const List<BoxShadow> kLoginCardShadow = [
  BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 12)),
  BoxShadow(color: Color(0x1AFFFFFF), blurRadius: 10, offset: Offset(0, -6)),
];

// ===============================================================
// REGISTER PAGE — page-specific layout tokens
// ===============================================================

/// Register page paddings
const EdgeInsets kRegisterPagePad = EdgeInsets.fromLTRB(
  kPagePadH,
  16,
  kPagePadH,
  24,
);

/// Top bar padding
const EdgeInsets kRegisterTopBarPad = EdgeInsets.fromLTRB(16, 10, 16, 10);

/// Button height
const double kRegisterButtonH = 56.0;

/// Gaps
const double kRegisterGap6 = 6.0;
const double kRegisterGap12 = 12.0;
const double kRegisterGap14 = 14.0;
const double kRegisterGap16 = 16.0;

/// Register title/hint styles
const TextStyle kRegisterTitleStyle = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.2,
  color: BrandTheme.textDark,
);

const TextStyle kRegisterHintStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  height: 1.22,
  color: kTextMuted,
);

/// Register topbar title style
const TextStyle kRegisterTopBarTitleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.1,
  color: BrandTheme.textDark,
);

/// Back pill
const double kBackPillRadius = 999.0;
const EdgeInsets kBackPillPad = EdgeInsets.all(12);
const double kBackPillOpacity = 0.9;
const double kBackIconSize = 18.0;
const List<BoxShadow> kBackPillShadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
];

/// Register card
const EdgeInsets kRegisterCardPad = EdgeInsets.all(16);
const double kRegisterCardWhiteOpacity = 0.95;
const List<BoxShadow> kRegisterCardShadow = kLoginCardShadow;

// ===============================================================
// CASTINGS PAGE — page-specific layout tokens
// ===============================================================

const TextStyle kCastingTitleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  color: kTextDark,
  height: 1.15,
);

const TextStyle kCastingBodyStyle = TextStyle(
  color: kTextDark,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  height: 1.22,
  letterSpacing: 0,
);

/// Casting card
const EdgeInsets kCastingCardPad = EdgeInsets.all(16);

/// Respond button height in list item header
const double kCastingRespondButtonH = 40.0;

/// Dialog paddings
const EdgeInsets kCastingDialogInsetPad = EdgeInsets.symmetric(
  horizontal: 18,
  vertical: 24,
);

const EdgeInsets kCastingDialogPad = EdgeInsets.fromLTRB(18, 18, 18, 16);

/// Dialog styles
const TextStyle kCastingDialogTitleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  color: kTextDark,
  fontSize: 20,
  height: 1.16,
);

const TextStyle kCastingDialogBodyStyle = TextStyle(
  fontWeight: FontWeight.w500,
  color: kTextMuted,
  height: 1.28,
  fontSize: 16,
  letterSpacing: 0,
);

/// Multi-profile dialog list
const double kCastingDialogMaxH = 420.0;

const double kCastingProfileTileRadius = 14.0;
const EdgeInsets kCastingProfileTileContentPad = EdgeInsets.symmetric(
  horizontal: 10,
);

// ===============================================================
// GRID — параметры сетки каталога
// ===============================================================

/// Количество колонок
const int kGridCrossAxisCount = 2;

/// Расстояние между карточками
const double kGridGap = 12.0;

/// Соотношение сторон карточки
const double kGridChildAspectRatio = 0.70;

/// Отступы grid
const EdgeInsets kGridPadding = EdgeInsets.only(bottom: 24);

// ===============================================================
// SEARCH / DIALOG / CARD TOKENS
// ===============================================================

/// Search debounce
const Duration kSearchDebounce = Duration(milliseconds: 350);

/// Search padding
const EdgeInsets kSearchContentPad = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 14,
);

/// Card info padding
const EdgeInsets kCardInfoPad = EdgeInsets.fromLTRB(12, 8, 12, 10);

/// Account pill padding
const EdgeInsets kAccountPad = EdgeInsets.symmetric(horizontal: 14);

/// Filter pill padding
const EdgeInsets kFilterPillPad = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 10,
);

/// Dialog paddings
const EdgeInsets kDialogInsetPad = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 24,
);

const EdgeInsets kDialogBodyPad = EdgeInsets.all(16);

const EdgeInsets kDialogFieldPad = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 14,
);

const EdgeInsets kDialogButtonPad = EdgeInsets.symmetric(vertical: 14);

const double kDialogActionsGap = 10.0;

/// Slider
const double kSliderTrackH = 4.0;
const double kRangeThumbRadius = 10.0;
const double kDialogFieldFocusBorderW = 1.2;

// ===============================================================
// CALENDAR
// ===============================================================

const int kCalendarCols = 7;
const double kCalendarGap = 8.0;
const double kCalendarDayRadius = 12.0;

// ===============================================================
// CATALOG FILTER LIMITS
// ===============================================================

const int kAgeMin = 0;
const int kAgeMax = 90;

const int kHeightMin = 20;
const int kHeightMax = 210;

const int kShoeMin = 5;
const int kShoeMax = 55;

const int kBustMin = 60;
const int kBustMax = 130;

const int kWaistMin = 30;
const int kWaistMax = 90;

const int kHipsMin = 60;
const int kHipsMax = 150;

/// Catalog / selection animations
const Duration kAnim160 = Duration(milliseconds: 160);
const Duration kAnim180 = Duration(milliseconds: 180);

// ===============================================================
// PROFILE PAGE — layout / component tokens
// ===============================================================

const EdgeInsets kMyProfilePagePad = EdgeInsets.fromLTRB(16, 18, 16, 24);
const EdgeInsets kMyProfileEditPagePad = EdgeInsets.fromLTRB(16, 10, 16, 24);

const EdgeInsets kProfileErrorPad = EdgeInsets.all(16);
const EdgeInsets kProfileBackButtonPad = EdgeInsets.symmetric(
  horizontal: 6,
  vertical: 8,
);
const EdgeInsets kProfileLogoutButtonPad = EdgeInsets.symmetric(horizontal: 14);
const EdgeInsets kProfileMediaInnerPad = EdgeInsets.all(12);

const double kProfileAddButtonSize = 56.0;
const double kProfileLogoutButtonHeight = 48.0;
const double kProfileSummaryImageSize = 72.0;
const double kProfileThumbSize = 74.0;
const double kProfileMediaPreviewMinHeight = 120.0;
const double kProfileMediaPreviewMaxHeight = 200.0;

const double kProfileImageRadius = 18.0;
const double kProfileFieldRadius = 16.0;
const double kProfileThumbRadius = 14.0;

const EdgeInsets kProfileDialogInsetPad = EdgeInsets.symmetric(
  horizontal: 24,
  vertical: 24,
);
const EdgeInsets kProfileDialogPad = EdgeInsets.fromLTRB(18, 18, 18, 16);

const EdgeInsets kProfilePlayBadgePad = EdgeInsets.all(6);
const EdgeInsets kProfileViewerPlayBadgePad = EdgeInsets.all(14);

const double kProfileSummaryGap = 16.0;
const double kProfileItemBottomGap = 14.0;
const double kProfileDialogTitleSize = 18.0;
const double kProfileDialogBodySize = 15.0;
const double kProfileDialogActionsTopGap = 18.0;

const double kProfileRemoveButtonInset = 4.0;
const double kProfileViewerBackInset = 8.0;

const double kProfileRemoveButtonSize = 22.0;
const double kProfileRemoveIconSize = 13.0;
const double kProfileViewerPlayIconSize = 34.0;
const double kProfileVideoFallbackIconSize = 28.0;

const double kProfileVideoThumbMaxWidth = 256.0;
const int kProfileVideoThumbQuality = 70;

const double kProfileDialogBodyHeight = 1.35;
const double kProfileDialogTitleLetterSpacing = 0.4;

const double kProfileCheckboxSize = 22.0;
const double kProfileCheckboxIconSize = 15.0;
const double kProfileCheckboxRadius = 6.0;
const double kProfileCheckboxRowRadius = 14.0;
const EdgeInsets kProfileCheckboxRowPad = EdgeInsets.symmetric(vertical: 4);
const double kProfileCheckboxGap = 12.0;

const double kProfileVideoViewerFallbackIconSize = 36.0;
const double kProfileVideoPlayIconSize = 18.0;

const Duration kProfileFlashDuration = Duration(milliseconds: 220);
const Duration kProfilePlusScaleDuration = Duration(milliseconds: 120);
const Duration kProfilePlusContainerDuration = Duration(milliseconds: 160);
const Duration kProfileViewerOverlayDuration = Duration(milliseconds: 160);

const double kProfileFallbackSpinnerSize = 18.0;
const double kProfileFallbackSpinnerStroke = 2.0;

const double kProfileVideoAspectFallback = 16 / 9;

// ===============================================================
// PROFILE PAGE — text styles
// ===============================================================

const TextStyle kProfileErrorTextStyle = TextStyle(color: kTextDanger);

const TextStyle kProfileSectionTitleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  letterSpacing: 1.4,
  color: kTextDark,
);

const TextStyle kProfileSummaryNameTextStyle = TextStyle(
  fontSize: kProfileDialogTitleSize,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
  color: kTextDark,
);

const TextStyle kProfileDialogTitleStyle = TextStyle(
  fontWeight: FontWeight.w800,
  fontSize: kProfileDialogTitleSize,
  letterSpacing: kProfileDialogTitleLetterSpacing,
  color: kTextDark,
);

const TextStyle kProfileDialogBodyStyle = TextStyle(
  fontSize: kProfileDialogBodySize,
  height: kProfileDialogBodyHeight,
  color: kTextDark,
);

const TextStyle kProfileDialogCheckboxTextStyle = TextStyle(
  color: kTextDark,
  fontSize: kProfileDialogBodySize,
);

const TextStyle kProfileHeaderSubtitleTextStyle = TextStyle(color: kTextMuted);
