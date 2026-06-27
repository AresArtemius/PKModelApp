import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
const _quickReactions = ['👍', '❤️', '🔥', '👀', '🙌', '😂'];
const _quickEmoji = ['🙂', '👍', '❤️', '🔥', '🙌', '👏', '✨', '😊'];

Uint8List? _buildChatImageThumbnail(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) return null;
  final thumb = image_lib.copyResize(decoded, width: 640);
  return Uint8List.fromList(image_lib.encodeJpg(thumb, quality: 72));
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
  bool _sending = false;
  bool _uploadingMedia = false;
  bool _loadingOlderMessages = false;
  bool _hasOlderMessages = true;
  final List<ChatMessage> _olderMessages = [];
  final _picker = ImagePicker();

  SupabaseClient get _sb => ref.read(supabaseProvider);

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId) return;
    _olderMessages.clear();
    _hasOlderMessages = true;
    _loadingOlderMessages = false;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _uploadingMedia) return;
    if (!await _ensureCanUseChat()) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(chatServiceProvider)
          .sendMessage(chatId: widget.chatId, body: text);
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
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

  Future<String> _uploadFile({
    required String path,
    required File file,
    required String contentType,
  }) async {
    await _sb.storage
        .from(_chatMediaBucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _sb.storage.from(_chatMediaBucket).getPublicUrl(path);
  }

  Future<void> _pickMedia({required bool video}) async {
    if (_sending || _uploadingMedia) return;
    if (!await _ensureCanUseChat()) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final picked = video
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 88,
            maxWidth: 1800,
          );
    if (picked == null) return;

    final caption = await _showMediaPreview(picked, video: video);
    if (caption == null) return;

    setState(() => _uploadingMedia = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final ext = _ext(picked.path, video: video);
      final pickedFile = File(picked.path);
      final mediaBytes = video ? null : await pickedFile.readAsBytes();
      final mediaPath = '$userId/chats/${widget.chatId}/$stamp.$ext';
      final contentType = _contentType(ext, video: video);
      final mediaUrl = video
          ? await _uploadFile(
              path: mediaPath,
              file: pickedFile,
              contentType: contentType,
            )
          : await _uploadBytes(
              path: mediaPath,
              bytes: mediaBytes!,
              contentType: contentType,
            );

      var thumbnailUrl = '';
      if (video) {
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: picked.path,
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
      } else if (mediaBytes != null && mediaBytes.isNotEmpty) {
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
            body: caption,
            mediaType: video ? 'video' : 'image',
            mediaUrl: mediaUrl,
            mediaThumbnailUrl: thumbnailUrl,
          );
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<String?> _showMediaPreview(XFile file, {required bool video}) async {
    final captionC = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: profileCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: video
                      ? Container(
                          color: kTextDark,
                          child: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 72,
                          ),
                        )
                      : Image.file(File(file.path), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionC,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _isRussian ? 'Комментарий' : 'Caption',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SheetActionButton(
                      label: _isRussian ? 'ОТМЕНА' : 'CANCEL',
                      dark: false,
                      onTap: () => Navigator.of(context).pop(null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetActionButton(
                      label: _isRussian ? 'ОТПРАВИТЬ' : 'SEND',
                      dark: true,
                      onTap: () => Navigator.of(context).pop(captionC.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    captionC.dispose();
    return result;
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
              _pickMedia(video: false);
            },
          ),
          _ActionSheetTile(
            icon: Icons.videocam_rounded,
            title: _isRussian ? 'Видео' : 'Video',
            onTap: () {
              Navigator.of(context).pop();
              _pickMedia(video: true);
            },
          ),
        ],
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final selection = _messageController.selection;
    final text = _messageController.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final next = text.replaceRange(start, end, emoji);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
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

  Future<void> _showEmojiMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionSheet(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final emoji in _quickEmoji)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _insertEmoji(emoji);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: pillDecoration(isDark: false, radius: 16),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Wrap(
              spacing: 10,
              children: [
                for (final emoji in _quickReactions)
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(context).pop();
                      await ref
                          .read(chatServiceProvider)
                          .setReaction(
                            chatId: widget.chatId,
                            messageId: message.id,
                            emoji: emoji,
                          );
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
              ],
            ),
          ),
          _ActionSheetTile(
            icon: Icons.close_rounded,
            title: _isRussian ? 'Убрать мою реакцию' : 'Remove my reaction',
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(chatServiceProvider).clearReaction(message.id);
            },
          ),
          if (mine)
            _ActionSheetTile(
              icon: Icons.delete_rounded,
              title: _isRussian ? 'Удалить сообщение' : 'Delete message',
              danger: true,
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(chatServiceProvider)
                    .deleteMessageForEveryone(message.id);
              },
            ),
        ],
      ),
    );
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
    final reactions = ref.watch(chatReactionsProvider(widget.chatId));
    final summary = ref.watch(chatSummaryProvider(widget.chatId));
    final avatars = ref.watch(chatParticipantAvatarsProvider(widget.chatId));
    final avatarMap = avatars.valueOrNull ?? const <String, String>{};
    final reactionMap = <String, List<ChatReaction>>{};
    for (final reaction in reactions.valueOrNull ?? const <ChatReaction>[]) {
      reactionMap.putIfAbsent(reaction.messageId, () => []).add(reaction);
    }
    final title = summary.maybeWhen(
      data: (value) {
        final parts = [
          value?.selectionTitle ?? '',
          value?.profileName ?? '',
        ].where((e) => e.trim().isNotEmpty).toList(growable: false);
        return parts.isEmpty ? t.chatUpper : parts.join(' • ');
      },
      orElse: () => t.chatUpper,
    );

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
                  title: title,
                  onBack: widget.embedded ? null : () => context.pop(),
                  onDeleteChat: _deleteChat,
                ),
                const SizedBox(height: 12),
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

                              return ListView.builder(
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
                                    reactions:
                                        reactionMap[item.id] ??
                                        const <ChatReaction>[],
                                    onLongPress: () => _showMessageActions(
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
                _Composer(
                  controller: _messageController,
                  hintText: t.messageHint,
                  sending: _sending || _uploadingMedia,
                  onSend: _send,
                  onAttach: _showAttachMenu,
                  onEmoji: _showEmojiMenu,
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.onBack,
    required this.onDeleteChat,
  });

  final String title;
  final VoidCallback? onBack;
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
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kTextDark,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
              fontSize: 20,
            ),
          ),
        ),
        _IconPill(icon: Icons.delete_outline_rounded, onTap: onDeleteChat),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.avatarUrl,
    required this.reactions,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final String avatarUrl;
  final List<ChatReaction> reactions;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final visibleBody =
        message.hasMedia &&
            ((message.isImage && message.body.trim() == 'Фото') ||
                (message.isVideo && message.body.trim() == 'Видео'))
        ? ''
        : message.body.trim();
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 244),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? kTextDark : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasMedia) ...[
              _MessageMedia(message: message),
              if (visibleBody.isNotEmpty) const SizedBox(height: 8),
            ],
            if (visibleBody.isNotEmpty)
              Text(
                visibleBody,
                style: TextStyle(
                  color: mine ? Colors.white : kTextDark,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
          ],
        ),
      ),
    );
    final bubbleWithReactions = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        bubble,
        if (reactions.isNotEmpty) _ReactionStrip(reactions: reactions),
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
                bubbleWithReactions,
                const SizedBox(width: 8),
                _ChatAvatar(avatarUrl: avatarUrl),
              ]
            : [
                _ChatAvatar(avatarUrl: avatarUrl),
                const SizedBox(width: 8),
                bubbleWithReactions,
              ],
      ),
    );
  }
}

class _MessageMedia extends StatelessWidget {
  const _MessageMedia({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final imageUrl = message.mediaThumbnailUrl.isNotEmpty
        ? message.mediaThumbnailUrl
        : message.mediaUrl;
    return GestureDetector(
      onTap: message.isImage
          ? () {
              showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(14),
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: message.mediaUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 1200,
                      maxWidthDiskCache: 1600,
                    ),
                  ),
                ),
              );
            }
          : message.isVideo
          ? () {
              showDialog<void>(
                context: context,
                builder: (context) => _VideoPlayerDialog(url: message.mediaUrl),
              );
            }
          : null,
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

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.url});

  final String url;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
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
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(14),
      child: AspectRatio(
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
            if (_ready && !_controller.value.isPlaying)
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 68,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({required this.reactions});

  final List<ChatReaction> reactions;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final reaction in reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in counts.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
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
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.trim().isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 19)
          : CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              memCacheWidth: 96,
              maxWidthDiskCache: 160,
              errorWidget: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 19,
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
    required this.onSend,
    required this.onAttach,
    required this.onEmoji,
  });

  final TextEditingController controller;
  final String hintText;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onEmoji;

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
      child: Row(
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
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: sending ? null : onEmoji,
            icon: const Icon(Icons.emoji_emotions_rounded, color: kTextMuted),
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

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.label,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: pillDecoration(isDark: dark, radius: 999),
        child: Text(
          label,
          style: TextStyle(
            color: dark ? Colors.white : kTextDark,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

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
          color: Colors.white.withValues(alpha: 0.76),
          border: Border.all(color: kBorderColor, width: 1),
        ),
        child: Icon(icon, color: kTextDark, size: 22),
      ),
    );
  }
}
