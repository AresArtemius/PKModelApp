import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import 'chat_models.dart';

class ChatService {
  const ChatService(this._sb);

  static const int _invitationListLimit = 100;
  static const int _messageStreamLimit = 120;
  static const int _reactionStreamLimit = _messageStreamLimit * 3;
  static const int _typingStreamLimit = 8;
  static const String _baseMessageSelect =
      'id,chat_id,sender_id,body,media_type,media_url,media_thumbnail_url,deleted_at,created_at';
  static const String _fileMessageFields = ',file_name,file_size,file_mime';

  final SupabaseClient _sb;

  String _messageSelect({
    bool includeReadAt = false,
    bool includeFileFields = true,
  }) {
    final readAt = includeReadAt ? ',read_at' : '';
    final fileFields = includeFileFields ? _fileMessageFields : '';
    return '$_baseMessageSelect$readAt$fileFields';
  }

  Future<List<CastingInvitation>> fetchMyInvitations(String userId) async {
    try {
      final rows = await _sb.rpc('get_my_selection_invitations');
      return (rows as List<dynamic>)
          .map(
            (e) => CastingInvitation.fromRpcMap(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.selectionId.isNotEmpty && e.profileId.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (_isRlsRecursion(e)) {
        return const <CastingInvitation>[];
      }
      if (!SupabaseCompat.isMissingRpc(e, 'get_my_selection_invitations')) {
        rethrow;
      }
    }

    Future<List<dynamic>> run({required bool includeVideoRequest}) async {
      return await _sb
          .from('selection_items')
          .select('''
          selection_id,
          profile_id,
          created_at,
          selection:selections!inner(
            id,
            title,
            created_at
            ${includeVideoRequest ? ',request_video_intro,video_intro_requirements' : ''}
          ),
          profile:profiles!inner(id,user_id,full_name,photo_urls,cover_photo_url)
        ''')
          .eq('profile.user_id', userId)
          .filter('model_hidden_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(_invitationListLimit);
    }

    List<dynamic> rows;
    try {
      rows = await run(includeVideoRequest: true);
    } on PostgrestException catch (e) {
      if (_isRlsRecursion(e)) {
        return const <CastingInvitation>[];
      }
      final missingVideoRequestColumns =
          SupabaseCompat.isMissingColumn(e, 'request_video_intro') ||
          SupabaseCompat.isMissingColumn(e, 'video_intro_requirements');
      if (!missingVideoRequestColumns) {
        if (!SupabaseCompat.isMissingColumn(e, 'model_hidden_at')) {
          rethrow;
        }
      }
      try {
        rows = await _fetchMyInvitationsWithoutHiddenFilter(
          userId,
          includeVideoRequest: false,
        );
      } on PostgrestException catch (fallbackError) {
        if (_isRlsRecursion(fallbackError)) {
          return const <CastingInvitation>[];
        }
        rethrow;
      }
    }

    return rows
        .map((e) => CastingInvitation.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.selectionId.isNotEmpty && e.profileId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<dynamic>> _fetchMyInvitationsWithoutHiddenFilter(
    String userId, {
    required bool includeVideoRequest,
  }) async {
    return await _sb
        .from('selection_items')
        .select('''
          selection_id,
          profile_id,
          created_at,
          selection:selections!inner(
            id,
            title,
            created_at
            ${includeVideoRequest ? ',request_video_intro,video_intro_requirements' : ''}
          ),
          profile:profiles!inner(id,user_id,full_name,photo_urls,cover_photo_url)
        ''')
        .eq('profile.user_id', userId)
        .order('created_at', ascending: false)
        .limit(_invitationListLimit);
  }

  bool _isRlsRecursion(PostgrestException e) {
    return SupabaseCompat.isRlsRecursion(e);
  }

  bool _isMissingChatFileColumn(PostgrestException e) {
    return SupabaseCompat.isMissingColumn(e, 'file_name') ||
        SupabaseCompat.isMissingColumn(e, 'file_size') ||
        SupabaseCompat.isMissingColumn(e, 'file_mime');
  }

  Future<String> ensureSelectionChat({
    required String selectionId,
    required String profileId,
    required String modelUserId,
  }) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return '';

    String? agentUserId;
    try {
      final selection = await _sb
          .from('selections')
          .select('created_by')
          .eq('id', selectionId)
          .maybeSingle();
      final createdBy = (selection?['created_by'] ?? '').toString();
      if (createdBy.isNotEmpty && createdBy != modelUserId) {
        agentUserId = createdBy;
      }
    } on PostgrestException {
      // Older SQL may not expose created_by to the current user yet.
    }

    final existing = await _sb
        .from('selection_chats')
        .select('id')
        .eq('selection_id', selectionId)
        .eq('profile_id', profileId)
        .maybeSingle();

    if (existing != null) {
      final id = (existing['id'] ?? '').toString();
      if (id.isNotEmpty) return id;
    }

    final data = await _sb
        .from('selection_chats')
        .upsert({
          'selection_id': selectionId,
          'profile_id': profileId,
          'model_user_id': modelUserId,
          'agent_user_id': userId == modelUserId ? agentUserId : userId,
        }, onConflict: 'selection_id,profile_id')
        .select('id')
        .single();

    return (data['id'] ?? '').toString();
  }

  Future<ChatSummary?> fetchChat(String chatId) async {
    final row = await _sb
        .from('selection_chats')
        .select('''
          id,
          selection_id,
          profile_id,
          model_user_id,
          agent_user_id,
          selection:selections(title),
          profile:profiles(full_name)
        ''')
        .eq('id', chatId)
        .maybeSingle();

    if (row == null) return null;
    return ChatSummary.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<ChatListItem>> fetchMyChats({
    required String userId,
    required bool archived,
  }) async {
    Future<List<dynamic>> run({required bool includeListState}) async {
      return await _sb
          .from('selection_chats')
          .select('''
            id,
            model_user_id,
            agent_user_id,
            created_at,
            updated_at,
            model_deleted_at,
            agent_deleted_at
            ${includeListState ? ',model_pinned_at,agent_pinned_at,model_archived_at,agent_archived_at' : ''},
            selection:selections(title),
            profile:profiles(full_name,photo_urls,cover_photo_url)
          ''')
          .or('model_user_id.eq.$userId,agent_user_id.eq.$userId')
          .order('updated_at', ascending: false)
          .limit(100);
    }

    List<dynamic> rows;
    try {
      rows = await run(includeListState: true);
    } on PostgrestException catch (e) {
      final missingState = SupabaseCompat.isMissingAnyColumn(e, const [
        'model_pinned_at',
        'agent_pinned_at',
        'model_archived_at',
        'agent_archived_at',
      ]);
      if (!missingState) rethrow;
      rows = await run(includeListState: false);
    }

    final items = <ChatListItem>[];
    for (final raw in rows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final chatId = (map['id'] ?? '').toString();
      if (chatId.isEmpty) continue;

      final modelUserId = (map['model_user_id'] ?? '').toString();
      final isModel = userId == modelUserId;
      final deletedAt = isModel
          ? (map['model_deleted_at'] ?? '').toString()
          : (map['agent_deleted_at'] ?? '').toString();
      if (deletedAt.trim().isNotEmpty) continue;

      final archivedAt = isModel
          ? (map['model_archived_at'] ?? '').toString()
          : (map['agent_archived_at'] ?? '').toString();
      final isArchived = archivedAt.trim().isNotEmpty;
      if (isArchived != archived) continue;

      final pinnedAt = isModel
          ? (map['model_pinned_at'] ?? '').toString()
          : (map['agent_pinned_at'] ?? '').toString();
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
      final latest = await _fetchLatestMessage(chatId);
      final fallbackTime = DateTime.tryParse(
        (map['updated_at'] ?? map['created_at'] ?? '').toString(),
      );
      items.add(
        ChatListItem(
          id: chatId,
          selectionTitle: (selection['title'] ?? '').toString().trim(),
          profileName: (profile['full_name'] ?? '').toString().trim(),
          photoUrl: _chatCoverPhoto(profile['cover_photo_url'], photoUrls),
          lastMessage: latest == null ? '' : _chatPreview(latest),
          lastMessageAt: latest?.createdAt ?? fallbackTime,
          unreadCount: await _fetchUnreadCount(chatId, userId),
          pinned: pinnedAt.trim().isNotEmpty,
          archived: isArchived,
        ),
      );
    }

    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;
      if (aTime == null && bTime == null) return a.title.compareTo(b.title);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  String _chatPreview(ChatMessage message) {
    final text = message.body.trim();
    if (text.isNotEmpty &&
        text != 'Фото' &&
        text != 'Видео' &&
        text != 'Файл') {
      return text;
    }
    if (message.isFile) {
      return message.fileDisplayName.isEmpty ? 'Файл' : message.fileDisplayName;
    }
    if (message.isVideo) return 'Видео';
    if (message.isImage) return 'Фото';
    return text;
  }

  String _chatCoverPhoto(dynamic rawCover, List<String> photoUrls) {
    final cover = (rawCover ?? '').toString().trim();
    if (cover.isNotEmpty) return cover;
    return photoUrls.isEmpty ? '' : photoUrls.first;
  }

  Future<ChatMessage?> _fetchLatestMessage(String chatId) async {
    Future<List<dynamic>> run({required bool includeFileFields}) async {
      return await _sb
          .from('selection_chat_messages')
          .select(_messageSelect(includeFileFields: includeFileFields))
          .eq('chat_id', chatId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(1);
    }

    List<dynamic> rows;
    try {
      rows = await run(includeFileFields: true);
    } on PostgrestException catch (e) {
      if (!_isMissingChatFileColumn(e)) rethrow;
      rows = await run(includeFileFields: false);
    }
    if (rows.isEmpty) return null;
    return ChatMessage.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<int> _fetchUnreadCount(String chatId, String userId) async {
    try {
      final rows = await _sb
          .from('selection_chat_messages')
          .select('id')
          .eq('chat_id', chatId)
          .neq('sender_id', userId)
          .filter('deleted_at', 'is', null)
          .filter('read_at', 'is', null);
      return (rows as List).length;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingColumn(e, 'read_at')) rethrow;
      return 0;
    }
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _sb
        .from('selection_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .limit(_messageStreamLimit)
        .map(
          (rows) => rows
              .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e)))
              .where((e) => !e.isDeleted)
              .toList(growable: false),
        );
  }

  Stream<List<ChatReaction>> watchReactions(String chatId) {
    return _sb
        .from('selection_chat_message_reactions')
        .stream(primaryKey: ['message_id', 'user_id'])
        .eq('chat_id', chatId)
        .order('updated_at')
        .limit(_reactionStreamLimit)
        .map(
          (rows) => rows
              .map((e) => ChatReaction.fromMap(Map<String, dynamic>.from(e)))
              .where((e) => e.messageId.isNotEmpty && e.emoji.isNotEmpty)
              .toList(growable: false),
        );
  }

  Stream<List<ChatTypingState>> watchTypingStates({
    required String chatId,
    required String currentUserId,
  }) {
    return _sb
        .from('selection_chat_typing_states')
        .stream(primaryKey: ['chat_id', 'user_id'])
        .eq('chat_id', chatId)
        .order('typed_at')
        .limit(_typingStreamLimit)
        .map(
          (rows) => rows
              .map((e) => ChatTypingState.fromMap(Map<String, dynamic>.from(e)))
              .where(
                (e) =>
                    e.userId.isNotEmpty &&
                    e.userId != currentUserId &&
                    e.isTyping &&
                    e.isFresh,
              )
              .toList(growable: false),
        );
  }

  Future<List<ChatMessage>> fetchMessagesBefore({
    required String chatId,
    required DateTime before,
    int limit = 60,
  }) async {
    Future<List<dynamic>> run({required bool includeReadAt}) async {
      return await _sb
          .from('selection_chat_messages')
          .select(_messageSelect(includeReadAt: includeReadAt))
          .eq('chat_id', chatId)
          .lt('created_at', before.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
    }

    List<dynamic> rows;
    try {
      rows = await run(includeReadAt: true);
    } on PostgrestException catch (e) {
      if (_isMissingChatFileColumn(e)) {
        rows = await _sb
            .from('selection_chat_messages')
            .select(
              _messageSelect(includeReadAt: true, includeFileFields: false),
            )
            .eq('chat_id', chatId)
            .lt('created_at', before.toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(limit);
      } else if (!SupabaseCompat.isMissingColumn(e, 'read_at')) {
        rethrow;
      } else {
        rows = await run(includeReadAt: false);
      }
    }

    return rows
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => !e.isDeleted)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Future<Map<String, String>> fetchChatParticipantAvatars(String chatId) async {
    List<dynamic>? rows;
    try {
      final rpcRows = await _sb.rpc(
        'get_selection_chat_participants',
        params: {'p_chat_id': chatId},
      );
      rows = rpcRows as List<dynamic>;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'get_selection_chat_participants')) {
        if (_isRlsRecursion(e)) return const <String, String>{};
        rethrow;
      }
    }

    if (rows == null) {
      try {
        final chat = await _sb
            .from('selection_chats')
            .select('model_user_id,agent_user_id')
            .eq('id', chatId)
            .maybeSingle();
        final ids = [
          (chat?['model_user_id'] ?? '').toString(),
          (chat?['agent_user_id'] ?? '').toString(),
        ].where((e) => e.isNotEmpty).toSet().toList(growable: false);
        if (ids.isEmpty) return const <String, String>{};
        rows = await _sb
            .from('user_profiles')
            .select('user_id,avatar_url')
            .inFilter('user_id', ids);
      } on PostgrestException catch (e) {
        if (_isRlsRecursion(e)) return const <String, String>{};
        rethrow;
      }
    }

    final avatars = <String, String>{};
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final userId = (map['user_id'] ?? '').toString();
      final avatarUrl = (map['avatar_url'] ?? '').toString().trim();
      if (userId.isNotEmpty && avatarUrl.isNotEmpty) {
        avatars[userId] = avatarUrl;
      }
    }
    return avatars;
  }

  Future<void> sendMessage({
    required String chatId,
    required String body,
    String mediaType = 'text',
    String mediaUrl = '',
    String mediaThumbnailUrl = '',
    String fileName = '',
    int? fileSize,
    String fileMime = '',
  }) async {
    final text = body.trim();
    final userId = _sb.auth.currentUser?.id;
    final hasMedia = mediaUrl.trim().isNotEmpty;
    if ((text.isEmpty && !hasMedia) || userId == null) return;

    final payload = <String, dynamic>{
      'chat_id': chatId,
      'sender_id': userId,
      'body': text.isEmpty && hasMedia
          ? (mediaType == 'video'
                ? 'Видео'
                : mediaType == 'file'
                ? 'Файл'
                : 'Фото')
          : text,
      'media_type': mediaType,
      'media_url': mediaUrl.trim().isEmpty ? null : mediaUrl.trim(),
      'media_thumbnail_url': mediaThumbnailUrl.trim().isEmpty
          ? null
          : mediaThumbnailUrl.trim(),
      'file_name': fileName.trim().isEmpty ? null : fileName.trim(),
      'file_size': fileSize,
      'file_mime': fileMime.trim().isEmpty ? null : fileMime.trim(),
    };

    try {
      await _sb.from('selection_chat_messages').insert(payload);
    } on PostgrestException catch (e) {
      if (!_isMissingChatFileColumn(e) || mediaType == 'file') rethrow;
      payload
        ..remove('file_name')
        ..remove('file_size')
        ..remove('file_mime');
      await _sb.from('selection_chat_messages').insert(payload);
    }
  }

  Future<void> markChatRead(String chatId) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || chatId.trim().isEmpty) return;

    try {
      await _sb.rpc('mark_selection_chat_read', params: {'p_chat_id': chatId});
      return;
    } on PostgrestException catch (e) {
      final missingSupport =
          SupabaseCompat.isMissingRpc(e, 'mark_selection_chat_read') ||
          SupabaseCompat.isMissingColumn(e, 'read_at');
      if (!missingSupport) rethrow;
    }

    try {
      await _sb
          .from('selection_chat_messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('chat_id', chatId)
          .neq('sender_id', userId)
          .filter('read_at', 'is', null)
          .filter('deleted_at', 'is', null);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingColumn(e, 'read_at')) rethrow;
    }
  }

  Future<void> setTyping({
    required String chatId,
    required bool isTyping,
  }) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || chatId.trim().isEmpty) return;

    try {
      await _sb.rpc(
        'set_selection_chat_typing',
        params: {'p_chat_id': chatId, 'p_is_typing': isTyping},
      );
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'set_selection_chat_typing')) {
        rethrow;
      }
    }

    try {
      await _sb.from('selection_chat_typing_states').upsert({
        'chat_id': chatId,
        'user_id': userId,
        'is_typing': isTyping,
        'typed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'chat_id,user_id');
    } on PostgrestException catch (e) {
      final missingTable = SupabaseCompat.isMissingRelation(e, const [
        'selection_chat_typing_states',
      ]);
      if (!missingTable) rethrow;
    }
  }

  Future<void> setChatPinned({
    required String chatId,
    required bool pinned,
  }) async {
    if (chatId.trim().isEmpty) return;
    try {
      await _sb.rpc(
        'set_selection_chat_pinned',
        params: {'p_chat_id': chatId, 'p_pinned': pinned},
      );
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'set_selection_chat_pinned')) {
        rethrow;
      }
    }
  }

  Future<void> setChatArchived({
    required String chatId,
    required bool archived,
  }) async {
    if (chatId.trim().isEmpty) return;
    try {
      await _sb.rpc(
        'set_selection_chat_archived',
        params: {'p_chat_id': chatId, 'p_archived': archived},
      );
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'set_selection_chat_archived')) {
        rethrow;
      }
    }
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || messageId.trim().isEmpty) return;

    await _sb
        .from('selection_chat_messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId)
        .eq('sender_id', userId);
  }

  Future<void> setReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || messageId.trim().isEmpty) return;
    final trimmedEmoji = emoji.trim();
    if (trimmedEmoji.isEmpty) return;

    await _sb.from('selection_chat_message_reactions').upsert({
      'chat_id': chatId,
      'message_id': messageId,
      'user_id': userId,
      'emoji': trimmedEmoji,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'message_id,user_id');
  }

  Future<void> clearReaction(String messageId) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || messageId.trim().isEmpty) return;

    await _sb
        .from('selection_chat_message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }

  Future<void> hideChatForMe(String chatId) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || chatId.trim().isEmpty) return;

    try {
      await _sb.rpc(
        'hide_selection_chat_for_me',
        params: {'p_chat_id': chatId},
      );
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'hide_selection_chat_for_me')) {
        rethrow;
      }
    }

    final chat = await _sb
        .from('selection_chats')
        .select('model_user_id,agent_user_id')
        .eq('id', chatId)
        .maybeSingle();
    final modelUserId = (chat?['model_user_id'] ?? '').toString();
    final agentUserId = (chat?['agent_user_id'] ?? '').toString();
    if (userId == modelUserId) {
      await _sb
          .from('selection_chats')
          .update({
            'model_deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', chatId);
    } else if (userId == agentUserId) {
      await _sb
          .from('selection_chats')
          .update({
            'agent_deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', chatId);
    }
  }

  Future<void> hideInvitationForMe({
    required String selectionId,
    required String profileId,
  }) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null ||
        selectionId.trim().isEmpty ||
        profileId.trim().isEmpty) {
      return;
    }

    try {
      await _sb.rpc(
        'hide_my_selection_invitation',
        params: {'p_selection_id': selectionId, 'p_profile_id': profileId},
      );
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'hide_my_selection_invitation')) {
        rethrow;
      }
    }

    await _sb
        .from('selection_items')
        .update({'model_hidden_at': DateTime.now().toUtc().toIso8601String()})
        .eq('selection_id', selectionId)
        .eq('profile_id', profileId);
  }
}
