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
}

final safetyServiceProvider = Provider<SafetyService>((ref) {
  return SafetyService(ref.read(supabaseProvider));
});
