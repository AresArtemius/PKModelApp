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
      photoUrl: photoUrls.isEmpty ? '' : photoUrls.first,
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
      photoUrl: photoUrls.isEmpty ? '' : photoUrls.first,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
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
    required this.deletedAt,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String body;
  final String mediaType;
  final String mediaUrl;
  final String mediaThumbnailUrl;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  bool get isDeleted => deletedAt != null;
  bool get hasMedia => mediaUrl.trim().isNotEmpty;
  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: (map['id'] ?? '').toString(),
      chatId: (map['chat_id'] ?? '').toString(),
      senderId: (map['sender_id'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      mediaType: (map['media_type'] ?? 'text').toString().trim(),
      mediaUrl: (map['media_url'] ?? '').toString().trim(),
      mediaThumbnailUrl: (map['media_thumbnail_url'] ?? '').toString().trim(),
      deletedAt: DateTime.tryParse((map['deleted_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
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
