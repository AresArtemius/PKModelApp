import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'brand_theme.dart';
import 'design_tokens.dart';
import 'ui_constants.dart';

/// Global Material theme built on the v2 tokens: white page, flat inputs
/// with 10 px radius, dark primary buttons, shadows only on dialogs/menus.
ThemeData buildModelAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    // Brand typeface with full Cyrillic; weights above 700 fall back to Bold.
    fontFamily: kBrandFontFamily,
    brightness: Brightness.light,
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: Tokens.ink,
    brightness: Brightness.light,
    primary: Tokens.ink,
    onPrimary: Tokens.textOnDark,
    secondary: Tokens.textSecondary,
    error: Tokens.danger,
    surface: Tokens.bg,
    onSurface: Tokens.text,
    outline: Tokens.border,
    outlineVariant: Tokens.border,
  );

  final inputRadius = BorderRadius.circular(10);
  InputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Tokens.radiusMd),
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Tokens.bg,
    canvasColor: Tokens.bg,
    dividerColor: Tokens.border,
    splashFactory: kIsWeb ? NoSplash.splashFactory : base.splashFactory,
    textTheme: base.textTheme.copyWith(
      displaySmall: AppText.display,
      headlineMedium: AppText.h1,
      titleLarge: AppText.h2,
      titleMedium: AppText.bodyStrong,
      bodyLarge: AppText.body,
      bodyMedium: AppText.small,
      bodySmall: AppText.caption,
      labelLarge: AppText.button,
      labelSmall: AppText.label,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      titleTextStyle: AppText.h2,
      contentTextStyle: AppText.body.copyWith(color: Tokens.textSecondary),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.border),
      ),
      textStyle: AppText.small,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Tokens.radiusLg),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Tokens.ink,
      contentTextStyle: AppText.small.copyWith(color: Tokens.textOnDark),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      actionTextColor: Tokens.textOnDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Tokens.text,
        disabledForegroundColor: kDisabledText,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        textStyle: AppText.button,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Tokens.textOnDark,
        backgroundColor: Tokens.ink,
        disabledForegroundColor: kDisabledText,
        disabledBackgroundColor: Tokens.surfaceAlt,
        minimumSize: const Size(Tokens.buttonMinWidth, Tokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s20),
        shape: buttonShape,
        textStyle: AppText.button,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Tokens.textOnDark,
        backgroundColor: Tokens.ink,
        disabledForegroundColor: kDisabledText,
        disabledBackgroundColor: Tokens.surfaceAlt,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(Tokens.buttonMinWidth, Tokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s20),
        shape: buttonShape,
        textStyle: AppText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Tokens.text,
        disabledForegroundColor: kDisabledText,
        side: const BorderSide(color: Tokens.borderStrong),
        minimumSize: const Size(Tokens.buttonMinWidth, Tokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s20),
        shape: buttonShape,
        textStyle: AppText.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Tokens.bg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Tokens.s16,
        vertical: 14,
      ),
      labelStyle: AppText.small.copyWith(color: Tokens.textSecondary),
      floatingLabelStyle: AppText.caption.copyWith(color: Tokens.text),
      hintStyle: AppText.small.copyWith(color: Tokens.textTertiary),
      border: inputBorder(Tokens.border),
      enabledBorder: inputBorder(Tokens.border),
      focusedBorder: inputBorder(Tokens.text, 1.5),
      errorBorder: inputBorder(Tokens.danger),
      focusedErrorBorder: inputBorder(Tokens.danger, 1.5),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: Tokens.borderStrong, width: 1.5),
    ),
    dividerTheme: const DividerThemeData(
      color: Tokens.border,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Tokens.ink,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      textStyle: AppText.caption.copyWith(color: Tokens.textOnDark),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
  );
}
