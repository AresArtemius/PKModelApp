import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_logger.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';

class SafetyService {
  const SafetyService(this._sb);

  static const reportsTable = 'profile_reports';
  static const blocksTable = 'blocked_users';

  final SupabaseClient _sb;

  Future<bool> reportProfile({
    required String profileId,
    required String reason,
    String comment = '',
  }) async {
    final userId = _sb.auth.currentUser?.id;
    final trimmedProfileId = profileId.trim();
    final trimmedReason = reason.trim();
    if (userId == null || trimmedProfileId.isEmpty || trimmedReason.isEmpty) {
      return false;
    }

    try {
      await _sb.from(reportsTable).insert({
        'profile_id': trimmedProfileId,
        'reporter_user_id': userId,
        'reason': trimmedReason,
        'comment': comment.trim(),
        'status': 'open',
      });
      return true;
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [reportsTable])) {
        AppLogger.warning('Profile reports table is not applied yet', error: e);
        return false;
      }
      rethrow;
    }
  }

  Future<bool> blockUser({
    required String blockedUserId,
    required String profileId,
  }) async {
    final userId = _sb.auth.currentUser?.id;
    final trimmedBlockedUserId = blockedUserId.trim();
    if (userId == null ||
        trimmedBlockedUserId.isEmpty ||
        trimmedBlockedUserId == userId) {
      return false;
    }

    try {
      await _sb.from(blocksTable).upsert({
        'blocker_user_id': userId,
        'blocked_user_id': trimmedBlockedUserId,
        'blocked_profile_id': profileId.trim().isEmpty
            ? null
            : profileId.trim(),
      }, onConflict: 'blocker_user_id,blocked_user_id');
      return true;
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [blocksTable])) {
        AppLogger.warning('Blocked users table is not applied yet', error: e);
        return false;
      }
      rethrow;
    }
  }

  Future<bool> isBlocked(String blockedUserId) async {
    final userId = _sb.auth.currentUser?.id;
    final target = blockedUserId.trim();
    if (userId == null || target.isEmpty) return false;
    try {
      final row = await _sb
          .from(blocksTable)
          .select('blocked_user_id')
          .eq('blocker_user_id', userId)
          .eq('blocked_user_id', target)
          .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [blocksTable])) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final userId = _sb.auth.currentUser?.id;
    final target = blockedUserId.trim();
    if (userId == null || target.isEmpty) return;
    await _sb
        .from(blocksTable)
        .delete()
        .eq('blocker_user_id', userId)
        .eq('blocked_user_id', target);
  }

  /// First catalogue profile of this account (reports are filed per profile).
  Future<String?> firstProfileIdOf(String userId) async {
    final row = await _sb
        .from('catalog_profiles')
        .select('id')
        .eq('user_id', userId.trim())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final id = (row?['id'] ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }
}

class BlockedAccount {
  const BlockedAccount({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.accountTag,
  });

  final String userId;
  final String name;
  final String avatarUrl;
  final String accountTag;

  factory BlockedAccount.fromMap(Map<String, dynamic> map) => BlockedAccount(
    userId: (map['user_id'] ?? '').toString(),
    name: (map['full_name'] ?? '').toString().trim(),
    avatarUrl: (map['avatar_url'] ?? '').toString().trim(),
    accountTag: (map['account_tag'] ?? '').toString().trim(),
  );
}

/// Accounts I have blocked (My account → Blocked users).
final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedAccount>>((
  ref,
) async {
  final sb = ref.read(supabaseProvider);
  if (sb.auth.currentUser == null) return const [];
  final rows = await sb.rpc<List<dynamic>>(
    'list_my_blocked_users',
    params: {'p_limit': 200},
  );
  return rows
      .map((e) => BlockedAccount.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList(growable: false);
});

/// Whether I have blocked this user (null entry while unknown).
final blockedByMeProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  userId,
) {
  return ref.read(safetyServiceProvider).isBlocked(userId);
});

final safetyServiceProvider = Provider<SafetyService>((ref) {
  return SafetyService(ref.read(supabaseProvider));
});
