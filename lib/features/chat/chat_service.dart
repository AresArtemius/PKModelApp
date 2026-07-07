import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/profile_action_log_service.dart';
import '../../core/supabase_compat.dart';
import 'chat_models.dart';

class _ChatActionContext {
  const _ChatActionContext({
    required this.profileId,
    required this.modelUserId,
    required this.agentUserId,
  });

  final String profileId;
  final String modelUserId;
  final String agentUserId;
}

class _ChatContentFlags {
  const _ChatContentFlags({
    required this.hasMedia,
    required this.hasFile,
    required this.hasAudio,
    required this.hasPinned,
  });

  final bool hasMedia;
  final bool hasFile;
  final bool hasAudio;
  final bool hasPinned;

  static const empty = _ChatContentFlags(
    hasMedia: false,
    hasFile: false,
    hasAudio: false,
    hasPinned: false,
  );
}

class ChatService {
  const ChatService(this._sb);

  static const int _invitationListLimit = 100;
  static const int _messageStreamLimit = 120;
  static const int _messageSearchLimit = 80;
  static const int _reactionStreamLimit = _messageStreamLimit * 3;
  static const int _typingStreamLimit = 8;
  static const String _baseMessageSelect =
      'id,chat_id,sender_id,body,media_type,media_url,media_thumbnail_url,deleted_at,created_at';
  static const String _fileMessageFields = ',file_name,file_size,file_mime';
  static const String _metadataMessageFields = ',metadata';

  final SupabaseClient _sb;

  String _messageSelect({
    bool includeReadFields = false,
    bool includeFileFields = true,
    bool includePinnedFields = false,
    bool includeMetadata = true,
  }) {
    final readFields = includeReadFields ? ',read_at,listened_at' : '';
    final fileFields = includeFileFields ? _fileMessageFields : '';
    final pinnedFields = includePinnedFields ? ',pinned_at,pinned_by' : '';
    final metadataFields = includeMetadata ? _metadataMessageFields : '';
    return '$_baseMessageSelect$readFields$fileFields$pinnedFields$metadataFields';
  }

  Future<List<CastingInvitation>> fetchMyInvitations(String userId) async {
    try {
      final rows = await _sb.rpc('get_my_selection_invitations');
      final invitations = (rows as List<dynamic>)
          .map(
            (e) => CastingInvitation.fromRpcMap(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.selectionId.isNotEmpty && e.profileId.isNotEmpty)
          .toList(growable: false);
      return _enrichInvitationsWithAccounts(invitations);
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
            created_at,
            created_by
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

    final invitations = rows
        .map((e) => CastingInvitation.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.selectionId.isNotEmpty && e.profileId.isNotEmpty)
        .toList(growable: false);
    return _enrichInvitationsWithAccounts(invitations);
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
            created_at,
            created_by
            ${includeVideoRequest ? ',request_video_intro,video_intro_requirements' : ''}
          ),
          profile:profiles!inner(id,user_id,full_name,photo_urls,cover_photo_url)
        ''')
        .eq('profile.user_id', userId)
        .order('created_at', ascending: false)
        .limit(_invitationListLimit);
  }

  Future<List<CastingInvitation>> _enrichInvitationsWithAccounts(
    List<CastingInvitation> invitations,
  ) async {
    var enriched = invitations;
    final missingOwnerSelectionIds = enriched
        .where((e) => e.accountUserId.trim().isEmpty)
        .map((e) => e.selectionId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (missingOwnerSelectionIds.isNotEmpty) {
      try {
        final rows = await _sb
            .from('selections')
            .select('id,created_by')
            .inFilter('id', missingOwnerSelectionIds.toList(growable: false));
        final owners = <String, String>{};
        for (final raw in rows as List) {
          final map = Map<String, dynamic>.from(raw as Map);
          final id = (map['id'] ?? '').toString();
          final createdBy = (map['created_by'] ?? '').toString();
          if (id.isNotEmpty && createdBy.isNotEmpty) owners[id] = createdBy;
        }
        enriched = enriched
            .map(
              (item) => item.accountUserId.trim().isNotEmpty
                  ? item
                  : item.copyWith(accountUserId: owners[item.selectionId]),
            )
            .toList(growable: false);
      } on PostgrestException catch (e) {
        if (!_isRlsRecursion(e)) {
          enriched = invitations;
        }
      }
    }

    final missingIds = enriched
        .where((e) => e.accountName.trim().isEmpty)
        .map((e) => e.accountUserId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (missingIds.isEmpty) {
      return enriched
          .map((e) => _normalizeInvitationAccount(e))
          .toList(growable: false);
    }

    Map<String, _ChatAccountPreview> previews = const {};
    try {
      final rows = await _sb
          .from('user_profiles')
          .select('user_id,avatar_url,full_name,company_name,position')
          .inFilter('user_id', missingIds.toList(growable: false));
      final result = <String, _ChatAccountPreview>{};
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final userId = (map['user_id'] ?? '').toString();
        if (userId.isEmpty) continue;
        result[userId] = _ChatAccountPreview.fromMap(map);
      }
      previews = result;
    } on PostgrestException catch (e) {
      if (!_isRlsRecursion(e)) {
        previews = const {};
      }
    }

    return enriched
        .map((item) {
          final preview = previews[item.accountUserId.trim()];
          return _normalizeInvitationAccount(
            item.copyWith(
              accountName: item.accountName.trim().isNotEmpty
                  ? item.accountName
                  : preview?.displayName,
              accountAvatarUrl: item.accountAvatarUrl.trim().isNotEmpty
                  ? item.accountAvatarUrl
                  : preview?.avatarUrl,
            ),
          );
        })
        .toList(growable: false);
  }

  CastingInvitation _normalizeInvitationAccount(CastingInvitation item) {
    final fallbackName = item.selectionTitle.trim().isNotEmpty
        ? item.selectionTitle
        : item.profileName;
    return item.copyWith(
      accountName: item.accountName.trim().isNotEmpty
          ? item.accountName.trim()
          : fallbackName,
      accountAvatarUrl: item.accountAvatarUrl.trim().isNotEmpty
          ? item.accountAvatarUrl.trim()
          : item.photoUrl,
    );
  }

  bool _isRlsRecursion(PostgrestException e) {
    return SupabaseCompat.isRlsRecursion(e);
  }

  bool _isMissingChatFileColumn(PostgrestException e) {
    return SupabaseCompat.isMissingColumn(e, 'file_name') ||
        SupabaseCompat.isMissingColumn(e, 'file_size') ||
        SupabaseCompat.isMissingColumn(e, 'file_mime');
  }

  bool _isMissingChatPinnedColumn(PostgrestException e) {
    return SupabaseCompat.isMissingColumn(e, 'pinned_at') ||
        SupabaseCompat.isMissingColumn(e, 'pinned_by');
  }

  bool _isMissingChatMetadataColumn(PostgrestException e) {
    return SupabaseCompat.isMissingColumn(e, 'metadata');
  }

  bool _isMissingChatReadField(PostgrestException e) {
    return SupabaseCompat.isMissingColumn(e, 'read_at') ||
        SupabaseCompat.isMissingColumn(e, 'listened_at');
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

    final resolvedAgentUserId = userId == modelUserId ? agentUserId : userId;
    if (resolvedAgentUserId != null && resolvedAgentUserId.isNotEmpty) {
      final existingConversation = await _sb
          .from('selection_chats')
          .select('id')
          .eq('model_user_id', modelUserId)
          .eq('agent_user_id', resolvedAgentUserId)
          .maybeSingle();

      if (existingConversation != null) {
        final id = (existingConversation['id'] ?? '').toString();
        if (id.isNotEmpty) {
          await _updateChatContext(
            chatId: id,
            selectionId: selectionId,
            profileId: profileId,
          );
          return id;
        }
      }
    }

    final existing = await _sb
        .from('selection_chats')
        .select('id,model_user_id,agent_user_id')
        .eq('selection_id', selectionId)
        .eq('profile_id', profileId)
        .maybeSingle();

    if (existing != null) {
      final id = (existing['id'] ?? '').toString();
      if (id.isNotEmpty) {
        return _normalizeExistingSelectionChat(
          chatId: id,
          selectionId: selectionId,
          profileId: profileId,
          modelUserId: modelUserId,
          agentUserId: resolvedAgentUserId,
        );
      }
    }

    Map<String, dynamic> data;
    try {
      data = await _sb
          .from('selection_chats')
          .insert({
            'selection_id': selectionId,
            'profile_id': profileId,
            'model_user_id': modelUserId,
            'agent_user_id': resolvedAgentUserId,
          })
          .select('id')
          .single();
    } on PostgrestException catch (e) {
      if (e.code != '23505' || resolvedAgentUserId == null) rethrow;
      final row = await _sb
          .from('selection_chats')
          .select('id')
          .eq('model_user_id', modelUserId)
          .eq('agent_user_id', resolvedAgentUserId)
          .maybeSingle();
      if (row == null) rethrow;
      data = Map<String, dynamic>.from(row);
    }

    final id = (data['id'] ?? '').toString();
    if (id.isNotEmpty) {
      await _updateChatContext(
        chatId: id,
        selectionId: selectionId,
        profileId: profileId,
      );
    }
    return id;
  }

  Future<String> _normalizeExistingSelectionChat({
    required String chatId,
    required String selectionId,
    required String profileId,
    required String modelUserId,
    required String? agentUserId,
  }) async {
    if (agentUserId == null || agentUserId.isEmpty) {
      await _recordChatContext(
        chatId: chatId,
        selectionId: selectionId,
        profileId: profileId,
      );
      return chatId;
    }
    try {
      await _sb
          .from('selection_chats')
          .update({
            'model_user_id': modelUserId,
            'agent_user_id': agentUserId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'model_deleted_at': null,
            'agent_deleted_at': null,
          })
          .eq('id', chatId);
      await _recordChatContext(
        chatId: chatId,
        selectionId: selectionId,
        profileId: profileId,
      );
      return chatId;
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      final accountChat = await _sb
          .from('selection_chats')
          .select('id')
          .eq('model_user_id', modelUserId)
          .eq('agent_user_id', agentUserId)
          .maybeSingle();
      final accountChatId = (accountChat?['id'] ?? '').toString();
      if (accountChatId.isEmpty) rethrow;
      await _updateChatContext(
        chatId: accountChatId,
        selectionId: selectionId,
        profileId: profileId,
      );
      return accountChatId;
    }
  }

  Future<void> _updateChatContext({
    required String chatId,
    required String selectionId,
    required String profileId,
  }) async {
    try {
      await _sb
          .from('selection_chats')
          .update({
            'selection_id': selectionId,
            'profile_id': profileId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'model_deleted_at': null,
            'agent_deleted_at': null,
          })
          .eq('id', chatId);
    } on PostgrestException {
      // Context refresh is helpful, but the existing conversation is usable.
    }
    await _recordChatContext(
      chatId: chatId,
      selectionId: selectionId,
      profileId: profileId,
    );
  }

  Future<void> _recordChatContext({
    required String chatId,
    required String selectionId,
    required String profileId,
  }) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null ||
        chatId.trim().isEmpty ||
        selectionId.trim().isEmpty ||
        profileId.trim().isEmpty) {
      return;
    }

    try {
      await _sb.from('selection_chat_contexts').insert({
        'chat_id': chatId,
        'selection_id': selectionId,
        'profile_id': profileId,
        'created_by': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      final missingTable = SupabaseCompat.isMissingRelation(e, const [
        'selection_chat_contexts',
      ]);
      if (!missingTable && !_isRlsRecursion(e)) rethrow;
    }
  }

  Future<List<ChatContextEntry>> fetchChatContexts(String chatId) async {
    if (chatId.trim().isEmpty) return const <ChatContextEntry>[];
    try {
      final rows = await _sb
          .from('selection_chat_contexts')
          .select('''
            id,
            chat_id,
            selection_id,
            profile_id,
            created_at,
            selection:selections(title),
            profile:profiles(full_name)
          ''')
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(12);
      return (rows as List)
          .map((e) => ChatContextEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      final missingTable = SupabaseCompat.isMissingRelation(e, const [
        'selection_chat_contexts',
      ]);
      if (missingTable || _isRlsRecursion(e)) {
        return const <ChatContextEntry>[];
      }
      rethrow;
    }
  }

  Future<ChatSummary?> fetchChat({
    required String chatId,
    required String currentUserId,
  }) async {
    final row = await _sb
        .from('selection_chats')
        .select('''
          id,
          selection_id,
          profile_id,
          model_user_id,
          agent_user_id,
          selection:selections(title),
          profile:profiles(full_name,photo_urls,cover_photo_url)
        ''')
        .eq('id', chatId)
        .maybeSingle();

    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    final modelUserId = (map['model_user_id'] ?? '').toString();
    final agentUserId = (map['agent_user_id'] ?? '').toString();
    final otherUserId = currentUserId == modelUserId
        ? agentUserId
        : modelUserId;
    final accountPreviews = await _fetchAccountPreviews([map], currentUserId);
    final accountPreview = accountPreviews[otherUserId];
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
    final modelProfileName = (profile['full_name'] ?? '').toString().trim();
    final selectionTitle = (selection['title'] ?? '').toString().trim();

    return ChatSummary.fromMap(
      map,
      accountTitle: accountPreview?.displayName ?? modelProfileName,
      accountAvatarUrl:
          accountPreview?.avatarUrl ??
          _chatCoverPhoto(profile['cover_photo_url'], photoUrls),
      contextLabel: _chatContextLabel(
        profileName: modelProfileName,
        selectionTitle: selectionTitle,
      ),
    );
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

    final accountPreviews = await _fetchAccountPreviews(rows, userId);
    final byParticipant = <String, ChatListItem>{};
    final unreadByParticipant = <String, int>{};
    for (final raw in rows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final chatId = (map['id'] ?? '').toString();
      if (chatId.isEmpty) continue;

      final modelUserId = (map['model_user_id'] ?? '').toString();
      final agentUserId = (map['agent_user_id'] ?? '').toString();
      final isModel = userId == modelUserId;
      final otherUserId = isModel ? agentUserId : modelUserId;
      final participantKey = otherUserId.isEmpty ? chatId : otherUserId;
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
      final modelProfileName = (profile['full_name'] ?? '').toString().trim();
      final selectionTitle = (selection['title'] ?? '').toString().trim();
      final accountPreview = accountPreviews[otherUserId];
      final latest = await _fetchLatestMessage(chatId);
      final flags = await _fetchChatContentFlags(chatId);
      final fallbackTime = DateTime.tryParse(
        (map['updated_at'] ?? map['created_at'] ?? '').toString(),
      );
      final unreadCount = await _fetchUnreadCount(chatId, userId);
      final nextItem = ChatListItem(
        id: chatId,
        selectionTitle: accountPreview?.displayName ?? modelProfileName,
        profileName: '',
        photoUrl:
            accountPreview?.avatarUrl ??
            _chatCoverPhoto(profile['cover_photo_url'], photoUrls),
        contextLabel: _chatContextLabel(
          profileName: modelProfileName,
          selectionTitle: selectionTitle,
        ),
        participantRole: isModel
            ? ChatParticipantRole.model
            : ChatParticipantRole.client,
        lastMessage: latest == null ? '' : _chatPreview(latest),
        lastMessageMediaType: latest?.mediaType ?? 'text',
        lastMessageMetadata: latest?.metadata ?? const <String, dynamic>{},
        lastMessageListenedAt: latest?.listenedAt,
        lastMessageAt: latest?.createdAt ?? fallbackTime,
        unreadCount: unreadCount,
        pinned: pinnedAt.trim().isNotEmpty,
        archived: isArchived,
        hasMediaMessages: flags.hasMedia || (latest != null && latest.hasMedia),
        hasFileMessages: flags.hasFile || (latest != null && latest.isFile),
        hasAudioMessages: flags.hasAudio || (latest != null && latest.isAudio),
        hasPinnedMessages:
            flags.hasPinned || (latest != null && latest.isPinned),
      );

      unreadByParticipant[participantKey] =
          (unreadByParticipant[participantKey] ?? 0) + unreadCount;
      final current = byParticipant[participantKey];
      if (current == null || _chatListItemIsNewer(nextItem, current)) {
        byParticipant[participantKey] = nextItem;
      } else if (nextItem.pinned && !current.pinned) {
        byParticipant[participantKey] = nextItem;
      }
    }

    final items = byParticipant.entries
        .map((entry) {
          final item = entry.value;
          return item.copyWith(
            unreadCount: unreadByParticipant[entry.key] ?? 0,
          );
        })
        .toList(growable: false);

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

  Future<_ChatContentFlags> _fetchChatContentFlags(String chatId) async {
    try {
      final rows = await _sb
          .from('selection_chat_messages')
          .select('media_type,pinned_at')
          .eq('chat_id', chatId)
          .filter('deleted_at', 'is', null)
          .or('media_type.neq.text,pinned_at.not.is.null')
          .limit(80);
      var hasMedia = false;
      var hasFile = false;
      var hasAudio = false;
      var hasPinned = false;
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final mediaType = (map['media_type'] ?? 'text').toString();
        if (mediaType != 'text') hasMedia = true;
        if (mediaType == 'file') hasFile = true;
        if (mediaType == 'audio') hasAudio = true;
        if ((map['pinned_at'] ?? '').toString().trim().isNotEmpty) {
          hasPinned = true;
        }
      }
      return _ChatContentFlags(
        hasMedia: hasMedia,
        hasFile: hasFile,
        hasAudio: hasAudio,
        hasPinned: hasPinned,
      );
    } on PostgrestException catch (e) {
      if (_isMissingChatPinnedColumn(e)) {
        return _fetchChatMediaFlagsWithoutPinned(chatId);
      }
      return _ChatContentFlags.empty;
    }
  }

  Future<_ChatContentFlags> _fetchChatMediaFlagsWithoutPinned(
    String chatId,
  ) async {
    try {
      final rows = await _sb
          .from('selection_chat_messages')
          .select('media_type')
          .eq('chat_id', chatId)
          .filter('deleted_at', 'is', null)
          .neq('media_type', 'text')
          .limit(80);
      var hasMedia = false;
      var hasFile = false;
      var hasAudio = false;
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final mediaType = (map['media_type'] ?? 'text').toString();
        if (mediaType != 'text') hasMedia = true;
        if (mediaType == 'file') hasFile = true;
        if (mediaType == 'audio') hasAudio = true;
      }
      return _ChatContentFlags(
        hasMedia: hasMedia,
        hasFile: hasFile,
        hasAudio: hasAudio,
        hasPinned: false,
      );
    } on PostgrestException {
      return _ChatContentFlags.empty;
    }
  }

  Future<Map<String, _ChatAccountPreview>> _fetchAccountPreviews(
    List<dynamic> chatRows,
    String currentUserId,
  ) async {
    final ids = <String>{};
    for (final raw in chatRows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final modelUserId = (map['model_user_id'] ?? '').toString();
      final agentUserId = (map['agent_user_id'] ?? '').toString();
      final otherUserId = currentUserId == modelUserId
          ? agentUserId
          : modelUserId;
      if (otherUserId.isNotEmpty) ids.add(otherUserId);
    }
    if (ids.isEmpty) return const <String, _ChatAccountPreview>{};

    try {
      final rows = await _sb
          .from('user_profiles')
          .select('user_id,avatar_url,full_name,company_name,position')
          .inFilter('user_id', ids.toList(growable: false));
      final result = <String, _ChatAccountPreview>{};
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final userId = (map['user_id'] ?? '').toString();
        if (userId.isEmpty) continue;
        result[userId] = _ChatAccountPreview.fromMap(map);
      }
      return result;
    } on PostgrestException catch (e) {
      final missingProfileColumns = SupabaseCompat.isMissingAnyColumn(e, const [
        'avatar_url',
        'full_name',
        'company_name',
        'position',
      ]);
      if (!missingProfileColumns && !_isRlsRecursion(e)) {
        return const <String, _ChatAccountPreview>{};
      }
      return const <String, _ChatAccountPreview>{};
    }
  }

  String _chatContextLabel({
    required String profileName,
    required String selectionTitle,
  }) {
    final parts = <String>[
      if (profileName.trim().isNotEmpty) 'Анкета: ${profileName.trim()}',
      if (selectionTitle.trim().isNotEmpty) 'Кастинг: ${selectionTitle.trim()}',
    ];
    return parts.join(' • ');
  }

  bool _chatListItemIsNewer(ChatListItem a, ChatListItem b) {
    final aTime = a.lastMessageAt;
    final bTime = b.lastMessageAt;
    if (aTime == null && bTime == null) return false;
    if (aTime == null) return false;
    if (bTime == null) return true;
    return aTime.isAfter(bTime);
  }

  String _chatPreview(ChatMessage message) {
    if (message.isAudio) {
      final duration = message.audioDuration;
      final suffix = duration == null
          ? ''
          : ' ${_formatAudioDuration(duration)}';
      return 'Голосовое$suffix';
    }
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

  String _formatAudioDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _chatCoverPhoto(dynamic rawCover, List<String> photoUrls) {
    final cover = (rawCover ?? '').toString().trim();
    if (cover.isNotEmpty) return cover;
    return photoUrls.isEmpty ? '' : photoUrls.first;
  }

  Future<ChatMessage?> _fetchLatestMessage(String chatId) async {
    Future<List<dynamic>> run({
      required bool includeFileFields,
      required bool includeMetadata,
    }) async {
      return await _sb
          .from('selection_chat_messages')
          .select(
            _messageSelect(
              includeReadFields: true,
              includeFileFields: includeFileFields,
              includeMetadata: includeMetadata,
            ),
          )
          .eq('chat_id', chatId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(1);
    }

    List<dynamic> rows;
    try {
      rows = await run(includeFileFields: true, includeMetadata: true);
    } on PostgrestException catch (e) {
      if (_isMissingChatFileColumn(e)) {
        rows = await run(includeFileFields: false, includeMetadata: true);
      } else if (_isMissingChatMetadataColumn(e)) {
        rows = await run(includeFileFields: true, includeMetadata: false);
      } else if (_isMissingChatReadField(e)) {
        rows = await _sb
            .from('selection_chat_messages')
            .select(
              _messageSelect(
                includeReadFields: false,
                includeFileFields: true,
                includeMetadata: true,
              ),
            )
            .eq('chat_id', chatId)
            .filter('deleted_at', 'is', null)
            .order('created_at', ascending: false)
            .limit(1);
      } else {
        rethrow;
      }
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

  Future<List<ChatMessage>> searchMessages({
    required String chatId,
    required String query,
    int limit = _messageSearchLimit,
  }) async {
    final cleanChatId = chatId.trim();
    final cleanQuery = query.trim();
    if (cleanChatId.isEmpty || cleanQuery.isEmpty) {
      return const <ChatMessage>[];
    }

    try {
      final rows = await _sb.rpc(
        'search_selection_chat_messages',
        params: {
          'p_chat_id': cleanChatId,
          'p_query': cleanQuery,
          'p_limit': limit.clamp(1, _messageSearchLimit),
        },
      );
      return (rows as List<dynamic>)
          .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((e) => !e.isDeleted)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'search_selection_chat_messages')) {
        rethrow;
      }
    }

    return _searchMessagesFallback(
      chatId: cleanChatId,
      query: cleanQuery,
      limit: limit,
    );
  }

  Future<Set<String>> searchMyChatIds({
    required String query,
    int limit = 100,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const <String>{};
    Future<List<dynamic>> run({
      required bool includeFileFields,
      required bool includePinnedFields,
    }) async {
      final fileFields = includeFileFields ? ',file_name,file_mime' : '';
      final pinnedFields = includePinnedFields ? ',pinned_at' : '';
      return await _sb
          .from('selection_chat_messages')
          .select('chat_id,body,media_type$fileFields$pinnedFields')
          .filter('deleted_at', 'is', null)
          .or(_chatSearchOrFilter(cleanQuery, includeFileFields))
          .order('created_at', ascending: false)
          .limit(limit.clamp(1, 200));
    }

    List<dynamic> rows;
    try {
      rows = await run(includeFileFields: true, includePinnedFields: true);
    } on PostgrestException catch (e) {
      if (_isMissingChatFileColumn(e)) {
        rows = await run(includeFileFields: false, includePinnedFields: true);
      } else if (_isMissingChatPinnedColumn(e)) {
        rows = await run(includeFileFields: true, includePinnedFields: false);
      } else {
        rethrow;
      }
    }

    return rows
        .map((raw) => (raw as Map)['chat_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  String _chatSearchOrFilter(String query, bool includeFileFields) {
    final escaped = query
        .replaceAll(RegExp(r'[,()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll('%', r'\%')
        .replaceAll('*', r'\*');
    final parts = <String>[
      'body.ilike.%$escaped%',
      'media_type.ilike.%$escaped%',
      if (includeFileFields) 'file_name.ilike.%$escaped%',
      if (includeFileFields) 'file_mime.ilike.%$escaped%',
    ];
    return parts.join(',');
  }

  Future<List<ChatMessage>> _searchMessagesFallback({
    required String chatId,
    required String query,
    required int limit,
  }) async {
    Future<List<dynamic>> run({
      required bool includeReadFields,
      required bool includeFileFields,
      required bool includeMetadata,
    }) async {
      return await _sb
          .from('selection_chat_messages')
          .select(
            _messageSelect(
              includeReadFields: includeReadFields,
              includeFileFields: includeFileFields,
              includeMetadata: includeMetadata,
            ),
          )
          .eq('chat_id', chatId)
          .ilike('body', '%$query%')
          .filter('deleted_at', 'is', null)
          .order('created_at')
          .limit(limit.clamp(1, _messageSearchLimit));
    }

    List<dynamic> rows;
    try {
      rows = await run(
        includeReadFields: true,
        includeFileFields: true,
        includeMetadata: true,
      );
    } on PostgrestException catch (e) {
      if (_isMissingChatFileColumn(e)) {
        rows = await run(
          includeReadFields: true,
          includeFileFields: false,
          includeMetadata: true,
        );
      } else if (_isMissingChatMetadataColumn(e)) {
        rows = await run(
          includeReadFields: true,
          includeFileFields: true,
          includeMetadata: false,
        );
      } else if (_isMissingChatReadField(e)) {
        rows = await run(
          includeReadFields: false,
          includeFileFields: true,
          includeMetadata: true,
        );
      } else {
        rethrow;
      }
    }

    return rows
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => !e.isDeleted)
        .toList(growable: false);
  }

  Future<List<ChatMessage>> fetchMessagesBefore({
    required String chatId,
    required DateTime before,
    int limit = 60,
  }) async {
    Future<List<dynamic>> run({
      required bool includeReadFields,
      required bool includeMetadata,
    }) async {
      return await _sb
          .from('selection_chat_messages')
          .select(
            _messageSelect(
              includeReadFields: includeReadFields,
              includeMetadata: includeMetadata,
            ),
          )
          .eq('chat_id', chatId)
          .lt('created_at', before.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
    }

    List<dynamic> rows;
    try {
      rows = await run(includeReadFields: true, includeMetadata: true);
    } on PostgrestException catch (e) {
      if (_isMissingChatFileColumn(e)) {
        rows = await _sb
            .from('selection_chat_messages')
            .select(
              _messageSelect(
                includeReadFields: true,
                includeFileFields: false,
                includeMetadata: true,
              ),
            )
            .eq('chat_id', chatId)
            .lt('created_at', before.toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(limit);
      } else if (_isMissingChatMetadataColumn(e)) {
        rows = await run(includeReadFields: true, includeMetadata: false);
      } else if (_isMissingChatPinnedColumn(e)) {
        rows = await run(includeReadFields: true, includeMetadata: true);
      } else if (!_isMissingChatReadField(e)) {
        rethrow;
      } else {
        rows = await run(includeReadFields: false, includeMetadata: true);
      }
    }

    return rows
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => !e.isDeleted)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Future<List<ChatMessage>> fetchPinnedMessages(String chatId) async {
    if (chatId.trim().isEmpty) return const <ChatMessage>[];

    Future<List<dynamic>> run({
      required bool includePinnedFields,
      required bool includeMetadata,
    }) async {
      return await _sb
          .from('selection_chat_messages')
          .select(
            _messageSelect(
              includeReadFields: true,
              includePinnedFields: includePinnedFields,
              includeMetadata: includeMetadata,
            ),
          )
          .eq('chat_id', chatId)
          .filter('deleted_at', 'is', null)
          .filter('pinned_at', 'not.is', null)
          .order('pinned_at', ascending: false)
          .limit(5);
    }

    try {
      final rows = await run(includePinnedFields: true, includeMetadata: true);
      return rows
          .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((e) => !e.isDeleted && e.isPinned)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (_isMissingChatPinnedColumn(e)) return const <ChatMessage>[];
      if (_isMissingChatReadField(e)) {
        final rows = await _sb
            .from('selection_chat_messages')
            .select(
              _messageSelect(
                includeReadFields: false,
                includePinnedFields: true,
                includeMetadata: true,
              ),
            )
            .eq('chat_id', chatId)
            .filter('deleted_at', 'is', null)
            .filter('pinned_at', 'not.is', null)
            .order('pinned_at', ascending: false)
            .limit(5);
        return rows
            .map(
              (e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .where((e) => !e.isDeleted && e.isPinned)
            .toList(growable: false);
      }
      if (_isMissingChatMetadataColumn(e)) {
        final rows = await run(
          includePinnedFields: true,
          includeMetadata: false,
        );
        return rows
            .map(
              (e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .where((e) => !e.isDeleted && e.isPinned)
            .toList(growable: false);
      }
      rethrow;
    }
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

  Future<void> markVoiceMessageListened(ChatMessage message) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null ||
        message.id.trim().isEmpty ||
        message.chatId.trim().isEmpty ||
        !message.isAudio ||
        message.senderId == userId ||
        message.listenedAt != null) {
      return;
    }

    try {
      await _sb.rpc(
        'mark_selection_chat_audio_listened',
        params: {'p_message_id': message.id},
      );
      return;
    } on PostgrestException catch (e) {
      final missingSupport =
          SupabaseCompat.isMissingRpc(
            e,
            'mark_selection_chat_audio_listened',
          ) ||
          SupabaseCompat.isMissingColumn(e, 'listened_at');
      if (!missingSupport) rethrow;
    }

    try {
      await _sb
          .from('selection_chat_messages')
          .update({'listened_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', message.id)
          .eq('chat_id', message.chatId)
          .neq('sender_id', userId)
          .eq('media_type', 'audio')
          .filter('deleted_at', 'is', null)
          .filter('listened_at', 'is', null);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingColumn(e, 'listened_at')) rethrow;
    }
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
    Map<String, dynamic>? metadata,
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
                : mediaType == 'audio'
                ? 'Голосовое сообщение'
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
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    Map<String, dynamic>? inserted;
    try {
      final row = await _sb
          .from('selection_chat_messages')
          .insert(payload)
          .select('id,read_at')
          .single();
      inserted = Map<String, dynamic>.from(row);
    } on PostgrestException catch (e) {
      if (_isMissingChatFileColumn(e) && mediaType != 'file') {
        payload
          ..remove('file_name')
          ..remove('file_size')
          ..remove('file_mime');
        final row = await _sb
            .from('selection_chat_messages')
            .insert(payload)
            .select('id,read_at')
            .single();
        inserted = Map<String, dynamic>.from(row);
      } else if (SupabaseCompat.isMissingColumn(e, 'read_at')) {
        final row = await _sb
            .from('selection_chat_messages')
            .insert(payload)
            .select('id')
            .single();
        inserted = Map<String, dynamic>.from(row);
      } else if (_isMissingChatMetadataColumn(e)) {
        payload.remove('metadata');
        final row = await _sb
            .from('selection_chat_messages')
            .insert(payload)
            .select('id,read_at')
            .single();
        inserted = Map<String, dynamic>.from(row);
      } else {
        rethrow;
      }
    }

    await _logMessageProfileAction(
      chatId: chatId,
      messageId: (inserted['id'] ?? '').toString(),
      body: payload['body']?.toString() ?? text,
      mediaType: mediaType,
      userId: userId,
      readAt: DateTime.tryParse((inserted['read_at'] ?? '').toString()),
    );
  }

  Future<void> forwardMessages({
    required String targetChatId,
    required List<ChatMessage> messages,
  }) async {
    final cleanTargetChatId = targetChatId.trim();
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || cleanTargetChatId.isEmpty || messages.isEmpty) {
      return;
    }

    final ordered =
        messages
            .where(
              (message) => !message.isDeleted && message.id.trim().isNotEmpty,
            )
            .toList(growable: false)
          ..sort((a, b) {
            final aTime = a.createdAt;
            final bTime = b.createdAt;
            if (aTime == null && bTime == null) return a.id.compareTo(b.id);
            if (aTime == null) return -1;
            if (bTime == null) return 1;
            return aTime.compareTo(bTime);
          });

    for (final message in ordered) {
      final metadata = Map<String, dynamic>.from(message.metadata);
      metadata['forwarded'] = true;
      metadata['forwarded_from_message_id'] = message.id;
      metadata['forwarded_from_chat_id'] = message.chatId;

      await sendMessage(
        chatId: cleanTargetChatId,
        body: _forwardedBody(message.body),
        mediaType: message.mediaType,
        mediaUrl: message.mediaUrl,
        mediaThumbnailUrl: message.mediaThumbnailUrl,
        fileName: message.fileName,
        fileSize: message.fileSize,
        fileMime: message.fileMime,
        metadata: metadata,
      );
    }
  }

  String _forwardedBody(String body) {
    final text = body.trim();
    return text.isEmpty ? 'Переслано' : text;
  }

  Future<void> _logMessageProfileAction({
    required String chatId,
    required String messageId,
    required String body,
    required String mediaType,
    required String userId,
    DateTime? readAt,
  }) async {
    try {
      final context = await _loadChatActionContext(chatId);
      if (context == null || context.profileId.isEmpty) return;
      final targetUserId = userId == context.modelUserId
          ? context.agentUserId
          : context.modelUserId;
      final title = body.trim().isNotEmpty
          ? body.trim()
          : switch (mediaType.trim()) {
              'video' => 'Видео',
              'file' => 'Файл',
              'audio' => 'Голосовое сообщение',
              'image' => 'Фото',
              _ => 'Сообщение',
            };
      await ProfileActionLogService(_sb).log(
        profileId: context.profileId,
        targetUserId: targetUserId,
        actionType: 'message',
        title: title,
        description: userId == context.modelUserId ? 'incoming' : 'outgoing',
        status: readAt == null ? 'sent' : 'read',
        relatedTable: 'selection_chat_messages',
        relatedId: messageId,
        relatedText: chatId,
        readAt: readAt,
        metadata: {'chat_id': chatId, 'media_type': mediaType},
      );
    } on PostgrestException {
      // Audit logging is best-effort and must not break sending messages.
    }
  }

  Future<_ChatActionContext?> _loadChatActionContext(String chatId) async {
    final id = chatId.trim();
    if (id.isEmpty) return null;
    try {
      final row = await _sb
          .from('selection_chats')
          .select('profile_id,model_user_id,agent_user_id')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _ChatActionContext(
        profileId: (row['profile_id'] ?? '').toString().trim(),
        modelUserId: (row['model_user_id'] ?? '').toString().trim(),
        agentUserId: (row['agent_user_id'] ?? '').toString().trim(),
      );
    } on PostgrestException catch (e) {
      if (_isRlsRecursion(e)) return null;
      rethrow;
    }
  }

  Future<void> markChatRead(String chatId) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || chatId.trim().isEmpty) return;

    try {
      await _sb.rpc('mark_selection_chat_read', params: {'p_chat_id': chatId});
      await _markChatActionLogsRead(chatId);
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
      await _markChatActionLogsRead(chatId);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingColumn(e, 'read_at')) rethrow;
    }
  }

  Future<void> _markChatActionLogsRead(String chatId) async {
    try {
      final now = DateTime.now();
      await _sb
          .from('profile_action_logs')
          .update({'status': 'read', 'read_at': now.toUtc().toIso8601String()})
          .eq('related_table', 'selection_chat_messages')
          .eq('related_text', chatId)
          .neq('actor_user_id', _sb.auth.currentUser?.id ?? '');
    } on PostgrestException {
      // Audit read-state sync is best-effort.
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

  Future<void> setMessagePinned({
    required String messageId,
    required bool pinned,
  }) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || messageId.trim().isEmpty) return;

    try {
      await _sb.rpc(
        'set_selection_chat_message_pinned',
        params: {'p_message_id': messageId, 'p_pinned': pinned},
      );
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(
        e,
        'set_selection_chat_message_pinned',
      )) {
        rethrow;
      }
    }

    try {
      await _sb
          .from('selection_chat_messages')
          .update({
            'pinned_at': pinned
                ? DateTime.now().toUtc().toIso8601String()
                : null,
            'pinned_by': pinned ? userId : null,
          })
          .eq('id', messageId);
    } on PostgrestException catch (e) {
      if (!_isMissingChatPinnedColumn(e)) rethrow;
    }
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    await deleteMessagesForEveryone([messageId]);
  }

  Future<void> deleteMessagesForEveryone(Iterable<String> messageIds) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return;
    final ids = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return;

    await _sb
        .from('selection_chat_messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
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

class _ChatAccountPreview {
  const _ChatAccountPreview({
    required this.displayName,
    required this.avatarUrl,
  });

  final String displayName;
  final String avatarUrl;

  factory _ChatAccountPreview.fromMap(Map<String, dynamic> map) {
    final companyName = (map['company_name'] ?? '').toString().trim();
    final fullName = (map['full_name'] ?? '').toString().trim();
    final position = (map['position'] ?? '').toString().trim();
    final title = companyName.isNotEmpty
        ? companyName
        : fullName.isNotEmpty
        ? fullName
        : position.isNotEmpty
        ? position
        : 'Аккаунт';

    return _ChatAccountPreview(
      displayName: title,
      avatarUrl: (map['avatar_url'] ?? '').toString().trim(),
    );
  }
}
