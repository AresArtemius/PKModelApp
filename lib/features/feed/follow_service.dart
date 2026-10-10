import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_providers.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';

/// Step 42: follows between accounts (feed_mvp.sql: `follows`,
/// `follow_counts`, `list_follow_accounts`).
class FollowCounts {
  const FollowCounts({
    required this.followers,
    required this.following,
    required this.iFollow,
  });

  final int followers;
  final int following;
  final bool iFollow;

  static const empty = FollowCounts(followers: 0, following: 0, iFollow: false);

  FollowCounts copyWith({int? followers, int? following, bool? iFollow}) {
    return FollowCounts(
      followers: followers ?? this.followers,
      following: following ?? this.following,
      iFollow: iFollow ?? this.iFollow,
    );
  }
}

class FollowAccount {
  const FollowAccount({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.accountTag,
    required this.accountType,
    required this.iFollow,
    this.followedAt,
  });

  final String userId;
  final String name;
  final String avatarUrl;
  final String accountTag;
  final String accountType;
  final bool iFollow;
  final DateTime? followedAt;

  factory FollowAccount.fromMap(Map<String, dynamic> map) {
    return FollowAccount(
      userId: (map['user_id'] ?? '').toString(),
      name: (map['full_name'] ?? '').toString().trim(),
      avatarUrl: (map['avatar_url'] ?? '').toString().trim(),
      accountTag: (map['account_tag'] ?? '').toString().trim(),
      accountType: (map['account_type'] ?? '').toString().trim(),
      iFollow: map['i_follow'] == true,
      followedAt: DateTime.tryParse((map['followed_at'] ?? '').toString()),
    );
  }
}

/// Step 49: a row of `suggest_follow_accounts()`.
class FollowSuggestion {
  const FollowSuggestion({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.accountTag,
    required this.accountType,
    required this.city,
    required this.followers,
    required this.reason,
  });

  final String userId;
  final String name;
  final String avatarUrl;
  final String accountTag;
  final String accountType;
  final String city;
  final int followers;

  /// `city` | `popular` | `active` | `profile`.
  final String reason;

  factory FollowSuggestion.fromMap(Map<String, dynamic> map) {
    return FollowSuggestion(
      userId: (map['user_id'] ?? '').toString(),
      name: (map['full_name'] ?? '').toString().trim(),
      avatarUrl: (map['avatar_url'] ?? '').toString().trim(),
      accountTag: (map['account_tag'] ?? '').toString().trim(),
      accountType: (map['account_type'] ?? '').toString().trim(),
      city: (map['city'] ?? '').toString().trim(),
      followers: (map['followers'] as num?)?.toInt() ?? 0,
      reason: (map['reason'] ?? '').toString(),
    );
  }
}

class FollowService {
  FollowService(this._sb);

  final SupabaseClient _sb;

  Future<FollowCounts> counts(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return FollowCounts.empty;
    try {
      final rows = await _sb.rpc('follow_counts', params: {'p_user_id': id});
      final list = rows as List<dynamic>;
      if (list.isEmpty) return FollowCounts.empty;
      final map = Map<String, dynamic>.from(list.first as Map);
      return FollowCounts(
        followers: (map['followers'] as num?)?.toInt() ?? 0,
        following: (map['following'] as num?)?.toInt() ?? 0,
        iFollow: map['i_follow'] == true,
      );
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRpc(e, 'follow_counts')) {
        return FollowCounts.empty;
      }
      rethrow;
    }
  }

  Future<void> follow(String userId) async {
    final me = _sb.auth.currentUser?.id;
    final id = userId.trim();
    if (me == null || id.isEmpty || id == me) return;
    await _sb.from('follows').upsert(
      {'follower_id': me, 'followee_id': id},
      onConflict: 'follower_id,followee_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unfollow(String userId) async {
    final me = _sb.auth.currentUser?.id;
    final id = userId.trim();
    if (me == null || id.isEmpty) return;
    await _sb
        .from('follows')
        .delete()
        .eq('follower_id', me)
        .eq('followee_id', id);
  }

  Future<List<FollowSuggestion>> suggestions({int limit = 8}) async {
    if (_sb.auth.currentUser == null) return const <FollowSuggestion>[];
    try {
      final rows = await _sb.rpc(
        'suggest_follow_accounts',
        params: {'p_limit': limit},
      );
      return (rows as List<dynamic>)
          .map(
            (e) => FollowSuggestion.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .where((a) => a.userId.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRpc(e, 'suggest_follow_accounts')) {
        return const <FollowSuggestion>[];
      }
      rethrow;
    }
  }

  /// `following` — accounts [userId] follows; `followers` — who follows
  /// them. Null user = me.
  Future<List<FollowAccount>> list({
    String direction = 'following',
    String? userId,
  }) async {
    try {
      final rows = await _sb.rpc(
        'list_follow_accounts',
        params: {
          'p_direction': direction,
          if (userId != null && userId.trim().isNotEmpty) 'p_user_id': userId,
          'p_limit': 200,
        },
      );
      return (rows as List<dynamic>)
          .map((e) => FollowAccount.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((a) => a.userId.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRpc(e, 'list_follow_accounts')) {
        return const <FollowAccount>[];
      }
      rethrow;
    }
  }
}

final followServiceProvider = Provider<FollowService>((ref) {
  return FollowService(ref.watch(supabaseProvider));
});

/// Followers / following / «do I follow» for an account; refreshed after
/// every follow or unfollow through [followActionsProvider].
final followCountsProvider = FutureProvider.autoDispose
    .family<FollowCounts, String>((ref, userId) {
      ref.watch(currentUserIdProvider);
      return ref.watch(followServiceProvider).counts(userId);
    });

final followListProvider = FutureProvider.autoDispose
    .family<List<FollowAccount>, String>((ref, direction) {
      ref.watch(currentUserIdProvider);
      return ref.watch(followServiceProvider).list(direction: direction);
    });

/// «Кого читать» for the current account; refreshed after a follow.
final followSuggestionsProvider = FutureProvider.autoDispose<List<FollowSuggestion>>((
  ref,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(followServiceProvider).suggestions();
});

/// Optimistic follow / unfollow: the counter moves at once, the server is
/// asked afterwards; on failure the previous state comes back.
class FollowActions {
  const FollowActions(this._ref);

  final Ref _ref;

  Future<bool> toggle(String userId, {required bool currentlyFollowing}) async {
    final service = _ref.read(followServiceProvider);
    try {
      if (currentlyFollowing) {
        await service.unfollow(userId);
      } else {
        await service.follow(userId);
      }
      _ref.invalidate(followCountsProvider(userId));
      final me = _ref.read(currentUserIdProvider);
      if (me != null) _ref.invalidate(followCountsProvider(me));
      _ref.invalidate(followListProvider('following'));
      _ref.invalidate(followSuggestionsProvider);
      return true;
    } catch (_) {
      _ref.invalidate(followCountsProvider(userId));
      return false;
    }
  }
}

final followActionsProvider = Provider<FollowActions>((ref) => FollowActions(ref));
