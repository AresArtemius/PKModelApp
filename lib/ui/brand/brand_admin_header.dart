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

class BrandAdminHeaderAction {
  const BrandAdminHeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

class BrandAdminHeaderActions extends StatelessWidget {
  const BrandAdminHeaderActions({
    super.key,
    required this.actions,
    this.maxVisible = 2,
  });

  final List<BrandAdminHeaderAction> actions;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visibleCount = actions.length <= maxVisible
        ? actions.length
        : maxVisible.clamp(0, actions.length - 1).toInt();
    final visible = actions.take(visibleCount).toList(growable: false);
    final overflow = actions.skip(visibleCount).toList(growable: false);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in visible)
          _BrandAdminHeaderIconButton(action: action),
        if (overflow.isNotEmpty)
          PopupMenuButton<int>(
            tooltip: 'Действия',
            color: Colors.white,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: kBorderColor),
            ),
            icon: const Icon(Icons.more_horiz_rounded, color: kTextDark),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 44),
            position: PopupMenuPosition.under,
            onSelected: (index) => overflow[index].onPressed?.call(),
            itemBuilder: (context) => [
              for (var i = 0; i < overflow.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  enabled: overflow[i].onPressed != null,
                  child: Row(
                    children: [
                      Icon(
                        overflow[i].icon,
                        size: 18,
                        color: overflow[i].destructive
                            ? BrandTheme.redTop
                            : kTextDark,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          overflow[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BrandTheme.pillText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            color: overflow[i].destructive
                                ? BrandTheme.redTop
                                : kTextDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _BrandAdminHeaderIconButton extends StatelessWidget {
  const _BrandAdminHeaderIconButton({required this.action});

  final BrandAdminHeaderAction action;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: action.label,
      onPressed: action.onPressed,
      icon: Icon(action.icon, color: BrandTheme.redTop, size: 22),
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 44),
      visualDensity: VisualDensity.compact,
    );
  }
}
