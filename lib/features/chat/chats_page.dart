import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../core/tab_alerts.dart';
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

/// v2 (web): the chats page is a full-width two-column layout — the
/// conversation list on the left, the open conversation on the right —
/// with no cards, pills or empty side margins.
const bool _chatsV2 = kIsWeb;
const double _chatsV2ListWidth = 400;

enum _ChatRoleFilter {
  all,
  model,
  client;

  String label(bool ru) {
    return switch (this) {
      _ChatRoleFilter.all => ru ? 'ВСЕ' : 'ALL',
      _ChatRoleFilter.model => ru ? 'КАК МОДЕЛЬ' : 'AS MODEL',
      _ChatRoleFilter.client => ru ? 'КАК ЗАКАЗЧИК' : 'AS CLIENT',
    };
  }

  String labelV2(bool ru) {
    return switch (this) {
      _ChatRoleFilter.all => ru ? 'Все' : 'All',
      _ChatRoleFilter.model => ru ? 'Как модель' : 'As model',
      _ChatRoleFilter.client => ru ? 'Как заказчик' : 'As client',
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

  String emptyTitle(bool ru) {
    return switch (this) {
      _ChatRoleFilter.all => ru ? 'ЧАТОВ НЕТ' : 'NO CHATS',
      _ChatRoleFilter.model =>
        ru ? 'ЧАТОВ КАК МОДЕЛЬ НЕТ' : 'NO CHATS AS MODEL',
      _ChatRoleFilter.client =>
        ru ? 'ЧАТОВ КАК ЗАКАЗЧИК НЕТ' : 'NO CHATS AS CLIENT',
    };
  }

  String emptyMessage(bool ru) {
    return switch (this) {
      _ChatRoleFilter.all =>
        ru
            ? 'Откройте приглашение или подборку, чтобы начать диалог.'
            : 'Open an invitation or selection to start a conversation.',
      _ChatRoleFilter.model =>
        ru
            ? 'Здесь будут диалоги, где пишут по вашим анкетам.'
            : 'Conversations about your profiles will appear here.',
      _ChatRoleFilter.client =>
        ru
            ? 'Здесь будут диалоги, которые вы начали как заказчик.'
            : 'Conversations you started as a client will appear here.',
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

  String label(bool ru) {
    return switch (this) {
      _ChatContentFilter.all => ru ? 'ВСЕ СООБЩЕНИЯ' : 'ALL MESSAGES',
      _ChatContentFilter.unread => ru ? 'НОВЫЕ' : 'UNREAD',
      _ChatContentFilter.pinned => ru ? 'ЗАКРЕП' : 'PINNED',
      _ChatContentFilter.media => ru ? 'МЕДИА' : 'MEDIA',
      _ChatContentFilter.files => ru ? 'ФАЙЛЫ' : 'FILES',
      _ChatContentFilter.voice => ru ? 'ГОЛОСОВЫЕ' : 'VOICE',
    };
  }

  String labelV2(bool ru) {
    return switch (this) {
      _ChatContentFilter.all => ru ? 'Все сообщения' : 'All messages',
      _ChatContentFilter.unread => ru ? 'Непрочитанные' : 'Unread',
      _ChatContentFilter.pinned => ru ? 'Закреплённые' : 'Pinned',
      _ChatContentFilter.media => ru ? 'Медиа' : 'Media',
      _ChatContentFilter.files => ru ? 'Файлы' : 'Files',
      _ChatContentFilter.voice => ru ? 'Голосовые' : 'Voice',
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
  String? _lastQueryChatId;
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

  List<ChatListItem> _visibleItems(List<ChatListItem> items) {
    final query = _query.trim();
    return items
        .where((item) {
          final localMatch = item.matches(query);
          final serverMatch =
              _serverSearchQuery == query &&
              _serverSearchChatIds.contains(item.id);
          return (localMatch || serverMatch) &&
              _roleFilter.matches(item) &&
              _contentFilter.matches(item);
        })
        .toList(growable: false);
  }

  /// `/chats?chat=<id>` opens that conversation: inside the two-column
  /// layout on wide screens, as its own page on narrow ones.
  void _syncQueryChat(BuildContext context, bool isDesktop) {
    final queryChat = GoRouterState.of(
      context,
    ).uri.queryParameters[Routes.chatsChatParam]?.trim();
    if (queryChat == null || queryChat.isEmpty) return;
    if (queryChat == _lastQueryChatId) return;
    _lastQueryChatId = queryChat;
    if (isDesktop) {
      _selectedChatId = queryChat;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push('${Routes.chatPrefix}$queryChat');
    });
  }

  Widget _buildV2(
    BuildContext context, {
    required AppLocalizations t,
    required bool ru,
    required AsyncValue<List<ChatListItem>> chats,
    required bool isDesktop,
  }) {
    final selectedId = _selectedChatId;
    final gutter = isDesktop ? 24.0 : 16.0;
    final listColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, isDesktop ? 20 : 12, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ru
                              ? (_archived ? 'Архив' : 'Чаты')
                              : (_archived ? 'Archive' : 'Chats'),
                          style: AppText.h1.copyWith(fontSize: 32),
                        ),
                      ),
                      _V2IconButton(
                        icon: _archived
                            ? Icons.inbox_outlined
                            : Icons.archive_outlined,
                        tooltip: _archived
                            ? (ru ? 'К диалогам' : 'Back to chats')
                            : (ru ? 'Архив' : 'Archive'),
                        active: _archived,
                        onTap: () => setState(() {
                          _archived = !_archived;
                          _selectedChatId = null;
                        }),
                      ),
                      _V2IconButton(
                        icon: Icons.mail_outline_rounded,
                        tooltip: ru ? 'Приглашения' : 'Invitations',
                        onTap: () => context.go(Routes.invitations),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: _V2SearchField(
                    controller: _searchController,
                    loading: _serverSearchLoading,
                    hint: ru ? 'Поиск по чатам' : 'Search chats',
                    trailing: _V2ContentFilterMenu(
                      value: _contentFilter,
                      onChanged: (value) => setState(() {
                        _contentFilter = value;
                        _selectedChatId = null;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: _V2RoleTabs(
                    value: _roleFilter,
                    onChanged: (value) => setState(() {
                      _roleFilter = value;
                      _selectedChatId = null;
                    }),
                  ),
                ),
                if (_contentFilter != _ChatContentFilter.all)
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
                    child: Row(
                      children: [
                        Icon(
                          _contentFilter.icon,
                          size: 14,
                          color: Tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _contentFilter.labelV2(ru),
                            style: AppText.caption.copyWith(fontSize: 13),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => setState(() {
                            _contentFilter = _ChatContentFilter.all;
                          }),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Tokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, thickness: 1, color: Tokens.border),
                Expanded(
                  child: chats.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: SkeletonList(rows: 7),
                    ),
                    error: (e, _) => _V2EmptyState(
                      title: t.errorUpper,
                      message: AppErrorMapper.message(e, t),
                    ),
                    data: (items) {
                      final visible = _visibleItems(items);
                      if (visible.isEmpty) {
                        return _V2EmptyState(
                          title: _archived
                              ? (ru ? 'Архив пуст' : 'Archive is empty')
                              : _contentFilter == _ChatContentFilter.all
                              ? _sentenceCaseChats(_roleFilter.emptyTitle(ru))
                              : (ru ? 'Ничего не найдено' : 'Nothing found'),
                          message: _archived
                              ? (ru
                                    ? 'Архивированные диалоги появятся здесь.'
                                    : 'Archived conversations will appear here.')
                              : _contentFilter != _ChatContentFilter.all
                              ? (ru
                                    ? 'Попробуйте другой фильтр или очистите поиск.'
                                    : 'Try another filter or clear the search.')
                              : _roleFilter.emptyMessage(ru),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 1,
                          indent: gutter + 66,
                          color: Tokens.border,
                        ),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return _ChatRowV2(
                            gutter: gutter,
                            item: item,
                            selected: isDesktop && item.id == selectedId,
                            archived: _archived,
                            onTap: isDesktop
                                ? () {
                                    unawaited(
                                      ref
                                          .read(tabAlertsProvider)
                                          .requestNotificationPermission(),
                                    );
                                    setState(() => _selectedChatId = item.id);
                                  }
                                : () => context.push(
                                    '${Routes.chatPrefix}${item.id}',
                                  ),
                            onPin: () => _setPinned(item, !item.pinned),
                            onArchive: () => _setArchived(item, !_archived),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );

    if (!isDesktop) {
      // Phone-width web: the list fills the screen, a chat opens as its
      // own page (/chat/:id) with a back arrow.
      return Scaffold(backgroundColor: Tokens.bg, body: listColumn);
    }

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: _chatsV2ListWidth, child: listColumn),
          const VerticalDivider(width: 1, thickness: 1, color: Tokens.border),
          Expanded(
            child: selectedId == null || selectedId.isEmpty
                ? _V2NoChatSelected(ru: ru)
                : ChatPage(
                    key: ValueKey(selectedId),
                    chatId: selectedId,
                    embedded: true,
                    onClose: () => setState(() => _selectedChatId = null),
                  ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final chats = ref.watch(myChatsProvider(_archived));
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _chatsDesktopBreakpoint;
    _syncQueryChat(context, isDesktop);
    if (_chatsV2) {
      return _buildV2(context, t: t, ru: ru, chats: chats, isDesktop: isDesktop);
    }
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
                      loading: () => const SkeletonList(rows: 7),
                      error: (e, _) => _ChatsEmptyState(
                        title: t.errorUpper,
                        message: AppErrorMapper.message(e, t),
                      ),
                      data: (items) {
                        final visible = _visibleItems(items);
                        if (visible.isEmpty) {
                          return _ChatsEmptyState(
                            title: _archived
                                ? (ru ? 'АРХИВ ПУСТ' : 'ARCHIVE IS EMPTY')
                                : _contentFilter == _ChatContentFilter.all
                                ? _roleFilter.emptyTitle(ru)
                                : (ru ? 'НИЧЕГО НЕ НАЙДЕНО' : 'NOTHING FOUND'),
                            message: _archived
                                ? (ru
                                      ? 'Архивированные диалоги появятся здесь.'
                                      : 'Archived conversations will appear here.')
                                : _contentFilter != _ChatContentFilter.all
                                ? (ru
                                      ? 'Попробуйте другой фильтр или очистите поиск.'
                                      : 'Try another filter or clear the search.')
                                : _roleFilter.emptyMessage(ru),
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
                            onSelect: (item) {
                              // A click is the user gesture the browser
                              // wants before asking about notifications.
                              unawaited(
                                ref
                                    .read(tabAlertsProvider)
                                    .requestNotificationPermission(),
                              );
                              setState(() => _selectedChatId = item.id);
                            },
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

String _sentenceCaseChats(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

class _V2IconButton extends StatelessWidget {
  const _V2IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 22,
      style: IconButton.styleFrom(
        foregroundColor: active ? Tokens.accent : Tokens.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

class _V2SearchField extends StatelessWidget {
  const _V2SearchField({
    required this.controller,
    required this.loading,
    required this.hint,
    required this.trailing,
  });

  final TextEditingController controller;
  final bool loading;
  final String hint;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Tokens.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppText.small,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: AppText.small.copyWith(color: Tokens.textTertiary),
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tokens.textSecondary,
                ),
              ),
            ),
          trailing,
        ],
      ),
    );
  }
}

class _V2ContentFilterMenu extends StatelessWidget {
  const _V2ContentFilterMenu({required this.value, required this.onChanged});

  final _ChatContentFilter value;
  final ValueChanged<_ChatContentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final active = value != _ChatContentFilter.all;
    return PopupMenuButton<_ChatContentFilter>(
      tooltip: ru ? 'Фильтр' : 'Filter',
      onSelected: onChanged,
      color: Tokens.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.border),
      ),
      itemBuilder: (context) => [
        for (final filter in _ChatContentFilter.values)
          PopupMenuItem<_ChatContentFilter>(
            value: filter,
            height: 40,
            child: Row(
              children: [
                Icon(
                  filter.icon,
                  size: 18,
                  color: filter == value ? Tokens.ink : Tokens.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    filter.labelV2(ru),
                    style: filter == value
                        ? AppText.smallStrong
                        : AppText.small,
                  ),
                ),
                if (filter == value)
                  const Icon(Icons.check_rounded, size: 18, color: Tokens.ink),
              ],
            ),
          ),
      ],
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          Icons.tune_rounded,
          size: 20,
          color: active ? Tokens.accent : Tokens.textSecondary,
        ),
      ),
    );
  }
}

class _V2RoleTabs extends StatelessWidget {
  const _V2RoleTabs({required this.value, required this.onChanged});

  final _ChatRoleFilter value;
  final ValueChanged<_ChatRoleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Row(
      children: [
        for (final filter in _ChatRoleFilter.values) ...[
          InkWell(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            onTap: () => onChanged(filter),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.labelV2(ru),
                    style: AppText.small.copyWith(
                      fontSize: 15,
                      fontWeight: filter == value
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: filter == value
                          ? Tokens.ink
                          : Tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: Tokens.fast,
                    height: 2,
                    width: 28,
                    color: filter == value
                        ? Tokens.accent
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
        ],
      ],
    );
  }
}

class _ChatRowV2 extends StatefulWidget {
  const _ChatRowV2({
    required this.item,
    required this.selected,
    required this.archived,
    required this.onTap,
    required this.onPin,
    required this.onArchive,
    this.gutter = 24,
  });

  final double gutter;
  final ChatListItem item;
  final bool selected;
  final bool archived;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onArchive;

  @override
  State<_ChatRowV2> createState() => _ChatRowV2State();
}

class _ChatRowV2State extends State<_ChatRowV2> {
  bool _hovered = false;

  String _contextLine() {
    return widget.item.contextLabel
        .split('•')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(
          (chunk) => chunk
              .replaceFirst(RegExp(r'^Анкета:\s*'), '')
              .replaceFirst(RegExp(r'^Кастинг:\s*'), ''),
        )
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final unread = item.unreadCount > 0;
    final contextLine = _contextLine();
    final hasLast = item.lastMessage.trim().isNotEmpty;
    final preview = hasLast
        ? item.lastMessage.trim()
        : (ru ? 'Нет сообщений' : 'No messages');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: widget.selected
            ? Tokens.surfaceAlt
            : _hovered
            ? Tokens.surface
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(widget.gutter, 14, 20, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _V2Avatar(url: item.photoUrl, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.pinned) ...[
                                const Icon(
                                  Icons.push_pin_rounded,
                                  size: 14,
                                  color: Tokens.textTertiary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.smallStrong.copyWith(
                                    fontSize: 15,
                                    height: 1.3,
                                    color: Tokens.ink,
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (item.lastMessageAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _formatChatTime(item.lastMessageAt!),
                                  style: AppText.caption.copyWith(
                                    color: unread
                                        ? Tokens.ink
                                        : Tokens.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (contextLine.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              contextLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                fontSize: 13,
                                color: Tokens.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (hasLast && item.lastMessageMine) ...[
                                Icon(
                                  item.lastMessageDelivered
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size: 15,
                                  color: item.lastMessageRead
                                      ? Tokens.accent
                                      : Tokens.textTertiary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: item.lastMessageIsAudio
                                    ? _ChatVoicePreview(item: item)
                                    : Text(
                                        preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.small.copyWith(
                                          color: !hasLast
                                              ? Tokens.textTertiary
                                              : unread
                                              ? Tokens.ink
                                              : Tokens.textSecondary,
                                          fontWeight: unread
                                              ? FontWeight.w500
                                              : FontWeight.w400,
                                        ),
                                      ),
                              ),
                              if (unread) ...[
                                const SizedBox(width: 10),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 22,
                                  ),
                                  height: 22,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Tokens.accent,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    item.unreadCount > 99
                                        ? '99+'
                                        : '${item.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.selected)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 3,
                    child: ColoredBox(color: Tokens.accent),
                  ),
                ),
              if (_hovered)
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _V2RowAction(
                        icon: item.pinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        tooltip: item.pinned
                            ? (ru ? 'Открепить' : 'Unpin')
                            : (ru ? 'Закрепить' : 'Pin'),
                        onTap: widget.onPin,
                      ),
                      const SizedBox(width: 4),
                      _V2RowAction(
                        icon: widget.archived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        tooltip: widget.archived
                            ? (ru ? 'Вернуть из архива' : 'Unarchive')
                            : (ru ? 'В архив' : 'Archive'),
                        onTap: widget.onArchive,
                      ),
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

class _V2RowAction extends StatelessWidget {
  const _V2RowAction({
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
        color: Tokens.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          side: const BorderSide(color: Tokens.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 16, color: Tokens.ink),
          ),
        ),
      ),
    );
  }
}

class _V2Avatar extends StatelessWidget {
  const _V2Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clean = url.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: SizedBox(
        width: size,
        height: size,
        child: clean.isEmpty
            ? const ColoredBox(
                color: Tokens.surfaceAlt,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Tokens.textTertiary,
                ),
              )
            : CachedNetworkImage(
                imageUrl: clean,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.6),
                memCacheWidth: 200,
                maxWidthDiskCache: 400,
                placeholder: (_, _) =>
                    const ColoredBox(color: Tokens.surfaceAlt),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Tokens.surfaceAlt,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Tokens.textTertiary,
                  ),
                ),
              ),
      ),
    );
  }
}

class _V2EmptyState extends StatelessWidget {
  const _V2EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _sentenceCaseChats(title),
              textAlign: TextAlign.center,
              style: AppText.h2,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.small.copyWith(color: Tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _V2NoChatSelected extends StatelessWidget {
  const _V2NoChatSelected({required this.ru});

  final bool ru;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ru ? 'Выберите диалог' : 'Select a conversation',
            style: AppText.h2.copyWith(color: Tokens.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            ru
                ? 'Переписка откроется здесь.'
                : 'The conversation will open here.',
            style: AppText.small.copyWith(color: Tokens.textSecondary),
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Row(
      children: [
        Expanded(
          child: Text(
            ru ? 'ЧАТЫ' : 'CHATS',
            style: _chatTitleStyle(size: 24, spacing: 4),
          ),
        ),
        SizedBox(
          height: 44,
          child: BrandPillButton(
            label: ru ? 'ПРИГЛАШЕНИЯ' : 'INVITATIONS',
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
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
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: ru ? 'Поиск по чатам' : 'Search chats',
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
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
                        filter.label(ru),
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
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
                            filter.label(ru),
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final intent = isClient
        ? (ru
              ? 'Ваш запрос по анкете / кастингу'
              : 'Your profile / casting request')
        : (ru ? 'Пишут по вашей анкете' : 'A message about your profile');
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pillDecoration(isDark: isClient, radius: 999),
      child: Text(
        role.label(ru),
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
