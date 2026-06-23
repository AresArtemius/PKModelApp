import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class AuthRequiredPage extends StatelessWidget {
  const AuthRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: kAuthRequiredPagePad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: kGap8),
                  Container(
                    padding: kAuthRequiredCardPad,
                    decoration: authRequiredCardDecoration(),
                    child: Column(
                      children: [
                        Text(
                          t.notRegisteredTitle,
                          textAlign: TextAlign.center,
                          style: kAuthRequiredTitleStyle,
                        ),
                        const SizedBox(height: kGap10),
                        Text(
                          t.notRegisteredMessage,
                          textAlign: TextAlign.center,
                          style: kAuthRequiredMessageStyle,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  BrandPillButton(
                    label: t.registerUpper,
                    style: BrandPillStyle.dark,
                    onTap: () => context.go(Routes.register),
                  ),
                  const SizedBox(height: kGap12),
                  BrandPillButton(
                    label: t.signInUpper,
                    style: BrandPillStyle.light,
                    onTap: () => context.go(Routes.login),
                  ),
                  const SizedBox(height: kGap6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
