import 'dart:async';
import 'package:flutter/material.dart';
import 'brand_theme.dart';

enum BrandPillStyle { dark, light }

class BrandPillButton extends StatefulWidget {
  const BrandPillButton({
    super.key,
    required this.label,
    required this.style,
    this.onTap,
  });

  final String label;
  final BrandPillStyle style;
  final VoidCallback? onTap;

  @override
  State<BrandPillButton> createState() => _BrandPillButtonState();
}

class _BrandPillButtonState extends State<BrandPillButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _flash = false;
  Timer? _timer;

  bool get _enabled => widget.onTap != null;
  bool get _active => _hovered || _pressed || _flash;

  void _startFlash() {
    _timer?.cancel();
    setState(() => _flash = true);
    _timer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _flash = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.style == BrandPillStyle.dark;
    final strongGlow = _flash;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(BrandTheme.pillRadius),
      border: isDark
          ? null
          : Border.all(color: const Color(0x22000000), width: 1),
      gradient: isDark
          ? (_active ? BrandTheme.redPillGradient : BrandTheme.darkPillGradient)
          : BrandTheme.lightPillGradient,
      boxShadow: [
        ...BrandTheme.basePillShadow(isDark: isDark),
        if (_active) ...BrandTheme.redGlow(strong: strongGlow),
      ],
    );

    final textStyle = BrandTheme.pillText.copyWith(
      color: isDark
          ? Colors.white.withValues(alpha: 0.95)
          : (_active ? BrandTheme.redTop : BrandTheme.textDark),
    );

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: _enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: _enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: _enabled
            ? (_) {
                setState(() => _pressed = false);
                _startFlash();
                widget.onTap?.call();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,

            height: BrandTheme.pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: decoration,
            child: Text(widget.label, style: textStyle),
          ),
        ),
      ),
    );
  }
}
