import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';

const _kAdminBg = BrandTheme.greyMid;

const double _kAdminPad = 14;
const double _kAdminPagePad = 16;
const double _kAdminSectionGap = 12;
const double _kAdminButtonGap = 10;
const double _kAdminMessagePadV = 18;
const double _kAdminMaxCardWidth = 460;

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final isAdminAsync = ref.watch(isAdminProvider);

    Future<void> signOutAndGoLogin() async {
      context.go(Routes.login);
      try {
        await ref.read(supabaseProvider).auth.signOut();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Sign out failed')));
        }
      }
    }

    return Scaffold(
      backgroundColor: _kAdminBg,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_kAdminPagePad),
          child: isAdminAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _ForbiddenView(
              message: t.adminOnlyUpper,
              exitLabel: t.adminExitUpper,
              onExit: signOutAndGoLogin,
            ),
            data: (isAdmin) {
              if (!isAdmin) {
                return _ForbiddenView(
                  message: t.adminOnlyUpper,
                  exitLabel: t.adminExitUpper,
                  onExit: signOutAndGoLogin,
                );
              }

              return _AdminHome(
                exitLabel: t.adminExitUpper,
                actions: [
                  (
                    label: t.adminCreateCastingUpper,
                    onTap: () => context.go(Routes.createCastingAdmin),
                  ),
                  (
                    label: t.selectionUpper,
                    onTap: () => context.go(Routes.adminSelection),
                  ),
                  (
                    label: t.adminModerationUpper,
                    onTap: () => context.go(Routes.moderationAdmin),
                  ),
                  (
                    label: t.adminAgentApplicationsUpper,
                    onTap: () =>
                        context.go(Routes.castingAgentApplicationsAdmin),
                  ),
                  (
                    label: Localizations.localeOf(context).languageCode == 'ru'
                        ? 'ОБЪЕДИНЕНИЕ АККАУНТОВ'
                        : 'ACCOUNT MERGES',
                    onTap: () => context.go(Routes.accountMergeRequestsAdmin),
                  ),
                  (
                    label: t.safetyAdminUpper,
                    onTap: () => context.go(Routes.safetyAdmin),
                  ),
                ],
                onExit: signOutAndGoLogin,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ForbiddenView extends StatelessWidget {
  const _ForbiddenView({
    required this.message,
    required this.exitLabel,
    required this.onExit,
  });

  final String message;
  final String exitLabel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminTopBar(exitLabel: exitLabel, onExit: onExit),
        const SizedBox(height: _kAdminSectionGap),
        Expanded(
          child: Center(
            child: _AdminSurface(
              maxWidth: _kAdminMaxCardWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _kAdminMessagePadV,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: adminCommandStyle(size: 14, letterSpacing: 1.1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({
    required this.exitLabel,
    required this.actions,
    required this.onExit,
  });

  final String exitLabel;
  final List<({String label, VoidCallback onTap})> actions;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminTopBar(exitLabel: exitLabel, onExit: onExit),
        const SizedBox(height: _kAdminSectionGap),
        Expanded(
          child: Center(
            child: _AdminSurface(
              maxWidth: _kAdminMaxCardWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    BrandPillButton(
                      label: actions[i].label,
                      style: BrandPillStyle.light,
                      onTap: actions[i].onTap,
                    ),
                    if (i != actions.length - 1)
                      const SizedBox(height: _kAdminButtonGap),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.exitLabel, required this.onExit});

  final String exitLabel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _AdminSurface(
      child: Align(
        alignment: Alignment.centerLeft,
        child: BrandPillButton(
          label: exitLabel,
          style: BrandPillStyle.dark,
          onTap: onExit,
        ),
      ),
    );
  }
}

class _AdminSurface extends StatelessWidget {
  const _AdminSurface({required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      constraints: maxWidth == null
          ? null
          : const BoxConstraints(maxWidth: _kAdminMaxCardWidth),
      padding: const EdgeInsets.all(_kAdminPad),
      decoration: catalogCardDecoration(),
      child: child,
    );

    if (maxWidth == null) return content;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: content,
    );
  }
}
