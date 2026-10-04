import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'auth_v2_widgets.dart';

class AuthRequiredPage extends StatelessWidget {
  const AuthRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (kIsWeb) {
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      return Scaffold(
        backgroundColor: Tokens.bg,
        body: AuthPageFrame(
          topBar: Row(
            children: [
              AuthBackLink(
                label: ru ? 'На главную' : 'Home',
                onTap: () => context.go(Routes.castings),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Tokens.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Tokens.ink,
                  size: 26,
                ),
              ),
              const SizedBox(height: 20),
              Text(ru ? 'Нужен аккаунт' : 'Sign in required', style: AppText.h1),
              const SizedBox(height: 8),
              Text(
                t.notRegisteredMessage,
                style: AppText.small.copyWith(color: Tokens.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: Tokens.inputHeight,
                child: FilledButton(
                  onPressed: () => context.go(Routes.register),
                  child: Text(t.signUp),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: Tokens.inputHeight,
                child: OutlinedButton(
                  onPressed: () => context.go(Routes.login),
                  child: Text(t.signInTitle),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
