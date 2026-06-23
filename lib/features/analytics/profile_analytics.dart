import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_logger.dart';
import '../../core/auth_providers.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';

class ProfileAnalyticsSummary {
  const ProfileAnalyticsSummary({
    required this.profileCount,
    required this.views,
    required this.selectionAdds,
    required this.invitations,
    required this.lastEventAt,
  });

  final int profileCount;
  final int views;
  final int selectionAdds;
  final int invitations;
  final DateTime? lastEventAt;

  bool get isEmpty =>
      profileCount == 0 &&
      views == 0 &&
      selectionAdds == 0 &&
      invitations == 0 &&
      lastEventAt == null;
}

class ProfileAnalyticsService {
  const ProfileAnalyticsService(this._sb);

  static const table = 'profile_analytics_events';
  static const eventView = 'profile_view';
  static const eventSelectionAdd = 'selection_add';
  static const eventInvitation = 'invitation';

  final SupabaseClient _sb;

  Future<void> trackProfileView(String profileId) async {
    await _track(profileId: profileId, eventType: eventView);
  }

  Future<void> trackSelectionAdd(String profileId) async {
    await _track(profileId: profileId, eventType: eventSelectionAdd);
  }

  Future<void> trackInvitation(String profileId) async {
    await _track(profileId: profileId, eventType: eventInvitation);
  }

  Future<void> _track({
    required String profileId,
    required String eventType,
  }) async {
    final trimmedId = profileId.trim();
    if (trimmedId.isEmpty) return;

    try {
      await _sb.from(table).insert({
        'profile_id': trimmedId,
        'event_type': eventType,
        'actor_user_id': _sb.auth.currentUser?.id,
      });
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table])) {
        AppLogger.warning(
          'Profile analytics table is not applied yet',
          error: e,
        );
        return;
      }
      AppLogger.warning('Profile analytics skipped', error: e);
    } catch (e, stack) {
      AppLogger.warning(
        'Profile analytics skipped',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<ProfileAnalyticsSummary> loadForCurrentUser() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const ProfileAnalyticsSummary(
        profileCount: 0,
        views: 0,
        selectionAdds: 0,
        invitations: 0,
        lastEventAt: null,
      );
    }

    final rpcSummary = await _loadSummaryViaRpc();
    if (rpcSummary != null) return rpcSummary;

    final profiles = await _sb
        .from('profiles')
        .select('id')
        .eq('user_id', userId);
    final profileIds = (profiles as List)
        .map((row) => ((row as Map)['id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (profileIds.isEmpty) {
      return const ProfileAnalyticsSummary(
        profileCount: 0,
        views: 0,
        selectionAdds: 0,
        invitations: 0,
        lastEventAt: null,
      );
    }

    final eventSummary = await _loadEventSummary(profileIds);
    final selectionAdds = await _loadSelectionAdds(profileIds);
    final invitations = await _loadInvitationCount(profileIds);

    return ProfileAnalyticsSummary(
      profileCount: profileIds.length,
      views: eventSummary.views,
      selectionAdds: selectionAdds,
      invitations: invitations,
      lastEventAt: eventSummary.lastEventAt,
    );
  }

  Future<ProfileAnalyticsSummary?> _loadSummaryViaRpc() async {
    try {
      final data = await _sb.rpc('get_my_profile_analytics');
      final row = data is List && data.isNotEmpty
          ? Map<String, dynamic>.from(data.first as Map)
          : data is Map
          ? Map<String, dynamic>.from(data)
          : null;
      if (row == null) return null;

      return ProfileAnalyticsSummary(
        profileCount: _intFromMap(row, 'profile_count'),
        views: _intFromMap(row, 'views'),
        selectionAdds: _intFromMap(row, 'selection_adds'),
        invitations: _intFromMap(row, 'invitations'),
        lastEventAt: DateTime.tryParse((row['last_event_at'] ?? '').toString()),
      );
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRpc(e, 'get_my_profile_analytics')) {
        return null;
      }
      if (SupabaseCompat.isMissingRelation(e, const [
        table,
        'selection_items',
        'selection_chats',
      ])) {
        return null;
      }
      AppLogger.warning('Profile analytics RPC skipped', error: e);
      return null;
    }
  }

  int _intFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  Future<({int views, DateTime? lastEventAt})> _loadEventSummary(
    List<String> profileIds,
  ) async {
    try {
      final views = await _sb
          .from(table)
          .count(CountOption.exact)
          .filter('profile_id', 'in', '(${profileIds.join(',')})')
          .eq('event_type', eventView);
      final rows = await _sb
          .from(table)
          .select('created_at')
          .filter('profile_id', 'in', '(${profileIds.join(',')})')
          .order('created_at', ascending: false)
          .limit(1);
      final lastRow = (rows as List).isEmpty
          ? null
          : Map<String, dynamic>.from(rows.first as Map);
      final lastEventAt = lastRow == null
          ? null
          : DateTime.tryParse((lastRow['created_at'] ?? '').toString());
      return (views: views, lastEventAt: lastEventAt);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table])) {
        AppLogger.warning(
          'Profile analytics table is not applied yet',
          error: e,
        );
        return (views: 0, lastEventAt: null);
      }
      rethrow;
    }
  }

  Future<int> _loadSelectionAdds(List<String> profileIds) async {
    try {
      final count = await _sb
          .from('selection_items')
          .count(CountOption.exact)
          .filter('profile_id', 'in', '(${profileIds.join(',')})');
      return count;
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['selection_items'])) {
        return 0;
      }
      AppLogger.warning('Selection add analytics skipped', error: e);
      return 0;
    }
  }

  Future<int> _loadInvitationCount(List<String> profileIds) async {
    try {
      final count = await _sb
          .from('selection_chats')
          .count(CountOption.exact)
          .filter('profile_id', 'in', '(${profileIds.join(',')})');
      return count;
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['selection_chats'])) {
        return 0;
      }
      AppLogger.warning('Invitation analytics skipped', error: e);
      return 0;
    }
  }
}

final profileAnalyticsServiceProvider = Provider<ProfileAnalyticsService>((
  ref,
) {
  return ProfileAnalyticsService(ref.read(supabaseProvider));
});

final profileAnalyticsProvider =
    FutureProvider.autoDispose<ProfileAnalyticsSummary>((ref) async {
      ref.watch(currentUserIdProvider);
      return ref.read(profileAnalyticsServiceProvider).loadForCurrentUser();
    });

void trackProfileViewLater(WidgetRef ref, String profileId) {
  unawaited(
    ref.read(profileAnalyticsServiceProvider).trackProfileView(profileId),
  );
}
