import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../core/storage_image_variant.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/ui_constants.dart';
import 'agent_workspace.dart';

const double _foldersDesktopBreakpoint = 900;
const double _foldersListWidth = 380;

String _foldersText(BuildContext context, String ru, String en) {
  return Localizations.localeOf(context).languageCode == 'ru' ? ru : en;
}

String _profilesCount(BuildContext context, int n) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  if (!ru) return n == 1 ? '1 profile' : '$n profiles';
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return '$n анкета';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$n анкеты';
  }
  return '$n анкет';
}

String _foldersCount(BuildContext context, int n) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  if (!ru) return n == 1 ? '1 folder' : '$n folders';
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return '$n папка';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$n папки';
  }
  return '$n папок';
}

/// Agent folders (v2): a folder list on the left, the selected folder's
/// profiles as a card grid on the right; on narrow screens the two are
/// separate screens (`?folder=` carries the open one).
class AgentFoldersPage extends ConsumerStatefulWidget {
  const AgentFoldersPage({super.key});

  @override
  ConsumerState<AgentFoldersPage> createState() => _AgentFoldersPageState();
}

class _AgentFoldersPageState extends ConsumerState<AgentFoldersPage> {
  String? _selectedId;

  String? _folderFromUrl() {
    final value = GoRouterState.of(context).uri.queryParameters['folder'];
    return (value == null || value.isEmpty) ? null : value;
  }

  void _select(String? id, {required bool isDesktop}) {
    setState(() => _selectedId = id);
    final uri = Uri(
      path: Routes.agentFolders,
      queryParameters: id == null ? null : {'folder': id},
    );
    if (isDesktop) {
      context.replace(uri.toString());
    } else {
      context.push(uri.toString());
    }
  }

  Future<void> _createFolder() async {
    final t = AppLocalizations.of(context)!;
    final title = await _promptFolderTitle(
      context,
      title: t.agentFolderCreateTitle,
    );
    if (title == null || !mounted) return;
    final folder = await ref
        .read(agentWorkspaceServiceProvider)
        .findOrCreateFolder(title);
    ref.invalidate(agentFoldersProvider);
    if (!mounted || folder == null) return;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _foldersDesktopBreakpoint;
    _select(folder.id, isDesktop: isDesktop);
  }

  Future<void> _renameFolder(AgentFolder folder) async {
    final title = await _promptFolderTitle(
      context,
      title: _foldersText(context, 'Переименовать папку', 'Rename folder'),
      initial: folder.title,
    );
    if (title == null || !mounted) return;
    await ref.read(agentWorkspaceServiceProvider).renameFolder(folder.id, title);
    ref
      ..invalidate(agentFoldersProvider)
      ..invalidate(agentFolderDetailsProvider(folder.id));
  }

  Future<void> _deleteFolder(AgentFolder folder) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _foldersText(
            ctx,
            'Удалить папку «${folder.title}»?',
            'Delete folder “${folder.title}”?',
          ),
        ),
        content: Text(
          _foldersText(
            ctx,
            'Анкеты останутся в каталоге, удалится только папка.',
            'Profiles stay in the catalogue; only the folder is removed.',
          ),
          style: AppText.small.copyWith(color: Tokens.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
            child: Text(_foldersText(ctx, 'Удалить', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(agentWorkspaceServiceProvider).deleteFolder(folder.id);
    ref.invalidate(agentFoldersProvider);
    if (!mounted) return;
    if (_selectedId == folder.id) {
      final isDesktop =
          MediaQuery.sizeOf(context).width >= _foldersDesktopBreakpoint;
      _select(null, isDesktop: isDesktop);
    }
  }

  Future<void> _removeProfile(AgentFolder folder, AgentFolderProfile p) async {
    await ref
        .read(agentWorkspaceServiceProvider)
        .setProfileInFolder(
          folderId: folder.id,
          profileId: p.id,
          selected: false,
        );
    ref.invalidate(agentFolderDetailsProvider(folder.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _foldersText(
            context,
            '${p.fullName} убрана из «${folder.title}»',
            '${p.fullName} removed from “${folder.title}”',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final canUse = ref.watch(canCreateSelectionsProvider);
    final folders = ref.watch(agentFoldersProvider);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _foldersDesktopBreakpoint;
    final urlFolder = _folderFromUrl();
    final selectedId = _selectedId ?? urlFolder;

    Widget guard(Widget Function(List<AgentFolder> items) body) {
      return canUse.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _FoldersEmptyState(
          icon: Icons.cloud_off_rounded,
          title: AppErrorMapper.message(e, t),
        ),
        data: (allowed) {
          if (!allowed) {
            return _FoldersEmptyState(
              icon: Icons.lock_outline_rounded,
              title: _foldersText(
                context,
                'Папки доступны агентствам',
                'Folders are for agencies',
              ),
            );
          }
          return folders.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: SkeletonList(rows: 5, leadingSize: 56),
            ),
            error: (e, _) => _FoldersEmptyState(
              icon: Icons.cloud_off_rounded,
              title: AppErrorMapper.message(e, t),
              actionLabel: _foldersText(context, 'Повторить', 'Retry'),
              onAction: () => ref.invalidate(agentFoldersProvider),
            ),
            data: body,
          );
        },
      );
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Tokens.bg,
        body: guard((items) {
          if (items.isEmpty) {
            return _FoldersEmptyState(
              icon: Icons.folder_open_outlined,
              title: t.agentNoFolders,
              hint: _foldersText(
                context,
                'Собирайте анкеты в папки — из каталога кнопкой «В подборку» или создайте папку сейчас.',
                'Collect profiles into folders — from the catalogue with “Add to selection”, or create one now.',
              ),
              actionLabel: _foldersText(
                context,
                'Создать папку',
                'Create folder',
              ),
              onAction: _createFolder,
              secondaryLabel: _foldersText(
                context,
                'Открыть каталог',
                'Open catalogue',
              ),
              onSecondary: () => context.go(Routes.search),
            );
          }
          final selected = items.firstWhere(
            (f) => f.id == selectedId,
            orElse: () => items.first,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _foldersListWidth,
                child: _FolderList(
                  items: items,
                  selectedId: selected.id,
                  onSelect: (f) => _select(f.id, isDesktop: true),
                  onCreate: _createFolder,
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Tokens.border,
              ),
              Expanded(
                child: _FolderDetail(
                  folder: selected,
                  onRename: () => _renameFolder(selected),
                  onDelete: () => _deleteFolder(selected),
                  onRemoveProfile: (p) => _removeProfile(selected, p),
                ),
              ),
            ],
          );
        }),
      );
    }

    // Mobile: list, or one folder when ?folder= is set.
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: guard((items) {
          AgentFolder? open;
          for (final f in items) {
            if (f.id == urlFolder) open = f;
          }
          if (open != null) {
            return _FolderDetail(
              folder: open,
              onBack: () => context.go(Routes.agentFolders),
              onRename: () => _renameFolder(open),
              onDelete: () => _deleteFolder(open),
              onRemoveProfile: (p) => _removeProfile(open, p),
            );
          }
          if (items.isEmpty) {
            return Column(
              children: [
                _MobileTitleBar(
                  title: _foldersText(context, 'Мои папки', 'My folders'),
                  onBack: () => context.go(Routes.search),
                ),
                Expanded(
                  child: _FoldersEmptyState(
                    icon: Icons.folder_open_outlined,
                    title: t.agentNoFolders,
                    hint: _foldersText(
                      context,
                      'Собирайте анкеты в папки — из каталога кнопкой «В подборку» или создайте папку сейчас.',
                      'Collect profiles into folders — from the catalogue with “Add to selection”, or create one now.',
                    ),
                    actionLabel: _foldersText(
                      context,
                      'Создать папку',
                      'Create folder',
                    ),
                    onAction: _createFolder,
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              _MobileTitleBar(
                title: _foldersText(context, 'Мои папки', 'My folders'),
                onBack: () => context.go(Routes.search),
                trailing: IconButton(
                  tooltip: t.agentFolderCreateTitle,
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              ),
              Expanded(
                child: _FolderList(
                  items: items,
                  selectedId: null,
                  onSelect: (f) => _select(f.id, isDesktop: false),
                  onCreate: null,
                  compact: true,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

Future<String?> _promptFolderTitle(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final t = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: t.agentFolderName),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(t.save),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
}

/// Left column / mobile list: title, «new folder», one row per folder with
/// a cover from its first profile and the count.
class _FolderList extends ConsumerWidget {
  const _FolderList({
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    this.compact = false,
  });

  final List<AgentFolder> items;
  final String? selectedId;
  final ValueChanged<AgentFolder> onSelect;
  final VoidCallback? onCreate;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 36, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _foldersText(context, 'Мои папки', 'My folders'),
                        style: AppText.h1.copyWith(fontSize: 32),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _foldersCount(context, items.length),
                        style: AppText.small.copyWith(
                          color: Tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCreate != null)
                  Tooltip(
                    message: AppLocalizations.of(context)!.agentFolderCreateTitle,
                    child: IconButton.filled(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Tokens.ink,
                        foregroundColor: Tokens.textOnDark,
                        fixedSize: const Size(40, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: Tokens.accent,
            backgroundColor: Tokens.bg,
            onRefresh: () async => ref.invalidate(agentFoldersProvider),
            child: ListView.separated(
              padding: compact
                  ? const EdgeInsets.fromLTRB(16, 4, 16, 24)
                  : const EdgeInsets.fromLTRB(32, 0, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, thickness: 1, color: Tokens.border),
              itemBuilder: (context, index) {
                final folder = items[index];
                return _FolderRow(
                  folder: folder,
                  selected: folder.id == selectedId,
                  onTap: () => onSelect(folder),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FolderRow extends ConsumerWidget {
  const _FolderRow({
    required this.folder,
    required this.selected,
    required this.onTap,
  });

  final AgentFolder folder;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(agentFolderDetailsProvider(folder.id));
    final profiles = details.value?.profiles ?? const <AgentFolderProfile>[];
    final covers = profiles
        .map((p) => p.photoUrl)
        .where((u) => u.isNotEmpty)
        .take(3)
        .toList(growable: false);
    final countText = details.isLoading
        ? ''
        : (profiles.isEmpty
              ? _foldersText(context, 'Пусто', 'Empty')
              : _profilesCount(context, profiles.length));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: Tokens.surface,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Tokens.fast,
                width: 2,
                height: 56,
                margin: const EdgeInsets.only(right: 16),
                color: selected ? Tokens.accent : Colors.transparent,
              ),
              _FolderCovers(urls: covers),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(
                        fontSize: 17,
                        color: selected ? Tokens.text : const Color(0xFF3A3A3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(countText, style: AppText.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to three stacked thumbnails — a folder «cover».
class _FolderCovers extends StatelessWidget {
  const _FolderCovers({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: const Icon(
          Icons.folder_outlined,
          color: Tokens.textTertiary,
          size: 24,
        ),
      );
    }
    return SizedBox(
      width: 56 + 10.0 * (urls.length - 1),
      height: 56,
      child: Stack(
        children: [
          for (var i = urls.length - 1; i >= 0; i--)
            Positioned(
              left: 10.0 * i,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  border: Border.all(color: Tokens.bg, width: 2),
                  color: Tokens.surfaceAlt,
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: storageImageVariant(urls[i], width: 160),
                  fit: BoxFit.cover,
                  memCacheWidth: 160,
                  placeholder: (_, _) =>
                      const ColoredBox(color: Tokens.surfaceAlt),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: Tokens.surfaceAlt),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Right column / mobile screen: folder title, actions and the card grid.
class _FolderDetail extends ConsumerWidget {
  const _FolderDetail({
    required this.folder,
    required this.onRename,
    required this.onDelete,
    required this.onRemoveProfile,
    this.onBack,
  });

  final AgentFolder folder;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ValueChanged<AgentFolderProfile> onRemoveProfile;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final details = ref.watch(agentFolderDetailsProvider(folder.id));
    final mobile = onBack != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = mobile
            ? const EdgeInsets.fromLTRB(16, 8, 16, 32)
            : const EdgeInsets.fromLTRB(40, 36, 40, 48);
        final columns = ((constraints.maxWidth - padding.horizontal + 16) /
                (220 + 16))
            .floor()
            .clamp(2, 6);
        return RefreshIndicator(
          color: Tokens.accent,
          backgroundColor: Tokens.bg,
          onRefresh: () async =>
              ref.invalidate(agentFolderDetailsProvider(folder.id)),
          child: ListView(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (mobile)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onBack,
                    style: TextButton.styleFrom(
                      foregroundColor: Tokens.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(_foldersText(context, 'Мои папки', 'My folders')),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.title,
                          style: AppText.display.copyWith(
                            fontSize: mobile ? 28 : 36,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          details.when(
                            loading: () => t.loadingDots,
                            error: (_, _) => '',
                            data: (d) {
                              final n = d?.profiles.length ?? 0;
                              return n == 0
                                  ? t.agentFolderEmpty
                                  : _profilesCount(context, n);
                            },
                          ),
                          style: AppText.small.copyWith(
                            color: Tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  PopupMenuButton<String>(
                    tooltip: _foldersText(context, 'Действия', 'Actions'),
                    position: PopupMenuPosition.under,
                    onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(
                          _foldersText(context, 'Переименовать', 'Rename'),
                          style: AppText.small,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          _foldersText(context, 'Удалить папку', 'Delete folder'),
                          style: AppText.small.copyWith(color: Tokens.danger),
                        ),
                      ),
                    ],
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Tokens.radiusSm),
                        border: Border.all(color: Tokens.border),
                      ),
                      child: const Icon(Icons.more_horiz_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              details.when(
                loading: () => SkeletonCardGrid(columns: columns, rows: 1),
                error: (e, _) => _FoldersEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: AppErrorMapper.message(e, t),
                  actionLabel: _foldersText(context, 'Повторить', 'Retry'),
                  onAction: () =>
                      ref.invalidate(agentFolderDetailsProvider(folder.id)),
                ),
                data: (d) {
                  final profiles = d?.profiles ?? const <AgentFolderProfile>[];
                  if (profiles.isEmpty) {
                    return _FoldersEmptyState(
                      icon: Icons.person_search_outlined,
                      title: t.agentFolderEmpty,
                      hint: _foldersText(
                        context,
                        'Откройте каталог и нажмите «В подборку» у нужной анкеты.',
                        'Open the catalogue and press “Add to selection” on a profile.',
                      ),
                      actionLabel: _foldersText(
                        context,
                        'Открыть каталог',
                        'Open catalogue',
                      ),
                      onAction: () => context.go(Routes.search),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: profiles.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
                      childAspectRatio: 3 / 4.7,
                    ),
                    itemBuilder: (context, i) => _FolderProfileCard(
                      profile: profiles[i],
                      onOpen: () =>
                          context.push('${Routes.modelPrefix}${profiles[i].id}'),
                      onRemove: () => onRemoveProfile(profiles[i]),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Catalogue-style card: 3:4 photo, name, facts; «remove» on hover.
class _FolderProfileCard extends StatefulWidget {
  const _FolderProfileCard({
    required this.profile,
    required this.onOpen,
    required this.onRemove,
  });

  final AgentFolderProfile profile;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  State<_FolderProfileCard> createState() => _FolderProfileCardState();
}

class _FolderProfileCardState extends State<_FolderProfileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final p = widget.profile;
    final facts = [
      if (p.age > 0) t.ageYears(p.age),
      if (p.height > 0) '${p.height} ${t.cm}',
      if (p.city.isNotEmpty) p.city,
    ].join(' · ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    child: p.photoUrl.isEmpty
                        ? const ColoredBox(
                            color: Tokens.surfaceAlt,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: Tokens.textTertiary,
                              size: 40,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: storageImageVariant(
                              p.photoUrl,
                              width: kCatalogCardImageWidth,
                            ),
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            placeholder: (_, _) =>
                                const ColoredBox(color: Tokens.surfaceAlt),
                            errorWidget: (_, _, _) =>
                                const ColoredBox(color: Tokens.surfaceAlt),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedOpacity(
                      duration: Tokens.fast,
                      opacity: _hovered ? 1 : 0,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: widget.onRemove,
                          child: Tooltip(
                            message: _foldersText(
                              context,
                              'Убрать из папки',
                              'Remove from folder',
                            ),
                            child: const SizedBox(
                              width: 30,
                              height: 30,
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Tokens.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p.fullName.isEmpty ? '—' : p.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.smallStrong,
            ),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                facts,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileTitleBar extends StatelessWidget {
  const _MobileTitleBar({
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(title, style: AppText.h2)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Empty / error state: icon, one line, optional hint and actions.
class _FoldersEmptyState extends StatelessWidget {
  const _FoldersEmptyState({
    required this.icon,
    required this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Tokens.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 32, color: Tokens.textSecondary),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: AppText.h2),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, Tokens.controlHeight),
                      ),
                      child: Text(actionLabel!),
                    ),
                    if (secondaryLabel != null)
                      OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(160, Tokens.controlHeight),
                        ),
                        child: Text(secondaryLabel!),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
