import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_dashboard_counts_provider.dart';
import 'roles_provider.dart';
import '../features/admin/account_merge_requests_page.dart';
import '../features/admin/admin_castings_page.dart';
import '../features/admin/admin_profiles_page.dart';
import '../features/admin/admin_support_page.dart';
import '../features/admin/admin_selections_table_page.dart';
import '../features/admin/admin_users_page.dart';
import '../features/admin/selection_admin_page.dart';
import '../features/admin/selection_casting_page.dart';
import '../features/admin/safety_admin_page.dart';
import '../features/admin/casting_agent_applications_page.dart';
import '../features/admin/profile_slot_requests_page.dart';
import '../features/analytics/profile_analytics_page.dart';
import '../features/auth/email_verification_page.dart';
import '../features/auth/login_page.dart';
import '../features/admin/admin_page.dart';
import '../features/admin/catalog_admin_page.dart';
import '../features/admin/create_casting_admin_page.dart';
import '../features/admin/moderation_admin_page.dart';
import '../features/admin/profile_action_audit_page.dart';
import '../features/auth/auth_required_page.dart';
import '../features/auth/register_page.dart';
import '../features/billing/billing_page.dart';
import '../features/castings/casting_page.dart';
import '../features/castings/castings_provider.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/chats_page.dart';
import '../features/chat/chat_providers.dart';
import '../features/chat/invitations_page.dart';
import '../features/catalog/agent_folders_page.dart';
import '../features/catalog/catalog_page.dart';
import '../features/catalog/model_profile_page.dart';
import '../features/onboarding/role_onboarding_page.dart';
import '../features/notifications/app_notifications.dart';
import '../features/notifications/notifications_page.dart';
import '../features/profile/my_profile_page.dart';
import '../features/profile/account_profile_edit_page.dart';
import '../features/profile/account_devices_page.dart';
import '../features/profile/account_mfa_page.dart';
import '../features/profile/data_privacy_page.dart';
import '../features/profile/public_account_profile_page.dart';
import '../features/support/support_page.dart';
import '../features/legal/legal_document_page.dart';
import '../features/legal/legal_documents.dart';
import '../gen_l10n/app_localizations.dart';
import '../ui/brand/brand_theme.dart';
import '../features/admin/selection_project_page.dart';

abstract class Routes {
  static const login = '/login';
  static const register = '/register';
  static const emailVerification = '/verify-email';
  static const authRequired = '/auth-required';
  static const onboarding = '/onboarding';
  static const privacyPolicy = '/privacy';
  static const termsOfService = '/terms';
  static const cookiePolicy = '/cookies';
  static const processingNotice = '/processing-notice';
  static const requisites = '/requisites';

  static const castings = '/castings';
  static const search = '/search';
  static const agentFolders = '/agent_folders';
  static const chats = '/chats';
  static const invitations = '/invitations';
  static const me = '/me';
  static const billing = '/billing';
  static const notifications = '/notifications';
  static const profileAnalytics = '/profile_analytics';
  static const accountProfile = '/account_profile';
  static const accountDevices = '/account_devices';
  static const accountMfa = '/account_mfa';
  static const dataPrivacy = '/data_privacy';
  static const support = '/support';
  static const publicAccountPrefix = '/@';
  static const publicAccount = '/@:tag';

  static const admin = '/admin';
  static const catalogAdmin = '/catalog_admin';
  static const moderationAdmin = '/moderation_admin';
  static const castingAgentApplicationsAdmin =
      '/casting_agent_applications_admin';
  static const accountMergeRequestsAdmin = '/account_merge_requests_admin';
  static const profileSlotRequestsAdmin = '/profile_slot_requests_admin';
  static const adminUsers = '/admin_users';
  static const adminProfiles = '/admin_profiles';
  static const adminSupport = '/admin_support';
  static const adminCastings = '/admin_castings';
  static const adminSelectionsTable = '/admin_selections_table';
  static const createCastingAdmin = '/create_casting_admin';
  static const adminSelection = '/admin_selection';
  static const safetyAdmin = '/safety_admin';
  static const profileActionAuditAdmin = '/profile_action_audit_admin';
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
const _routeParamTag = 'tag';
const double _kDesktopShellBreakpoint = 900;
const double _kExpandedDesktopShellBreakpoint = 1180;
const double _kCompactDesktopNavWidth = 112;
const double _kExpandedDesktopNavWidth = 232;
const double _kDesktopContentMaxWidth = 1720;

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _indexFromLocation(String path) {
    if (path.startsWith(Routes.castings)) return 0;
    if (path.startsWith(Routes.search)) return 1;
    if (path.startsWith(Routes.agentFolders)) return 1;
    if (path.startsWith(Routes.chats)) return 2;
    if (path.startsWith(Routes.invitations)) return 2;
    if (path.startsWith(Routes.billing)) return 3;
    if (path.startsWith(Routes.notifications)) return 3;
    if (path.startsWith(Routes.profileAnalytics)) return 3;
    if (path.startsWith(Routes.accountDevices)) return 3;
    if (path.startsWith(Routes.accountMfa)) return 3;
    if (path.startsWith(Routes.dataPrivacy)) return 3;
    if (path.startsWith(Routes.support)) return 3;
    if (path.startsWith(Routes.me)) return 3;
    if (path.startsWith(Routes.admin)) return 4;
    if (path.startsWith(Routes.catalogAdmin)) return 4;
    if (path.startsWith(Routes.moderationAdmin)) return 4;
    if (path.startsWith(Routes.castingAgentApplicationsAdmin)) return 4;
    if (path.startsWith(Routes.accountMergeRequestsAdmin)) return 4;
    if (path.startsWith(Routes.profileSlotRequestsAdmin)) return 4;
    if (path.startsWith(Routes.adminUsers)) return 4;
    if (path.startsWith(Routes.adminProfiles)) return 4;
    if (path.startsWith(Routes.adminSupport)) return 4;
    if (path.startsWith(Routes.adminCastings)) return 4;
    if (path.startsWith(Routes.adminSelectionsTable)) return 4;
    if (path.startsWith(Routes.createCastingAdmin)) return 4;
    if (path.startsWith(Routes.adminSelection)) return 4;
    if (path.startsWith(Routes.safetyAdmin)) return 4;
    if (path.startsWith(Routes.profileActionAuditAdmin)) return 4;
    if (path.startsWith(Routes.adminSelectionProject)) return 4;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final currentIndex = _indexFromLocation(path);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= _kDesktopShellBreakpoint;
    final isExpandedDesktop = width >= _kExpandedDesktopShellBreakpoint;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: isExpandedDesktop
                  ? _kExpandedDesktopNavWidth
                  : _kCompactDesktopNavWidth,
              child: AppDesktopNav(
                currentIndex: currentIndex,
                expanded: isExpandedDesktop,
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFE8E8E8),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kDesktopContentMaxWidth,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
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
  const AppDesktopNav({super.key, this.currentIndex, this.expanded = false});

  final int? currentIndex;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
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
    final items = [
      (
        icon: Icons.videocam,
        label: t.castingsTab,
        route: Routes.castings,
        badge: castingsBadge,
      ),
      (icon: Icons.search, label: t.catalogTab, route: Routes.search, badge: 0),
      (
        icon: Icons.mail_rounded,
        label: 'Чаты',
        route: Routes.chats,
        badge: unreadChats,
      ),
      (
        icon: Icons.person,
        label: t.myProfileTab,
        route: Routes.me,
        badge: unreadNotifications,
      ),
      if (isAdmin)
        (
          icon: Icons.admin_panel_settings_rounded,
          label: t.adminTab,
          route: Routes.admin,
          badge: adminBadge,
        ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: BrandTheme.darkPillGradient),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 22,
            horizontal: expanded ? 16 : 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopNavBrand(expanded: expanded),
              SizedBox(height: expanded ? 26 : 18),
              for (var i = 0; i < items.length; i++) ...[
                _DesktopNavItem(
                  icon: items[i].icon,
                  label: items[i].label,
                  selected: currentIndex == i,
                  expanded: expanded,
                  badge: items[i].badge,
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

class _DesktopNavBrand extends StatelessWidget {
  const _DesktopNavBrand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Center(
        child: Image.asset(
          'assets/images/pk-logo-red-512.png',
          width: 54,
          height: 54,
          fit: BoxFit.contain,
        ),
      );
    }

    return Row(
      children: [
        Image.asset(
          'assets/images/pk-logo-red-512.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'PK\nMANAGEMENT',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BrandTheme.pillText.copyWith(
              color: Colors.white,
              fontSize: 13,
              height: 1.08,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final int badge;
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
          constraints: BoxConstraints(minHeight: expanded ? 58 : 0),
          padding: EdgeInsets.symmetric(
            vertical: expanded ? 13 : 12,
            horizontal: expanded ? 14 : 8,
          ),
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
          child: expanded
              ? Row(
                  children: [
                    _NavIconWithBadge(icon: icon, color: color, badge: badge),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BrandTheme.pillText.copyWith(
                          color: color,
                          fontSize: 13,
                          letterSpacing: 0.3,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavIconWithBadge(icon: icon, color: color, badge: badge),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
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
    final items = [
      (
        icon: Icons.videocam,
        label: t.castingsTab,
        route: Routes.castings,
        badge: castingsBadge,
      ),
      (icon: Icons.search, label: t.catalogTab, route: Routes.search, badge: 0),
      (
        icon: Icons.mail_rounded,
        label: 'Чаты',
        route: Routes.chats,
        badge: unreadChats,
      ),
      (
        icon: Icons.person,
        label: t.myProfileTab,
        route: Routes.me,
        badge: unreadNotifications,
      ),
      if (isAdmin)
        (
          icon: Icons.admin_panel_settings_rounded,
          label: t.adminTab,
          route: Routes.admin,
          badge: adminBadge,
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
                    badge: items[i].badge,
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
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white70;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavIconWithBadge(icon: icon, color: color, badge: badge),
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

class _NavIconWithBadge extends StatelessWidget {
  const _NavIconWithBadge({
    required this.icon,
    required this.color,
    required this.badge,
  });

  final IconData icon;
  final Color color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 31,
      height: 31,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(icon, color: color, size: 27)),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: BrandTheme.redTop,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
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
    path: Routes.privacyPolicy,
    builder: (context, state) =>
        const LegalDocumentPage(kind: LegalDocumentKind.privacy),
  ),
  GoRoute(
    path: Routes.termsOfService,
    builder: (context, state) =>
        const LegalDocumentPage(kind: LegalDocumentKind.terms),
  ),
  GoRoute(
    path: Routes.cookiePolicy,
    builder: (context, state) =>
        const LegalDocumentPage(kind: LegalDocumentKind.cookies),
  ),
  GoRoute(
    path: Routes.processingNotice,
    builder: (context, state) =>
        const LegalDocumentPage(kind: LegalDocumentKind.processingNotice),
  ),
  GoRoute(
    path: Routes.requisites,
    builder: (context, state) =>
        const LegalDocumentPage(kind: LegalDocumentKind.requisites),
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
    path: Routes.accountDevices,
    builder: (context, state) => const AccountDevicesPage(),
  ),
  GoRoute(
    path: Routes.accountMfa,
    builder: (context, state) => const AccountMfaPage(),
  ),
  GoRoute(
    path: Routes.dataPrivacy,
    builder: (context, state) => const DataPrivacyPage(),
  ),

  GoRoute(
    path: Routes.publicAccount,
    builder: (context, state) {
      final tag = state.pathParameters[_routeParamTag] ?? '';
      return PublicAccountProfilePage(rawTag: tag);
    },
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
        path: Routes.chats,
        builder: (context, state) => const ChatsPage(),
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
      GoRoute(
        path: Routes.support,
        builder: (context, state) => const SupportPage(),
      ),
      GoRoute(
        path: Routes.admin,
        builder: (context, state) => const AdminPage(),
      ),
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
        path: Routes.profileSlotRequestsAdmin,
        builder: (context, state) => const ProfileSlotRequestsPage(),
      ),
      GoRoute(
        path: Routes.adminUsers,
        builder: (context, state) => const AdminUsersPage(),
      ),
      GoRoute(
        path: Routes.adminProfiles,
        builder: (context, state) => const AdminProfilesPage(),
      ),
      GoRoute(
        path: Routes.adminSupport,
        builder: (context, state) => const AdminSupportPage(),
      ),
      GoRoute(
        path: Routes.adminCastings,
        builder: (context, state) => const AdminCastingsPage(),
      ),
      GoRoute(
        path: Routes.adminSelectionsTable,
        builder: (context, state) => const AdminSelectionsTablePage(),
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
        path: Routes.profileActionAuditAdmin,
        builder: (context, state) => const ProfileActionAuditPage(),
      ),
      GoRoute(
        path: '${Routes.adminSelection}/:$_routeParamId',
        builder: (context, state) {
          final id = state.pathParameters[_routeParamId] ?? '';
          return SelectionCastingPage(
            castingId: id,
            from: state.uri.queryParameters['from'],
          );
        },
      ),
      GoRoute(
        path: '${Routes.adminSelectionProject}/:$_routeParamId',
        builder: (context, state) {
          final id = state.pathParameters[_routeParamId] ?? '';
          return SelectionProjectPage(
            selectionId: id,
            from: state.uri.queryParameters['from'],
          );
        },
      ),
    ],
  ),
];
