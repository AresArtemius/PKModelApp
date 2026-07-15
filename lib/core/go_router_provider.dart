import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import 'roles_provider.dart';
import 'router.dart';
import 'supabase_provider.dart';

const _authPaths = <String>{
  Routes.login,
  Routes.register,
  Routes.emailVerification,
};

const _publicPaths = <String>{
  Routes.login,
  Routes.register,
  Routes.emailVerification,
  Routes.privacyPolicy,
  Routes.termsOfService,
  Routes.cookiePolicy,
  Routes.processingNotice,
  Routes.requisites,
  Routes.search,
  Routes.castings,
  Routes.authRequired,
};

const _adminPaths = <String>{
  Routes.admin,
  Routes.catalogAdmin,
  Routes.moderationAdmin,
  Routes.castingAgentApplicationsAdmin,
  Routes.createCastingAdmin,
  Routes.safetyAdmin,
};

final goRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseProvider);

  bool? isAdminCached;
  Future<bool> getIsAdmin() async {
    final cached = isAdminCached;
    if (cached != null) return cached;
    final isAdmin = await ref.read(isAdminProvider.future);
    isAdminCached = isAdmin;
    return isAdmin;
  }

  return GoRouter(
    initialLocation: Routes.login,
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange,
      onEvent: () {
        isAdminCached = null;
        ref.invalidate(accountRoleProvider);
        ref.invalidate(isAdminProvider);
        ref.invalidate(canCreateSelectionsProvider);
      },
    ),
    redirect: (context, state) async {
      final loggedIn = supabase.auth.currentSession != null;
      final path = state.uri.path;
      final user = supabase.auth.currentUser;
      final email = user?.email?.trim() ?? '';
      final emailConfirmedAt = user?.emailConfirmedAt?.trim() ?? '';
      final emailNeedsConfirmation =
          email.isNotEmpty && emailConfirmedAt.isEmpty;

      final goingToAuth = _authPaths.contains(path);
      final goingToEmailVerification = path == Routes.emailVerification;
      final isModelRoute = path.startsWith(Routes.modelPrefix);
      final isPublicModelRoute = path.startsWith(Routes.publicModelPrefix);
      final isPublicSelectionRoute = path.startsWith(
        Routes.publicSelectionPrefix,
      );
      final isPublicAccountRoute = path.startsWith(Routes.publicAccountPrefix);
      final isAdminSelectionRoute = path.startsWith(Routes.adminSelection);

      final isPublic =
          _publicPaths.contains(path) ||
          isModelRoute ||
          isPublicModelRoute ||
          isPublicSelectionRoute ||
          isPublicAccountRoute;
      final isAdminRoute = _adminPaths.contains(path) || isAdminSelectionRoute;

      if (!loggedIn) {
        if (path == Routes.me ||
            path == Routes.chats ||
            path == Routes.invitations) {
          return Routes.authRequired;
        }
        if (!isPublic) return Routes.login;
        return null;
      }

      if (emailNeedsConfirmation && !goingToEmailVerification) {
        return '${Routes.emailVerification}?email=${Uri.encodeComponent(email)}';
      }

      if (!emailNeedsConfirmation && goingToEmailVerification) {
        return Routes.search;
      }

      if (goingToAuth) {
        final isAdmin = await getIsAdmin();
        return isAdmin ? Routes.admin : Routes.search;
      }

      if (isAdminRoute) {
        final isAdmin = await getIsAdmin();
        if (!isAdmin) return Routes.search;
      }

      return null;
    },
    routes: appRoutes,
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream, {VoidCallback? onEvent}) {
    _sub = stream.asBroadcastStream().listen((_) {
      onEvent?.call();
      notifyListeners();
    });
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
