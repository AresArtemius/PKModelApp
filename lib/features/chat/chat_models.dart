class CastingInvitation {
  const CastingInvitation({
    required this.selectionId,
    required this.profileId,
    required this.modelUserId,
    required this.selectionTitle,
    required this.requestVideoIntro,
    required this.videoIntroRequirements,
    required this.profileName,
    required this.photoUrl,
    required this.createdAt,
  });

  final String selectionId;
  final String profileId;
  final String modelUserId;
  final String selectionTitle;
  final bool requestVideoIntro;
  final String videoIntroRequirements;
  final String profileName;
  final String photoUrl;
  final DateTime? createdAt;

  factory CastingInvitation.fromMap(Map<String, dynamic> map) {
    final selection = Map<String, dynamic>.from(
      (map['selection'] as Map?) ?? {},
    );
    final profile = Map<String, dynamic>.from((map['profile'] as Map?) ?? {});
    final photoUrlsRaw = profile['photo_urls'];
    final photoUrls = photoUrlsRaw is List
        ? photoUrlsRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return CastingInvitation(
      selectionId: (map['selection_id'] ?? '').toString(),
      profileId: (map['profile_id'] ?? '').toString(),
      modelUserId: (profile['user_id'] ?? '').toString(),
      selectionTitle: (selection['title'] ?? '').toString().trim(),
      requestVideoIntro: selection['request_video_intro'] == true,
      videoIntroRequirements: (selection['video_intro_requirements'] ?? '')
          .toString()
          .trim(),
      profileName: (profile['full_name'] ?? '').toString().trim(),
      photoUrl: _coverPhoto(profile['cover_photo_url'], photoUrls),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  factory CastingInvitation.fromRpcMap(Map<String, dynamic> map) {
    final photoUrlsRaw = map['photo_urls'];
    final photoUrls = photoUrlsRaw is List
        ? photoUrlsRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return CastingInvitation(
      selectionId: (map['selection_id'] ?? '').toString(),
      profileId: (map['profile_id'] ?? '').toString(),
      modelUserId: (map['model_user_id'] ?? '').toString(),
      selectionTitle: (map['selection_title'] ?? '').toString().trim(),
      requestVideoIntro: map['request_video_intro'] == true,
      videoIntroRequirements: (map['video_intro_requirements'] ?? '')
          .toString()
          .trim(),
      profileName: (map['profile_name'] ?? '').toString().trim(),
      photoUrl: _coverPhoto(map['cover_photo_url'], photoUrls),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }
}

String _coverPhoto(dynamic rawCover, List<String> photoUrls) {
  final cover = (rawCover ?? '').toString().trim();
  if (cover.isNotEmpty) return cover;
  return photoUrls.isEmpty ? '' : photoUrls.first;
}

class ChatListItem {
  const ChatListItem({
    required this.id,
    required this.selectionTitle,
    required this.profileName,
    required this.photoUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.pinned,
    required this.archived,
  });

  final String id;
  final String selectionTitle;
  final String profileName;
  final String photoUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool pinned;
  final bool archived;

  ChatListItem copyWith({
    String? id,
    String? selectionTitle,
    String? profileName,
    String? photoUrl,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? pinned,
    bool? archived,
  }) {
    return ChatListItem(
      id: id ?? this.id,
      selectionTitle: selectionTitle ?? this.selectionTitle,
      profileName: profileName ?? this.profileName,
      photoUrl: photoUrl ?? this.photoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
    );
  }

  String get title {
    final parts = [
      selectionTitle,
      profileName,
    ].where((e) => e.trim().isNotEmpty).toList(growable: false);
    return parts.isEmpty ? 'Чат' : parts.join(' • ');
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        lastMessage.toLowerCase().contains(q);
  }
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.selectionId,
    required this.profileId,
    required this.modelUserId,
    required this.agentUserId,
    required this.selectionTitle,
    required this.profileName,
  });

  final String id;
  final String selectionId;
  final String profileId;
  final String modelUserId;
  final String agentUserId;
  final String selectionTitle;
  final String profileName;

  factory ChatSummary.fromMap(Map<String, dynamic> map) {
    final selection = Map<String, dynamic>.from(
      (map['selection'] as Map?) ?? {},
    );
    final profile = Map<String, dynamic>.from((map['profile'] as Map?) ?? {});
    return ChatSummary(
      id: (map['id'] ?? '').toString(),
      selectionId: (map['selection_id'] ?? '').toString(),
      profileId: (map['profile_id'] ?? '').toString(),
      modelUserId: (map['model_user_id'] ?? '').toString(),
      agentUserId: (map['agent_user_id'] ?? '').toString(),
      selectionTitle: (selection['title'] ?? '').toString().trim(),
      profileName: (profile['full_name'] ?? '').toString().trim(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.body,
    required this.mediaType,
    required this.mediaUrl,
    required this.mediaThumbnailUrl,
    required this.fileName,
    required this.fileSize,
    required this.fileMime,
    required this.deletedAt,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String body;
  final String mediaType;
  final String mediaUrl;
  final String mediaThumbnailUrl;
  final String fileName;
  final int? fileSize;
  final String fileMime;
  final DateTime? deletedAt;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isDeleted => deletedAt != null;
  bool get hasMedia => mediaUrl.trim().isNotEmpty;
  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
  bool get isFile => mediaType == 'file';
  String get fileDisplayName {
    final explicit = fileName.trim();
    if (explicit.isNotEmpty) return explicit;
    final path = Uri.tryParse(mediaUrl)?.path ?? mediaUrl;
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: (map['id'] ?? '').toString(),
      chatId: (map['chat_id'] ?? '').toString(),
      senderId: (map['sender_id'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      mediaType: (map['media_type'] ?? 'text').toString().trim(),
      mediaUrl: (map['media_url'] ?? '').toString().trim(),
      mediaThumbnailUrl: (map['media_thumbnail_url'] ?? '').toString().trim(),
      fileName: (map['file_name'] ?? '').toString().trim(),
      fileSize: _intOrNull(map['file_size']),
      fileMime: (map['file_mime'] ?? '').toString().trim(),
      deletedAt: DateTime.tryParse((map['deleted_at'] ?? '').toString()),
      readAt: DateTime.tryParse((map['read_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }
}

int? _intOrNull(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  return int.tryParse(raw.toString());
}

class ChatTypingState {
  const ChatTypingState({
    required this.chatId,
    required this.userId,
    required this.isTyping,
    required this.typedAt,
  });

  final String chatId;
  final String userId;
  final bool isTyping;
  final DateTime? typedAt;

  bool get isFresh {
    final typed = typedAt;
    if (typed == null) return false;
    return DateTime.now().toUtc().difference(typed.toUtc()).inSeconds <= 8;
  }

  factory ChatTypingState.fromMap(Map<String, dynamic> map) {
    return ChatTypingState(
      chatId: (map['chat_id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      isTyping: map['is_typing'] == true,
      typedAt: DateTime.tryParse((map['typed_at'] ?? '').toString()),
    );
  }
}

class ChatReaction {
  const ChatReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  final String messageId;
  final String userId;
  final String emoji;

  factory ChatReaction.fromMap(Map<String, dynamic> map) {
    return ChatReaction(
      messageId: (map['message_id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      emoji: (map['emoji'] ?? '').toString(),
    );
  }
}
