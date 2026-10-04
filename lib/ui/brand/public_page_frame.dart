import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_top_bar.dart';
import '../../core/auth_providers.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import 'design_tokens.dart';

/// Frame for the pages a guest can open from a shared link (/p/:id, /s/:id,
/// /@tag): the regular top bar on wide screens, a slim bar with the logo
/// and «Войти» on narrow ones. Signed-in visitors get the same page.
class PublicPageFrame extends ConsumerWidget {
  const PublicPageFrame({
    super.key,
    required this.child,
    this.currentIndex = 1,
    this.onBack,
    this.backLabel,
    this.wideBreakpoint = 900,
  });

  final Widget child;
  final int currentIndex;
  final VoidCallback? onBack;
  final String? backLabel;
  final double wideBreakpoint;

  static const double narrowBarHeight = 56;

  /// Location of the sign-in page that comes back here afterwards.
  static String loginWithReturn(BuildContext context) {
    final here = GoRouterState.of(context).uri.toString();
    return '${Routes.login}?next=${Uri.encodeComponent(here)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    if (wide) {
      return Scaffold(
        backgroundColor: Tokens.bg,
        body: Column(
          children: [
            AppTopBar(currentIndex: currentIndex),
            Expanded(child: child),
          ],
        ),
      );
    }

    final t = AppLocalizations.of(context)!;
    final signedIn = ref.watch(isAuthenticatedProvider);
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: narrowBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Tokens.border)),
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      tooltip: backLabel,
                      style: IconButton.styleFrom(
                        foregroundColor: Tokens.textSecondary,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.go(Routes.castings),
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/pk-logo-red-512.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'PK MANAGEMENT',
                            style: TextStyle(
                              color: Tokens.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!signedIn)
                    OutlinedButton(
                      onPressed: () => context.go(loginWithReturn(context)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(t.signInTitle),
                    )
                  else
                    TextButton(
                      onPressed: () => context.go(Routes.search),
                      style: TextButton.styleFrom(
                        foregroundColor: Tokens.textSecondary,
                      ),
                      child: Text(t.catalogTab),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
