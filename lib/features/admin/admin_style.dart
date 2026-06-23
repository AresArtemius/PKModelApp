import 'package:flutter/material.dart';

import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

TextStyle adminCommandStyle({
  double size = 16,
  double letterSpacing = 1.8,
  FontWeight weight = FontWeight.w700,
  Color color = kTextDark,
  double? height,
}) {
  return BrandTheme.pillText.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle adminBodyStyle({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color color = kTextMuted,
  double height = 1.25,
}) {
  return BrandTheme.pillText.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0,
    height: height,
  );
}

class AdminMessageCard extends StatelessWidget {
  const AdminMessageCard({
    super.key,
    required this.text,
    this.isError = false,
    this.maxWidth,
  });

  final String text;
  final bool isError;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: maxWidth ?? 460),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: catalogCardDecoration().copyWith(
          border: Border.all(
            color: isError ? BrandTheme.redTop : kBorderColor,
            width: isError ? 1.2 : 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: adminCommandStyle(
            size: 13,
            color: isError ? BrandTheme.redTop : kTextMuted,
            letterSpacing: 0.8,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
