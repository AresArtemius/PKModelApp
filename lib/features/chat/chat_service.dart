import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import 'chat_models.dart';

class ChatService {
  const ChatService(this._sb);

  static const int _invitationListLimit = 100;
  static const int _messageStreamLimit = 120;
  static const int _reactionStreamLimit = _messageStreamLimit * 3;

  final SupabaseClient _sb;

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
          profile:profiles!inner(id,user_id,full_name,photo_urls)
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
          profile:profiles!inner(id,user_id,full_name,photo_urls)
        ''')
        .eq('profile.user_id', userId)
        .order('created_at', ascending: false)
        .limit(_invitationListLimit);
  }

  bool _isRlsRecursion(PostgrestException e) {
    return SupabaseCompat.isRlsRecursion(e);
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

  Future<List<ChatMessage>> fetchMessagesBefore({
    required String chatId,
    required DateTime before,
    int limit = 60,
  }) async {
    final rows = await _sb
        .from('selection_chat_messages')
        .select(
          'id,chat_id,sender_id,body,media_type,media_url,media_thumbnail_url,deleted_at,created_at',
        )
        .eq('chat_id', chatId)
        .lt('created_at', before.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
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
  }) async {
    final text = body.trim();
    final userId = _sb.auth.currentUser?.id;
    final hasMedia = mediaUrl.trim().isNotEmpty;
    if ((text.isEmpty && !hasMedia) || userId == null) return;

    await _sb.from('selection_chat_messages').insert({
      'chat_id': chatId,
      'sender_id': userId,
      'body': text.isEmpty && hasMedia
          ? (mediaType == 'video' ? 'Видео' : 'Фото')
          : text,
      'media_type': mediaType,
      'media_url': mediaUrl.trim().isEmpty ? null : mediaUrl.trim(),
      'media_thumbnail_url': mediaThumbnailUrl.trim().isEmpty
          ? null
          : mediaThumbnailUrl.trim(),
    });
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
