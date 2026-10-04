import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// One template for the service pages (billing, support, devices, 2FA,
/// data & privacy, analytics): a title, an optional «Назад» link, and a
/// 760 px column aligned to the left gutter with hairline sections.
class SettingsPageV2 extends StatelessWidget {
  const SettingsPageV2({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.backLabel,
    this.onBack,
    this.actions = const [],
    this.maxWidth = 760,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final String? backLabel;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final List<Widget> children;
  final double maxWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    final gutter = wide ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(gutter, onBack == null ? 28 : 16, gutter, 48),
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.translate(
                          offset: const Offset(-8, 0),
                          child: TextButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: Text(backLabel ?? ''),
                            style: TextButton.styleFrom(
                              foregroundColor: Tokens.textSecondary,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 36),
                              textStyle: AppText.smallStrong,
                            ),
                          ),
                        ),
                      ),
                    if (onBack != null) const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: actions.isEmpty ? maxWidth : maxWidth - 200,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppText.h1.copyWith(
                                  fontSize: wide ? 32 : 28,
                                ),
                              ),
                              if (subtitle != null && subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: AppText.caption.copyWith(fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (actions.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                actions[i],
                              ],
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section of a settings page: small uppercase label, optional hint and
/// the content, separated from the next section by a hairline.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.hint,
    this.trailing,
  });

  final String title;
  final String? hint;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: AppText.label.copyWith(color: Tokens.textTertiary),
                    ),
                    if (hint != null && hint!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        hint!,
                        style: AppText.small.copyWith(
                          color: Tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Label on the left, value on the right — a line of a facts table.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.trailing,
    this.labelWidth = 180,
    this.selectable = true,
  });

  final String label;
  final String? value;
  final Widget? child;
  final Widget? trailing;
  final double labelWidth;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final valueWidget =
        child ??
        (selectable
            ? SelectableText(
                value ?? '',
                style: AppText.small.copyWith(fontSize: 15, color: Tokens.text),
              )
            : Text(
                value ?? '',
                style: AppText.small.copyWith(fontSize: 15, color: Tokens.text),
              ));
    final labelWidget = Text(
      label,
      style: AppText.small.copyWith(color: Tokens.textTertiary),
    );

    if (narrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelWidget, const SizedBox(height: 2), valueWidget],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: labelWidth, child: labelWidget),
          Expanded(child: valueWidget),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// List row with an icon circle, title, subtitle and an optional trailing
/// control — devices, sessions, tickets, FAQ entries.
class SettingsListRow extends StatelessWidget {
  const SettingsListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.active = false,
    this.last = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? Tokens.ink : Tokens.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: active ? Colors.white : Tokens.textSecondary,
                ),
              ));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Tokens.border)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Tokens.text,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: Tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              if (trailing == null && onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Tokens.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet note or an error/success strip inside a section.
class SettingsNote extends StatelessWidget {
  const SettingsNote({
    super.key,
    required this.text,
    this.tone = SettingsNoteTone.quiet,
  });

  final String text;
  final SettingsNoteTone tone;

  @override
  Widget build(BuildContext context) {
    if (tone == SettingsNoteTone.quiet) {
      return Text(
        text,
        style: AppText.small.copyWith(color: Tokens.textSecondary, height: 1.45),
      );
    }
    final (bg, fg) = switch (tone) {
      SettingsNoteTone.danger => (Tokens.accentSoft, Tokens.danger),
      SettingsNoteTone.success => (const Color(0xFFE8F4EC), Tokens.success),
      SettingsNoteTone.info => (Tokens.surfaceAlt, Tokens.text),
      SettingsNoteTone.quiet => (Colors.transparent, Tokens.textSecondary),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: AppText.small.copyWith(color: fg, height: 1.4)),
    );
  }
}

enum SettingsNoteTone { quiet, info, success, danger }

/// Small status dot + text («Включено», «Не настроено»).
class SettingsStatus extends StatelessWidget {
  const SettingsStatus({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: AppText.small.copyWith(color: Tokens.text)),
      ],
    );
  }
}
