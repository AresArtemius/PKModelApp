import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'brand_theme.dart';
import 'feature_ui_tokens.dart';

// ===============================================================
// DECORATIONS — общие декорации
// ===============================================================

/// Стандартная рамка pill-элементов
InputBorder pillBorder({Color? color, double? width}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(kPillRadius),
    borderSide: BorderSide(color: color ?? kBorderColor, width: width ?? 1),
  );
}

/// Универсальная pill-декорация (светлая / тёмная)
BoxDecoration pillDecoration({required bool isDark, required double radius}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: isDark
        ? BrandTheme.darkPillGradient
        : BrandTheme.lightPillGradient,
    border: Border.all(color: kBorderColor, width: 1),
    boxShadow: BrandTheme.basePillShadow(isDark: isDark),
  );
}

/// Shared input decoration
InputDecoration pillInputDecoration({
  required String hint,
  Color? focusColor,
  double? focusWidth,
}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withValues(alpha: kWhiteOpacity92),
    contentPadding: kDialogFieldPad,
    border: pillBorder(),
    enabledBorder: pillBorder(),
    focusedBorder: pillBorder(
      color: focusColor ?? BrandTheme.redTop,
      width: focusWidth ?? kDialogFieldFocusBorderW,
    ),
  );
}

// ===============================================================
// AUTH REQUIRED PAGE — decoration
// ===============================================================

BoxDecoration authRequiredCardDecoration() {
  return catalogCardDecoration();
}

// ===============================================================
// CASTINGS PAGE — decorations
// ===============================================================

BoxDecoration castingCardDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.96),
        const Color(0xFFF6F6F6).withValues(alpha: 0.94),
      ],
    ),
    borderRadius: BorderRadius.circular(kCardRadius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.76), width: 1),
    boxShadow: BrandTheme.surfaceShadow(
      darkColor: const Color(0x22000000),
      darkBlur: 16,
      darkOffset: const Offset(0, 10),
      lightColor: Colors.white.withValues(alpha: 0.92),
      lightBlur: 8,
      lightOffset: const Offset(0, -3),
    ),
  );
}

BoxDecoration castingDialogDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(kCardRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.97),
        const Color(0xFFF1F1F1).withValues(alpha: 0.95),
      ],
    ),
    boxShadow: BrandTheme.surfaceShadow(
      darkColor: Colors.black.withValues(alpha: 0.18),
      darkBlur: 22,
      darkOffset: const Offset(0, 12),
      lightColor: Colors.white.withValues(alpha: 0.82),
      lightBlur: 8,
      lightOffset: const Offset(0, -3),
    ),
    border: Border.all(color: Colors.white.withValues(alpha: 0.78), width: 1),
  );
}

// ===============================================================
// CATALOG PAGE — decorations
// ===============================================================

BoxDecoration catalogCardDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(kCardRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.97),
        const Color(0xFFF7F7F7).withValues(alpha: 0.95),
      ],
    ),
    border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 1),
    boxShadow: BrandTheme.surfaceShadow(
      darkColor: const Color(0x21000000),
      darkBlur: 15,
      darkOffset: const Offset(0, 9),
      lightColor: Colors.white.withValues(alpha: 0.9),
      lightBlur: 8,
      lightOffset: const Offset(0, -3),
    ),
  );
}

BoxDecoration catalogSearchDecoration({
  Color? borderColor,
  double borderWidth = 1,
  double? radius,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius ?? BrandTheme.pillRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.96),
        const Color(0xFFF8F8F8).withValues(alpha: 0.94),
      ],
    ),
    border: Border.all(
      color: borderColor ?? Colors.white.withValues(alpha: 0.72),
      width: borderWidth,
    ),
    boxShadow: BrandTheme.surfaceShadow(
      darkColor: const Color(0x16000000),
      darkBlur: 11,
      darkOffset: const Offset(0, 6),
      lightColor: Colors.white.withValues(alpha: 0.86),
      lightBlur: 6,
      lightOffset: const Offset(0, -2),
    ),
  );
}

BoxDecoration catalogPhotoPlaceholderDecoration() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE9E9E9), Color(0xFFD6D6D6), Color(0xFFF1F1F1)],
      stops: [0, 0.62, 1],
    ),
  );
}

BoxDecoration catalogDialogDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(kCardRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.98),
        const Color(0xFFF4F4F4).withValues(alpha: 0.96),
      ],
    ),
    border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 1),
    boxShadow: BrandTheme.surfaceShadow(
      darkColor: Colors.black.withValues(alpha: 0.24),
      darkBlur: 24,
      darkOffset: const Offset(0, 13),
      lightColor: Colors.white.withValues(alpha: 0.9),
      lightBlur: 9,
      lightOffset: const Offset(0, -3),
    ),
  );
}

ButtonStyle castingDialogOutlinedButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: kTextDark,
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  side: BorderSide(color: Colors.black.withValues(alpha: 0.12), width: 1),
);

ButtonStyle castingDialogFilledButtonStyle() => ElevatedButton.styleFrom(
  foregroundColor: Colors.white,
  backgroundColor: kTextDark,
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  elevation: 0,
);

BoxDecoration profileCardDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: kLoginCardWhiteOpacity),
    borderRadius: BorderRadius.circular(kCardRadius),
    boxShadow: kLoginCardShadow,
  );
}

BoxDecoration profileDialogDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: kLoginCardWhiteOpacity),
    borderRadius: BorderRadius.circular(kCardRadius),
    boxShadow: kLoginCardShadow,
    border: Border.all(color: kBorderColor),
  );
}

BoxDecoration profileMediaBoxDecoration() {
  return BoxDecoration(
    color: kSurfaceSoft,
    borderRadius: BorderRadius.circular(kProfileFieldRadius),
    border: Border.all(color: kBorderColor),
  );
}

BoxDecoration profileRemoveButtonDecoration() {
  return BoxDecoration(
    color: kOverlayDark,
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
    boxShadow: const [
      BoxShadow(color: kShadowSoftDark, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );
}

BoxDecoration profileAddButtonDecoration({required bool glow}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(kProfileImageRadius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2F2F2F), Color(0xFF0F0F0F)],
    ),
    boxShadow: [
      const BoxShadow(
        color: kShadowSoftDark,
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
      if (glow)
        BoxShadow(
          color: BrandTheme.redTop.withValues(alpha: 0.40),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
    ],
  );
}

InputDecoration profileFieldDecoration({required String label}) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withValues(alpha: kWhiteOpacity92),
    contentPadding: kDialogFieldPad,
    border: pillBorder(),
    enabledBorder: pillBorder(),
    focusedBorder: pillBorder(
      color: BrandTheme.redTop,
      width: kDialogFieldFocusBorderW,
    ),
  );
}

BoxDecoration profileLogoutButtonDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(kProfileFieldRadius),
    color: kTextDark,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.10),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration profileImagePlaceholderDecoration() {
  return BoxDecoration(
    color: kSurfaceLight,
    borderRadius: BorderRadius.circular(kProfileImageRadius),
    border: Border.all(color: kBorderColor),
  );
}

BoxDecoration profileThumbDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(kProfileThumbRadius),
    border: Border.all(color: kBorderColor),
  );
}

BoxDecoration profileVideoThumbDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(kProfileThumbRadius),
    color: kOverlayDark,
    border: Border.all(color: kBorderColor),
  );
}
