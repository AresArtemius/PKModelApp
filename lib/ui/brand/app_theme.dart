import 'package:flutter/material.dart';

import 'brand_theme.dart';
import 'ui_constants.dart';

ThemeData buildModelAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: null,
    brightness: Brightness.light,
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: kTextDark,
    brightness: Brightness.light,
    primary: kTextDark,
    secondary: kTextMid,
    error: kTextDanger,
    surface: Colors.white,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BrandTheme.greyMid,
    canvasColor: BrandTheme.greyMid,
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
        side: const BorderSide(color: kBorderColor, width: 1),
      ),
      titleTextStyle: const TextStyle(
        color: kTextDark,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
        height: 1.12,
      ),
      contentTextStyle: const TextStyle(
        color: kTextMid,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.36,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kTextDark,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      behavior: SnackBarBehavior.fixed,
      elevation: 0,
      actionTextColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTextDark,
        disabledForegroundColor: kDisabledText,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: kTextDark,
        disabledForegroundColor: kDisabledText,
        disabledBackgroundColor: kSurfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kPillRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextDark,
        disabledForegroundColor: kDisabledText,
        side: const BorderSide(color: kBorderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kPillRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: kWhiteOpacity92),
      labelStyle: const TextStyle(color: kTextMuted),
      floatingLabelStyle: const TextStyle(color: kTextDark),
      hintStyle: const TextStyle(color: kTextMuted),
      border: pillBorder(),
      enabledBorder: pillBorder(),
      focusedBorder: pillBorder(color: BrandTheme.redTop, width: 1.5),
    ),
  );
}
