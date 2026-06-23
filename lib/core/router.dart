import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'roles_provider.dart';
import '../features/admin/account_merge_requests_page.dart';
import '../features/admin/selection_admin_page.dart';
import '../features/admin/selection_casting_page.dart';
import '../features/admin/safety_admin_page.dart';
import '../features/admin/casting_agent_applications_page.dart';
import '../features/analytics/profile_analytics_page.dart';
import '../features/auth/email_verification_page.dart';
import '../features/auth/login_page.dart';
import '../features/admin/admin_page.dart';
import '../features/admin/catalog_admin_page.dart';
import '../features/admin/create_casting_admin_page.dart';
import '../features/admin/moderation_admin_page.dart';
import '../features/auth/auth_required_page.dart';
import '../features/auth/register_page.dart';
import '../features/billing/billing_page.dart';
import '../features/castings/casting_page.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/invitations_page.dart';
import '../features/catalog/agent_folders_page.dart';
import '../features/catalog/catalog_page.dart';
import '../features/catalog/model_profile_page.dart';
import '../features/onboarding/role_onboarding_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/profile/my_profile_page.dart';
import '../features/profile/account_profile_edit_page.dart';
import '../gen_l10n/app_localizations.dart';
import '../ui/brand/brand_theme.dart';
import '../features/admin/selection_project_page.dart';

abstract class Routes {
  static const login = '/login';
  static const register = '/register';
  static const emailVerification = '/verify-email';
  static const authRequired = '/auth-required';
  static const onboarding = '/onboarding';

  static const castings = '/castings';
  static const search = '/search';
  static const agentFolders = '/agent_folders';
  static const invitations = '/invitations';
  static const me = '/me';
  static const billing = '/billing';
  static const notifications = '/notifications';
  static const profileAnalytics = '/profile_analytics';
  static const accountProfile = '/account_profile';

  static const admin = '/admin';
  static const catalogAdmin = '/catalog_admin';
  static const moderationAdmin = '/moderation_admin';
  static const castingAgentApplicationsAdmin =
      '/casting_agent_applications_admin';
  static const accountMergeRequestsAdmin = '/account_merge_requests_admin';
  static const createCastingAdmin = '/create_casting_admin';
  static const adminSelection = '/admin_selection';
  static const safetyAdmin = '/safety_admin';
  static const adminSelectionProject = '/admin_selection_project';
  static const modelPrefix = '/model/';
  static const model = '/model/:id';
  static const publicModelPrefix = '/p/';
  static const publicModel = '/p/:id';
  static const publicSelectionPrefix = '/s/';
  static const publicSelection = '/s/:id';
  static const chatPrefix = '/chat/';
  static const chat = '/chat/:id';
}

const _routeParamId = 'id';
const double _kDesktopShellBreakpoint = 900;
const double _kDesktopNavWidth = 112;

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _indexFromLocation(String path) {
    if (path.startsWith(Routes.castings)) return 0;
    if (path.startsWith(Routes.search)) return 1;
    if (path.startsWith(Routes.agentFolders)) return 1;
    if (path.startsWith(Routes.invitations)) return 2;
    if (path.startsWith(Routes.billing)) return 3;
    if (path.startsWith(Routes.notifications)) return 3;
    if (path.startsWith(Routes.profileAnalytics)) return 3;
    if (path.startsWith(Routes.me)) return 3;
    if (path.startsWith(Routes.admin)) return 4;
    if (path.startsWith(Routes.catalogAdmin)) return 4;
    if (path.startsWith(Routes.moderationAdmin)) return 4;
    if (path.startsWith(Routes.castingAgentApplicationsAdmin)) return 4;
    if (path.startsWith(Routes.accountMergeRequestsAdmin)) return 4;
    if (path.startsWith(Routes.createCastingAdmin)) return 4;
    if (path.startsWith(Routes.adminSelection)) return 4;
    if (path.startsWith(Routes.safetyAdmin)) return 4;
    if (path.startsWith(Routes.adminSelectionProject)) return 4;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final currentIndex = _indexFromLocation(path);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kDesktopShellBreakpoint;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: _kDesktopNavWidth,
              child: AppDesktopNav(currentIndex: currentIndex),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(currentIndex: currentIndex),
    );
  }
}

class AppDesktopNav extends ConsumerWidget {
  const AppDesktopNav({super.key, this.currentIndex});

  final int? currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final items = [
      (icon: Icons.videocam, label: t.castingsTab, route: Routes.castings),
      (icon: Icons.search, label: t.catalogTab, route: Routes.search),
      (
        icon: Icons.mail_rounded,
        label: t.invitationsTab,
        route: Routes.invitations,
      ),
      (icon: Icons.person, label: t.myProfileTab, route: Routes.me),
      if (isAdmin)
        (
          icon: Icons.admin_panel_settings_rounded,
          label: t.adminTab,
          route: Routes.admin,
        ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: BrandTheme.darkPillGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
          child: Column(
            children: [
              const SizedBox(height: 10),
              for (var i = 0; i < items.length; i++) ...[
                _DesktopNavItem(
                  icon: items[i].icon,
                  label: items[i].label,
                  selected: currentIndex == i,
                  onTap: () => context.go(items[i].route),
                ),
                const SizedBox(height: 10),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white70;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 27),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 11,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key, this.currentIndex});

  final int? currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final items = [
      (icon: Icons.videocam, label: t.castingsTab, route: Routes.castings),
      (icon: Icons.search, label: t.catalogTab, route: Routes.search),
      (
        icon: Icons.mail_rounded,
        label: t.invitationsTab,
        route: Routes.invitations,
      ),
      (icon: Icons.person, label: t.myProfileTab, route: Routes.me),
      if (isAdmin)
        (
          icon: Icons.admin_panel_settings_rounded,
          label: t.adminTab,
          route: Routes.admin,
        ),
    ];

    return Container(
      decoration: const BoxDecoration(gradient: BrandTheme.darkPillGradient),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: currentIndex == i,
                    onTap: () => context.go(items[i].route),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white70;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

final List<RouteBase> appRoutes = [
  GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),

  GoRoute(
    path: Routes.register,
    builder: (context, state) => const RegisterPage(),
  ),
  GoRoute(
    path: Routes.emailVerification,
    builder: (context, state) =>
        EmailVerificationPage(email: state.uri.queryParameters['email'] ?? ''),
  ),

  GoRoute(
    path: Routes.authRequired,
    builder: (context, state) => const AuthRequiredPage(),
  ),

  GoRoute(
    path: Routes.accountProfile,
    builder: (context, state) => const AccountProfileEditPage(),
  ),

  GoRoute(
    path: Routes.onboarding,
    builder: (context, state) => const RoleOnboardingPage(),
  ),

  GoRoute(
    path: Routes.model,
    builder: (context, state) {
      final id = state.pathParameters[_routeParamId] ?? '';
      return ModelProfilePage(modelId: id);
    },
  ),

  GoRoute(
    path: Routes.publicModel,
    builder: (context, state) {
      final id = state.pathParameters[_routeParamId] ?? '';
      return ModelProfilePage(modelId: id);
    },
  ),

  GoRoute(
    path: Routes.publicSelection,
    builder: (context, state) {
      final id = state.pathParameters[_routeParamId] ?? '';
      return SelectionProjectPage(selectionId: id, isPublic: true);
    },
  ),

  GoRoute(
    path: Routes.chat,
    builder: (context, state) {
      final id = state.pathParameters[_routeParamId] ?? '';
      return ChatPage(chatId: id);
    },
  ),

  GoRoute(path: Routes.admin, builder: (context, state) => const AdminPage()),
  GoRoute(
    path: Routes.catalogAdmin,
    builder: (context, state) => const CatalogAdminPage(),
  ),
  GoRoute(
    path: Routes.moderationAdmin,
    builder: (context, state) => const ModerationAdminPage(),
  ),
  GoRoute(
    path: Routes.castingAgentApplicationsAdmin,
    builder: (context, state) => const CastingAgentApplicationsPage(),
  ),
  GoRoute(
    path: Routes.accountMergeRequestsAdmin,
    builder: (context, state) => const AccountMergeRequestsPage(),
  ),
  GoRoute(
    path: Routes.createCastingAdmin,
    builder: (context, state) => const CreateCastingAdminPage(),
  ),
  GoRoute(
    path: Routes.adminSelection,
    builder: (context, state) => const SelectionAdminPage(),
  ),
  GoRoute(
    path: Routes.safetyAdmin,
    builder: (context, state) => const SafetyAdminPage(),
  ),
  GoRoute(
    path: '${Routes.adminSelection}/:$_routeParamId',
    builder: (context, state) {
      final id = state.pathParameters[_routeParamId] ?? '';
      return SelectionCastingPage(castingId: id);
    },
  ),
  GoRoute(
    path: '${Routes.adminSelectionProject}/:$_routeParamId',
    builder: (context, state) {
      final id = state.pathParameters[_routeParamId] ?? '';
      return SelectionProjectPage(selectionId: id);
    },
  ),

  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: [
      GoRoute(
        path: Routes.castings,
        builder: (context, state) => const CastingPage(),
      ),
      GoRoute(
        path: Routes.search,
        builder: (context, state) => const CatalogPage(),
      ),
      GoRoute(
        path: Routes.agentFolders,
        builder: (context, state) => const AgentFoldersPage(),
      ),
      GoRoute(
        path: Routes.invitations,
        builder: (context, state) => const InvitationsPage(),
      ),
      GoRoute(
        path: Routes.me,
        builder: (context, state) => const MyProfilePage(),
      ),
      GoRoute(
        path: Routes.billing,
        builder: (context, state) => const BillingPage(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: Routes.profileAnalytics,
        builder: (context, state) => const ProfileAnalyticsPage(),
      ),
    ],
  ),
];
