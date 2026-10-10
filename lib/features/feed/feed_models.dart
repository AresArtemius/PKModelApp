/// Step 44: rows of `get_feed()` (supabase/sql/feed_mvp.sql).
class FeedMedia {
  const FeedMedia({
    required this.id,
    required this.type,
    required this.url,
    required this.thumbnailUrl,
    this.width,
    this.height,
  });

  final String id;

  /// `image` | `video`.
  final String type;
  final String url;
  final String thumbnailUrl;
  final int? width;
  final int? height;

  bool get isVideo => type == 'video';

  /// Width / height when both are known, otherwise a 4:5 portrait default.
  double get aspectRatio {
    final w = width ?? 0;
    final h = height ?? 0;
    if (w > 0 && h > 0) return w / h;
    return 4 / 5;
  }

  factory FeedMedia.fromMap(Map<String, dynamic> map) {
    return FeedMedia(
      id: (map['id'] ?? '').toString(),
      type: (map['type'] ?? 'image').toString(),
      url: (map['url'] ?? '').toString().trim(),
      thumbnailUrl: (map['thumbnail_url'] ?? '').toString().trim(),
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
    );
  }
}

enum FeedPostKind { text, media, casting, booked, repost }

FeedPostKind feedPostKindFromString(String value) {
  return switch (value) {
    'media' => FeedPostKind.media,
    'casting' => FeedPostKind.casting,
    'booked' => FeedPostKind.booked,
    'repost' => FeedPostKind.repost,
    _ => FeedPostKind.text,
  };
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.authorTag,
    required this.authorAccountType,
    required this.kind,
    required this.body,
    required this.visibility,
    required this.profileId,
    required this.profileName,
    required this.profilePhotoUrl,
    required this.castingId,
    required this.castingTitle,
    required this.repostOf,
    required this.repostAuthorName,
    required this.repostBody,
    required this.city,
    required this.commentsEnabled,
    required this.auto,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.saveCount,
    required this.media,
    required this.liked,
    required this.saved,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String authorTag;
  final String authorAccountType;
  final FeedPostKind kind;
  final String body;
  final String visibility;
  final String? profileId;
  final String profileName;
  final String profilePhotoUrl;
  final String? castingId;
  final String castingTitle;
  final String? repostOf;
  final String repostAuthorName;
  final String repostBody;
  final String city;
  final bool commentsEnabled;
  final bool auto;
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final int saveCount;
  final List<FeedMedia> media;
  final bool liked;
  final bool saved;
  final DateTime createdAt;

  /// What to show as the author line: name, then @tag, then a placeholder.
  String displayAuthor(bool ru) {
    if (authorName.isNotEmpty) return authorName;
    if (authorTag.isNotEmpty) return '@$authorTag';
    return ru ? 'Аккаунт' : 'Account';
  }

  FeedPost copyWith({
    int? likeCount,
    int? saveCount,
    int? repostCount,
    int? commentCount,
    bool? liked,
    bool? saved,
  }) {
    return FeedPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      authorTag: authorTag,
      authorAccountType: authorAccountType,
      kind: kind,
      body: body,
      visibility: visibility,
      profileId: profileId,
      profileName: profileName,
      profilePhotoUrl: profilePhotoUrl,
      castingId: castingId,
      castingTitle: castingTitle,
      repostOf: repostOf,
      repostAuthorName: repostAuthorName,
      repostBody: repostBody,
      city: city,
      commentsEnabled: commentsEnabled,
      auto: auto,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,
      saveCount: saveCount ?? this.saveCount,
      media: media,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
      createdAt: createdAt,
    );
  }

  factory FeedPost.fromMap(Map<String, dynamic> map) {
    String str(String key) => (map[key] ?? '').toString().trim();
    String? idOrNull(String key) {
      final v = str(key);
      return v.isEmpty ? null : v;
    }
    int intOf(String key) => (map[key] as num?)?.toInt() ?? 0;

    final rawMedia = map['media'];
    final media = rawMedia is List
        ? rawMedia
              .whereType<Map>()
              .map((m) => FeedMedia.fromMap(Map<String, dynamic>.from(m)))
              .where((m) => m.url.isNotEmpty)
              .toList(growable: false)
        : const <FeedMedia>[];

    return FeedPost(
      id: str('id'),
      authorId: str('author_id'),
      authorName: str('author_name'),
      authorAvatarUrl: str('author_avatar_url'),
      authorTag: str('author_tag'),
      authorAccountType: str('author_account_type'),
      kind: feedPostKindFromString(str('kind')),
      body: (map['body'] ?? '').toString(),
      visibility: str('visibility'),
      profileId: idOrNull('profile_id'),
      profileName: str('profile_name'),
      profilePhotoUrl: str('profile_photo_url'),
      castingId: idOrNull('casting_id'),
      castingTitle: str('casting_title'),
      repostOf: idOrNull('repost_of'),
      repostAuthorName: str('repost_author_name'),
      repostBody: (map['repost_body'] ?? '').toString(),
      city: str('city'),
      commentsEnabled: map['comments_enabled'] != false,
      auto: map['auto'] == true,
      likeCount: intOf('like_count'),
      commentCount: intOf('comment_count'),
      repostCount: intOf('repost_count'),
      saveCount: intOf('save_count'),
      media: media,
      liked: map['liked'] == true,
      saved: map['saved'] == true,
      createdAt:
          DateTime.tryParse(str('created_at'))?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Step 47: a row of `list_post_comments()`.
class FeedComment {
  const FeedComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.authorTag,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String authorTag;
  final String body;
  final DateTime createdAt;

  String displayAuthor(bool ru) {
    if (authorName.isNotEmpty) return authorName;
    if (authorTag.isNotEmpty) return '@$authorTag';
    return ru ? 'Аккаунт' : 'Account';
  }

  factory FeedComment.fromMap(Map<String, dynamic> map) {
    String str(String key) => (map[key] ?? '').toString().trim();
    return FeedComment(
      id: str('id'),
      postId: str('post_id'),
      authorId: str('author_id'),
      authorName: str('author_name'),
      authorAvatarUrl: str('author_avatar_url'),
      authorTag: str('author_tag'),
      body: (map['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(str('created_at'))?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
