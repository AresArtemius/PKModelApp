import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Единый стиль приложения (цвета, радиусы, тени, фон, кнопки).
class BrandTheme {
  // Colors
  static const redTop = Color(0xFFB00000);
  static const redBottom = Color(0xFF7A0000);

  static const greyTop = Color(0xFFF1F1F1);
  static const greyMid = Color(0xFFE7E7E7);
  static const greyBottom = Color(0xFFDADADA);

  static const textDark = Color(0xFF4A4A4A);

  static const _white22 = Color(0x22FFFFFF);
  static const _white08 = Color(0x08FFFFFF);
  static const _transparentWhite = Color(0x00FFFFFF);
  static const _solidWhite = Color(0xFFFFFFFF);
  static const _black22 = Color(0x22000000);
  static const _black44 = Color(0x44000000);

  // Radii
  static const pillRadius = 999.0;

  // Sizes
  static const pillHeight = 56.0;

  static const _bgGlowCenter = Alignment(0.0, -0.05);
  static const _bgGlowRadius = 0.9;
  static const _bgVignetteCenter = Alignment(0.0, 0.0);
  static const _bgVignetteRadius = 1.1;
  static const _bgVignetteStops = <double>[0.55, 0.82, 1.0];
  static const _bgBlurSigma = 8.0;

  // Shadows
  static const _baseShadowColor = Color(0x33000000);

  static List<BoxShadow> basePillShadow({required bool isDark}) => [
    BoxShadow(
      color: _baseShadowColor,
      blurRadius: isDark ? 26 : 18,
      offset: const Offset(0, 10),
    ),
    const BoxShadow(
      color: BrandTheme._white22,
      blurRadius: 12,
      offset: Offset(0, -6),
    ),
  ];

  static List<BoxShadow> redGlow({required bool strong}) => [
    BoxShadow(
      color: strong ? const Color(0x88B00000) : const Color(0x66B00000),
      blurRadius: strong ? 30 : 22,
      spreadRadius: strong ? 4 : 2,
      offset: const Offset(0, 12),
    ),
  ];

  // Gradients
  static const darkPillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A3A3A), Color(0xFF1F1F1F)],
  );

  static const lightPillGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3F3F3), Color(0xFFE6E6E6)],
  );

  static const redPillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [redTop, redBottom],
  );

  // Typography
  static const pillText = TextStyle(
    fontSize: 16,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w500,
  );
}

/// Фон “как на референсе”: центр светлее, края темнее + лёгкая дымка.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                BrandTheme.greyTop,
                BrandTheme.greyMid,
                BrandTheme.greyBottom,
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: BrandTheme._bgGlowCenter,
                radius: BrandTheme._bgGlowRadius,
                colors: [BrandTheme._solidWhite, BrandTheme._transparentWhite],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: BrandTheme._bgVignetteCenter,
                radius: BrandTheme._bgVignetteRadius,
                colors: [
                  BrandTheme._transparentWhite,
                  BrandTheme._black22,
                  BrandTheme._black44,
                ],
                stops: BrandTheme._bgVignetteStops,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: BrandTheme._bgBlurSigma,
              sigmaY: BrandTheme._bgBlurSigma,
            ),
            child: Container(color: BrandTheme._white08),
          ),
        ),
      ],
    );
  }
}
