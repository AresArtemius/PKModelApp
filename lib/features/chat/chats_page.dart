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

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedChatId;
  bool _archived = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                  _ChatsSearch(controller: _searchController),
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
                            .where((item) => item.matches(_query))
                            .toList(growable: false);
                        if (visible.isEmpty) {
                          return _ChatsEmptyState(
                            title: _archived ? 'АРХИВ ПУСТ' : 'ЧАТОВ НЕТ',
                            message: _archived
                                ? 'Архивированные диалоги появятся здесь.'
                                : 'Откройте приглашение или подборку, чтобы начать диалог.',
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
  const _ChatsSearch({required this.controller});

  final TextEditingController controller;

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
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
