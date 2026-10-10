import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_top_bar.dart';
import 'auth_providers.dart';
import 'admin_dashboard_counts_provider.dart';
import 'roles_provider.dart';
import 'tab_alerts.dart';
import 'deferred_page.dart';
import '../features/admin/account_merge_requests_page.dart' deferred as account_merge_requests_page;
import '../features/admin/admin_castings_page.dart' deferred as admin_castings_page;
import '../features/admin/admin_profiles_page.dart' deferred as admin_profiles_page;
import '../features/admin/admin_support_page.dart' deferred as admin_support_page;
import '../features/admin/admin_selections_table_page.dart' deferred as admin_selections_table_page;
import '../features/admin/admin_users_page.dart' deferred as admin_users_page;
import '../features/admin/selection_admin_page.dart' deferred as selection_admin_page;
import '../features/admin/selection_casting_page.dart' deferred as selection_casting_page;
import '../features/admin/safety_admin_page.dart' deferred as safety_admin_page;
import '../features/admin/casting_agent_applications_page.dart' deferred as casting_agent_applications_page;
import '../features/admin/profile_slot_requests_page.dart' deferred as profile_slot_requests_page;
import '../features/analytics/profile_analytics_page.dart';
import '../features/auth/email_verification_page.dart';
import '../features/auth/login_page.dart';
import '../features/admin/admin_page.dart' deferred as admin_page;
import '../features/admin/catalog_admin_page.dart' deferred as catalog_admin_page;
import '../features/admin/create_casting_admin_page.dart' deferred as create_casting_admin_page;
import '../features/admin/moderation_admin_page.dart' deferred as moderation_admin_page;
import '../features/admin/profile_action_audit_page.dart' deferred as profile_action_audit_page;
import '../features/auth/auth_required_page.dart';
import '../features/auth/register_page.dart';
import '../features/billing/billing_page.dart';
import '../features/castings/casting_page.dart';
import '../features/castings/castings_provider.dart';
import '../features/castings/casting_reference_media.dart';
import '../features/chat/chat_models.dart';
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
import '../features/profile/my_profile_edit_page.dart';
import '../features/profile/my_profile_page.dart';
import '../features/profile/profile_model.dart';
import '../features/profile/account_profile_edit_page.dart';
import '../features/profile/account_devices_page.dart';
import '../features/profile/account_mfa_page.dart';
import '../features/profile/data_privacy_page.dart';
import '../features/profile/public_account_profile_page.dart';
import '../features/feed/feed_page.dart';
import '../features/feed/following_page.dart';
import '../features/support/support_page.dart';
import '../features/legal/legal_document_page.dart';
import '../features/legal/legal_documents.dart';
import '../features/legal/account_deletion_page.dart';
import '../features/landing/landing_preview_page.dart';
import '../gen_l10n/app_localizations.dart';
import '../ui/brand/brand_theme.dart';
import '../ui/brand/command_palette.dart';
import '../ui/brand/design_tokens.dart';
import '../features/admin/selection_project_page.dart' deferred as selection_project_page;

abstract class Routes {
  static const landingPreview = '/landing-preview';
  static const login = '/login';
  static const register = '/register';
  static const emailVerification = '/verify-email';
  static const authRequired = '/auth-required';
  static const onboarding = '/onboarding';
  static const privacyPolicy = '/privacy';
  static const termsOfService = '/terms';
  static const childSafety = '/child-safety';
  static const cookiePolicy = '/cookies';
  static const processingNotice = '/processing-notice';
  static const requisites = '/requisites';
  static const accountDeletion = '/account-deletion';

  static const castings = '/castings';
  static const search = '/search';
  static const agentFolders = '/agent_folders';
  static const chats = '/chats';
  static const invitations = '/invitations';
  static const me = '/me';
  static const myProfileEdit = '/me/edit';
  static const myProfileNew = '/me/new';
  static const billing = '/billing';
  static const notifications = '/notifications';
  static const profileAnalytics = '/profile_analytics';
  static const accountProfile = '/account_profile';
  static const accountDevices = '/account_devices';
  static const accountMfa = '/account_mfa';
  static const dataPrivacy = '/data_privacy';
  static const support = '/support';
  static const following = '/following';

  /// Step 44: the home feed (web). Nav index 5 in [AppShell].
  static const feed = '/feed';
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
  static const modelPhotos = '/model/:id/photos/:index';
  static const modelVideo = '/model/:id/video';
  static String modelPhotosLocation(String modelId, int index) =>
      '$modelPrefix$modelId/photos/$index';
  static String modelVideoLocation(String modelId) =>
      '$modelPrefix$modelId/video';
  static const publicModelPrefix = '/p/';
  static const publicModel = '/p/:id';
  static const publicSelectionPrefix = '/s/';
  static const publicSelection = '/s/:id';
  static const chatPrefix = '/chat/';
  static const chat = '/chat/:id';

  /// Full-screen viewers as routes, so the browser «Back» closes them:
  /// a photo / video from a chat and a casting reference.
  static const chatMedia = '/chat/:id/media/:messageId';
  static String chatMediaLocation(String chatId, String messageId) =>
      '$chatPrefix$chatId/media/$messageId';
  static const castingReference = '/castings/reference';

  /// Step 28 (web): the conversation open inside the two-column chats page
  /// lives in the URL, so a reload or a shared link lands on it.
  static const chatsChat = '/chats/:id';
  static const chatsChatPrefix = '/chats/';
  static String chatsLocation(String chatId) => '$chatsChatPrefix$chatId';

  /// Query parameter of [chats] that pre-selects a conversation (older
  /// links; redirected to [chatsLocation] on the web).
  static const chatsChatParam = 'chat';

  /// Where "write a message" should take the user: on the web the
  /// conversation opens inside the two-column chats page, on native apps it
  /// is a page of its own.
  static String chatLocation(String chatId) {
    if (kIsWeb) return chatsLocation(chatId);
    return '$chatPrefix$chatId';
  }
}

const _routeParamId = 'id';
const _routeParamTag = 'tag';

Page<void> _chatsPage(Widget child) {
  return NoTransitionPage<void>(
    key: const ValueKey<String>('chats-page'),
    child: child,
  );
}

Page<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
const double _kDesktopShellBreakpoint = 900;

/// Routes whose content is mostly text and reads better in a 1280 px column.
// Service pages own their 760 px column now (SettingsPageV2), so nothing
// is centred by the shell any more; kept for pages that may need it later.
const List<String> _kNarrowContentPrefixes = [];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _indexFromLocation(String path) {
    if (path.startsWith(Routes.feed)) return 5;
    if (path.startsWith(Routes.castings)) return 0;
    if (path.startsWith(Routes.search)) return 1;
    if (path.startsWith(Routes.agentFolders)) return 1;
    if (path.startsWith(Routes.chats)) return 2;
    if (path.startsWith(Routes.invitations)) return 2;
    if (path.startsWith(Routes.billing)) return 3;
    if (path.startsWith(Routes.notifications)) return 3;
    if (path.startsWith(Routes.profileAnalytics)) return 3;
    if (path.startsWith(Routes.accountProfile)) return 3;
    if (path.startsWith(Routes.accountDevices)) return 3;
    if (path.startsWith(Routes.accountMfa)) return 3;
    if (path.startsWith(Routes.dataPrivacy)) return 3;
    if (path.startsWith(Routes.support)) return 3;
    if (path.startsWith(Routes.following)) return 3;
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
    // On web, text behaves like on any site: names and parameters can be
    // selected with the mouse and copied. Mobile apps keep native behaviour.
    // Step 39: ⌘K / Ctrl+K and «/» open the command palette on web.
    final content = kIsWeb
        ? CommandPaletteHost(child: SelectionArea(child: child))
        : child;

    if (isDesktop) {
      // v2 shell: white top bar; catalogue/castings/chats use the full
      // width (pages own their paddings), text-like pages stay in a column.
      final narrow = _kNarrowContentPrefixes.any(path.startsWith);
      return Scaffold(
        body: Column(
          children: [
            AppTopBar(currentIndex: currentIndex),
            Expanded(
              child: ColoredBox(
                color: Tokens.bg,
                child: narrow
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: Tokens.contentMaxWidth,
                          ),
                          child: content,
                        ),
                      )
                    : content,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: AppBottomNav(currentIndex: currentIndex),
    );
  }
}

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key, this.currentIndex});

  final int? currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appNotificationsRealtimeProvider);
    ref.watch(presenceHeartbeatProvider);
    ref.watch(onlineUsersProvider);
    ref.watch(chatListRealtimeProvider);
    ref.watch(tabAlertsSyncProvider);
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
    final signedIn = ref.watch(isAuthenticatedProvider);
    final items = [
      // Step 44: the feed is web-only for now; native keeps the old tabs.
      if (kIsWeb && signedIn)
        (
          icon: Icons.dynamic_feed_rounded,
          label: 'Лента',
          route: Routes.feed,
          badge: 0,
          index: 5,
        ),
      (
        icon: Icons.videocam,
        label: t.castingsTab,
        route: Routes.castings,
        badge: castingsBadge,
        index: 0,
      ),
      (
        icon: Icons.search,
        label: t.catalogTab,
        route: Routes.search,
        badge: 0,
        index: 1,
      ),
      (
        icon: Icons.mail_rounded,
        label: 'Чаты',
        route: Routes.chats,
        badge: unreadChats,
        index: 2,
      ),
      (
        icon: Icons.person,
        label: t.myProfileTab,
        route: Routes.me,
        badge: unreadNotifications,
        index: 3,
      ),
      if (isAdmin)
        (
          icon: Icons.admin_panel_settings_rounded,
          label: t.adminTab,
          route: Routes.admin,
          badge: adminBadge,
          index: 4,
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
                    selected: currentIndex == items[i].index,
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
  GoRoute(
    path: Routes.landingPreview,
    builder: (context, state) => const LandingPreviewPage(),
  ),
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
    path: Routes.childSafety,
    builder: (context, state) =>
        const LegalDocumentPage(kind: LegalDocumentKind.childSafety),
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
    path: Routes.accountDeletion,
    builder: (context, state) => const AccountDeletionPage(),
  ),

  GoRoute(
    path: Routes.authRequired,
    builder: (context, state) => const AuthRequiredPage(),
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

  // Full-screen photo gallery / video of a profile. Router pages rather than
  // imperative pushes, so the browser Back button closes them instead of
  // leaving the profile. The media list travels in `extra`; on a direct
  // open (reload, shared link) there is none, so we land on the profile.
  GoRoute(
    path: Routes.modelPhotos,
    redirect: (context, state) {
      if (state.extra is List<String>) return null;
      return '${Routes.modelPrefix}${state.pathParameters[_routeParamId] ?? ''}';
    },
    pageBuilder: (context, state) {
      final urls = state.extra as List<String>;
      final index = int.tryParse(state.pathParameters['index'] ?? '') ?? 0;
      return _fadePage(
        state,
        ModelPhotoGalleryPage(
          urls: urls,
          initialIndex: index.clamp(0, urls.isEmpty ? 0 : urls.length - 1),
        ),
      );
    },
  ),
  GoRoute(
    path: Routes.modelVideo,
    redirect: (context, state) {
      if (state.extra is String && (state.extra as String).isNotEmpty) {
        return null;
      }
      return '${Routes.modelPrefix}${state.pathParameters[_routeParamId] ?? ''}';
    },
    pageBuilder: (context, state) =>
        _fadePage(state, ModelVideoPage(url: state.extra as String)),
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
      final accessToken = state.uri.queryParameters['access'] ?? '';
      return DeferredPage(
        libraryKey: 'selection_project_page',
        load: selection_project_page.loadLibrary,
        builder: (_) => selection_project_page.SelectionProjectPage(
          selectionId: id,
          isPublic: true,
          feedbackAccessToken: accessToken,
        ),
      );
    },
  ),

  GoRoute(
    path: Routes.chat,
    builder: (context, state) {
      final id = state.pathParameters[_routeParamId] ?? '';
      return ChatPage(chatId: id);
    },
  ),
  // The message travels in `extra`; on a direct open (reload, shared link)
  // there is none, so we land on the chat.
  GoRoute(
    path: Routes.chatMedia,
    redirect: (context, state) {
      if (state.extra is ChatMessage) return null;
      return Routes.chatLocation(state.pathParameters[_routeParamId] ?? '');
    },
    pageBuilder: (context, state) => _fadePage(
      state,
      ChatMediaViewerPage(message: state.extra as ChatMessage),
    ),
  ),
  GoRoute(
    path: Routes.castingReference,
    redirect: (context, state) =>
        state.extra is CastingReferenceMedia ? null : Routes.castings,
    pageBuilder: (context, state) => _fadePage(
      state,
      CastingReferenceLightboxPage(
        item: state.extra as CastingReferenceMedia,
      ),
    ),
  ),

  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: [
      GoRoute(
        path: Routes.castings,
        builder: (context, state) => const CastingPage(),
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
        path: Routes.search,
        builder: (context, state) => const CatalogPage(),
      ),
      GoRoute(
        path: Routes.agentFolders,
        builder: (context, state) => const AgentFoldersPage(),
      ),
      // /chats and /chats/:id share one page key, so switching between
      // conversations updates the URL without rebuilding the list.
      GoRoute(
        path: Routes.chats,
        pageBuilder: (context, state) => _chatsPage(const ChatsPage()),
      ),
      GoRoute(
        path: Routes.chatsChat,
        pageBuilder: (context, state) => _chatsPage(
          ChatsPage(chatId: state.pathParameters[_routeParamId]),
        ),
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
        path: Routes.myProfileEdit,
        // The profile to edit travels as `extra`; a direct link has none.
        redirect: (context, state) =>
            state.extra is MyProfileState ? null : Routes.me,
        builder: (context, state) => MyProfileEditPage(
          startBlank: false,
          initial: state.extra as MyProfileState,
        ),
      ),
      GoRoute(
        path: Routes.myProfileNew,
        builder: (context, state) => MyProfileEditPage(
          startBlank: true,
          initial: null,
          initialProfileType: profileTypeFromString(
            state.uri.queryParameters['type'],
          ),
        ),
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
        path: Routes.following,
        builder: (context, state) => const FollowingPage(),
      ),
      GoRoute(
        path: Routes.feed,
        pageBuilder: (context, state) => const NoTransitionPage<void>(
          key: ValueKey<String>('feed-page'),
          child: FeedPage(),
        ),
      ),
      GoRoute(
        path: Routes.admin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'admin_page',
          load: admin_page.loadLibrary,
          builder: (_) => admin_page.AdminPage(),
        ),
      ),
      GoRoute(
        path: Routes.catalogAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'catalog_admin_page',
          load: catalog_admin_page.loadLibrary,
          builder: (_) => catalog_admin_page.CatalogAdminPage(),
        ),
      ),
      GoRoute(
        path: Routes.moderationAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'moderation_admin_page',
          load: moderation_admin_page.loadLibrary,
          builder: (_) => moderation_admin_page.ModerationAdminPage(),
        ),
      ),
      GoRoute(
        path: Routes.castingAgentApplicationsAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'casting_agent_applications_page',
          load: casting_agent_applications_page.loadLibrary,
          builder: (_) => casting_agent_applications_page.CastingAgentApplicationsPage(),
        ),
      ),
      GoRoute(
        path: Routes.accountMergeRequestsAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'account_merge_requests_page',
          load: account_merge_requests_page.loadLibrary,
          builder: (_) => account_merge_requests_page.AccountMergeRequestsPage(),
        ),
      ),
      GoRoute(
        path: Routes.profileSlotRequestsAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'profile_slot_requests_page',
          load: profile_slot_requests_page.loadLibrary,
          builder: (_) => profile_slot_requests_page.ProfileSlotRequestsPage(),
        ),
      ),
      GoRoute(
        path: Routes.adminUsers,
        builder: (context, state) => DeferredPage(
          libraryKey: 'admin_users_page',
          load: admin_users_page.loadLibrary,
          builder: (_) => admin_users_page.AdminUsersPage(),
        ),
      ),
      GoRoute(
        path: Routes.adminProfiles,
        builder: (context, state) => DeferredPage(
          libraryKey: 'admin_profiles_page',
          load: admin_profiles_page.loadLibrary,
          builder: (_) => admin_profiles_page.AdminProfilesPage(),
        ),
      ),
      GoRoute(
        path: Routes.adminSupport,
        builder: (context, state) => DeferredPage(
          libraryKey: 'admin_support_page',
          load: admin_support_page.loadLibrary,
          builder: (_) => admin_support_page.AdminSupportPage(),
        ),
      ),
      GoRoute(
        path: Routes.adminCastings,
        builder: (context, state) => DeferredPage(
          libraryKey: 'admin_castings_page',
          load: admin_castings_page.loadLibrary,
          builder: (_) => admin_castings_page.AdminCastingsPage(),
        ),
      ),
      GoRoute(
        path: Routes.adminSelectionsTable,
        builder: (context, state) => DeferredPage(
          libraryKey: 'admin_selections_table_page',
          load: admin_selections_table_page.loadLibrary,
          builder: (_) => admin_selections_table_page.AdminSelectionsTablePage(),
        ),
      ),
      GoRoute(
        path: Routes.createCastingAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'create_casting_admin_page',
          load: create_casting_admin_page.loadLibrary,
          builder: (_) => create_casting_admin_page.CreateCastingAdminPage(),
        ),
      ),
      GoRoute(
        path: Routes.adminSelection,
        builder: (context, state) => DeferredPage(
          libraryKey: 'selection_admin_page',
          load: selection_admin_page.loadLibrary,
          builder: (_) => selection_admin_page.SelectionAdminPage(),
        ),
      ),
      GoRoute(
        path: Routes.safetyAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'safety_admin_page',
          load: safety_admin_page.loadLibrary,
          builder: (_) => safety_admin_page.SafetyAdminPage(),
        ),
      ),
      GoRoute(
        path: Routes.profileActionAuditAdmin,
        builder: (context, state) => DeferredPage(
          libraryKey: 'profile_action_audit_page',
          load: profile_action_audit_page.loadLibrary,
          builder: (_) => profile_action_audit_page.ProfileActionAuditPage(),
        ),
      ),
      GoRoute(
        path: '${Routes.adminSelection}/:$_routeParamId',
        builder: (context, state) {
          final id = state.pathParameters[_routeParamId] ?? '';
          final from = state.uri.queryParameters['from'];
          return DeferredPage(
            libraryKey: 'selection_casting_page',
            load: selection_casting_page.loadLibrary,
            builder: (_) => selection_casting_page.SelectionCastingPage(
              castingId: id,
              from: from,
            ),
          );
        },
      ),
      GoRoute(
        path: '${Routes.adminSelectionProject}/:$_routeParamId',
        builder: (context, state) {
          final id = state.pathParameters[_routeParamId] ?? '';
          final from = state.uri.queryParameters['from'];
          return DeferredPage(
            libraryKey: 'selection_project_page',
            load: selection_project_page.loadLibrary,
            builder: (_) => selection_project_page.SelectionProjectPage(
              selectionId: id,
              from: from,
            ),
          );
        },
      ),
    ],
  ),
];
