import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'chat_models.dart';
import 'chat_page.dart';
import 'chat_providers.dart';

const double _chatsDesktopBreakpoint = 900;
const double _chatsDesktopMaxWidth = 1480;
const double _chatsDesktopListWidth = 430;

enum _ChatRoleFilter {
  all,
  model,
  client;

  String get label {
    return switch (this) {
      _ChatRoleFilter.all => 'ВСЕ',
      _ChatRoleFilter.model => 'КАК МОДЕЛЬ',
      _ChatRoleFilter.client => 'КАК ЗАКАЗЧИК',
    };
  }

  bool matches(ChatListItem item) {
    return switch (this) {
      _ChatRoleFilter.all => true,
      _ChatRoleFilter.model =>
        item.participantRole == ChatParticipantRole.model,
      _ChatRoleFilter.client =>
        item.participantRole == ChatParticipantRole.client,
    };
  }

  String get emptyTitle {
    return switch (this) {
      _ChatRoleFilter.all => 'ЧАТОВ НЕТ',
      _ChatRoleFilter.model => 'ЧАТОВ КАК МОДЕЛЬ НЕТ',
      _ChatRoleFilter.client => 'ЧАТОВ КАК ЗАКАЗЧИК НЕТ',
    };
  }

  String get emptyMessage {
    return switch (this) {
      _ChatRoleFilter.all =>
        'Откройте приглашение или подборку, чтобы начать диалог.',
      _ChatRoleFilter.model =>
        'Здесь будут диалоги, где пишут по вашим анкетам.',
      _ChatRoleFilter.client =>
        'Здесь будут диалоги, которые вы начали как заказчик.',
    };
  }
}

enum _ChatContentFilter {
  all,
  unread,
  pinned,
  media,
  files,
  voice;

  String get label {
    return switch (this) {
      _ChatContentFilter.all => 'ВСЕ СООБЩЕНИЯ',
      _ChatContentFilter.unread => 'НОВЫЕ',
      _ChatContentFilter.pinned => 'ЗАКРЕП',
      _ChatContentFilter.media => 'МЕДИА',
      _ChatContentFilter.files => 'ФАЙЛЫ',
      _ChatContentFilter.voice => 'ГОЛОСОВЫЕ',
    };
  }

  IconData get icon {
    return switch (this) {
      _ChatContentFilter.all => Icons.all_inbox_rounded,
      _ChatContentFilter.unread => Icons.mark_chat_unread_rounded,
      _ChatContentFilter.pinned => Icons.push_pin_rounded,
      _ChatContentFilter.media => Icons.photo_library_rounded,
      _ChatContentFilter.files => Icons.attach_file_rounded,
      _ChatContentFilter.voice => Icons.mic_rounded,
    };
  }

  bool matches(ChatListItem item) {
    return switch (this) {
      _ChatContentFilter.all => true,
      _ChatContentFilter.unread => item.unreadCount > 0,
      _ChatContentFilter.pinned => item.pinned || item.hasPinnedMessages,
      _ChatContentFilter.media => item.hasMediaMessages,
      _ChatContentFilter.files => item.hasFileMessages,
      _ChatContentFilter.voice => item.hasAudioMessages,
    };
  }
}

TextStyle _chatTitleStyle({
  Color color = kTextDark,
  double size = 18,
  double spacing = 1.4,
  FontWeight weight = FontWeight.w800,
}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

String _formatVoicePreviewDuration(Duration? duration) {
  final value = duration ?? Duration.zero;
  final totalSeconds = value.inSeconds.clamp(0, 24 * 60 * 60);
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  String _query = '';
  String _serverSearchQuery = '';
  Set<String> _serverSearchChatIds = const <String>{};
  bool _serverSearchLoading = false;
  String? _selectedChatId;
  bool _archived = false;
  _ChatRoleFilter _roleFilter = _ChatRoleFilter.all;
  _ChatContentFilter _contentFilter = _ChatContentFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final value = _searchController.text;
      setState(() => _query = value);
      _scheduleServerChatSearch(value);
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleServerChatSearch(String value) {
    _searchDebounceTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _serverSearchQuery = '';
        _serverSearchChatIds = const <String>{};
        _serverSearchLoading = false;
      });
      return;
    }
    setState(() => _serverSearchLoading = true);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 320), () {
      unawaited(_runServerChatSearch(query));
    });
  }

  Future<void> _runServerChatSearch(String query) async {
    try {
      final ids = await ref
          .read(chatServiceProvider)
          .searchMyChatIds(query: query);
      if (!mounted || _query.trim() != query) return;
      setState(() {
        _serverSearchQuery = query;
        _serverSearchChatIds = ids;
        _serverSearchLoading = false;
      });
    } catch (_) {
      if (!mounted || _query.trim() != query) return;
      setState(() {
        _serverSearchQuery = query;
        _serverSearchChatIds = const <String>{};
        _serverSearchLoading = false;
      });
    }
  }

  Future<void> _setPinned(ChatListItem item, bool value) async {
    await ref
        .read(chatServiceProvider)
        .setChatPinned(chatId: item.id, pinned: value);
    ref.invalidate(myChatsProvider(_archived));
  }

  Future<void> _setArchived(ChatListItem item, bool value) async {
    await ref
        .read(chatServiceProvider)
        .setChatArchived(chatId: item.id, archived: value);
    if (_selectedChatId == item.id) {
      setState(() => _selectedChatId = null);
    }
    ref.invalidate(myChatsProvider(_archived));
    ref.invalidate(myChatsProvider(!_archived));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final chats = ref.watch(myChatsProvider(_archived));
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _chatsDesktopBreakpoint;
    final pagePadding = isDesktop
        ? const EdgeInsets.fromLTRB(32, 24, 32, 28)
        : const EdgeInsets.fromLTRB(16, 18, 16, 24);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: pagePadding,
              child: Column(
                children: [
                  _ChatsHeader(
                    archived: _archived,
                    onArchivedChanged: (value) {
                      setState(() {
                        _archived = value;
                        _selectedChatId = null;
                      });
                    },
                    onInvitations: () => context.go(Routes.invitations),
                  ),
                  const SizedBox(height: 14),
                  _ChatsSearch(
                    controller: _searchController,
                    loading: _serverSearchLoading,
                  ),
                  const SizedBox(height: 14),
                  _ChatRoleSegments(
                    value: _roleFilter,
                    onChanged: (value) {
                      setState(() {
                        _roleFilter = value;
                        _selectedChatId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _ChatContentSegments(
                    value: _contentFilter,
                    onChanged: (value) {
                      setState(() {
                        _contentFilter = value;
                        _selectedChatId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: chats.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _ChatsEmptyState(
                        title: t.errorUpper,
                        message: AppErrorMapper.message(e, t),
                      ),
                      data: (items) {
                        final visible = items
                            .where((item) {
                              final query = _query.trim();
                              final localMatch = item.matches(query);
                              final serverMatch =
                                  _serverSearchQuery == query &&
                                  _serverSearchChatIds.contains(item.id);
                              return (localMatch || serverMatch) &&
                                  _roleFilter.matches(item) &&
                                  _contentFilter.matches(item);
                            })
                            .toList(growable: false);
                        if (visible.isEmpty) {
                          return _ChatsEmptyState(
                            title: _archived
                                ? 'АРХИВ ПУСТ'
                                : _contentFilter == _ChatContentFilter.all
                                ? _roleFilter.emptyTitle
                                : 'НИЧЕГО НЕ НАЙДЕНО',
                            message: _archived
                                ? 'Архивированные диалоги появятся здесь.'
                                : _contentFilter != _ChatContentFilter.all
                                ? 'Попробуйте другой фильтр или очистите поиск.'
                                : _roleFilter.emptyMessage,
                          );
                        }
                        if (isDesktop) {
                          final active = visible.firstWhere(
                            (item) => item.id == _selectedChatId,
                            orElse: () => visible.first,
                          );
                          return _ChatsDesktopLayout(
                            items: visible,
                            selectedChatId: active.id,
                            archived: _archived,
                            onSelect: (item) =>
                                setState(() => _selectedChatId = item.id),
                            onPin: _setPinned,
                            onArchive: _setArchived,
                          );
                        }
                        return RefreshIndicator(
                          color: Colors.black,
                          backgroundColor: Colors.white,
                          onRefresh: () async =>
                              ref.invalidate(myChatsProvider(_archived)),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = visible[index];
                              return _ChatListTile(
                                item: item,
                                selected: false,
                                archived: _archived,
                                onTap: () => context.push(
                                  '${Routes.chatPrefix}${item.id}',
                                ),
                                onPin: () => _setPinned(item, !item.pinned),
                                onArchive: () => _setArchived(item, !_archived),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatsHeader extends StatelessWidget {
  const _ChatsHeader({
    required this.archived,
    required this.onArchivedChanged,
    required this.onInvitations,
  });

  final bool archived;
  final ValueChanged<bool> onArchivedChanged;
  final VoidCallback onInvitations;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('ЧАТЫ', style: _chatTitleStyle(size: 24, spacing: 4)),
        ),
        SizedBox(
          height: 44,
          child: BrandPillButton(
            label: 'ПРИГЛАШЕНИЯ',
            style: BrandPillStyle.light,
            onTap: onInvitations,
          ),
        ),
        const SizedBox(width: 10),
        _ArchiveToggle(archived: archived, onChanged: onArchivedChanged),
      ],
    );
  }
}

class _ArchiveToggle extends StatelessWidget {
  const _ArchiveToggle({required this.archived, required this.onChanged});

  final bool archived;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!archived),
        child: Container(
          width: 46,
          height: 44,
          alignment: Alignment.center,
          decoration: pillDecoration(isDark: archived, radius: 18),
          child: Icon(
            archived ? Icons.markunread_mailbox_rounded : Icons.archive_rounded,
            color: archived ? Colors.white : kTextDark,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _ChatsSearch extends StatelessWidget {
  const _ChatsSearch({required this.controller, required this.loading});

  final TextEditingController controller;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: catalogSearchDecoration(radius: 22),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Поиск по чатам',
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kTextMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatsDesktopLayout extends StatelessWidget {
  const _ChatsDesktopLayout({
    required this.items,
    required this.selectedChatId,
    required this.archived,
    required this.onSelect,
    required this.onPin,
    required this.onArchive,
  });

  final List<ChatListItem> items;
  final String selectedChatId;
  final bool archived;
  final ValueChanged<ChatListItem> onSelect;
  final Future<void> Function(ChatListItem item, bool value) onPin;
  final Future<void> Function(ChatListItem item, bool value) onArchive;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _chatsDesktopMaxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _chatsDesktopListWidth,
              decoration: catalogCardDecoration(),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ChatListTile(
                    item: item,
                    selected: item.id == selectedChatId,
                    archived: archived,
                    onTap: () => onSelect(item),
                    onPin: () => onPin(item, !item.pinned),
                    onArchive: () => onArchive(item, !archived),
                  );
                },
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Container(
                decoration: catalogCardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: ChatPage(
                  key: ValueKey(selectedChatId),
                  chatId: selectedChatId,
                  embedded: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRoleSegments extends StatelessWidget {
  const _ChatRoleSegments({required this.value, required this.onChanged});

  final _ChatRoleFilter value;
  final ValueChanged<_ChatRoleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _ChatRoleFilter.values
            .map((filter) {
              final selected = filter == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onChanged(filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 40,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: pillDecoration(isDark: selected, radius: 999),
                      child: Text(
                        filter.label,
                        style: _chatTitleStyle(
                          color: selected ? Colors.white : kTextMuted,
                          size: 11,
                          spacing: 1,
                          weight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _ChatContentSegments extends StatelessWidget {
  const _ChatContentSegments({required this.value, required this.onChanged});

  final _ChatContentFilter value;
  final ValueChanged<_ChatContentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _ChatContentFilter.values
            .map((filter) {
              final selected = filter == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onChanged(filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 38,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: selected
                            ? kTextDark
                            : Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? kTextDark
                              : kBorderColor.withValues(alpha: 0.82),
                        ),
                        boxShadow: selected
                            ? BrandTheme.basePillShadow(isDark: true)
                            : const [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            filter.icon,
                            size: 15,
                            color: selected ? Colors.white : kTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            filter.label,
                            style: _chatTitleStyle(
                              color: selected ? Colors.white : kTextMuted,
                              size: 10,
                              spacing: 0.8,
                              weight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.item,
    required this.selected,
    required this.archived,
    required this.onTap,
    required this.onPin,
    required this.onArchive,
  });

  final ChatListItem item;
  final bool selected;
  final bool archived;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: catalogCardDecoration().copyWith(
            border: Border.all(
              color: selected
                  ? BrandTheme.redTop.withValues(alpha: 0.58)
                  : Colors.white.withValues(alpha: 0.78),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _ChatAvatarPreview(url: item.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.pinned) ...[
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 15,
                            color: BrandTheme.redTop,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _chatTitleStyle(
                              size: 15,
                              spacing: 0.2,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (item.lastMessageAt != null)
                          Text(
                            _formatChatTime(item.lastMessageAt!),
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ChatContextSummary(item: item),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: item.lastMessageIsAudio
                              ? _ChatVoicePreview(item: item)
                              : Text(
                                  item.lastMessage.isEmpty
                                      ? 'Диалог создан'
                                      : item.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: item.unreadCount > 0
                                        ? kTextDark
                                        : kTextMuted,
                                    fontSize: 13,
                                    fontWeight: item.unreadCount > 0
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                        ),
                        if (item.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            height: 24,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: pillDecoration(
                              isDark: true,
                              radius: 999,
                            ),
                            child: Text(
                              item.unreadCount > 99
                                  ? '99+'
                                  : '${item.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _ChatTileIconButton(
                    icon: item.pinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    onTap: onPin,
                  ),
                  const SizedBox(height: 8),
                  _ChatTileIconButton(
                    icon: archived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded,
                    onTap: onArchive,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatVoicePreview extends StatelessWidget {
  const _ChatVoicePreview({required this.item});

  final ChatListItem item;

  @override
  Widget build(BuildContext context) {
    final unread = item.unreadCount > 0;
    final listened = item.lastMessageAudioListened;
    final duration = _formatVoicePreviewDuration(item.lastMessageAudioDuration);
    return Row(
      children: [
        Icon(
          Icons.mic_rounded,
          size: 15,
          color: unread ? BrandTheme.redTop : kTextMuted,
        ),
        const SizedBox(width: 5),
        Text(
          duration == '00:00' ? 'Голосовое' : duration,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread ? kTextDark : kTextMuted,
            fontSize: 12,
            fontWeight: unread ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: SizedBox(
            height: 18,
            child: CustomPaint(
              painter: _ChatVoicePreviewPainter(
                seed: item.id,
                color: unread ? BrandTheme.redTop : kTextMuted,
              ),
            ),
          ),
        ),
        if (unread || listened) ...[
          const SizedBox(width: 7),
          Text(
            unread ? 'новое' : 'прослушано',
            style: TextStyle(
              color: unread ? BrandTheme.redTop : kTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChatVoicePreviewPainter extends CustomPainter {
  const _ChatVoicePreviewPainter({required this.seed, required this.color});

  final String seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final hash = seed.hashCode.abs();
    final bars = math.max(12, (size.width / 5).floor());
    final step = size.width / bars;
    final barWidth = math.min(2.4, step * 0.52);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.74)
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(barWidth);

    for (var i = 0; i < bars; i++) {
      final wave =
          0.28 +
          0.72 * ((math.sin((i + 2) * ((hash % 13) + 5) * 0.61) + 1) / 2);
      final height = math.max(4.0, size.height * wave);
      final x = i * step + (step - barWidth) / 2;
      final y = (size.height - height) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, height), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatVoicePreviewPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.color != color;
  }
}

class _ChatContextSummary extends StatelessWidget {
  const _ChatContextSummary({required this.item});

  final ChatListItem item;

  List<({String label, IconData icon})> _contextParts() {
    final chunks = item.contextLabel
        .split('•')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final parts = <({String label, IconData icon})>[];
    for (final chunk in chunks) {
      final lower = chunk.toLowerCase();
      if (lower.startsWith('анкета:')) {
        parts.add((
          label: chunk.replaceFirst(RegExp('Анкета:\\s*'), '').trim(),
          icon: Icons.badge_rounded,
        ));
      } else if (lower.startsWith('кастинг:')) {
        parts.add((
          label: chunk.replaceFirst(RegExp('Кастинг:\\s*'), '').trim(),
          icon: Icons.videocam_rounded,
        ));
      } else {
        parts.add((label: chunk, icon: Icons.link_rounded));
      }
    }
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final isClient = item.participantRole == ChatParticipantRole.client;
    final intent = isClient
        ? 'Ваш запрос по анкете / кастингу'
        : 'Пишут по вашей анкете';
    final parts = _contextParts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ChatRoleBadge(role: item.participantRole),
            Text(
              intent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final part in parts)
                _ChatContextChip(icon: part.icon, label: part.label),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChatRoleBadge extends StatelessWidget {
  const _ChatRoleBadge({required this.role});

  final ChatParticipantRole role;

  @override
  Widget build(BuildContext context) {
    final isClient = role == ChatParticipantRole.client;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pillDecoration(isDark: isClient, radius: 999),
      child: Text(
        role.label,
        style: _chatTitleStyle(
          color: isClient ? Colors.white : kTextMuted,
          size: 9,
          spacing: 0.8,
          weight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChatContextChip extends StatelessWidget {
  const _ChatContextChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final clean = label.trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: catalogSearchDecoration(radius: 999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kTextMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              clean,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAvatarPreview extends StatelessWidget {
  const _ChatAvatarPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 58,
        height: 58,
        child: url.trim().isEmpty
            ? Container(
                decoration: catalogPhotoPlaceholderDecoration(),
                child: Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                maxWidthDiskCache: 320,
                placeholder: (_, _) =>
                    Container(decoration: catalogPhotoPlaceholderDecoration()),
                errorWidget: (_, _, _) => Container(
                  decoration: catalogPhotoPlaceholderDecoration(),
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ChatTileIconButton extends StatelessWidget {
  const _ChatTileIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: catalogSearchDecoration(radius: 14),
          child: Icon(icon, color: kTextDark, size: 18),
        ),
      ),
    );
  }
}

class _ChatsEmptyState extends StatelessWidget {
  const _ChatsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        decoration: catalogCardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: _chatTitleStyle(color: kTextMuted, size: 18, spacing: 2.4),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 15,
                height: 1.32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatChatTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
}
