import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/protected_media_url.dart';
import '../../ui/brand/ui_constants.dart';
import 'chat_models.dart';
import 'chat_providers.dart';

/// Width of the context column on the right of a conversation.
const double chatContextPanelWidth = 320;

/// The window width from which the context panel is offered.
const double chatContextPanelBreakpoint = 1400;

/// Step 29: the right-hand column of a conversation on a wide screen —
/// who the chat is with (profile or casting), pinned messages, the photos,
/// videos and files exchanged. Collapses with the button in the header.
class ChatContextPanel extends ConsumerWidget {
  const ChatContextPanel({
    super.key,
    required this.chatId,
    required this.title,
    required this.avatarUrl,
    required this.otherUserId,
    required this.summary,
    required this.contexts,
    required this.pinned,
    required this.localMedia,
    required this.previewBuilder,
    required this.onJumpToMessage,
    required this.onUnpin,
    required this.onOpenMedia,
    required this.onClose,
    this.onOpenProfile,
    this.onOpenCasting,
  });

  final String chatId;
  final String title;
  final String avatarUrl;
  final String otherUserId;
  final ChatSummary? summary;
  final List<ChatContextEntry> contexts;
  final List<ChatMessage> pinned;

  /// Media among the messages already on screen: new attachments show up
  /// here before the server list is refreshed.
  final List<ChatMessage> localMedia;
  final String Function(ChatMessage message) previewBuilder;
  final ValueChanged<ChatMessage> onJumpToMessage;
  final ValueChanged<ChatMessage> onUnpin;
  final ValueChanged<ChatMessage> onOpenMedia;
  final VoidCallback onClose;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenCasting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final online =
        otherUserId.isNotEmpty && ref.watch(userIsOnlineProvider(otherUserId));
    final fetched =
        ref.watch(chatMediaProvider(chatId)).valueOrNull ?? const <ChatMessage>[];
    final media = _mergeMedia(fetched, localMedia);
    final pictures = media
        .where((m) => m.isImage || m.isVideo)
        .toList(growable: false);
    final files = media.where((m) => m.isFile).toList(growable: false);

    final profileName = summary?.profileName.trim() ?? '';
    final selectionTitle = summary?.selectionTitle.trim() ?? '';
    final history = contexts
        .where(
          (entry) =>
              summary == null ||
              entry.profileId != summary!.profileId ||
              entry.selectionId != summary!.selectionId,
        )
        .take(6)
        .toList(growable: false);

    return Container(
      width: chatContextPanelWidth,
      decoration: const BoxDecoration(
        color: Tokens.bg,
        border: Border(left: BorderSide(color: Tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ru ? 'О диалоге' : 'About',
                      style: AppText.smallStrong.copyWith(fontSize: 15),
                    ),
                  ),
                  IconButton(
                    tooltip: ru ? 'Скрыть панель' : 'Hide panel',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      foregroundColor: Tokens.textSecondary,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                // Who the conversation is with.
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusLg),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: avatarUrl.trim().isEmpty
                          ? const ColoredBox(
                              color: Tokens.surfaceAlt,
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: Tokens.textTertiary,
                                size: 36,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.6),
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: Tokens.surfaceAlt,
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: Tokens.textTertiary,
                                  size: 36,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h2.copyWith(fontSize: 18, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  online
                      ? (ru ? 'в сети' : 'online')
                      : (ru ? 'не в сети' : 'offline'),
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    fontSize: 13,
                    color: online ? Tokens.success : Tokens.textTertiary,
                    fontWeight: online ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),

                // Context: profile and casting.
                if (profileName.isNotEmpty || selectionTitle.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(ru ? 'Контекст' : 'Context'),
                  if (profileName.isNotEmpty)
                    _ContextRow(
                      icon: Icons.badge_outlined,
                      label: ru ? 'Анкета' : 'Profile',
                      value: profileName,
                      onTap: onOpenProfile,
                    ),
                  if (selectionTitle.isNotEmpty)
                    _ContextRow(
                      icon: Icons.video_camera_front_outlined,
                      label: ru ? 'Кастинг' : 'Casting',
                      value: selectionTitle,
                      onTap: onOpenCasting,
                    ),
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      ru ? 'Раньше в этом диалоге' : 'Earlier in this chat',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 4),
                    for (final entry in history)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          [
                            if (entry.profileName.trim().isNotEmpty)
                              entry.profileName.trim(),
                            if (entry.selectionTitle.trim().isNotEmpty)
                              entry.selectionTitle.trim(),
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.copyWith(
                            color: Tokens.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ],

                // Pinned.
                if (pinned.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    ru
                        ? 'Закреплённые · ${pinned.length}'
                        : 'Pinned · ${pinned.length}',
                  ),
                  for (final message in pinned)
                    _PinnedRow(
                      text: previewBuilder(message),
                      onTap: () => onJumpToMessage(message),
                      onUnpin: () => onUnpin(message),
                      ru: ru,
                    ),
                ],

                // Photos and videos.
                if (pictures.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    ru
                        ? 'Фото и видео · ${pictures.length}'
                        : 'Photos & videos · ${pictures.length}',
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: pictures.length,
                    itemBuilder: (context, index) {
                      final message = pictures[index];
                      return _MediaThumb(
                        message: message,
                        onTap: () => onOpenMedia(message),
                      );
                    },
                  ),
                ],

                // Files.
                if (files.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    ru ? 'Файлы · ${files.length}' : 'Files · ${files.length}',
                  ),
                  for (final message in files)
                    _FileRow(
                      message: message,
                      onTap: () => onOpenMedia(message),
                    ),
                ],

                if (pictures.isEmpty && files.isEmpty && pinned.isEmpty) ...[
                  const SizedBox(height: 32),
                  Text(
                    ru
                        ? 'Здесь появятся закреплённые сообщения, фото и файлы из этого диалога.'
                        : 'Pinned messages, photos and files from this chat will appear here.',
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(fontSize: 13, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<ChatMessage> _mergeMedia(
    List<ChatMessage> fetched,
    List<ChatMessage> local,
  ) {
    final byId = <String, ChatMessage>{};
    for (final message in fetched) {
      byId[message.id] = message;
    }
    for (final message in local) {
      if (!message.hasMedia || message.isDeleted || message.isAudio) continue;
      if (message.metadata['pending'] == true) continue;
      byId[message.id] = message;
    }
    final items = byId.values.toList(growable: false);
    items.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return items;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppText.smallStrong.copyWith(color: Tokens.ink),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Tokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.caption),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    color: onTap == null ? Tokens.text : Tokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Tokens.textTertiary,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: row,
    );
  }
}

class _PinnedRow extends StatefulWidget {
  const _PinnedRow({
    required this.text,
    required this.onTap,
    required this.onUnpin,
    required this.ru,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onUnpin;
  final bool ru;

  @override
  State<_PinnedRow> createState() => _PinnedRowState();
}

class _PinnedRowState extends State<_PinnedRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 32,
                decoration: BoxDecoration(
                  color: Tokens.accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small,
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: _hovered
                    ? IconButton(
                        tooltip: widget.ru ? 'Открепить' : 'Unpin',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onUnpin,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Tokens.textSecondary,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaThumb extends ConsumerWidget {
  const _MediaThumb({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = message.mediaThumbnailUrl.isNotEmpty
        ? message.mediaThumbnailUrl
        : message.mediaUrl;
    final url = ref.watch(_panelMediaUrlProvider(source));
    const placeholder = ColoredBox(color: Tokens.surfaceAlt);
    final image = url.when(
      data: (resolved) => resolved.trim().isEmpty
          ? const ColoredBox(
              color: Tokens.surfaceAlt,
              child: Icon(
                Icons.broken_image_outlined,
                color: Tokens.textTertiary,
                size: 18,
              ),
            )
          : CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => const ColoredBox(
                color: Tokens.surfaceAlt,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Tokens.textTertiary,
                  size: 18,
                ),
              ),
            ),
      loading: () => placeholder,
      error: (_, _) => placeholder,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (message.isVideo)
                Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
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

class _FileRow extends StatelessWidget {
  const _FileRow({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = _formatSize(message.fileSize);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: const Icon(
                Icons.insert_drive_file_outlined,
                size: 18,
                color: Tokens.ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.fileDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (size.isNotEmpty) Text(size, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = value >= 100 || unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text ${units[unit]}';
  }
}

final _panelMediaUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, source) {
      return ref.read(protectedMediaUrlServiceProvider).resolve(source);
    });
