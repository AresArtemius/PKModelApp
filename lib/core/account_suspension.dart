import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_provider.dart';

/// Set when the signed-in account turned out to be suspended by a moderator
/// (moderation_v2.sql). The login page shows the notice once.
final suspendedNoticeProvider = StateProvider<bool>((ref) => false);

/// Called on every auth event: a suspended account is signed out at once,
/// even while its current access token is still valid.
Future<void> checkAccountSuspension(Ref ref) async {
  final sb = ref.read(supabaseProvider);
  final userId = sb.auth.currentUser?.id;
  if (userId == null) return;
  try {
    final suspended = await sb.rpc(
      'user_is_suspended',
      params: {'p_user_id': userId},
    );
    if (suspended == true) {
      ref.read(suspendedNoticeProvider.notifier).state = true;
      await sb.auth.signOut();
    }
  } catch (_) {
    // The RPC may not be applied yet; the server-side ban still works.
  }
}

/// The notice text for the login page.
String suspendedNoticeText(bool ru) => ru
    ? 'Аккаунт заблокирован администрацией PK Management за нарушение правил. Если это ошибка, напишите на artem@president-kids.ru.'
    : 'This account has been suspended by PK Management for breaking the rules. If this is a mistake, write to artem@president-kids.ru.';
