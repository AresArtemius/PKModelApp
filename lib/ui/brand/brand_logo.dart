import 'dart:async';
import 'package:flutter/material.dart';

class BrandLogo extends StatefulWidget {
  const BrandLogo({
    super.key,
    required this.height,
    this.blackAsset = 'assets/images/pk-logo-black-512.png',
    this.redAsset = 'assets/images/pk-logo-red-512.png',
  });

  final double height;
  final String blackAsset;
  final String redAsset;

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> {
  bool _hovered = false;
  bool _pressed = false;
  bool _flash = false;
  Timer? _timer;

  bool get _active => _hovered || _pressed || _flash;

  void _startFlash() {
    _timer?.cancel();
    setState(() => _flash = true);
    _timer = Timer(const Duration(milliseconds: 220), () {
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _startFlash();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Image.asset(
              _active ? widget.blackAsset : widget.redAsset,
              key: ValueKey(_active),
              height: widget.height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
