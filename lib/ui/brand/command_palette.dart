import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_providers.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../core/storage_image_variant.dart';
import '../../features/castings/castings_provider.dart';
import '../../features/catalog/catalog_providers.dart';
import '../../features/catalog/model_data.dart';
import '../../features/chat/chat_models.dart';
import '../../features/chat/chat_providers.dart';
import 'ui_constants.dart';

/// Step 39: the command palette. Cmd+K / Ctrl+K opens it from any page of
/// the app shell; `/` does the same (the palette is the global search).
/// Type to find profiles, castings and chats, or jump to a section;
/// ↑ ↓ move, Enter opens, Esc closes.
class CommandPaletteHost extends StatefulWidget {
  const CommandPaletteHost({super.key, required this.child});

  final Widget child;

  @override
  State<CommandPaletteHost> createState() => _CommandPaletteHostState();
}

class _CommandPaletteHostState extends State<CommandPaletteHost> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    if (kIsWeb) HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final command = keyboard.isMetaPressed || keyboard.isControlPressed;
    if (command && key == LogicalKeyboardKey.keyK) {
      _toggle();
      return true;
    }
    if (key == LogicalKeyboardKey.slash &&
        !command &&
        !keyboard.isAltPressed &&
        !_open &&
        !_typing()) {
      _toggle();
      return true;
    }
    return false;
  }

  static bool _typing() {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus == null) return false;
    return focus.widget is EditableText ||
        focus.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _toggle() async {
    if (_open) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    _open = true;
    try {
      await showCommandPalette(context);
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'palette',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, _, _) => const _CommandPalette(),
    transitionBuilder: (context, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.02),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

enum _ItemKind { nav, profile, casting, chat }

class _PaletteItem {
  const _PaletteItem({
    required this.kind,
    required this.title,
    required this.location,
    this.subtitle = '',
    this.keywords = '',
    this.icon,
    this.imageUrl = '',
    this.focalX = 0,
    this.focalY = -0.6,
  });

  final _ItemKind kind;
  final String title;
  final String subtitle;
  final String location;
  final String keywords;
  final IconData? icon;
  final String imageUrl;
  final double focalX;
  final double focalY;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        subtitle.toLowerCase().contains(q) ||
        keywords.toLowerCase().contains(q);
  }
}

class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette();

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';
  int _cursor = 0;
  List<ModelVm> _profiles = const [];
  bool _searching = false;
  String _searchedFor = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    final value = _controller.text;
    if (value == _query) return;
    setState(() {
      _query = value;
      _cursor = 0;
    });
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _profiles = const [];
        _searching = false;
        _searchedFor = '';
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 220), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final found = await ref
          .read(catalogRepositoryProvider)
          .loadApprovedProfilesPage(offset: 0, limit: 6, query: q);
      if (!mounted || _query.trim() != q) return;
      setState(() {
        _profiles = found;
        _searching = false;
        _searchedFor = q;
      });
    } catch (_) {
      if (!mounted || _query.trim() != q) return;
      setState(() {
        _profiles = const [];
        _searching = false;
        _searchedFor = q;
      });
    }
  }

  List<_PaletteItem> _navItems(bool ru, bool admin, bool signedIn) {
    return [
      _PaletteItem(
        kind: _ItemKind.nav,
        title: ru ? 'Каталог' : 'Catalogue',
        location: Routes.search,
        icon: Icons.grid_view_rounded,
        keywords: 'catalog каталог модели models поиск search',
      ),
      _PaletteItem(
        kind: _ItemKind.nav,
        title: ru ? 'Кастинги' : 'Castings',
        location: Routes.castings,
        icon: Icons.video_camera_front_outlined,
        keywords: 'castings кастинги',
      ),
      if (signedIn) ...[
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Чаты' : 'Chats',
          location: Routes.chats,
          icon: Icons.chat_bubble_outline_rounded,
          keywords: 'chats чаты сообщения messages',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Приглашения' : 'Invitations',
          location: Routes.invitations,
          icon: Icons.mail_outline_rounded,
          keywords: 'invitations приглашения',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Папки' : 'Folders',
          location: Routes.agentFolders,
          icon: Icons.folder_outlined,
          keywords: 'folders папки подборки',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Мой аккаунт' : 'My account',
          location: Routes.me,
          icon: Icons.person_outline_rounded,
          keywords: 'account аккаунт профиль profile настройки settings',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Уведомления' : 'Notifications',
          location: Routes.notifications,
          icon: Icons.notifications_none_rounded,
          keywords: 'notifications уведомления',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Тарифы' : 'Plans',
          location: Routes.billing,
          icon: Icons.workspace_premium_outlined,
          keywords: 'billing тарифы оплата pro',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Аналитика' : 'Analytics',
          location: Routes.profileAnalytics,
          icon: Icons.insights_outlined,
          keywords: 'analytics аналитика статистика',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Поддержка' : 'Support',
          location: Routes.support,
          icon: Icons.help_outline_rounded,
          keywords: 'support поддержка помощь help',
        ),
      ],
      if (admin) ...[
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Админка' : 'Admin',
          location: Routes.admin,
          icon: Icons.admin_panel_settings_outlined,
          keywords: 'admin админ',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Админ · Пользователи' : 'Admin · Users',
          location: Routes.adminUsers,
          icon: Icons.people_outline_rounded,
          keywords: 'admin users пользователи',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Админ · Анкеты' : 'Admin · Profiles',
          location: Routes.adminProfiles,
          icon: Icons.badge_outlined,
          keywords: 'admin profiles анкеты',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Админ · Модерация' : 'Admin · Moderation',
          location: Routes.moderationAdmin,
          icon: Icons.verified_user_outlined,
          keywords: 'admin moderation модерация',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Админ · Кастинги' : 'Admin · Castings',
          location: Routes.adminCastings,
          icon: Icons.movie_outlined,
          keywords: 'admin castings кастинги',
        ),
        _PaletteItem(
          kind: _ItemKind.nav,
          title: ru ? 'Админ · Поддержка' : 'Admin · Support',
          location: Routes.adminSupport,
          icon: Icons.support_agent_outlined,
          keywords: 'admin support поддержка',
        ),
      ],
    ];
  }

  void _open(_PaletteItem item) {
    Navigator.of(context, rootNavigator: true).pop();
    // Let the dialog close before the route changes under it.
    final router = GoRouter.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => router.go(item.location));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<_PaletteItem> items) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (items.isEmpty) return KeyEventResult.handled;
      setState(() => _cursor = (_cursor + 1) % items.length);
      _reveal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (items.isEmpty) return KeyEventResult.handled;
      setState(() => _cursor = (_cursor - 1 + items.length) % items.length);
      _reveal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (items.isEmpty) return KeyEventResult.handled;
      _open(items[_cursor.clamp(0, items.length - 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context, rootNavigator: true).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _reveal() {
    if (!_scroll.hasClients) return;
    const rowHeight = 52.0;
    final top = _cursor * rowHeight;
    final viewport = _scroll.position.viewportDimension;
    final offset = _scroll.offset;
    if (top < offset) {
      _scroll.jumpTo(top);
    } else if (top + rowHeight > offset + viewport) {
      _scroll.jumpTo(top + rowHeight - viewport);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final signedIn = ref.watch(isAuthenticatedProvider);
    final admin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final q = _query.trim();

    final nav = _navItems(ru, admin, signedIn)
        .where((item) => item.matches(q))
        .toList(growable: false);

    final castings = q.length < 2
        ? const <_PaletteItem>[]
        : (ref.watch(castingsProvider).valueOrNull ?? const [])
              .where((c) => c.title.toLowerCase().contains(q.toLowerCase()))
              .take(5)
              .map(
                (c) => _PaletteItem(
                  kind: _ItemKind.casting,
                  title: c.title.trim().isEmpty
                      ? (ru ? 'Кастинг' : 'Casting')
                      : c.title.trim(),
                  subtitle: [
                    if (c.datesText.trim().isNotEmpty) c.datesText.trim(),
                    if (c.fee.trim().isNotEmpty) c.fee.trim(),
                  ].join(' · '),
                  location: '${Routes.castings}?casting=${c.id}',
                  icon: Icons.video_camera_front_outlined,
                ),
              )
              .toList(growable: false);

    final chats = q.length < 2 || !signedIn
        ? const <_PaletteItem>[]
        : (ref.watch(myChatsProvider(false)).valueOrNull ??
                  const <ChatListItem>[])
              .where((c) => c.matches(q))
              .take(5)
              .map(
                (c) => _PaletteItem(
                  kind: _ItemKind.chat,
                  title: c.title,
                  subtitle: c.contextLabel
                      .replaceAll('Анкета: ', '')
                      .replaceAll('Кастинг: ', '')
                      .replaceAll(' • ', ' · '),
                  location: Routes.chatLocation(c.id),
                  icon: Icons.chat_bubble_outline_rounded,
                  imageUrl: c.photoUrl,
                ),
              )
              .toList(growable: false);

    final profiles = q.length < 2
        ? const <_PaletteItem>[]
        : _profiles
              .map(
                (m) => _PaletteItem(
                  kind: _ItemKind.profile,
                  title: m.fullName.trim().isEmpty
                      ? (ru ? 'Анкета' : 'Profile')
                      : m.fullName.trim(),
                  subtitle: [
                    if (m.age > 0) (ru ? '${m.age} лет' : '${m.age} y.o.'),
                    if (m.height > 0) '${m.height} ${ru ? 'см' : 'cm'}',
                    if (m.city.trim().isNotEmpty) m.city.trim(),
                  ].join(' · '),
                  location: '${Routes.modelPrefix}${m.id}',
                  icon: Icons.person_outline_rounded,
                  imageUrl: m.coverPhotoUrl.trim().isNotEmpty
                      ? m.coverPhotoUrl
                      : (m.photoUrls.isNotEmpty ? m.photoUrls.first : ''),
                  focalX: m.coverPhotoFocalX,
                  focalY: m.coverPhotoFocalY,
                ),
              )
              .toList(growable: false);

    final sections = <(String, List<_PaletteItem>)>[
      if (profiles.isNotEmpty) (ru ? 'Анкеты' : 'Profiles', profiles),
      if (castings.isNotEmpty) (ru ? 'Кастинги' : 'Castings', castings),
      if (chats.isNotEmpty) (ru ? 'Чаты' : 'Chats', chats),
      if (nav.isNotEmpty) (ru ? 'Переходы' : 'Go to', nav),
    ];
    final flat = [for (final s in sections) ...s.$2];
    if (_cursor >= flat.length) _cursor = 0;

    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = (width - 32).clamp(320.0, 640.0);
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.7).clamp(
      280.0,
      560.0,
    );

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Tokens.bg,
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            border: Border.all(color: Tokens.border),
            boxShadow: Tokens.popoverShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: (node, event) => _onKey(node, event, flat),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: Tokens.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: true,
                          style: AppText.body.copyWith(fontSize: 17),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            hintText: ru
                                ? 'Анкеты, кастинги, чаты, разделы…'
                                : 'Profiles, castings, chats, sections…',
                            hintStyle: AppText.body.copyWith(
                              fontSize: 17,
                              color: Tokens.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        const _Kbd(label: 'Esc'),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Tokens.border),
              Flexible(
                child: flat.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                        child: Text(
                          _searching
                              ? (ru ? 'Ищем…' : 'Searching…')
                              : q.length < 2
                              ? (ru
                                    ? 'Введите хотя бы две буквы'
                                    : 'Type at least two letters')
                              : _searchedFor == q
                              ? (ru ? 'Ничего не нашлось' : 'Nothing found')
                              : (ru ? 'Ищем…' : 'Searching…'),
                          style: AppText.small.copyWith(
                            color: Tokens.textTertiary,
                          ),
                        ),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        children: [
                          for (final section in sections) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                              child: Text(
                                section.$1,
                                style: AppText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Tokens.textTertiary,
                                ),
                              ),
                            ),
                            for (final item in section.$2)
                              _PaletteRow(
                                item: item,
                                active: flat.indexOf(item) == _cursor,
                                onHover: () => setState(
                                  () => _cursor = flat.indexOf(item),
                                ),
                                onTap: () => _open(item),
                              ),
                          ],
                        ],
                      ),
              ),
              const Divider(height: 1, thickness: 1, color: Tokens.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(
                  children: [
                    const _Kbd(label: '↑↓'),
                    const SizedBox(width: 6),
                    Text(
                      ru ? 'выбор' : 'move',
                      style: AppText.caption.copyWith(color: Tokens.textTertiary),
                    ),
                    const SizedBox(width: 14),
                    const _Kbd(label: '↵'),
                    const SizedBox(width: 6),
                    Text(
                      ru ? 'открыть' : 'open',
                      style: AppText.caption.copyWith(color: Tokens.textTertiary),
                    ),
                    const Spacer(),
                    const _Kbd(label: '⌘K'),
                    const SizedBox(width: 6),
                    const _Kbd(label: '/'),
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

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.item,
    required this.active,
    required this.onHover,
    required this.onTap,
  });

  final _PaletteItem item;
  final bool active;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showImage = item.kind != _ItemKind.nav;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          color: active ? Tokens.surfaceAlt : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              if (showImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: item.imageUrl.trim().isEmpty
                        ? ColoredBox(
                            color: Tokens.surfaceAlt,
                            child: Icon(
                              item.icon ?? Icons.circle_outlined,
                              size: 16,
                              color: Tokens.textTertiary,
                            ),
                          )
                        : FocalImage(
                            url: storageImageVariant(item.imageUrl, width: 120),
                            focalX: item.focalX,
                            focalY: item.focalY,
                            memCacheWidth: 120,
                          ),
                  ),
                )
              else
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    item.icon ?? Icons.arrow_forward_rounded,
                    size: 20,
                    color: Tokens.textSecondary,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Tokens.text,
                      ),
                    ),
                    if (item.subtitle.trim().isNotEmpty)
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                  ],
                ),
              ),
              if (active)
                const Icon(
                  Icons.keyboard_return_rounded,
                  size: 16,
                  color: Tokens.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Tokens.borderStrong),
        color: Tokens.surface,
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: Tokens.textSecondary,
        ),
      ),
    );
  }
}
