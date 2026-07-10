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

Future<bool> showAdminConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Отмена',
  String confirmLabel = 'Да',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: kTextDark.withValues(alpha: 0.34),
    builder: (dialogContext) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: DecoratedBox(
          decoration: catalogCardDecoration().copyWith(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: adminCommandStyle(
                    size: 16,
                    letterSpacing: 1.0,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: adminBodyStyle(
                    size: 13,
                    color: kTextDark,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _AdminDialogButton(
                      label: cancelLabel,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                    const SizedBox(width: 10),
                    _AdminDialogButton(
                      label: confirmLabel,
                      dark: true,
                      destructive: destructive,
                      onTap: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

class _AdminDialogButton extends StatelessWidget {
  const _AdminDialogButton({
    required this.label,
    required this.onTap,
    this.dark = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool dark;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final gradient = destructive
        ? BrandTheme.redPillGradient
        : dark
        ? BrandTheme.darkPillGradient
        : BrandTheme.lightPillGradient;
    final color = dark || destructive ? Colors.white : kTextDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(999),
            border: dark || destructive
                ? null
                : Border.all(color: kBorderColor),
            boxShadow: BrandTheme.basePillShadow(isDark: dark || destructive),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: adminCommandStyle(
                size: 11,
                letterSpacing: 0.4,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminMenuOption<T> {
  const AdminMenuOption({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
}

class AdminLoadMoreFooter extends StatelessWidget {
  const AdminLoadMoreFooter({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Ink(
              decoration: pillDecoration(isDark: true, radius: 999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Text(
                  label,
                  style: adminCommandStyle(
                    size: 11,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPopupMenuButton<T> extends StatelessWidget {
  const AdminPopupMenuButton({
    super.key,
    required this.tooltip,
    required this.options,
    required this.child,
    this.onSelected,
  });

  final String tooltip;
  final List<AdminMenuOption<T>> options;
  final Widget child;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: const Color(0x33000000),
      offset: const Offset(0, 8),
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 300),
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorderColor),
      ),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            enabled: option.enabled,
            height: 44,
            padding: EdgeInsets.zero,
            child: _AdminPopupMenuItem(option: option),
          ),
      ],
      child: child,
    );
  }
}

class _AdminPopupMenuItem<T> extends StatelessWidget {
  const _AdminPopupMenuItem({required this.option});

  final AdminMenuOption<T> option;

  @override
  Widget build(BuildContext context) {
    final color = option.destructive ? BrandTheme.redTop : kTextDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (option.icon != null) ...[
            Icon(option.icon, size: 17, color: color),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: adminBodyStyle(
                size: 12,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    return AdminPopupMenuButton<int>(
      tooltip: title,
      options: [
        for (var i = 0; i < items.length; i++)
          AdminMenuOption<int>(
            value: i,
            label: '${items[i].$1}: ${items[i].$2}',
            enabled: false,
            icon: i == 0 ? Icons.analytics_outlined : Icons.circle_outlined,
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
    return AdminPopupMenuButton<T>(
      tooltip: label,
      onSelected: onSelected,
      options: options,
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
