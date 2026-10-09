import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/app_error_mapper.dart';
import '../../core/content_safety_filter.dart';
import '../../core/auth_providers.dart';
import '../../core/entitlements_provider.dart';
import '../../core/protected_media_url.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'chat_context_panel.dart';
import 'chat_models.dart';
import 'chat_providers.dart';
import 'chat_web_input_stub.dart'
    if (dart.library.html) 'chat_web_input_web.dart';

part 'attachments_panel.dart';
part 'chat_header.dart';
part 'chat_thread.dart';
part 'composer.dart';
part 'message_bubble.dart';

const _chatMediaBucket = 'chat-media';
const _legacyChatMediaBucket = 'profile-media';
const _chatRealtimeMessageLimit = 120;
const _replyPrefix = '↩ ';
const _replySeparator = '\n\n';

/// Step 34: files above this size are refused before the upload starts
/// (the chat-media bucket does not take larger ones).
const int _maxChatFileBytes = 50 * 1024 * 1024;
const _replyToIdKey = 'reply_to_id';
const _replyToSenderKey = 'reply_to_sender';

Uint8List? _buildChatImageThumbnail(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) return null;
  final thumb = image_lib.copyResize(decoded, width: 640);
  return Uint8List.fromList(image_lib.encodeJpg(thumb, quality: 72));
}

String _pluralFilesRu(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'файл'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)
      ? 'файла'
      : 'файлов';
  return '$n $word';
}

String _formatFileSize(int? bytes) {
  final value = bytes ?? 0;
  if (value <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = value.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  final text = unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

String _formatVoiceDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.chatId,
    this.embedded = false,
    this.onClose,
  });

  final String chatId;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _composerFocus = FocusNode(debugLabel: 'chat-composer');
  bool _inlineVoice = false;
  bool _dragging = false;
  void Function()? _disposeWebInput;
  final _searchController = TextEditingController();
  final _messageListController = ScrollController();
  bool _sending = false;
  bool _uploadingMedia = false;
  bool _loadingOlderMessages = false;
  bool _hasOlderMessages = true;
  ChatMessage? _replyingTo;

  /// Message being edited in the composer (Telegram-style: the text goes
  /// into the main input, Enter / send saves, ✕ or Esc cancels).
  ChatMessage? _editingMessage;

  bool _feedSeeded = false;
  final Set<String> _seenMessageIds = <String>{};
  bool _showScrollDown = false;

  /// Step 29: the context panel on wide screens; the choice survives
  /// switching between conversations within the session.
  static bool _contextPanelPreferred = true;
  bool _contextPanelOpen = _contextPanelPreferred;
  int _newWhileScrolled = 0;

  /// Optimistic outgoing messages shown until the realtime stream carries
  /// the stored row (temp id → stored id in [_pendingSentIds]).
  final List<ChatMessage> _pendingMessages = <ChatMessage>[];
  final Map<String, String> _pendingSentIds = <String, String>{};
  final Set<String> _selectedMessageIds = <String>{};
  bool _searchOpen = false;
  String _searchQuery = '';
  int _searchHitCursor = 0;
  String? _activeSearchMessageId;
  _PendingChatAttachment? _pendingAttachment;

  /// Step 34: further files dropped or pasted together with the pending
  /// one; sent one after another right after it.
  final List<_PendingChatAttachment> _queuedAttachments =
      <_PendingChatAttachment>[];
  DateTime? _lastTypingSentAt;
  Timer? _typingStopTimer;
  Timer? _searchDebounceTimer;
  final List<ChatMessage> _olderMessages = [];

  /// Step 31: bubble keys so a reply quote can scroll to its original.
  final Map<String, GlobalKey> _bubbleKeys = <String, GlobalKey>{};
  List<ChatMessage> _serverSearchResults = const <ChatMessage>[];
  String? _mentionQuery;
  final _picker = ImagePicker();
  bool _serverSearchLoading = false;
  String _serverSearchQuery = '';
  String _serverSearchError = '';

  SupabaseClient get _sb => ref.read(supabaseProvider);

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId) return;
    unawaited(_setTyping(false));
    _olderMessages.clear();
    _bubbleKeys.clear();
    _hasOlderMessages = true;
    _loadingOlderMessages = false;
    _replyingTo = null;
    _selectedMessageIds.clear();
    _searchOpen = false;
    _searchQuery = '';
    _searchHitCursor = 0;
    _activeSearchMessageId = null;
    _serverSearchResults = const <ChatMessage>[];
    _serverSearchLoading = false;
    _serverSearchQuery = '';
    _serverSearchError = '';
    _mentionQuery = null;
    _searchController.clear();
    _pendingAttachment = null;
    _queuedAttachments.clear();
    _lastTypingSentAt = null;
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageInputChanged);
    _messageListController.addListener(_handleFeedScroll);
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    if (kIsWeb) {
      _disposeWebInput = ChatWebInput.install(
        onFile: _attachWebFile,
        onDragState: (dragging) {
          if (!mounted || _dragging == dragging) return;
          setState(() => _dragging = dragging);
        },
      );
    }
  }

  void _handleFeedScroll() {
    if (!_messageListController.hasClients) return;
    // Reversed list: offset 0 is the newest message.
    final away = _messageListController.offset > 240;
    if (away != _showScrollDown) {
      setState(() {
        _showScrollDown = away;
        if (!away) _newWhileScrolled = 0;
      });
    }
  }

  /// Counts incoming messages that arrive while the user is scrolled up.
  void _trackNewWhileScrolled(List<ChatMessage> items, String userId) {
    if (!_feedSeeded || !_showScrollDown) return;
    var added = 0;
    for (final m in items) {
      if (m.senderId != userId && !_seenMessageIds.contains(m.id)) added++;
    }
    if (added > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _newWhileScrolled += added);
      });
    }
  }

  /// Enter sends a pending attachment even when the text field is not
  /// focused (a pasted or dropped file leaves focus on the page).
  bool _handleGlobalKey(KeyEvent event) {
    if (!kIsWeb || !mounted) return false;
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _searchOpen && !_inlineVoice) {
      _toggleSearch();
      return true;
    }
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return false;
    if (_composerFocus.hasFocus || _inlineVoice) return false;
    if (_pendingAttachment == null || _sending || _uploadingMedia) return false;
    unawaited(_send());
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _disposeWebInput?.call();
    _composerFocus.dispose();
    _typingStopTimer?.cancel();
    _searchDebounceTimer?.cancel();
    unawaited(_setTyping(false));
    _messageController.removeListener(_handleMessageInputChanged);
    _messageController.dispose();
    _searchController.dispose();
    _messageListController.dispose();
    super.dispose();
  }

  void _handleMessageInputChanged() {
    _updateMentionQuery();
    _handleTypingChanged();
  }

  void _updateMentionQuery() {
    final nextQuery = _currentMentionQuery();
    if (nextQuery == _mentionQuery) return;
    if (!mounted) return;
    setState(() => _mentionQuery = nextQuery);
  }

  String? _currentMentionQuery() {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 1 || cursor > text.length) return null;
    final prefix = text.substring(0, cursor);
    final match = RegExp(
      r'(^|[\s(])@([a-zA-Z0-9._-]{0,32})$',
    ).firstMatch(prefix);
    return match?.group(2)?.toLowerCase();
  }

  void _insertMention(ChatMentionTarget target) {
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) return;
    final text = _messageController.text;
    final prefix = text.substring(0, cursor);
    final match = RegExp(
      r'(^|[\s(])@([a-zA-Z0-9._-]{0,32})$',
    ).firstMatch(prefix);
    if (match == null) return;
    final start = match.start + (match.group(1)?.length ?? 0);
    final replacement = '${target.handle} ';
    final nextText = text.replaceRange(start, cursor, replacement);
    final nextCursor = start + replacement.length;
    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    setState(() => _mentionQuery = null);
  }

  void _handleTypingChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    _typingStopTimer?.cancel();
    if (!hasText) {
      unawaited(_setTyping(false));
      return;
    }

    final now = DateTime.now();
    final last = _lastTypingSentAt;
    if (last == null || now.difference(last).inMilliseconds > 1500) {
      _lastTypingSentAt = now;
      unawaited(_setTyping(true));
    }
    _typingStopTimer = Timer(const Duration(milliseconds: 2500), () {
      unawaited(_setTyping(false));
    });
  }

  Future<void> _setTyping(bool isTyping) async {
    try {
      await ref
          .read(chatServiceProvider)
          .setTyping(chatId: widget.chatId, isTyping: isTyping);
    } catch (_) {
      // Typing is a soft realtime hint. If SQL is not applied yet, ignore it.
    }
  }

  bool _markReadInFlight = false;

  Future<void> _markRead() async {
    if (_markReadInFlight || !mounted) return;
    _markReadInFlight = true;
    try {
      await ref.read(chatServiceProvider).markChatRead(widget.chatId);
    } catch (_) {
      // Read receipts are best effort while older SQL is still possible.
    } finally {
      _markReadInFlight = false;
    }
  }

  Future<void> _markVoiceListened(ChatMessage message) async {
    try {
      await ref.read(chatServiceProvider).markVoiceMessageListened(message);
    } catch (_) {
      // Voice listens are best effort while older SQL is still possible.
    }
  }

  Future<void> _send() async {
    if (_sending || _uploadingMedia) return;
    if (_editingMessage != null) {
      await _saveEdit();
      return;
    }
    if (!await _ensureCanUseChat()) return;
    final text = _messageController.text.trim();
    final attachment = _pendingAttachment;
    if (text.isEmpty && attachment == null) return;
    final body = text.isEmpty ? '' : _composeOutgoingBody(text);
    final contentIssue = ContentSafetyFilter.firstIssue({
      _isRussian ? 'сообщение' : 'message': text,
    });
    if (contentIssue != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ContentSafetyFilter.message(
              isRussian: _isRussian,
              fieldLabel: contentIssue.fieldLabel,
            ),
          ),
        ),
      );
      return;
    }

    if (attachment == null) {
      await _sendTextOptimistic(body: body, rawText: text);
      return;
    }

    setState(() => _sending = true);
    try {
      await _sendAttachment(attachment: attachment, body: body);
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _replyingTo = null;
        _pendingAttachment = null;
        _mentionQuery = null;
      });
      // The rest of a multi-file drop goes out as separate messages.
      while (_queuedAttachments.isNotEmpty) {
        final next = _queuedAttachments.first;
        setState(() {
          _queuedAttachments.removeAt(0);
          _pendingAttachment = next;
        });
        await _sendAttachment(attachment: next, body: '');
        if (!mounted) return;
        setState(() => _pendingAttachment = null);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Step 34: refuses a file above the upload limit with a visible reason.
  bool _rejectIfTooLarge(int? size, {String name = ''}) {
    if (size == null || size <= _maxChatFileBytes) return false;
    if (!mounted) return true;
    final limit = _formatFileSize(_maxChatFileBytes);
    final label = name.trim().isEmpty ? '' : '«${name.trim()}» ';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isRussian
              ? 'Файл $label' 'больше $limit — отправить не получится.'
              : 'File $label' 'is larger than $limit and cannot be sent.',
        ),
      ),
    );
    return true;
  }

  /// Telegram-style send: the composer clears at once, the message shows
  /// with a clock until the server confirms it; on failure the text comes
  /// back into the composer.
  Future<void> _sendTextOptimistic({
    required String body,
    required String rawText,
  }) async {
    final userId = ref.read(currentUserIdProvider) ?? '';
    final pending = ChatMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      chatId: widget.chatId,
      senderId: userId,
      body: body,
      mediaType: 'text',
      mediaUrl: '',
      mediaThumbnailUrl: '',
      fileName: '',
      fileSize: null,
      fileMime: '',
      metadata: const <String, dynamic>{'pending': true},
      deletedAt: null,
      readAt: null,
      listenedAt: null,
      pinnedAt: null,
      pinnedBy: '',
      editedAt: null,
      createdAt: DateTime.now().toUtc(),
    );
    final restoreReply = _replyingTo;
    final replyMetadata = _replyMetadata(restoreReply);
    setState(() {
      _pendingMessages.add(pending);
      _replyingTo = null;
      _mentionQuery = null;
      _messageController.clear();
    });
    _scrollFeedToBottom();
    try {
      final storedId = await ref
          .read(chatServiceProvider)
          .sendMessage(
            chatId: widget.chatId,
            body: body,
            metadata: replyMetadata,
          );
      if (!mounted) return;
      if (storedId == null || storedId.isEmpty) {
        setState(() => _pendingMessages.remove(pending));
        return;
      }
      _pendingSentIds[pending.id] = storedId;
      // The stream normally carries the row within a moment; make sure the
      // placeholder never outlives it by much even if the event is missed.
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (!mounted) return;
        if (_pendingMessages.any((m) => m.id == pending.id)) {
          setState(() => _pendingMessages.remove(pending));
          ref.invalidate(chatMessagesProvider(widget.chatId));
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingMessages.remove(pending);
        _replyingTo = restoreReply;
        _messageController.value = TextEditingValue(
          text: rawText,
          selection: TextSelection.collapsed(offset: rawText.length),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    }
  }

  void _toggleContextPanel() {
    setState(() {
      _contextPanelOpen = !_contextPanelOpen;
      _contextPanelPreferred = _contextPanelOpen;
    });
  }

  void _scrollFeedToBottom() {
    if (!_messageListController.hasClients) return;
    if (_newWhileScrolled != 0) setState(() => _newWhileScrolled = 0);
    // The feed is a reversed list: offset 0 is the newest message.
    _messageListController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  String _composeOutgoingBody(String text) {
    final reply = _replyingTo;
    if (reply == null) return text;
    final quote = _replyPreviewText(reply);
    if (quote.isEmpty) return text;
    return '$_replyPrefix$quote$_replySeparator$text';
  }

  /// Step 31: the reply link travels in `metadata` (`reply_to_id`), so a
  /// click on the quote can jump to the original; the text prefix stays
  /// for older clients.
  Map<String, dynamic>? _replyMetadata(ChatMessage? reply) {
    if (reply == null) return null;
    if (reply.id.startsWith('pending-')) return null;
    return <String, dynamic>{
      _replyToIdKey: reply.id,
      _replyToSenderKey: reply.senderId,
    };
  }

  String _replyPreviewText(ChatMessage message) {
    final parsed = _ParsedMessageBody.from(message.body);
    final source = parsed.body.trim().isNotEmpty
        ? parsed.body.trim()
        : message.isVideo
        ? (_isRussian ? 'Видео' : 'Video')
        : message.isImage
        ? (_isRussian ? 'Фото' : 'Photo')
        : message.isFile
        ? (message.fileDisplayName.isEmpty
              ? (_isRussian ? 'Файл' : 'File')
              : message.fileDisplayName)
        : message.isAudio
        ? (_isRussian ? 'Голосовое сообщение' : 'Voice message')
        : '';
    final compact = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 90) return compact;
    return '${compact.substring(0, 90)}...';
  }

  String _messageSearchText(ChatMessage message) {
    final parsed = _ParsedMessageBody.from(message.body);
    final parts = <String>[
      parsed.replyQuote,
      parsed.body,
      if (message.isImage) _isRussian ? 'фото изображение' : 'photo image',
      if (message.isVideo) _isRussian ? 'видео' : 'video',
      if (message.isFile) message.fileDisplayName,
      if (message.isAudio) _isRussian ? 'голосовое аудио' : 'voice audio',
    ];
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<ChatMessage> _searchHits(List<ChatMessage> messages) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const <ChatMessage>[];
    if (_serverSearchQuery.toLowerCase() == query &&
        !_serverSearchLoading &&
        _serverSearchError.isEmpty) {
      return _serverSearchResults;
    }
    return messages
        .where(
          (message) =>
              _messageSearchText(message).toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchQuery = '';
        _searchHitCursor = 0;
        _activeSearchMessageId = null;
        _serverSearchResults = const <ChatMessage>[];
        _serverSearchLoading = false;
        _serverSearchQuery = '';
        _serverSearchError = '';
        _searchController.clear();
        _searchDebounceTimer?.cancel();
      }
    });
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _searchHitCursor = 0;
      _activeSearchMessageId = null;
    });
    _scheduleServerSearch(value);
  }

  void _scheduleServerSearch(String value) {
    _searchDebounceTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _serverSearchResults = const <ChatMessage>[];
        _serverSearchLoading = false;
        _serverSearchQuery = '';
        _serverSearchError = '';
      });
      return;
    }
    setState(() {
      _serverSearchLoading = true;
      _serverSearchError = '';
    });
    _searchDebounceTimer = Timer(const Duration(milliseconds: 320), () {
      unawaited(_runServerSearch(query));
    });
  }

  Future<void> _runServerSearch(String query) async {
    try {
      final results = await ref
          .read(chatServiceProvider)
          .searchMessages(chatId: widget.chatId, query: query);
      if (!mounted || _searchQuery.trim() != query) return;
      setState(() {
        _serverSearchResults = results;
        _serverSearchQuery = query;
        _serverSearchLoading = false;
        _serverSearchError = '';
        if (_searchHitCursor >= results.length) _searchHitCursor = 0;
      });
    } catch (error) {
      if (!mounted || _searchQuery.trim() != query) return;
      setState(() {
        _serverSearchResults = const <ChatMessage>[];
        _serverSearchQuery = query;
        _serverSearchLoading = false;
        _serverSearchError = AppErrorMapper.message(
          error,
          AppLocalizations.of(context)!,
        );
      });
    }
  }

  Future<void> _jumpToSearchHit(
    List<ChatMessage> visibleMessages,
    List<ChatMessage> hits, {
    required int direction,
  }) async {
    if (hits.isEmpty) return;
    final nextCursor = direction == 0
        ? _searchHitCursor.clamp(0, hits.length - 1).toInt()
        : (_searchHitCursor + direction) % hits.length;
    final safeCursor = nextCursor < 0 ? hits.length - 1 : nextCursor;
    final target = hits[safeCursor];
    final effectiveMessages = _ensureMessageVisible(target, visibleMessages);
    await _jumpToSearchTarget(
      target: target,
      visibleMessages: effectiveMessages,
      cursor: safeCursor,
    );
  }

  List<ChatMessage> _ensureMessageVisible(
    ChatMessage target,
    List<ChatMessage> visibleMessages,
  ) {
    if (visibleMessages.any((item) => item.id == target.id)) {
      return visibleMessages;
    }
    setState(() {
      _olderMessages.removeWhere((item) => item.id == target.id);
      _olderMessages.add(target);
    });
    return _mergedMessages(
      ref.read(chatMessagesProvider(widget.chatId)).valueOrNull ??
          const <ChatMessage>[],
    );
  }

  Future<void> _jumpToSearchTarget({
    required ChatMessage target,
    required List<ChatMessage> visibleMessages,
    required int cursor,
  }) async {
    final targetIndex = visibleMessages.indexWhere(
      (item) => item.id == target.id,
    );
    if (targetIndex == -1) return;
    final reverseBuilderIndex = visibleMessages.length - 1 - targetIndex;
    const estimatedMessageExtent = 96.0;
    final targetOffset = reverseBuilderIndex * estimatedMessageExtent;
    setState(() {
      _searchHitCursor = cursor;
      _activeSearchMessageId = target.id;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!_messageListController.hasClients) return;
    final clampedOffset = targetOffset
        .clamp(0.0, _messageListController.position.maxScrollExtent)
        .toDouble();
    await _messageListController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _jumpToMessage(
    String messageId,
    List<ChatMessage> visibleMessages,
  ) async {
    final targetIndex = visibleMessages.indexWhere(
      (item) => item.id == messageId,
    );
    if (targetIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian
                ? 'Сообщение выше в истории. Загрузите старые сообщения.'
                : 'This message is earlier in history. Load older messages.',
          ),
        ),
      );
      return;
    }
    final reverseBuilderIndex = visibleMessages.length - 1 - targetIndex;
    const estimatedMessageExtent = 96.0;
    final targetOffset = reverseBuilderIndex * estimatedMessageExtent;
    setState(() => _activeSearchMessageId = messageId);
    if (!_messageListController.hasClients) return;
    final clampedOffset = targetOffset
        .clamp(0.0, _messageListController.position.maxScrollExtent)
        .toDouble();
    await _messageListController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    // The estimate above lands near the bubble; once it is built, settle
    // on it exactly.
    await WidgetsBinding.instance.endOfFrame;
    final bubbleContext = _bubbleKeys[messageId]?.currentContext;
    if (bubbleContext != null && bubbleContext.mounted) {
      await Scrollable.ensureVisible(
        bubbleContext,
        alignment: 0.4,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// Step 31: a click on a reply quote scrolls to the original message,
  /// loading older history when it is outside the loaded window.
  Future<void> _jumpToReply(String messageId) async {
    List<ChatMessage> visible() => _mergedMessages(
      ref.read(chatMessagesProvider(widget.chatId)).valueOrNull ??
          const <ChatMessage>[],
    );
    bool found(List<ChatMessage> items) =>
        items.any((item) => item.id == messageId);

    var items = visible();
    var pages = 0;
    while (!found(items) && _hasOlderMessages && pages < 4) {
      await _loadOlderMessages(items);
      if (!mounted) return;
      pages++;
      items = visible();
    }
    if (!found(items)) {
      ChatMessage? original;
      try {
        original = await ref
            .read(chatServiceProvider)
            .fetchMessageById(chatId: widget.chatId, messageId: messageId);
      } catch (_) {
        original = null;
      }
      if (!mounted) return;
      if (original == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isRussian
                  ? 'Исходное сообщение удалено или недоступно.'
                  : 'The original message was deleted or is unavailable.',
            ),
          ),
        );
        return;
      }
      items = _ensureMessageVisible(original, items);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    await _jumpToMessage(messageId, items);
    // The highlight is a pointer, not a state: let it fade.
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted || _searchOpen) return;
      if (_activeSearchMessageId == messageId) {
        setState(() => _activeSearchMessageId = null);
      }
    });
  }

  List<ChatMessage> _pinnedMessagesForPanel(
    List<ChatMessage> fetched,
    List<ChatMessage> visible,
  ) {
    final byId = <String, ChatMessage>{};
    for (final message in fetched) {
      if (message.isPinned && !message.isDeleted) byId[message.id] = message;
    }
    for (final message in visible) {
      if (message.isPinned && !message.isDeleted) byId[message.id] = message;
    }
    final result = byId.values.toList(growable: false);
    result.sort((a, b) {
      final aTime = a.pinnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.pinnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return result;
  }

  Future<void> _setMessagePinned(ChatMessage message, bool pinned) async {
    try {
      await ref
          .read(chatServiceProvider)
          .setMessagePinned(messageId: message.id, pinned: pinned);
      ref.invalidate(pinnedChatMessagesProvider(widget.chatId));
      ref.invalidate(chatMessagesProvider(widget.chatId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    }
  }

  ChatMessage? _singleSelectedMessage(List<ChatMessage> visibleMessages) {
    final selected = _selectedMessages(visibleMessages);
    if (selected.length != 1) return null;
    return selected.first;
  }

  List<ChatMessage> _selectedMessages(List<ChatMessage> visibleMessages) {
    final selected = <ChatMessage>[];
    for (final message in visibleMessages) {
      if (_selectedMessageIds.contains(message.id)) selected.add(message);
    }
    selected.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return a.id.compareTo(b.id);
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      return aTime.compareTo(bTime);
    });
    return selected;
  }

  void _replyToSelectedMessage(ChatMessage message) {
    setState(() {
      _replyingTo = message;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _toggleSelectedMessagePinned(ChatMessage message) async {
    await _setMessagePinned(message, !message.isPinned);
    if (!mounted) return;
    _clearMessageSelection();
  }

  Future<void> _forwardSelectedMessages(List<ChatMessage> messages) async {
    final cleanMessages = messages
        .where((message) => !message.isDeleted && message.id.trim().isNotEmpty)
        .toList(growable: false);
    if (cleanMessages.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    List<ChatListItem> chats;
    try {
      chats = await ref
          .read(chatServiceProvider)
          .fetchMyChats(userId: userId, archived: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
      return;
    }

    // The current chat is a valid target too (forward "to myself" here),
    // listed first.
    final targets = [
      ...chats.where((chat) => chat.id == widget.chatId),
      ...chats.where((chat) => chat.id != widget.chatId),
    ];
    if (!mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian ? 'Нет диалога для пересылки.' : 'No chat to forward to.',
          ),
        ),
      );
      return;
    }

    final target = await showModalBottomSheet<ChatListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ForwardChatPickerSheet(chats: targets, count: cleanMessages.length),
    );
    if (target == null || !mounted) return;

    try {
      await ref
          .read(chatServiceProvider)
          .forwardMessages(targetChatId: target.id, messages: cleanMessages);
      if (!mounted) return;
      _clearMessageSelection();
      ref.invalidate(myChatsProvider(false));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian
                ? 'Сообщения пересланы: ${target.title}'
                : 'Messages forwarded to ${target.title}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    }
  }

  bool get _isRussian =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

  String _ext(String path, {required bool video}) {
    final lower = path.toLowerCase();
    final index = lower.lastIndexOf('.');
    if (index == -1 || index == lower.length - 1) return video ? 'mp4' : 'jpg';
    return lower.substring(index + 1);
  }

  String _fileExt(String name) {
    final lower = name.toLowerCase();
    final index = lower.lastIndexOf('.');
    if (index == -1 || index == lower.length - 1) return 'bin';
    final ext = lower.substring(index + 1).replaceAll(RegExp(r'[^a-z0-9]'), '');
    return ext.isEmpty ? 'bin' : ext;
  }

  String _contentType(String ext, {required bool video}) {
    if (video) {
      if (ext == 'mov') return 'video/quicktime';
      return 'video/mp4';
    }
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  String _audioContentType(String ext, String mimeType) {
    final mime = mimeType.trim();
    if (mime.isNotEmpty) return mime;
    return switch (ext) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'webm' => 'audio/webm',
      'ogg' => 'audio/ogg',
      'aac' => 'audio/aac',
      _ => 'audio/mp4',
    };
  }

  String _documentContentType(String ext, String mimeType) {
    final mime = mimeType.trim();
    if (mime.isNotEmpty) return mime;
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  Future<String> _uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await _uploadBytesToBucket(
        bucket: _chatMediaBucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      return ProtectedMediaUrlService.storageUri(
        bucket: _chatMediaBucket,
        path: path,
      );
    } on StorageException catch (e) {
      if (!_isMissingChatMediaBucket(e)) rethrow;
      await _uploadBytesToBucket(
        bucket: _legacyChatMediaBucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      return _sb.storage.from(_legacyChatMediaBucket).getPublicUrl(path);
    }
  }

  Future<void> _uploadBytesToBucket({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _sb.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  bool _isMissingChatMediaBucket(StorageException e) {
    final status = e.statusCode?.trim() ?? '';
    final message = e.message.toLowerCase();
    return status == '404' ||
        message.contains('bucket not found') ||
        message.contains('not found');
  }

  Future<void> _selectPendingMedia({
    required bool video,
    ImageSource source = ImageSource.gallery,
  }) async {
    if (_sending || _uploadingMedia) return;
    if (!await _ensureCanUseChat()) return;

    XFile? picked;
    try {
      picked = video
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(
              source: source,
              imageQuality: 88,
              maxWidth: 1800,
            );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian
                ? 'Не удалось открыть медиа. Проверьте разрешения устройства.'
                : 'Could not open media. Check device permissions.',
          ),
        ),
      );
      return;
    }
    if (picked == null) return;
    final selected = picked;

    final bytes = video ? null : await selected.readAsBytes();
    if (!mounted) return;
    final pickedSize = bytes?.length ?? await selected.length();
    if (!mounted) return;
    if (_rejectIfTooLarge(pickedSize, name: selected.name)) return;
    setState(() {
      _pendingAttachment = _PendingChatAttachment(
        file: selected,
        kind: video
            ? _PendingAttachmentKind.video
            : _PendingAttachmentKind.image,
        fileName: selected.name.trim().isEmpty
            ? selected.path.split('/').last
            : selected.name,
        fileSize: bytes?.length,
        mimeType: selected.mimeType ?? '',
        previewBytes: bytes,
      );
    });
  }

  Future<void> _selectPendingFile() async {
    if (_sending || _uploadingMedia) return;
    if (!await _ensureCanUseChat()) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian
                ? 'Не удалось открыть файл. Проверьте разрешения устройства.'
                : 'Could not open file. Check device permissions.',
          ),
        ),
      );
      return;
    }
    final picked = result?.files.single;
    if (picked == null) return;

    var bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await XFile(picked.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian
                ? 'Файл пустой или недоступен для отправки.'
                : 'The file is empty or unavailable.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    if (_rejectIfTooLarge(
      picked.size > 0 ? picked.size : bytes.length,
      name: picked.name,
    )) {
      return;
    }
    setState(() {
      _pendingAttachment = _PendingChatAttachment(
        file: picked.path == null ? null : XFile(picked.path!),
        kind: _PendingAttachmentKind.file,
        fileName: picked.name,
        fileSize: picked.size > 0 ? picked.size : bytes!.length,
        mimeType: picked.extension == null ? '' : '',
        bytes: bytes,
        previewBytes: null,
      );
    });
  }

  /// A file pasted from the clipboard or dropped onto the page.
  void _attachWebFile(WebInputFile file) {
    if (!mounted || _sending || _uploadingMedia || _editingMessage != null) {
      return;
    }
    if (_rejectIfTooLarge(file.bytes.length, name: file.name)) return;
    final mime = file.mimeType.toLowerCase();
    final isImage = mime.startsWith('image/');
    final isVideo = mime.startsWith('video/');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final hasName = file.name.trim().isNotEmpty && file.name.contains('.');
    final name = hasName
        ? file.name.trim()
        : isImage
        ? 'image_$stamp.${mime.split('/').last == 'jpeg' ? 'jpg' : mime.split('/').last}'
        : isVideo
        ? 'video_$stamp.${mime.split('/').last}'
        : 'file_$stamp.bin';
    final attachment = _PendingChatAttachment(
      kind: isImage
          ? _PendingAttachmentKind.image
          : isVideo
          ? _PendingAttachmentKind.video
          : _PendingAttachmentKind.file,
      fileName: name,
      fileSize: file.bytes.length,
      mimeType: file.mimeType,
      bytes: file.bytes,
      previewBytes: isImage ? file.bytes : null,
    );
    setState(() {
      // Several files at once: the first is previewed, the rest queue up.
      if (_pendingAttachment == null) {
        _pendingAttachment = attachment;
      } else {
        _queuedAttachments.add(attachment);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  void _insertAtCursor(String text) {
    final value = _messageController.value;
    final selection = value.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, value.text.length)
        : value.text.length;
    final end = selection.isValid
        ? selection.end.clamp(0, value.text.length)
        : value.text.length;
    final next = value.text.replaceRange(start, end, text);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _composerFocus.requestFocus();
  }

  Future<void> _recordVoiceMessage() async {
    if (_sending || _uploadingMedia) return;
    if (!await _ensureCanUseChat()) return;
    if (!mounted) return;

    if (kIsWeb) {
      // v2: record right in the composer, send with one click.
      setState(() => _inlineVoice = true);
      return;
    }

    final attachment = await showModalBottomSheet<_PendingChatAttachment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _VoiceRecorderSheet(),
    );
    if (attachment == null || !mounted) return;
    setState(() => _pendingAttachment = attachment);
  }

  Future<void> _sendInlineVoice(_PendingChatAttachment attachment) async {
    setState(() {
      _inlineVoice = false;
      _sending = true;
    });
    try {
      await _sendAttachment(attachment: attachment, body: '');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment({
    required _PendingChatAttachment attachment,
    required String body,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _uploadingMedia = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final ext = attachment.isFile
          ? _fileExt(attachment.fileName)
          : attachment.isAudio
          ? _fileExt(attachment.fileName)
          : _ext(
              attachment.file?.path ?? attachment.fileName,
              video: attachment.isVideo,
            );
      final mediaBytes =
          attachment.bytes ??
          attachment.previewBytes ??
          await attachment.file!.readAsBytes();
      final mediaPath = '$userId/chats/${widget.chatId}/$stamp.$ext';
      final contentType = attachment.isFile
          ? _documentContentType(ext, attachment.mimeType)
          : attachment.isAudio
          ? _audioContentType(ext, attachment.mimeType)
          : _contentType(ext, video: attachment.isVideo);
      final mediaUrl = await _uploadBytes(
        path: mediaPath,
        bytes: mediaBytes,
        contentType: contentType,
      );

      var thumbnailUrl = '';
      if (attachment.isVideo && !kIsWeb && attachment.file != null) {
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: attachment.file!.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 900,
          quality: 80,
        );
        if (thumbnail != null && thumbnail.isNotEmpty) {
          thumbnailUrl = await _uploadBytes(
            path: '$userId/chats/${widget.chatId}/${stamp}_preview.jpg',
            bytes: thumbnail,
            contentType: 'image/jpeg',
          );
        }
      } else if (attachment.isImage && mediaBytes.isNotEmpty) {
        final thumbnail = await compute(_buildChatImageThumbnail, mediaBytes);
        if (thumbnail != null && thumbnail.isNotEmpty) {
          thumbnailUrl = await _uploadBytes(
            path: '$userId/chats/${widget.chatId}/${stamp}_thumb.jpg',
            bytes: thumbnail,
            contentType: 'image/jpeg',
          );
        }
      }

      await ref
          .read(chatServiceProvider)
          .sendMessage(
            chatId: widget.chatId,
            body: body,
            mediaType: attachment.mediaType,
            mediaUrl: mediaUrl,
            mediaThumbnailUrl: thumbnailUrl,
            fileName: attachment.isFile || attachment.isAudio
                ? attachment.fileName
                : '',
            fileSize: attachment.isFile || attachment.isAudio
                ? attachment.fileSize
                : null,
            fileMime: attachment.isFile || attachment.isAudio
                ? contentType
                : '',
            metadata: <String, dynamic>{
              if (attachment.isAudio && attachment.duration != null)
                'duration_ms': attachment.duration!.inMilliseconds,
              ...?(body.isEmpty ? null : _replyMetadata(_replyingTo)),
            },
          );
      ref.invalidate(chatMediaProvider(widget.chatId));
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _showAttachMenu() async {
    if (!await _ensureCanUseChat()) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionSheet(
        children: [
          _ActionSheetTile(
            icon: Icons.photo_rounded,
            title: _isRussian ? 'Фото' : 'Photo',
            onTap: () {
              Navigator.of(context).pop();
              _selectPendingMedia(video: false);
            },
          ),
          _ActionSheetTile(
            icon: Icons.videocam_rounded,
            title: _isRussian ? 'Видео' : 'Video',
            onTap: () {
              Navigator.of(context).pop();
              _selectPendingMedia(video: true);
            },
          ),
          _ActionSheetTile(
            icon: Icons.photo_camera_rounded,
            title: _isRussian ? 'Камера' : 'Camera',
            onTap: () {
              Navigator.of(context).pop();
              _selectPendingMedia(video: false, source: ImageSource.camera);
            },
          ),
          _ActionSheetTile(
            icon: Icons.attach_file_rounded,
            title: _isRussian ? 'Файл' : 'File',
            onTap: () {
              Navigator.of(context).pop();
              _selectPendingFile();
            },
          ),
          _ActionSheetTile(
            icon: Icons.mic_rounded,
            title: _isRussian ? 'Голосовое сообщение' : 'Voice message',
            onTap: () {
              Navigator.of(context).pop();
              _recordVoiceMessage();
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureCanUseChat() async {
    final entitlements = await ref.read(accountEntitlementsProvider.future);
    if (entitlements.canUseSelectionChat) return true;
    if (!mounted) return false;

    final goToBilling = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.billingUpgradeRequiredTitle),
        content: Text(
          AppLocalizations.of(context)!.billingUpgradeRequiredMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppLocalizations.of(context)!.billingUpgradeActionUpper,
              style: const TextStyle(color: BrandTheme.redTop),
            ),
          ),
        ],
      ),
    );
    if (goToBilling == true && mounted) {
      context.go(Routes.billing);
    }
    return false;
  }

  List<ChatMessage> _mergedMessages(List<ChatMessage> liveMessages) {
    final byId = <String, ChatMessage>{};
    for (final message in _olderMessages) {
      byId[message.id] = message;
    }
    for (final message in liveMessages) {
      byId[message.id] = message;
    }
    // Optimistic messages: drop the ones the stream has caught up with.
    _pendingMessages.removeWhere((pending) {
      final storedId = _pendingSentIds[pending.id];
      final arrived = storedId != null && byId.containsKey(storedId);
      if (arrived) _pendingSentIds.remove(pending.id);
      return arrived;
    });
    for (final pending in _pendingMessages) {
      byId[pending.id] = pending;
    }

    final items = byId.values.toList(growable: false);
    items.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return a.id.compareTo(b.id);
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      final byTime = aTime.compareTo(bTime);
      return byTime == 0 ? a.id.compareTo(b.id) : byTime;
    });
    return items;
  }

  Future<void> _loadOlderMessages(List<ChatMessage> visibleMessages) async {
    if (_loadingOlderMessages ||
        !_hasOlderMessages ||
        visibleMessages.isEmpty) {
      return;
    }
    final oldestCreatedAt = visibleMessages.first.createdAt;
    if (oldestCreatedAt == null) {
      setState(() => _hasOlderMessages = false);
      return;
    }

    setState(() => _loadingOlderMessages = true);
    try {
      final older = await ref
          .read(chatServiceProvider)
          .fetchMessagesBefore(chatId: widget.chatId, before: oldestCreatedAt);
      if (!mounted) return;
      setState(() {
        _olderMessages.addAll(older);
        _hasOlderMessages = older.isNotEmpty;
      });
    } finally {
      if (mounted) setState(() => _loadingOlderMessages = false);
    }
  }

  Future<void> _showMessageActions({
    required ChatMessage message,
    required bool mine,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionSheet(
        children: [
          _ActionSheetTile(
            icon: Icons.reply_rounded,
            title: _isRussian ? 'Ответить' : 'Reply',
            onTap: () {
              Navigator.of(context).pop();
              _startReply(message);
            },
          ),
          if (mine && message.mediaType == 'text' && !message.isDeleted)
            _ActionSheetTile(
              icon: Icons.edit_rounded,
              title: _isRussian ? 'Редактировать' : 'Edit',
              onTap: () async {
                Navigator.of(context).pop();
                await _editMessage(message);
              },
            ),
          _ActionSheetTile(
            icon: Icons.forward_rounded,
            title: _isRussian ? 'Переслать' : 'Forward',
            onTap: () async {
              Navigator.of(context).pop();
              await _forwardSelectedMessages([message]);
            },
          ),
          _ActionSheetTile(
            icon: message.isPinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined,
            title: message.isPinned
                ? (_isRussian ? 'Открепить' : 'Unpin')
                : (_isRussian ? 'Закрепить' : 'Pin'),
            onTap: () async {
              Navigator.of(context).pop();
              await _setMessagePinned(message, !message.isPinned);
            },
          ),
          _ActionSheetTile(
            icon: Icons.checklist_rounded,
            title: _isRussian ? 'Выбрать' : 'Select',
            onTap: () {
              Navigator.of(context).pop();
              _toggleMessageSelection(message);
            },
          ),
          if (mine)
            _ActionSheetTile(
              icon: Icons.delete_rounded,
              title: _isRussian ? 'Удалить сообщение' : 'Delete message',
              danger: true,
              onTap: () async {
                Navigator.of(context).pop();
                await _deleteSelectedMessages({message.id});
              },
            ),
        ],
      ),
    );
  }

  void _startReply(ChatMessage message) {
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
    });
    _composerFocus.requestFocus();
  }

  /// Puts the message text into the composer for editing.
  Future<void> _editMessage(ChatMessage message) async {
    final parsed = _ParsedMessageBody.from(message.body);
    _composerFocus.requestFocus();
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      _pendingAttachment = null;
      _mentionQuery = null;
      _messageController.value = TextEditingValue(
        text: parsed.body,
        selection: TextSelection.collapsed(offset: parsed.body.length),
      );
    });
  }

  void _cancelEdit() {
    if (_editingMessage == null) return;
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  /// ↑ in an empty composer: edit the latest own text message, like in
  /// Telegram / Slack.
  Future<void> _editLastOwnMessage() async {
    if (_editingMessage != null || _messageController.text.isNotEmpty) return;
    final userId = ref.read(currentUserIdProvider) ?? '';
    if (userId.isEmpty) return;
    final live =
        ref.read(chatMessagesProvider(widget.chatId)).valueOrNull ??
        const <ChatMessage>[];
    final merged = _mergedMessages(live);
    ChatMessage? last;
    for (final message in merged.reversed) {
      if (message.senderId != userId) continue;
      if (message.mediaType != 'text' || message.isDeleted) continue;
      if (_ParsedMessageBody.from(message.body).body.trim().isEmpty) continue;
      last = message;
      break;
    }
    if (last == null) return;
    await _editMessage(last);
  }

  Future<void> _saveEdit() async {
    final message = _editingMessage;
    if (message == null) return;
    final parsed = _ParsedMessageBody.from(message.body);
    final updated = _messageController.text.trim();
    if (updated.isEmpty) return;
    if (updated == parsed.body) {
      _cancelEdit();
      return;
    }
    final contentIssue = ContentSafetyFilter.firstIssue({
      _isRussian ? 'сообщение' : 'message': updated,
    });
    if (contentIssue != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ContentSafetyFilter.message(
              isRussian: _isRussian,
              fieldLabel: contentIssue.fieldLabel,
            ),
          ),
        ),
      );
      return;
    }

    final body = parsed.replyQuote.isEmpty
        ? updated
        : '$_replyPrefix${parsed.replyQuote}$_replySeparator$updated';
    setState(() => _sending = true);
    try {
      await ref
          .read(chatServiceProvider)
          .editTextMessage(messageId: message.id, body: body);
      ref.invalidate(chatMessagesProvider(widget.chatId));
      if (!mounted) return;
      setState(() {
        _editingMessage = null;
        _messageController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _selectionMode => _selectedMessageIds.isNotEmpty;

  void _toggleMessageSelection(ChatMessage message) {
    if (message.deletedAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian
                ? 'Это сообщение уже удалено.'
                : 'This message is already deleted.',
          ),
        ),
      );
      return;
    }
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _clearMessageSelection() {
    if (_selectedMessageIds.isEmpty) return;
    setState(_selectedMessageIds.clear);
  }

  Future<void> _deleteSelectedMessages(Set<String> ids) async {
    final cleanIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (cleanIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isRussian ? 'Удалить сообщения?' : 'Delete messages?'),
        content: Text(
          cleanIds.length == 1
              ? (_isRussian
                    ? 'Сообщение будет удалено у всех участников чата.'
                    : 'The message will be deleted for every chat participant.')
              : (_isRussian
                    ? 'Выбранные сообщения будут удалены у всех участников чата.'
                    : 'Selected messages will be deleted for every chat participant.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_isRussian ? 'Отмена' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _isRussian ? 'Удалить' : 'Delete',
              style: const TextStyle(color: BrandTheme.redTop),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(chatServiceProvider).deleteMessagesForEveryone(cleanIds);
      if (!mounted) return;
      setState(() => _selectedMessageIds.removeAll(cleanIds));
      ref.invalidate(pinnedChatMessagesProvider(widget.chatId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    }
  }

  Future<void> _deleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isRussian ? 'Удалить чат?' : 'Delete chat?'),
        content: Text(
          _isRussian
              ? 'Вся переписка будет безвозвратно удалена у обоих участников.'
              : 'The entire conversation will be permanently deleted for both participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_isRussian ? 'Отмена' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _isRussian ? 'Удалить' : 'Delete',
              style: const TextStyle(color: BrandTheme.redTop),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(chatServiceProvider).deleteChatForEveryone(widget.chatId);
      ref.invalidate(myChatsProvider(false));
      ref.invalidate(myChatsProvider(true));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      context.pop();
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(Routes.chats);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final pinnedMessages = ref.watch(pinnedChatMessagesProvider(widget.chatId));
    final typingStates = ref.watch(chatTypingStatesProvider(widget.chatId));
    final summary = ref.watch(chatSummaryProvider(widget.chatId));
    final contexts = ref.watch(chatContextsProvider(widget.chatId));
    final avatars = ref.watch(chatParticipantAvatarsProvider(widget.chatId));
    final mentionTargetsAsync = ref.watch(
      chatMentionTargetsProvider(widget.chatId),
    );
    final avatarMap = avatars.valueOrNull ?? const <String, String>{};
    final mentionQuery = _mentionQuery;
    final mentionTargets = mentionQuery == null
        ? const <ChatMentionTarget>[]
        : (mentionTargetsAsync.valueOrNull ?? const <ChatMentionTarget>[])
              .where((target) => target.matches(mentionQuery))
              .take(5)
              .toList(growable: false);
    final searchVisibleMessages = messages.valueOrNull == null
        ? const <ChatMessage>[]
        : _mergedMessages(messages.valueOrNull!);
    final selectedMessage = _singleSelectedMessage(searchVisibleMessages);
    final selectedMessages = _selectedMessages(searchVisibleMessages);
    final selectedMessagesAllMine =
        selectedMessages.isNotEmpty &&
        selectedMessages.every((message) => message.senderId == userId);
    final searchHits = _searchHits(searchVisibleMessages);
    final pinnedPanelMessages = _pinnedMessagesForPanel(
      pinnedMessages.valueOrNull ?? const <ChatMessage>[],
      searchVisibleMessages,
    );
    final searchPosition = searchHits.isEmpty
        ? 0
        : _searchHitCursor.clamp(0, searchHits.length - 1).toInt() + 1;
    final headerData = summary.maybeWhen(
      data: (value) {
        final title = (value?.accountTitle ?? '').trim();
        return _ChatHeaderData(
          title: title.isEmpty ? t.chatUpper : title,
          subtitle: value?.contextLabel ?? '',
          avatarUrl: value?.accountAvatarUrl ?? '',
        );
      },
      orElse: () => _ChatHeaderData(title: t.chatUpper),
    );
    final chatContext = summary.valueOrNull;
    // v2 (web, inside the two-column chats page): flat full-height column —
    // 72 px header with a hairline, the feed, the composer at the bottom.
    final v2 = kIsWeb;

    final profileId = chatContext?.profileId.trim() ?? '';
    final selectionId = chatContext?.selectionId.trim() ?? '';
    final otherUserId = chatContext == null
        ? ''
        : (chatContext.modelUserId == userId
              ? chatContext.agentUserId
              : chatContext.modelUserId);
    // Step 29: the context column fits next to the list and the feed only
    // on a wide window.
    final canShowContextPanel =
        v2 &&
        widget.embedded &&
        MediaQuery.sizeOf(context).width >= chatContextPanelBreakpoint;
    final showContextPanel = canShowContextPanel && _contextPanelOpen;
    final header = v2
        ? _ChatHeaderV2(
            title: headerData.title,
            subtitle: headerData.subtitle,
            otherUserId: otherUserId,
            avatarUrl: headerData.avatarUrl,
            onBack: widget.embedded ? null : _goBack,
            onSearch: _toggleSearch,
            searchActive: _searchOpen,
            onDeleteChat: _deleteChat,
            onToggleInfo: canShowContextPanel ? _toggleContextPanel : null,
            infoActive: showContextPanel,
            onOpenProfile: profileId.isEmpty
                ? null
                : () => context.push('${Routes.modelPrefix}$profileId'),
            // The public casting page only works for a published casting;
            // otherwise the button has nowhere useful to go.
            onOpenCasting:
                selectionId.isEmpty || chatContext?.selectionIsPublic != true
                ? null
                : () => context.push(
                    '${Routes.publicSelectionPrefix}$selectionId',
                  ),
          )
        : _ChatHeader(
            title: headerData.title,
            subtitle: headerData.subtitle,
            avatarUrl: headerData.avatarUrl,
            onBack: widget.embedded ? widget.onClose : _goBack,
            onSearch: _toggleSearch,
            searchActive: _searchOpen,
            onDeleteChat: _deleteChat,
          );

    final content = Stack(
      children: [
        if (!widget.embedded) const BrandBackground(),
        if (v2) const Positioned.fill(child: ColoredBox(color: Tokens.surface)),
        SafeArea(
          top: !widget.embedded,
          bottom: !widget.embedded,
          child: Padding(
            padding: v2
                ? EdgeInsets.zero
                : EdgeInsets.fromLTRB(
                    widget.embedded ? 18 : 16,
                    widget.embedded ? 18 : 12,
                    widget.embedded ? 18 : 16,
                    widget.embedded ? 18 : 12,
                  ),
            child: Column(
              children: [
                header,
                const SizedBox(height: 12),
                // Lays out the quick reactions once so the emoji fallback
                // font is fetched before the picker opens (otherwise its
                // first paint shows boxes).
                if (v2)
                  Offstage(
                    child: Text(_quickReactionsV2.join(), maxLines: 1),
                  ),
                if (_searchOpen) ...[
                  _V2Pad(
                    enabled: v2,
                    child: _ChatSearchPanel(
                    flat: v2,
                    controller: _searchController,
                    query: _searchQuery,
                    hitCount: searchHits.length,
                    currentPosition: searchPosition,
                    loading: _serverSearchLoading,
                    errorText: _serverSearchError,
                    onChanged: _handleSearchChanged,
                    onClose: _toggleSearch,
                    onPrevious: () => _jumpToSearchHit(
                      searchVisibleMessages,
                      searchHits,
                      direction: -1,
                    ),
                    onNext: () => _jumpToSearchHit(
                      searchVisibleMessages,
                      searchHits,
                      direction: 1,
                    ),
                    onSubmitted: () => _jumpToSearchHit(
                      searchVisibleMessages,
                      searchHits,
                      direction: 0,
                    ),
                  ),
                  ),
                  const SizedBox(height: 12),
                ],
                // v2 carries the context in the header line and its actions.
                if (!v2 &&
                    chatContext != null &&
                    (chatContext.profileName.trim().isNotEmpty ||
                        chatContext.selectionTitle.trim().isNotEmpty)) ...[
                  _V2Pad(
                    enabled: v2,
                    child: _ChatContextCard(
                      summary: chatContext,
                      contexts:
                          contexts.valueOrNull ?? const <ChatContextEntry>[],
                      flat: v2,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (pinnedPanelMessages.isNotEmpty) ...[
                  _V2Pad(
                    enabled: v2,
                    child: _PinnedMessagesPanel(
                      flat: v2,
                      messages: pinnedPanelMessages,
                      isRussian: _isRussian,
                      previewBuilder: _replyPreviewText,
                      onTap: (message) =>
                          _jumpToMessage(message.id, searchVisibleMessages),
                      onUnpin: (message) => _setMessagePinned(message, false),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: _V2Pad(
                    enabled: v2,
                    child: messages.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        '${t.errorUpper}: ${AppErrorMapper.message(e, t)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kTextDanger),
                      ),
                    ),
                    data: (items) => items.isEmpty
                        ? (v2
                              ? _EmptyConversationV2(
                                  title: headerData.title,
                                  ru: _isRussian,
                                )
                              : Center(
                                  child: Text(
                                    t.chatEmptyMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: kTextMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ))
                        : Builder(
                            builder: (context) {
                              final visibleMessages = _mergedMessages(items);
                              final canLoadOlder =
                                  _hasOlderMessages &&
                                  items.length >= _chatRealtimeMessageLimit;
                              if (items.any(
                                (e) =>
                                    e.senderId != userId &&
                                    e.readAt == null &&
                                    !e.isDeleted,
                              )) {
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _markRead(),
                                );
                              }
                              if (v2) {
                                _markDeliveredIfNeeded(items, userId);
                                _trackNewWhileScrolled(items, userId);
                                return _buildFeedV2(
                                  context,
                                  visibleMessages: visibleMessages,
                                  userId: userId,
                                  canLoadOlder: canLoadOlder,
                                );
                              }

                              return ListView.builder(
                                controller: _messageListController,
                                reverse: true,
                                itemCount:
                                    visibleMessages.length +
                                    (canLoadOlder ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == visibleMessages.length) {
                                    return _LoadOlderMessagesButton(
                                      loading: _loadingOlderMessages,
                                      onTap: () =>
                                          _loadOlderMessages(visibleMessages),
                                    );
                                  }
                                  final item =
                                      visibleMessages[visibleMessages.length -
                                          1 -
                                          index];
                                  return _MessageBubble(
                                    message: item,
                                    mine: item.senderId == userId,
                                    avatarUrl: avatarMap[item.senderId] ?? '',
                                    showReadStatus:
                                        item.senderId == userId && index == 0,
                                    onMediaTap: () =>
                                        _openMediaViewer(context, item),
                                    onVoiceListened: () =>
                                        _markVoiceListened(item),
                                    selected: _selectedMessageIds.contains(
                                      item.id,
                                    ),
                                    searchQuery: _searchQuery,
                                    activeSearchResult:
                                        _activeSearchMessageId == item.id,
                                    onTap: _selectionMode
                                        ? () => _toggleMessageSelection(item)
                                        : null,
                                    onLongPress: () {
                                      if (_selectionMode) {
                                        _toggleMessageSelection(item);
                                        return;
                                      }
                                      _showMessageActions(
                                        message: item,
                                        mine: item.senderId == userId,
                                      );
                                    },
                                    onSecondaryTap: () => _showMessageActions(
                                      message: item,
                                      mine: item.senderId == userId,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_uploadingMedia) ...[
                  _V2Pad(enabled: v2, child: const _ChatUploadProgress()),
                  const SizedBox(height: 10),
                ],
                if ((typingStates.valueOrNull ?? const <ChatTypingState>[])
                    .isNotEmpty) ...[
                  _V2Pad(enabled: v2, child: const _TypingIndicator()),
                  const SizedBox(height: 10),
                ],
                if (mentionQuery != null && mentionTargets.isNotEmpty) ...[
                  _V2Pad(
                    enabled: v2,
                    child: _MentionSuggestions(
                      targets: mentionTargets,
                      onSelect: _insertMention,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_selectionMode) ...[
                  _V2Pad(
                    enabled: v2,
                    child: _MessageSelectionBar(
                    count: _selectedMessageIds.length,
                    singleMessage: selectedMessage,
                    onCancel: _clearMessageSelection,
                    onReply: selectedMessage == null
                        ? null
                        : () => _replyToSelectedMessage(selectedMessage),
                    onForward: selectedMessages.isEmpty
                        ? null
                        : () => _forwardSelectedMessages(selectedMessages),
                    onTogglePin: selectedMessage == null
                        ? null
                        : () => _toggleSelectedMessagePinned(selectedMessage),
                    onDelete: selectedMessagesAllMine
                        ? () => _deleteSelectedMessages(
                            Set<String>.from(_selectedMessageIds),
                          )
                        : null,
                    flat: v2,
                  ),
                  ),
                  const SizedBox(height: 10),
                ],
                Padding(
                  padding: v2
                      ? (MediaQuery.sizeOf(context).width < 600
                            ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
                            : const EdgeInsets.fromLTRB(24, 0, 24, 20))
                      : EdgeInsets.zero,
                  child: _Composer(
                    controller: _messageController,
                    focusNode: _composerFocus,
                    recorder: _inlineVoice
                        ? _InlineVoiceRecorder(
                            onCancel: () => setState(() => _inlineVoice = false),
                            onSend: _sendInlineVoice,
                          )
                        : null,
                    hintText: t.messageHint,
                    sending: _sending || _uploadingMedia,
                    replyingToText: _replyingTo == null
                        ? null
                        : _replyPreviewText(_replyingTo!),
                    editingText: _editingMessage == null
                        ? null
                        : _ParsedMessageBody.from(_editingMessage!.body).body,
                    onCancelEdit: _cancelEdit,
                    onInsertEmoji: v2 ? _insertAtCursor : null,
                    onEditLast: v2 ? _editLastOwnMessage : null,
                    attachment: _pendingAttachment,
                    queuedAttachments: _queuedAttachments.length,
                    onCancelReply: () => setState(() => _replyingTo = null),
                    onRemoveAttachment: () => setState(() {
                      _pendingAttachment = null;
                      _queuedAttachments.clear();
                    }),
                    onSend: _send,
                    onAttach: _showAttachMenu,
                    onRecordVoice: _recordVoiceMessage,
                    flat: v2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final body = showContextPanel
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: content),
              ChatContextPanel(
                chatId: widget.chatId,
                title: headerData.title,
                avatarUrl: headerData.avatarUrl,
                otherUserId: otherUserId,
                summary: chatContext,
                contexts: contexts.valueOrNull ?? const <ChatContextEntry>[],
                pinned: pinnedPanelMessages,
                localMedia: searchVisibleMessages,
                previewBuilder: _replyPreviewText,
                onJumpToMessage: (message) =>
                    _jumpToMessage(message.id, searchVisibleMessages),
                onUnpin: (message) => _setMessagePinned(message, false),
                onOpenMedia: (message) => _openMediaViewer(context, message),
                onClose: _toggleContextPanel,
                onOpenProfile: profileId.isEmpty
                    ? null
                    : () => context.push('${Routes.modelPrefix}$profileId'),
                onOpenCasting:
                    selectionId.isEmpty || chatContext?.selectionIsPublic != true
                    ? null
                    : () => context.push(
                        '${Routes.publicSelectionPrefix}$selectionId',
                      ),
              ),
            ],
          )
        : content;

    final withDropOverlay = Stack(
      children: [
        body,
        if (_dragging)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: 0.82),
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Tokens.radiusLg),
                    border: Border.all(color: Tokens.accent, width: 2),
                    color: Tokens.accentSoft,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.file_download_outlined,
                          size: 40,
                          color: Tokens.accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isRussian
                              ? 'Отпустите, чтобы прикрепить файл'
                              : 'Drop to attach the file',
                          style: AppText.h2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) return withDropOverlay;

    return Scaffold(resizeToAvoidBottomInset: true, body: withDropOverlay);
  }

  bool _deliveredMarkPending = false;

  /// Incoming messages that reached this client are ✓✓ for the sender.
  void _markDeliveredIfNeeded(List<ChatMessage> items, String userId) {
    if (_deliveredMarkPending) return;
    final pending = items.any(
      (m) => m.senderId != userId && !m.isDelivered && !m.isDeleted,
    );
    if (!pending) return;
    _deliveredMarkPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(chatServiceProvider).markChatsDelivered([widget.chatId]);
      } catch (_) {
        // Best effort: the read receipt covers it later.
      } finally {
        _deliveredMarkPending = false;
      }
    });
  }

  Widget _buildFeedV2(
    BuildContext context, {
    required List<ChatMessage> visibleMessages,
    required String userId,
    required bool canLoadOlder,
  }) {
    final reactions =
        ref.watch(chatReactionsProvider(widget.chatId)).valueOrNull ??
        const <ChatReaction>[];
    final reactionsByMessage = <String, List<ChatReaction>>{};
    for (final reaction in reactions) {
      reactionsByMessage.putIfAbsent(reaction.messageId, () => []).add(reaction);
    }
    final entries = _feedEntriesV2(visibleMessages, userId);

    final avatarMap =
        ref.watch(chatParticipantAvatarsProvider(widget.chatId)).valueOrNull ??
        const <String, String>{};
    final otherPartyName =
        (ref.watch(chatSummaryProvider(widget.chatId)).valueOrNull?.accountTitle ??
                '')
            .trim();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    // Messages present at the first frame do not animate in; later ones do.
    final firstFrame = !_feedSeeded;
    if (firstFrame) {
      _feedSeeded = true;
      _seenMessageIds.addAll(visibleMessages.map((m) => m.id));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;
        final maxBubbleWidth = narrow
            ? constraints.maxWidth * 0.8
            : math.min(560.0, math.max(280.0, constraints.maxWidth * 0.55));
        return Stack(
          children: [
            SelectionArea(
          child: ListView.builder(
          controller: _messageListController,
          reverse: true,
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          itemCount: entries.length + (canLoadOlder ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == entries.length) {
              return _LoadOlderMessagesButton(
                loading: _loadingOlderMessages,
                onTap: () => _loadOlderMessages(visibleMessages),
              );
            }
            final entry = entries[entries.length - 1 - index];
            if (entry.dayLabel != null) {
              return _DaySeparatorV2(label: entry.dayLabel!);
            }
            final item = entry.message!;
            final mine = item.senderId == userId;
            final animateIn = !_seenMessageIds.contains(item.id);
            _seenMessageIds.add(item.id);
            final replyToId = (item.metadata[_replyToIdKey] ?? '').toString();
            final replyToSender =
                (item.metadata[_replyToSenderKey] ?? '').toString();
            final quoteAuthor = replyToSender.isEmpty
                ? ''
                : replyToSender == userId
                ? (ru ? 'Вы' : 'You')
                : otherPartyName;
            return RepaintBoundary(
              child: _AppearV2(
                animate: animateIn,
                child: _BubbleV2(
              key: _bubbleKeys.putIfAbsent(item.id, GlobalKey.new),
              quoteAuthor: quoteAuthor,
              onQuoteTap: replyToId.isEmpty || _selectionMode
                  ? null
                  : () => _jumpToReply(replyToId),
              message: item,
              mine: mine,
              avatarUrl: mine ? '' : (avatarMap[item.senderId] ?? ''),
              firstInGroup: entry.firstInGroup,
              lastInGroup: entry.lastInGroup,
              maxWidth: maxBubbleWidth,
              reactions:
                  reactionsByMessage[item.id] ?? const <ChatReaction>[],
              currentUserId: userId,
              selected: _selectedMessageIds.contains(item.id),
              selectionMode: _selectionMode,
              searchQuery: _searchQuery,
              activeSearchResult: _activeSearchMessageId == item.id,
              onMediaTap: () => _openMediaViewer(context, item),
              onVoiceListened: () => _markVoiceListened(item),
              onTap: _selectionMode
                  ? () => _toggleMessageSelection(item)
                  : null,
              onLongPress: () {
                if (_selectionMode) {
                  _toggleMessageSelection(item);
                  return;
                }
                _showMessageActions(message: item, mine: mine);
              },
              onContextMenu: (position) =>
                  _showMessageMenuV2(item, mine: mine, position: position),
              onReact: (emoji) => _toggleReaction(item, emoji),
              onReply: () => _startReply(item),
              ),
              ),
            );
          },
          ),
            ),
            if (_showScrollDown)
              Positioned(
                right: 8,
                bottom: 12,
                child: _ScrollDownButtonV2(
                  count: _newWhileScrolled,
                  onTap: _scrollFeedToBottom,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Day separators + author grouping: a message is "first in group" when
  /// the previous one is from someone else, on another day, or more than
  /// ten minutes older; "last in group" symmetrically.
  List<_FeedEntryV2> _feedEntriesV2(List<ChatMessage> messages, String userId) {
    final entries = <_FeedEntryV2>[];
    const gap = Duration(minutes: 10);
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final day = m.createdAt?.toLocal();
      final prevDay = prev?.createdAt?.toLocal();
      final newDay =
          day != null &&
          (prevDay == null ||
              prevDay.year != day.year ||
              prevDay.month != day.month ||
              prevDay.day != day.day);
      if (newDay) {
        entries.add(_FeedEntryV2.day(_dayLabelV2(day, _isRussian)));
      }
      bool sameGroup(ChatMessage? other) {
        if (other == null || other.senderId != m.senderId) return false;
        final a = m.createdAt;
        final b = other.createdAt;
        if (a == null || b == null) return true;
        final aL = a.toLocal();
        final bL = b.toLocal();
        if (aL.year != bL.year || aL.month != bL.month || aL.day != bL.day) {
          return false;
        }
        return (a.difference(b)).abs() <= gap;
      }

      entries.add(
        _FeedEntryV2.message(
          m,
          firstInGroup: newDay || !sameGroup(prev),
          lastInGroup: !sameGroup(next),
        ),
      );
    }
    return entries;
  }

  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    final userId = ref.read(currentUserIdProvider) ?? '';
    final service = ref.read(chatServiceProvider);
    final current =
        (ref.read(chatReactionsProvider(widget.chatId)).valueOrNull ??
                const <ChatReaction>[])
            .where((r) => r.messageId == message.id && r.userId == userId)
            .map((r) => r.emoji)
            .firstOrNull;
    try {
      if (current == emoji) {
        await service.clearReaction(message.id);
      } else {
        await service.setReaction(
          chatId: widget.chatId,
          messageId: message.id,
          emoji: emoji,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(error, AppLocalizations.of(context)!),
          ),
        ),
      );
    }
  }

  /// Desktop context menu (right click) with the same actions as the
  /// mobile action sheet.
  Future<void> _showMessageMenuV2(
    ChatMessage message, {
    required bool mine,
    required Offset position,
  }) async {
    if (message.metadata['pending'] == true) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final rect = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 1, 1),
      Offset.zero & overlay.size,
    );
    PopupMenuItem<String> item(String value, IconData icon, String label,
        {bool danger = false}) {
      return PopupMenuItem<String>(
        value: value,
        height: 40,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: danger ? Tokens.danger : Tokens.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppText.small.copyWith(
                color: danger ? Tokens.danger : Tokens.text,
              ),
            ),
          ],
        ),
      );
    }

    final parsed = _ParsedMessageBody.from(message.body);
    final selected = await showMenu<String>(
      context: context,
      position: rect,
      color: Tokens.bg,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.border),
      ),
      items: [
        item('reply', Icons.reply_rounded, _isRussian ? 'Ответить' : 'Reply'),
        if (mine && message.mediaType == 'text' && !message.isDeleted)
          item('edit', Icons.edit_outlined,
              _isRussian ? 'Редактировать' : 'Edit'),
        if (parsed.body.trim().isNotEmpty)
          item('copy', Icons.copy_rounded,
              _isRussian ? 'Копировать текст' : 'Copy text'),
        item('forward', Icons.forward_rounded,
            _isRussian ? 'Переслать' : 'Forward'),
        item(
          'pin',
          message.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          message.isPinned
              ? (_isRussian ? 'Открепить' : 'Unpin')
              : (_isRussian ? 'Закрепить' : 'Pin'),
        ),
        item('select', Icons.checklist_rounded,
            _isRussian ? 'Выбрать' : 'Select'),
        if (mine)
          item('delete', Icons.delete_outline_rounded,
              _isRussian ? 'Удалить' : 'Delete', danger: true),
      ],
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'reply':
        _startReply(message);
      case 'edit':
        await _editMessage(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: parsed.body.trim()));
      case 'forward':
        await _forwardSelectedMessages([message]);
      case 'pin':
        await _setMessagePinned(message, !message.isPinned);
      case 'select':
        _toggleMessageSelection(message);
      case 'delete':
        await _deleteSelectedMessages({message.id});
    }
  }

  void _openMediaViewer(BuildContext context, ChatMessage message) {
    if (!message.hasMedia) return;
    showDialog<void>(
      context: context,
      builder: (context) => _MediaViewerDialog(message: message),
    );
  }
}
