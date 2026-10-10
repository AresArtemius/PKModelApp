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

  // ---- Step 45: likes, saves, reposts ---------------------------------

  Future<void> like(String postId) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    await _sb.from('post_likes').upsert(
      {'post_id': postId, 'user_id': me},
      onConflict: 'post_id,user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unlike(String postId) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    await _sb.from('post_likes').delete().eq('post_id', postId).eq('user_id', me);
  }

  Future<void> save(String postId) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    await _sb.from('post_saves').upsert(
      {'post_id': postId, 'user_id': me},
      onConflict: 'post_id,user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unsave(String postId) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    await _sb.from('post_saves').delete().eq('post_id', postId).eq('user_id', me);
  }

  // ---- Step 47: comments and reports ----------------------------------

  Future<List<FeedComment>> listComments(String postId) async {
    try {
      final rows = await _sb.rpc(
        'list_post_comments',
        params: {'p_post_id': postId, 'p_limit': 200},
      );
      return (rows as List<dynamic>)
          .map((e) => FeedComment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRpc(e, 'list_post_comments')) {
        return const <FeedComment>[];
      }
      rethrow;
    }
  }

  Future<void> addComment(String postId, String body) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    await _sb.from('post_comments').insert({
      'post_id': postId,
      'author_id': me,
      'body': body.trim(),
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _sb.from('post_comments').delete().eq('id', commentId);
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
    String comment = '',
  }) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    await _sb.from('post_reports').upsert(
      {
        'post_id': postId,
        'reporter_user_id': me,
        'reason': reason,
        'comment': comment.trim(),
      },
      onConflict: 'post_id,reporter_user_id',
    );
  }

  /// Soft delete of my own post (admins can hide any post the same way).
  Future<void> deletePost(String postId) async {
    await _sb
        .from('posts')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', postId);
  }

  /// A repost is a post of kind `repost` that points at a post, a profile or
  /// a casting (exactly one of them) with an optional caption.
  Future<void> repost({
    String? repostOf,
    String? profileId,
    String? castingId,
    String body = '',
    String visibility = 'public',
  }) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    await _sb.from('posts').insert({
      'author_id': me,
      'kind': 'repost',
      'body': body.trim(),
      'visibility': visibility,
      if (repostOf != null) 'repost_of': repostOf,
      if (profileId != null) 'profile_id': profileId,
      if (castingId != null) 'casting_id': castingId,
    });
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

  void remove(String postId) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id != postId) p,
      ],
    );
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
/// Optimistic like / save for every loaded feed scope, then the server; on
/// failure the previous value comes back.
class FeedActions {
  const FeedActions(this._ref);

  final Ref _ref;

  static const _scopes = ['home', 'saved'];

  void _patchAll(String postId, FeedPost Function(FeedPost) update) {
    for (final scope in _scopes) {
      // Only feeds that are already loaded; do not start one just to patch it.
      if (!_ref.exists(feedControllerProvider(scope))) continue;
      _ref.read(feedControllerProvider(scope).notifier).patch(postId, update);
    }
  }

  Future<bool> toggleLike(FeedPost post) async {
    final wasLiked = post.liked;
    _patchAll(
      post.id,
      (p) => p.copyWith(
        liked: !wasLiked,
        likeCount: (p.likeCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 30),
      ),
    );
    try {
      final service = _ref.read(feedServiceProvider);
      if (wasLiked) {
        await service.unlike(post.id);
      } else {
        await service.like(post.id);
      }
      return true;
    } catch (_) {
      _patchAll(
        post.id,
        (p) => p.copyWith(
          liked: wasLiked,
          likeCount: (p.likeCount + (wasLiked ? 1 : -1)).clamp(0, 1 << 30),
        ),
      );
      return false;
    }
  }

  Future<bool> toggleSave(FeedPost post) async {
    final wasSaved = post.saved;
    _patchAll(post.id, (p) => p.copyWith(saved: !wasSaved));
    try {
      final service = _ref.read(feedServiceProvider);
      if (wasSaved) {
        await service.unsave(post.id);
      } else {
        await service.save(post.id);
      }
      return true;
    } catch (_) {
      _patchAll(post.id, (p) => p.copyWith(saved: wasSaved));
      return false;
    }
  }

  Future<void> addComment(String postId, String body) async {
    await _ref.read(feedServiceProvider).addComment(postId, body);
    _patchAll(postId, (p) => p.copyWith(commentCount: p.commentCount + 1));
    _ref.invalidate(postCommentsProvider(postId));
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _ref.read(feedServiceProvider).deleteComment(commentId);
    _patchAll(
      postId,
      (p) => p.copyWith(commentCount: (p.commentCount - 1).clamp(0, 1 << 30)),
    );
    _ref.invalidate(postCommentsProvider(postId));
  }

  Future<void> deletePost(String postId) async {
    await _ref.read(feedServiceProvider).deletePost(postId);
    for (final scope in _scopes) {
      if (!_ref.exists(feedControllerProvider(scope))) continue;
      _ref.read(feedControllerProvider(scope).notifier).remove(postId);
    }
  }

  /// After a repost the home feed is refreshed so the new post shows up.
  Future<void> repost({
    String? repostOf,
    String? profileId,
    String? castingId,
    String body = '',
    String visibility = 'public',
  }) async {
    await _ref.read(feedServiceProvider).repost(
      repostOf: repostOf,
      profileId: profileId,
      castingId: castingId,
      body: body,
      visibility: visibility,
    );
    if (repostOf != null) {
      _patchAll(repostOf, (p) => p.copyWith(repostCount: p.repostCount + 1));
    }
    await _ref.read(feedControllerProvider('home').notifier).refresh();
  }
}

final feedActionsProvider = Provider<FeedActions>((ref) => FeedActions(ref));

/// Comments of one post; invalidated after adding or removing one.
final postCommentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, String>((ref, postId) {
      return ref.watch(feedServiceProvider).listComments(postId);
    });

final feedControllerProvider =
    StateNotifierProvider.family<FeedController, FeedState, String>((
      ref,
      scope,
    ) {
      ref.watch(currentUserIdProvider);
      return FeedController(ref.watch(feedServiceProvider), scope);
    });
