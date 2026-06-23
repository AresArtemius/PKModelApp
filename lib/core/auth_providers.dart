import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_provider.dart';
import '../features/auth/auth_controller.dart';

final authSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  final sb = ref.watch(supabaseProvider);
  return sb.auth.currentSession;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authSessionProvider)?.user;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserIdProvider) != null;
});

final authSessionValidatorProvider = FutureProvider<void>((ref) async {
  ref.watch(authStateProvider);

  final sb = ref.watch(supabaseProvider);
  final session = sb.auth.currentSession;
  if (session == null) return;

  try {
    await sb.auth.getUser();
  } on AuthException catch (e) {
    final message = e.message.toLowerCase();
    final code = (e.statusCode ?? '').trim();
    final sessionIsInvalid =
        code == '401' ||
        code == '403' ||
        message.contains('jwt') ||
        message.contains('user') && message.contains('does not exist') ||
        message.contains('session') && message.contains('not found');

    if (!sessionIsInvalid) return;

    await sb.auth.signOut();
  }
});
