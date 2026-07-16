import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import 'my_profile_controller.dart';
import 'profile_supabase_schema.dart';

class ProfileCreationCapacity {
  const ProfileCreationCapacity({
    required this.currentCount,
    required this.limit,
    required this.pendingRequest,
  });

  final int currentCount;
  final int limit;
  final bool pendingRequest;
  bool get canCreate => currentCount < limit;
}

final profileCreationCapacityProvider =
    FutureProvider.autoDispose<ProfileCreationCapacity>((ref) async {
      final sb = ref.read(supabaseProvider);
      try {
        final data = await sb.rpc('my_profile_creation_capacity');
        final rows = data is List ? data : const [];
        if (rows.isNotEmpty && rows.first is Map) {
          final row = Map<String, dynamic>.from(rows.first as Map);
          return ProfileCreationCapacity(
            currentCount: (row['current_count'] as num?)?.toInt() ?? 0,
            limit:
                (row['profile_limit'] as num?)?.toInt() ??
                MyProfileController.defaultProfileLimit,
            pendingRequest: row['has_pending_request'] == true,
          );
        }
      } on PostgrestException catch (e) {
        if (!SupabaseCompat.isMissingRpc(e, 'my_profile_creation_capacity')) {
          rethrow;
        }
      }

      final uid = sb.auth.currentUser?.id;
      final count = uid == null
          ? 0
          : await sb
                .from(ProfileSupabaseSchema.table)
                .count(CountOption.exact)
                .eq('user_id', uid);
      return ProfileCreationCapacity(
        currentCount: count,
        limit: MyProfileController.defaultProfileLimit,
        pendingRequest: false,
      );
    });

Future<void> requestExtraProfileSlot(WidgetRef ref) async {
  await ref.read(supabaseProvider).rpc('request_extra_profile_slot');
  ref.invalidate(profileCreationCapacityProvider);
}
