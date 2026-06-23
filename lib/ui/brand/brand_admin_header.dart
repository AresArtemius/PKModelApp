import 'package:flutter/material.dart';

import 'brand_theme.dart';
import 'ui_constants.dart';

class BrandAdminHeader extends StatelessWidget {
  const BrandAdminHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.sideWidth = kTopBarIconBoxW,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final double sideWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardRadius),
        gradient: BrandTheme.lightPillGradient,
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Row(
        children: [
          SizedBox(
            width: sideWidth,
            child: Center(
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: kTextDark),
                splashRadius: 22,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: BrandTheme.pillText.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: sideWidth,
            child: trailing == null
                ? const SizedBox()
                : Center(child: trailing),
          ),
        ],
      ),
    );
  }
}
