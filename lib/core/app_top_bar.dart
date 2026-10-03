import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/castings/castings_provider.dart';
import '../features/chat/chat_providers.dart';
import '../features/notifications/app_notifications.dart';
import '../gen_l10n/app_localizations.dart';
import '../ui/brand/ui_constants.dart';
import 'account_profile_service.dart';
import 'admin_dashboard_counts_provider.dart';
import 'auth_providers.dart';
import 'roles_provider.dart';
import 'router.dart';
import 'supabase_provider.dart';

/// Desktop header (v2 visual standard, step 18в): logo, the three sections
/// with badges, and on the right either «Войти» or the avatar menu.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key, required this.currentIndex});

  /// 0 castings, 1 catalogue, 2 chats, 3 account, 4 admin (AppShell order).
  final int currentIndex;

  static const double height = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appNotificationsRealtimeProvider);
    final t = AppLocalizations.of(context)!;
    final signedIn = ref.watch(isAuthenticatedProvider);
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final unreadChats = ref
        .watch(unreadChatCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);
    final unreadNotifications = ref
        .watch(unreadNotificationsCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);
    final adminBadge = ref
        .watch(adminDashboardCountsProvider)
        .maybeWhen(data: (value) => value.total, orElse: () => 0);
    final castingsBadge = ref
        .watch(actionableCastingsCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);

    final sections = [
      (label: t.castingsTab, route: Routes.castings, badge: castingsBadge),
      (label: t.catalogTab, route: Routes.search, badge: 0),
      (label: 'Чаты', route: Routes.chats, badge: unreadChats),
    ];

    final rightActions = <Widget>[
      if (!signedIn)
        OutlinedButton(
          onPressed: () => context.go(Routes.login),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          child: Text(t.signInTitle),
        )
      else ...[
        if (isAdmin)
          _IconAction(
            icon: Icons.admin_panel_settings_outlined,
            tooltip: t.adminTab,
            badge: adminBadge,
            selected: currentIndex == 4,
            onTap: () => context.go(Routes.admin),
          ),
        _IconAction(
          icon: Icons.notifications_none_rounded,
          tooltip: _sentenceCase(t.notificationsUpper),
          badge: unreadNotifications,
          selected: false,
          onTap: () => context.go(Routes.notifications),
        ),
        const SizedBox(width: Tokens.s8),
        _AvatarMenu(isAdmin: isAdmin, selected: currentIndex == 3),
      ],
    ];

    // Full-width bar: the logo sits on the page's left gutter, the sections
    // are centred on the screen, the account actions on the right gutter.
    return Material(
      color: Tokens.bg,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s32),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Tokens.border)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  _Brand(onTap: () => context.go(Routes.castings)),
                  const Spacer(),
                  ...rightActions,
                ],
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < sections.length; i++)
                    _SectionLink(
                      label: sections[i].label,
                      badge: sections[i].badge,
                      selected: currentIndex == i,
                      onTap: () => context.go(sections[i].route),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Image.asset(
              'assets/images/pk-logo-red-512.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            const Text(
              'PK MANAGEMENT',
              style: TextStyle(
                color: Tokens.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: SizedBox(
        height: AppTopBar.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppText.body.copyWith(
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Tokens.text : Tokens.textSecondary,
                    ),
                  ),
                  if (badge > 0) ...[
                    const SizedBox(width: 8),
                    _Badge(count: badge),
                  ],
                ],
              ),
            ),
            if (selected)
              Positioned(
                left: 20,
                right: 20,
                bottom: 0,
                child: Container(height: 2, color: Tokens.accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 24,
                  color: selected ? Tokens.text : Tokens.textSecondary,
                ),
              ),
              if (badge > 0)
                Positioned(top: 4, right: 2, child: _Badge(count: badge)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Tokens.accent,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

enum _AccountAction { account, notifications, billing, admin, signOut }

class _AvatarMenu extends ConsumerWidget {
  const _AvatarMenu({required this.isAdmin, required this.selected});

  final bool isAdmin;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final owner = ref
        .watch(accountOwnerProfileProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final email = ref.watch(currentUserProvider)?.email ?? '';
    final name = owner?.fullName.trim() ?? '';
    final title = name.isNotEmpty ? name : email;

    return PopupMenuButton<_AccountAction>(
      tooltip: t.myProfileTab,
      offset: const Offset(0, 48),
      position: PopupMenuPosition.under,
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.isEmpty ? t.myProfileTab : title,
                style: AppText.smallStrong,
                overflow: TextOverflow.ellipsis,
              ),
              if (name.isNotEmpty && email.isNotEmpty)
                Text(
                  email,
                  style: AppText.caption,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountAction.account,
          child: Text(t.myProfileTab),
        ),
        PopupMenuItem(
          value: _AccountAction.notifications,
          child: Text(_sentenceCase(t.notificationsUpper)),
        ),
        if (isAdmin)
          PopupMenuItem(
            value: _AccountAction.admin,
            child: Text(t.adminTab),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountAction.signOut,
          child: Text(t.signOut, style: const TextStyle(color: Tokens.danger)),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Tokens.surfaceAlt,
          border: Border.all(
            color: selected ? Tokens.text : Tokens.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: _AvatarImage(url: owner?.avatarUrl ?? '', fallback: title),
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _AccountAction action,
  ) async {
    switch (action) {
      case _AccountAction.account:
        context.go(Routes.me);
      case _AccountAction.notifications:
        context.go(Routes.notifications);
      case _AccountAction.billing:
        context.go(Routes.billing);
      case _AccountAction.admin:
        context.go(Routes.admin);
      case _AccountAction.signOut:
        final sb = ref.read(supabaseProvider);
        context.go(Routes.login);
        await sb.auth.signOut();
    }
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.fallback});

  final String url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final initial = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().substring(0, 1).toUpperCase();
    final letter = Text(
      initial,
      style: AppText.smallStrong.copyWith(color: Tokens.textSecondary),
    );
    if (url.trim().isEmpty) return letter;
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: 36,
      height: 36,
      errorBuilder: (_, _, _) => letter,
    );
  }
}

String _sentenceCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}
