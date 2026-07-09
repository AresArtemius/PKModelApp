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

class AdminMenuOption<T> {
  const AdminMenuOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AdminCompactSummary extends StatelessWidget {
  const AdminCompactSummary({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    final first = items.isEmpty ? '' : '${items.first.$1}: ${items.first.$2}';
    return PopupMenuButton<int>(
      tooltip: title,
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: false,
            child: Text(
              '${items[i].$1}: ${items[i].$2}',
              style: adminBodyStyle(color: kTextDark),
            ),
          ),
      ],
      child: _AdminCompactPill(
        icon: Icons.analytics_outlined,
        label: first.isEmpty ? title : '$title · $first',
        trailing: Icons.keyboard_arrow_down_rounded,
      ),
    );
  }
}

class AdminMenuFilter<T> extends StatelessWidget {
  const AdminMenuFilter({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String valueLabel;
  final List<AdminMenuOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            child: Text(option.label, style: adminBodyStyle(color: kTextDark)),
          ),
      ],
      child: _AdminCompactPill(
        icon: Icons.tune_rounded,
        label: '$label: $valueLabel',
        trailing: Icons.keyboard_arrow_down_rounded,
      ),
    );
  }
}

class _AdminCompactPill extends StatelessWidget {
  const _AdminCompactPill({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: kTextDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: adminCommandStyle(size: 12, letterSpacing: 0.2),
              ),
            ),
            const SizedBox(width: 4),
            Icon(trailing, size: 18, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}
