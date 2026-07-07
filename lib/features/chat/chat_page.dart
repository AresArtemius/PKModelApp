import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/app_error_mapper.dart';
import '../../core/auth_providers.dart';
import '../../core/entitlements_provider.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'chat_models.dart';
import 'chat_providers.dart';

const _chatMediaBucket = 'profile-media';
const _chatRealtimeMessageLimit = 120;
const _replyPrefix = '↩ ';
const _replySeparator = '\n\n';

Uint8List? _buildChatImageThumbnail(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) return null;
  final thumb = image_lib.copyResize(decoded, width: 640);
  return Uint8List.fromList(image_lib.encodeJpg(thumb, quality: 72));
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
  final _searchController = TextEditingController();
  final _messageListController = ScrollController();
  bool _sending = false;
  bool _uploadingMedia = false;
  bool _loadingOlderMessages = false;
  bool _hasOlderMessages = true;
  ChatMessage? _replyingTo;
  final Set<String> _selectedMessageIds = <String>{};
  bool _searchOpen = false;
  String _searchQuery = '';
  int _searchHitCursor = 0;
  String? _activeSearchMessageId;
  _PendingChatAttachment? _pendingAttachment;
  DateTime? _lastTypingSentAt;
  Timer? _typingStopTimer;
  final List<ChatMessage> _olderMessages = [];
  final _picker = ImagePicker();

  SupabaseClient get _sb => ref.read(supabaseProvider);

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId) return;
    unawaited(_setTyping(false));
    _olderMessages.clear();
    _hasOlderMessages = true;
    _loadingOlderMessages = false;
    _replyingTo = null;
    _selectedMessageIds.clear();
    _searchOpen = false;
    _searchQuery = '';
    _searchHitCursor = 0;
    _activeSearchMessageId = null;
    _searchController.clear();
    _pendingAttachment = null;
    _lastTypingSentAt = null;
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleTypingChanged);
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    unawaited(_setTyping(false));
    _messageController.removeListener(_handleTypingChanged);
    _messageController.dispose();
    _searchController.dispose();
    _messageListController.dispose();
    super.dispose();
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

  Future<void> _markRead() async {
    try {
      await ref.read(chatServiceProvider).markChatRead(widget.chatId);
    } catch (_) {
      // Read receipts are best effort while older SQL is still possible.
    }
  }

  Future<void> _send() async {
    if (_sending || _uploadingMedia) return;
    if (!await _ensureCanUseChat()) return;
    final text = _messageController.text.trim();
    final attachment = _pendingAttachment;
    if (text.isEmpty && attachment == null) return;
    final body = text.isEmpty ? '' : _composeOutgoingBody(text);

    setState(() => _sending = true);
    try {
      if (attachment == null) {
        await ref
            .read(chatServiceProvider)
            .sendMessage(chatId: widget.chatId, body: body);
      } else {
        await _sendAttachment(attachment: attachment, body: body);
      }
      _messageController.clear();
      setState(() {
        _replyingTo = null;
        _pendingAttachment = null;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _composeOutgoingBody(String text) {
    final reply = _replyingTo;
    if (reply == null) return text;
    final quote = _replyPreviewText(reply);
    if (quote.isEmpty) return text;
    return '$_replyPrefix$quote$_replySeparator$text';
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
    ];
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<ChatMessage> _searchHits(List<ChatMessage> messages) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const <ChatMessage>[];
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
        _searchController.clear();
      }
    });
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _searchHitCursor = 0;
      _activeSearchMessageId = null;
    });
  }

  Future<void> _jumpToSearchHit(
    List<ChatMessage> visibleMessages,
    List<ChatMessage> hits, {
    required int direction,
  }) async {
    if (hits.isEmpty || visibleMessages.isEmpty) return;
    final nextCursor = direction == 0
        ? _searchHitCursor.clamp(0, hits.length - 1).toInt()
        : (_searchHitCursor + direction) % hits.length;
    final safeCursor = nextCursor < 0 ? hits.length - 1 : nextCursor;
    final target = hits[safeCursor];
    final targetIndex = visibleMessages.indexWhere(
      (item) => item.id == target.id,
    );
    if (targetIndex == -1) return;
    final reverseBuilderIndex = visibleMessages.length - 1 - targetIndex;
    const estimatedMessageExtent = 96.0;
    final targetOffset = reverseBuilderIndex * estimatedMessageExtent;
    setState(() {
      _searchHitCursor = safeCursor;
      _activeSearchMessageId = target.id;
    });
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
    if (_selectedMessageIds.length != 1) return null;
    final id = _selectedMessageIds.first;
    for (final message in visibleMessages) {
      if (message.id == id) return message;
    }
    return null;
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
    await _sb.storage
        .from(_chatMediaBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _sb.storage.from(_chatMediaBucket).getPublicUrl(path);
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
            fileName: attachment.isFile ? attachment.fileName : '',
            fileSize: attachment.isFile ? attachment.fileSize : null,
            fileMime: attachment.isFile ? contentType : '',
          );
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
              setState(() => _replyingTo = message);
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
          if (mine)
            _ActionSheetTile(
              icon: Icons.checklist_rounded,
              title: _isRussian ? 'Выбрать' : 'Select',
              onTap: () {
                Navigator.of(context).pop();
                _toggleMessageSelection(message, mine: mine);
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

  bool get _selectionMode => _selectedMessageIds.isNotEmpty;

  void _toggleMessageSelection(ChatMessage message, {required bool mine}) {
    if (!mine || message.deletedAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRussian
                ? 'Выбирать для удаления можно только свои сообщения.'
                : 'Only your own messages can be selected for deletion.',
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
              ? 'Чат будет скрыт у вас. У второго участника история останется.'
              : 'The chat will be hidden for you. The other participant keeps the history.',
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
    await ref.read(chatServiceProvider).hideChatForMe(widget.chatId);
    if (!mounted) return;
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      context.pop();
    }
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
    final avatarMap = avatars.valueOrNull ?? const <String, String>{};
    final searchVisibleMessages = messages.valueOrNull == null
        ? const <ChatMessage>[]
        : _mergedMessages(messages.valueOrNull!);
    final selectedMessage = _singleSelectedMessage(searchVisibleMessages);
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

    final content = Stack(
      children: [
        if (!widget.embedded) const BrandBackground(),
        SafeArea(
          top: !widget.embedded,
          bottom: !widget.embedded,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 18 : 16,
              widget.embedded ? 18 : 12,
              widget.embedded ? 18 : 16,
              widget.embedded ? 18 : 12,
            ),
            child: Column(
              children: [
                _ChatHeader(
                  title: headerData.title,
                  subtitle: headerData.subtitle,
                  avatarUrl: headerData.avatarUrl,
                  onBack: widget.embedded
                      ? widget.onClose
                      : () => context.pop(),
                  onSearch: _toggleSearch,
                  searchActive: _searchOpen,
                  onDeleteChat: _deleteChat,
                ),
                const SizedBox(height: 12),
                if (_searchOpen) ...[
                  _ChatSearchPanel(
                    controller: _searchController,
                    query: _searchQuery,
                    hitCount: searchHits.length,
                    currentPosition: searchPosition,
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
                  const SizedBox(height: 12),
                ],
                if (chatContext != null &&
                    (chatContext.profileName.trim().isNotEmpty ||
                        chatContext.selectionTitle.trim().isNotEmpty)) ...[
                  _ChatContextCard(
                    summary: chatContext,
                    contexts:
                        contexts.valueOrNull ?? const <ChatContextEntry>[],
                  ),
                  const SizedBox(height: 12),
                ],
                if (pinnedPanelMessages.isNotEmpty) ...[
                  _PinnedMessagesPanel(
                    messages: pinnedPanelMessages,
                    isRussian: _isRussian,
                    previewBuilder: _replyPreviewText,
                    onTap: (message) =>
                        _jumpToMessage(message.id, searchVisibleMessages),
                    onUnpin: (message) => _setMessagePinned(message, false),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
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
                        ? Center(
                            child: Text(
                              t.chatEmptyMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kTextMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final visibleMessages = _mergedMessages(items);
                              final canLoadOlder =
                                  _hasOlderMessages &&
                                  items.length >= _chatRealtimeMessageLimit;
                              if (items.any((e) => e.senderId != userId)) {
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _markRead(),
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
                                    selected: _selectedMessageIds.contains(
                                      item.id,
                                    ),
                                    searchQuery: _searchQuery,
                                    activeSearchResult:
                                        _activeSearchMessageId == item.id,
                                    onTap: _selectionMode
                                        ? () => _toggleMessageSelection(
                                            item,
                                            mine: item.senderId == userId,
                                          )
                                        : null,
                                    onLongPress: () {
                                      final mine = item.senderId == userId;
                                      if (_selectionMode || mine) {
                                        _toggleMessageSelection(
                                          item,
                                          mine: mine,
                                        );
                                        return;
                                      }
                                      _showMessageActions(
                                        message: item,
                                        mine: mine,
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
                const SizedBox(height: 12),
                if (_uploadingMedia) ...[
                  const _ChatUploadProgress(),
                  const SizedBox(height: 10),
                ],
                if ((typingStates.valueOrNull ?? const <ChatTypingState>[])
                    .isNotEmpty) ...[
                  const _TypingIndicator(),
                  const SizedBox(height: 10),
                ],
                if (_selectionMode) ...[
                  _MessageSelectionBar(
                    count: _selectedMessageIds.length,
                    singleMessage: selectedMessage,
                    onCancel: _clearMessageSelection,
                    onReply: selectedMessage == null
                        ? null
                        : () => _replyToSelectedMessage(selectedMessage),
                    onTogglePin: selectedMessage == null
                        ? null
                        : () => _toggleSelectedMessagePinned(selectedMessage),
                    onDelete: () => _deleteSelectedMessages(
                      Set<String>.from(_selectedMessageIds),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _Composer(
                  controller: _messageController,
                  hintText: t.messageHint,
                  sending: _sending || _uploadingMedia,
                  replyingToText: _replyingTo == null
                      ? null
                      : _replyPreviewText(_replyingTo!),
                  attachment: _pendingAttachment,
                  onCancelReply: () => setState(() => _replyingTo = null),
                  onRemoveAttachment: () =>
                      setState(() => _pendingAttachment = null),
                  onSend: _send,
                  onAttach: _showAttachMenu,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(resizeToAvoidBottomInset: true, body: content);
  }

  void _openMediaViewer(BuildContext context, ChatMessage message) {
    if (!message.hasMedia) return;
    showDialog<void>(
      context: context,
      builder: (context) => _MediaViewerDialog(message: message),
    );
  }
}

class _LoadOlderMessagesButton extends StatelessWidget {
  const _LoadOlderMessagesButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: GestureDetector(
          onTap: loading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: pillDecoration(isDark: false, radius: 18),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isRussian ? 'ЗАГРУЗИТЬ СТАРЫЕ' : 'LOAD OLDER',
                    style: const TextStyle(
                      color: kTextDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PinnedMessagesPanel extends StatelessWidget {
  const _PinnedMessagesPanel({
    required this.messages,
    required this.isRussian,
    required this.previewBuilder,
    required this.onTap,
    required this.onUnpin,
  });

  final List<ChatMessage> messages;
  final bool isRussian;
  final String Function(ChatMessage message) previewBuilder;
  final ValueChanged<ChatMessage> onTap;
  final ValueChanged<ChatMessage> onUnpin;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages.take(3).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.push_pin_rounded,
                size: 18,
                color: BrandTheme.redTop,
              ),
              const SizedBox(width: 8),
              Text(
                isRussian ? 'ЗАКРЕПЛЕНО' : 'PINNED',
                style: const TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                messages.length.toString(),
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final message in visibleMessages)
            _PinnedMessageRow(
              message: message,
              preview: previewBuilder(message),
              isRussian: isRussian,
              onTap: () => onTap(message),
              onUnpin: () => onUnpin(message),
            ),
        ],
      ),
    );
  }
}

class _PinnedMessageRow extends StatelessWidget {
  const _PinnedMessageRow({
    required this.message,
    required this.preview,
    required this.isRussian,
    required this.onTap,
    required this.onUnpin,
  });

  final ChatMessage message;
  final String preview;
  final bool isRussian;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final cleanPreview = preview.trim().isEmpty
        ? (isRussian ? 'Сообщение' : 'Message')
        : preview.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Text(
                cleanPreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: isRussian ? 'Открепить' : 'Unpin',
            onPressed: onUnpin,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: kTextMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
        ],
      ),
    );
  }
}

class _ChatSearchPanel extends StatelessWidget {
  const _ChatSearchPanel({
    required this.controller,
    required this.query,
    required this.hitCount,
    required this.currentPosition,
    required this.onChanged,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String query;
  final int hitCount;
  final int currentPosition;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final hasQuery = query.trim().isNotEmpty;
    final hasHits = hitCount > 0;
    final statusText = !hasQuery
        ? (isRussian ? 'Поиск' : 'Search')
        : hasHits
        ? '$currentPosition / $hitCount'
        : (isRussian ? 'Нет' : 'None');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: kTextDark, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: isRussian ? 'Поиск по сообщениям' : 'Search messages',
                border: InputBorder.none,
                isDense: true,
                hintStyle: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 46, maxWidth: 86),
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasQuery && !hasHits ? BrandTheme.redTop : kTextMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: hasHits ? onPrevious : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            color: kTextDark,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: hasHits ? onNext : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: kTextDark,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: kTextDark,
          ),
        ],
      ),
    );
  }
}

class _ChatHeaderData {
  const _ChatHeaderData({
    required this.title,
    this.subtitle = '',
    this.avatarUrl = '',
  });

  final String title;
  final String subtitle;
  final String avatarUrl;
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.onBack,
    required this.onSearch,
    required this.searchActive,
    required this.onDeleteChat,
  });

  final String title;
  final String subtitle;
  final String avatarUrl;
  final VoidCallback? onBack;
  final VoidCallback onSearch;
  final bool searchActive;
  final VoidCallback onDeleteChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack == null)
          const SizedBox(width: 48)
        else
          _IconPill(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack!),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChatHeaderAvatar(url: avatarUrl),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextDark,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 18,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kTextMuted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconPill(
              icon: Icons.search_rounded,
              onTap: onSearch,
              active: searchActive,
            ),
            const SizedBox(width: 8),
            _IconPill(icon: Icons.delete_outline_rounded, onTap: onDeleteChat),
          ],
        ),
      ],
    );
  }
}

class _ChatHeaderAvatar extends StatelessWidget {
  const _ChatHeaderAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 34,
        height: 34,
        color: kTextDark,
        child: url.trim().isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 21)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    const Icon(Icons.person_rounded, color: Colors.white),
              ),
      ),
    );
  }
}

class _ChatContextCard extends StatelessWidget {
  const _ChatContextCard({required this.summary, required this.contexts});

  final ChatSummary summary;
  final List<ChatContextEntry> contexts;

  @override
  Widget build(BuildContext context) {
    final profileName = summary.profileName.trim();
    final selectionTitle = summary.selectionTitle.trim();
    final hasProfile = summary.profileId.trim().isNotEmpty;
    final hasSelection = summary.selectionId.trim().isNotEmpty;
    final history = contexts
        .where(
          (entry) =>
              entry.profileId != summary.profileId ||
              entry.selectionId != summary.selectionId,
        )
        .take(4)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: pillDecoration(isDark: true, radius: 15),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'КОНТЕКСТ ДИАЛОГА',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kTextMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (profileName.isNotEmpty)
                      _ContextLine(label: 'Анкета', value: profileName),
                    if (selectionTitle.isNotEmpty)
                      _ContextLine(label: 'Кастинг', value: selectionTitle),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasProfile)
                    _ContextIconButton(
                      icon: Icons.badge_rounded,
                      tooltip: 'Открыть анкету',
                      onTap: () => context.push(
                        '${Routes.modelPrefix}${summary.profileId}',
                      ),
                    ),
                  if (hasProfile && hasSelection) const SizedBox(width: 6),
                  if (hasSelection)
                    _ContextIconButton(
                      icon: Icons.video_camera_front_rounded,
                      tooltip: 'Открыть кастинг',
                      onTap: () => context.push(
                        '${Routes.publicSelectionPrefix}${summary.selectionId}',
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: kBorderColor),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.history_rounded, size: 15, color: kTextMuted),
                SizedBox(width: 6),
                Text(
                  'ИСТОРИЯ КОНТЕКСТОВ',
                  style: TextStyle(
                    color: kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in history) ...[
              _ContextHistoryRow(entry: entry),
              if (entry != history.last) const SizedBox(height: 7),
            ],
          ],
        ],
      ),
    );
  }
}

class _ContextHistoryRow extends StatelessWidget {
  const _ContextHistoryRow({required this.entry});

  final ChatContextEntry entry;

  @override
  Widget build(BuildContext context) {
    final profileName = entry.profileName.trim();
    final selectionTitle = entry.selectionTitle.trim();
    final date = _shortDate(entry.createdAt);
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: BrandTheme.redTop,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                [
                  if (profileName.isNotEmpty) profileName,
                  if (selectionTitle.isNotEmpty) selectionTitle,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              if (date.isNotEmpty)
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.profileId.trim().isNotEmpty)
              _ContextMiniButton(
                icon: Icons.badge_rounded,
                tooltip: 'Открыть анкету',
                onTap: () =>
                    context.push('${Routes.modelPrefix}${entry.profileId}'),
              ),
            if (entry.profileId.trim().isNotEmpty &&
                entry.selectionId.trim().isNotEmpty)
              const SizedBox(width: 5),
            if (entry.selectionId.trim().isNotEmpty)
              _ContextMiniButton(
                icon: Icons.video_camera_front_rounded,
                tooltip: 'Открыть кастинг',
                onTap: () => context.push(
                  '${Routes.publicSelectionPrefix}${entry.selectionId}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _shortDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }
}

class _ContextMiniButton extends StatelessWidget {
  const _ContextMiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: catalogSearchDecoration(radius: 11),
            child: Icon(icon, color: kTextDark, size: 16),
          ),
        ),
      ),
    );
  }
}

class _ContextLine extends StatelessWidget {
  const _ContextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: kTextMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, letterSpacing: 0),
      ),
    );
  }
}

class _ContextIconButton extends StatelessWidget {
  const _ContextIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: catalogSearchDecoration(radius: 15),
            child: Icon(icon, color: kTextDark, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MessageSelectionBar extends StatelessWidget {
  const _MessageSelectionBar({
    required this.count,
    required this.singleMessage,
    required this.onCancel,
    required this.onReply,
    required this.onTogglePin,
    required this.onDelete,
  });

  final int count;
  final ChatMessage? singleMessage;
  final VoidCallback onCancel;
  final VoidCallback? onReply;
  final VoidCallback? onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final pinTooltip = singleMessage?.isPinned == true
        ? (isRussian ? 'Открепить' : 'Unpin')
        : (isRussian ? 'Закрепить' : 'Pin');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: kTextDark,
        borderRadius: BorderRadius.circular(22),
        boxShadow: BrandTheme.basePillShadow(isDark: true),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              isRussian
                  ? 'ВЫБРАНО СООБЩЕНИЙ: $count'
                  : 'MESSAGES SELECTED: $count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (onReply != null)
            Tooltip(
              message: isRussian ? 'Ответить' : 'Reply',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, color: Colors.white),
              ),
            ),
          if (onTogglePin != null)
            Tooltip(
              message: pinTooltip,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onTogglePin,
                icon: Icon(
                  singleMessage?.isPinned == true
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_rounded, color: BrandTheme.redTop),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.avatarUrl,
    required this.showReadStatus,
    required this.onMediaTap,
    required this.selected,
    required this.searchQuery,
    required this.activeSearchResult,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTap,
  });

  final ChatMessage message;
  final bool mine;
  final String avatarUrl;
  final bool showReadStatus;
  final bool selected;
  final String searchQuery;
  final bool activeSearchResult;
  final VoidCallback onMediaTap;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final parsedBody = _ParsedMessageBody.from(message.body);
    final visibleBody =
        message.hasMedia &&
            ((message.isImage && parsedBody.body.trim() == 'Фото') ||
                (message.isVideo && parsedBody.body.trim() == 'Видео'))
        ? ''
        : parsedBody.body.trim();
    final bubble = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(maxWidth: 244),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: activeSearchResult
              ? BrandTheme.redTop.withValues(alpha: mine ? 0.92 : 0.08)
              : mine
              ? kTextDark
              : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected || activeSearchResult
                ? BrandTheme.redTop
                : kBorderColor,
            width: selected || activeSearchResult ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parsedBody.replyQuote.isNotEmpty) ...[
              _ReplyPreview(text: parsedBody.replyQuote, mine: mine),
              const SizedBox(height: 8),
            ],
            if (message.hasMedia) ...[
              _MessageMedia(message: message, onTap: onMediaTap),
              if (visibleBody.isNotEmpty) const SizedBox(height: 8),
            ],
            if (visibleBody.isNotEmpty)
              _HighlightedMessageText(
                text: visibleBody,
                query: searchQuery,
                style: TextStyle(
                  color: mine ? Colors.white : kTextDark,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                highlightColor: mine
                    ? Colors.white.withValues(alpha: 0.22)
                    : BrandTheme.redTop.withValues(alpha: 0.18),
              ),
          ],
        ),
      ),
    );
    final bubbleContent = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            if (selected)
              Positioned(
                top: -7,
                right: mine ? -7 : null,
                left: mine ? null : -7,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: BrandTheme.redTop,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            if (message.isPinned)
              Positioned(
                top: -7,
                right: mine ? null : -7,
                left: mine ? -7 : null,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandTheme.redTop, width: 2),
                  ),
                  child: const Icon(
                    Icons.push_pin_rounded,
                    size: 13,
                    color: BrandTheme.redTop,
                  ),
                ),
              ),
          ],
        ),
        if (showReadStatus) _MessageReadStatus(readAt: message.readAt),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: mine
            ? [
                bubbleContent,
                const SizedBox(width: 8),
                _ChatAvatar(avatarUrl: avatarUrl),
              ]
            : [
                _ChatAvatar(avatarUrl: avatarUrl),
                const SizedBox(width: 8),
                bubbleContent,
              ],
      ),
    );
  }
}

class _ParsedMessageBody {
  const _ParsedMessageBody({required this.replyQuote, required this.body});

  final String replyQuote;
  final String body;

  factory _ParsedMessageBody.from(String raw) {
    final text = raw.trim();
    if (!text.startsWith(_replyPrefix)) {
      return _ParsedMessageBody(replyQuote: '', body: text);
    }
    final withoutPrefix = text.substring(_replyPrefix.length);
    final separatorIndex = withoutPrefix.indexOf(_replySeparator);
    if (separatorIndex <= 0) {
      return _ParsedMessageBody(replyQuote: '', body: text);
    }
    return _ParsedMessageBody(
      replyQuote: withoutPrefix.substring(0, separatorIndex).trim(),
      body: withoutPrefix
          .substring(separatorIndex + _replySeparator.length)
          .trim(),
    );
  }
}

class _HighlightedMessageText extends StatelessWidget {
  const _HighlightedMessageText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  });

  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || text.isEmpty) return Text(text, style: style);

    final lowerText = text.toLowerCase();
    final lowerQuery = cleanQuery.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;

    while (cursor < text.length) {
      final index = lowerText.indexOf(lowerQuery, cursor);
      if (index < 0) break;
      if (index > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: style.copyWith(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      cursor = index + lowerQuery.length;
    }

    if (spans.isEmpty) return Text(text, style: style);
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.14)
            : kTextDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: mine ? Colors.white : BrandTheme.redTop,
            width: 3,
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: mine ? Colors.white.withValues(alpha: 0.78) : kTextMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

class _MessageReadStatus extends StatelessWidget {
  const _MessageReadStatus({required this.readAt});

  final DateTime? readAt;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final read = readAt != null;
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            read ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15,
            color: read ? BrandTheme.redTop : kTextMuted,
          ),
          const SizedBox(width: 4),
          Text(
            read
                ? (isRussian ? 'прочитано' : 'read')
                : (isRussian ? 'доставлено' : 'delivered'),
            style: TextStyle(
              color: read ? BrandTheme.redTop : kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMedia extends StatelessWidget {
  const _MessageMedia({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (message.isFile) {
      return _MessageFileCard(message: message, onTap: onTap);
    }
    final imageUrl = message.mediaThumbnailUrl.isNotEmpty
        ? message.mediaThumbnailUrl
        : message.mediaUrl;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 220,
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 520,
                maxWidthDiskCache: 900,
                placeholder: (_, _) =>
                    Container(color: Colors.white.withValues(alpha: 0.18)),
                errorWidget: (_, _, _) => Container(
                  color: Colors.white.withValues(alpha: 0.18),
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
              if (message.isVideo)
                Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageFileCard extends StatelessWidget {
  const _MessageFileCard({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = _formatFileSize(message.fileSize);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kTextDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insert_drive_file_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileDisplayName.isEmpty
                          ? 'Файл'
                          : message.fileDisplayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    if (size.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        size,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaViewerDialog extends StatelessWidget {
  const _MediaViewerDialog({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isFile) {
      return _FileViewerDialog(message: message);
    }
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: message.isVideo
                  ? _VideoPlayerSurface(url: message.mediaUrl)
                  : InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: CachedNetworkImage(
                        imageUrl: message.mediaUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 1400,
                        maxWidthDiskCache: 2000,
                        placeholder: (_, _) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _ViewerCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileViewerDialog extends StatelessWidget {
  const _FileViewerDialog({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final size = _formatFileSize(message.fileSize);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kTextDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.fileDisplayName.isEmpty
                            ? (isRussian ? 'Файл' : 'File')
                            : message.fileDisplayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                      if (size.isNotEmpty || message.fileMime.isNotEmpty)
                        Text(
                          [
                            if (size.isNotEmpty) size,
                            if (message.fileMime.isNotEmpty) message.fileMime,
                          ].join(' • '),
                          style: const TextStyle(
                            color: kTextMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SelectableText(
              message.mediaUrl,
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: message.mediaUrl),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isRussian ? 'Ссылка скопирована' : 'Link copied',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(isRussian ? 'СКОПИРОВАТЬ' : 'COPY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerCloseButton extends StatelessWidget {
  const _ViewerCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _VideoPlayerSurface extends StatefulWidget {
  const _VideoPlayerSurface({required this.url});

  final String url;

  @override
  State<_VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<_VideoPlayerSurface> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _ready ? _controller.value.aspectRatio : 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_ready)
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: VideoPlayer(_controller),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (_ready && !_controller.value.isBuffering)
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          if (_ready && !_controller.value.isPlaying)
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 78,
            ),
        ],
      ),
    );
  }
}

enum _PendingAttachmentKind { image, video, file }

class _PendingChatAttachment {
  const _PendingChatAttachment({
    required this.kind,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.previewBytes,
    this.file,
    this.bytes,
  });

  final _PendingAttachmentKind kind;
  final XFile? file;
  final String fileName;
  final int? fileSize;
  final String mimeType;
  final Uint8List? bytes;
  final Uint8List? previewBytes;

  bool get isImage => kind == _PendingAttachmentKind.image;
  bool get isVideo => kind == _PendingAttachmentKind.video;
  bool get isFile => kind == _PendingAttachmentKind.file;
  String get mediaType => switch (kind) {
    _PendingAttachmentKind.image => 'image',
    _PendingAttachmentKind.video => 'video',
    _PendingAttachmentKind.file => 'file',
  };
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: kTextDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: avatarUrl.trim().isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 19)
          : ClipOval(
              child: SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  memCacheWidth: 160,
                  maxWidthDiskCache: 220,
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: kTextDark,
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hintText,
    required this.sending,
    required this.replyingToText,
    required this.attachment,
    required this.onCancelReply,
    required this.onRemoveAttachment,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final String hintText;
  final bool sending;
  final String? replyingToText;
  final _PendingChatAttachment? attachment;
  final VoidCallback onCancelReply;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingToText != null && replyingToText!.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: kTextDark.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: BrandTheme.redTop,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      replyingToText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close_rounded, color: kTextMuted),
                  ),
                ],
              ),
            ),
          ],
          if (attachment != null) ...[
            _PendingAttachmentPreview(
              attachment: attachment!,
              onRemove: onRemoveAttachment,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                onPressed: sending ? null : onAttach,
                icon: const Icon(Icons.add_rounded, color: kTextDark),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: BrandTheme.redTop),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentPreview extends StatelessWidget {
  const _PendingAttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  final _PendingChatAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final isFile = attachment.isFile;
    final size = _formatFileSize(attachment.fileSize);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kTextDark.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 74,
              height: 74,
              child: isFile
                  ? Container(
                      color: kTextDark,
                      child: const Icon(
                        Icons.insert_drive_file_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    )
                  : attachment.isVideo
                  ? Container(
                      color: kTextDark,
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    )
                  : attachment.previewBytes == null
                  ? Container(color: Colors.white)
                  : Image.memory(attachment.previewBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFile
                      ? (isRussian ? 'ФАЙЛ ГОТОВ' : 'FILE READY')
                      : attachment.isVideo
                      ? (isRussian ? 'ВИДЕО ГОТОВО' : 'VIDEO READY')
                      : (isRussian ? 'ФОТО ГОТОВО' : 'PHOTO READY'),
                  style: const TextStyle(
                    color: kTextDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFile
                      ? [
                          attachment.fileName,
                          if (size.isNotEmpty) size,
                        ].where((e) => e.trim().isNotEmpty).join(' • ')
                      : isRussian
                      ? 'Добавьте подпись и нажмите отправить.'
                      : 'Add a caption and tap send.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _ChatUploadProgress extends StatelessWidget {
  const _ChatUploadProgress();

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kTextDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: BrandTheme.basePillShadow(isDark: true),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isRussian ? 'ЗАГРУЗКА МЕДИА' : 'UPLOADING MEDIA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorderColor),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 18, height: 18, child: _TypingDots()),
            const SizedBox(width: 10),
            Text(
              isRussian ? 'ПЕЧАТАЕТ...' : 'TYPING...',
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (index) {
            final value = (_controller.value + index / 3) % 1;
            final opacity = value < 0.5 ? 1.0 : 0.35;
            return Opacity(
              opacity: opacity,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: kTextMuted,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: profileCardDecoration(),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _ActionSheetTile extends StatelessWidget {
  const _ActionSheetTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BrandTheme.redTop : kTextDark;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
      onTap: onTap,
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active ? kTextDark : Colors.white.withValues(alpha: 0.76),
          border: Border.all(
            color: active ? BrandTheme.redTop : kBorderColor,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Icon(icon, color: active ? Colors.white : kTextDark, size: 22),
      ),
    );
  }
}
