import 'package:flutter/material.dart';

import 'brand_theme.dart';

/// Design tokens v2 — the single source for colour, radius, spacing, shadow
/// and type scale on the web cabinet (see «Визуальный стандарт» in the plan).
///
/// Rules of thumb:
/// - white page, `surface` for panels, one accent colour for the primary
///   action only;
/// - radii 8 / 12, 16 for modals; no soft drop shadows on cards;
/// - headings in sentence case; uppercase only for 11–12 px labels.
class Tokens {
  const Tokens._();

  // ---- Colour ---------------------------------------------------------
  static const Color bg = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F5);
  static const Color surfaceAlt = Color(0xFFF1F1EF);
  static const Color border = Color(0xFFE6E6E3);
  static const Color borderStrong = Color(0xFFD6D6D2);

  static const Color text = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF9A9A96);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color accent = BrandTheme.redTop; // #B00000
  static const Color accentHover = Color(0xFF960000);
  static const Color accentSoft = Color(0xFFFBEAEA);

  static const Color success = Color(0xFF1E7F4F);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFB10F0F);

  /// Dark primary button / selected nav item.
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkHover = Color(0xFF000000);

  // ---- Radius ---------------------------------------------------------
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  // ---- Spacing --------------------------------------------------------
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  /// Content column on desktop and the width of forms.
  static const double contentMaxWidth = 1280;
  static const double formMaxWidth = 440;
  static const double formWidth = 360;

  // ---- Controls -------------------------------------------------------
  static const double controlHeight = 46;
  static const double inputHeight = 48;
  static const double buttonMinWidth = 140;

  // ---- Shadows (modals and popovers only) -----------------------------
  static const List<BoxShadow> modalShadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 20)),
  ];
  static const List<BoxShadow> popoverShadow = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  // ---- Motion ---------------------------------------------------------
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
}

/// Type scale 12 / 14 / 16 / 20 / 28 / 40 (Golos Text).
class AppText {
  const AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.5,
    color: Tokens.text,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.2,
    color: Tokens.text,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: Tokens.text,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Tokens.text,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: Tokens.text,
  );
  static const TextStyle small = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Tokens.text,
  );
  static const TextStyle smallStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: Tokens.text,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Tokens.textSecondary,
  );

  /// Uppercase label, the only place where tracking is allowed.
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.8,
    color: Tokens.textSecondary,
  );

  /// Button text.
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );
}
