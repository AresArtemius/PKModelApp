import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/ui_constants.dart';

/// Wide-screen frame for the auth pages: a dark brand panel on the left and
/// a white column with the form on the right (v2 visual standard, step 18б).
///
/// The brand panel is a gradient for now; drop a photo into [AuthBrandPanel]
/// (`imageAsset`) once there is one with usage rights.
class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({
    super.key,
    required this.child,
    this.topBar,
    this.panelWidth = 520,
  });

  /// Form column content; already scrollable or short enough to fit.
  final Widget child;

  /// Optional row above the form (links, language toggle).
  final Widget? topBar;

  final double panelWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(child: AuthBrandPanel()),
        SizedBox(
          width: panelWidth,
          child: ColoredBox(
            color: Tokens.bg,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (topBar != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 20, 24, 0),
                      child: topBar,
                    ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 32,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: Tokens.formWidth,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left half of the auth screens: brand gradient, logo and the claim.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key, this.imageAsset});

  /// Optional full-bleed photo; the gradient stays on top as a scrim.
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageAsset != null)
          Image.asset(
            imageAsset!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF020202),
                Color(0xFF140507),
                Color(0xFF42000A),
                Color(0xFF760012),
              ],
              stops: [0, 0.46, 0.78, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0.2),
              radius: 0.9,
              colors: [Color(0x55B00000), Color(0x00B00000)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 40, 48, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/pk-logo-splash-512.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'PK MANAGEMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  t.authHeroTitle,
                  style: AppText.display.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact two-option switch (Email / Телефон) for the v2 forms.
class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _AuthModeOption(
                label: labels[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthModeOption extends StatelessWidget {
  const _AuthModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Tokens.fast,
          decoration: BoxDecoration(
            color: selected ? Tokens.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.smallStrong.copyWith(
              color: selected ? Tokens.text : Tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
