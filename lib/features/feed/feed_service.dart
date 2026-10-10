import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_providers.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import 'feed_models.dart';

/// Step 44: reading the feed through `get_feed()` with keyset pagination
/// over (created_at, id). Likes and saves come in step 46.
class FeedService {
  FeedService(this._sb);

  final SupabaseClient _sb;

  static const pageSize = 20;

  /// `scope`: `home` | `saved` | `author:<uuid>`.
  Future<List<FeedPost>> fetchPage({
    String scope = 'home',
    FeedPost? after,
    int limit = pageSize,
  }) async {
    try {
      final rows = await _sb.rpc(
        'get_feed',
        params: {
          if (after != null) 'p_cursor_at': after.createdAt.toUtc().toIso8601String(),
          if (after != null) 'p_cursor_id': after.id,
          'p_limit': limit,
          'p_scope': scope,
        },
      );
      return (rows as List<dynamic>)
          .map((e) => FeedPost.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRpc(e, 'get_feed')) {
        return const <FeedPost>[];
      }
      rethrow;
    }
  }
}

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService(ref.watch(supabaseProvider));
});

class FeedState {
  const FeedState({
    this.posts = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<FeedPost> posts;

  /// First page in flight (nothing to show yet).
  final bool loading;

  /// Next page in flight (posts already on screen).
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  bool get isEmpty => !loading && posts.isEmpty;

  FeedState copyWith({
    List<FeedPost>? posts,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// One feed per scope: loads the first page on creation, appends on
/// [loadMore], starts over on [refresh].
class FeedController extends StateNotifier<FeedState> {
  FeedController(this._service, this.scope) : super(const FeedState()) {
    refresh();
  }

  final FeedService _service;
  final String scope;

  int _generation = 0;

  Future<void> refresh() async {
    final gen = ++_generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _service.fetchPage(scope: scope);
      if (gen != _generation) return;
      state = FeedState(
        posts: page,
        hasMore: page.length >= FeedService.pageSize,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    if (state.posts.isEmpty) return refresh();
    final gen = _generation;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await _service.fetchPage(scope: scope, after: state.posts.last);
      if (gen != _generation) return;
      final known = state.posts.map((p) => p.id).toSet();
      final fresh = page.where((p) => !known.contains(p.id)).toList();
      state = state.copyWith(
        posts: [...state.posts, ...fresh],
        loadingMore: false,
        hasMore: page.length >= FeedService.pageSize,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  /// Local patch (optimistic like / save, step 46).
  void patch(String postId, FeedPost Function(FeedPost) update) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts) p.id == postId ? update(p) : p,
      ],
    );
  }
}

/// Not auto-disposed on purpose: the feed stays loaded while the user moves
/// around the cabinet, so coming back does not start from scratch. A sign-in
/// or sign-out rebuilds it.
final feedControllerProvider =
    StateNotifierProvider.family<FeedController, FeedState, String>((
      ref,
      scope,
    ) {
      ref.watch(currentUserIdProvider);
      return FeedController(ref.watch(feedServiceProvider), scope);
    });
