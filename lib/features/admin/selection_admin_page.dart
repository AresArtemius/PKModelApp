import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_action_log_service.dart';
import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';
import 'selection_providers.dart';
import 'selection_status.dart';

const _bg = BrandTheme.greyMid;
const _text = kTextDark;

class SelectionAdminPage extends ConsumerStatefulWidget {
  const SelectionAdminPage({super.key});

  @override
  ConsumerState<SelectionAdminPage> createState() => _SelectionAdminPageState();
}

class _SelectionAdminPageState extends ConsumerState<SelectionAdminPage> {
  final Set<String> _selectedIds = <String>{};
  final Map<String, String> _selectedKinds = <String, String>{};
  bool _isDeleting = false;

  void _toggleSelected(String id, String kind) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedKinds.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedKinds[id] = kind;
      }
    });
  }

  void _clearSelected() {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _selectedIds.clear();
      _selectedKinds.clear();
    });
  }

  Future<bool> _confirmDelete({required int count}) async {
    final t = AppLocalizations.of(context)!;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: catalogDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.deleteUpper,
                textAlign: TextAlign.center,
                style: adminCommandStyle(size: 18, letterSpacing: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                t.deleteSelectedItemsConfirm(count),
                textAlign: TextAlign.center,
                style: adminBodyStyle(color: _text, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: t.cancelUpper,
                      isDark: false,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: t.deleteUpper,
                      isDark: true,
                      onTap: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }

  Future<void> _deleteSelected({bool skipConfirm = false}) async {
    if (_selectedIds.isEmpty || _isDeleting) return;

    final t = AppLocalizations.of(context)!;
    final confirmed =
        skipConfirm || await _confirmDelete(count: _selectedIds.length);
    if (!mounted || !confirmed) return;

    setState(() => _isDeleting = true);

    try {
      final sb = ref.read(supabaseProvider);

      final selectionIds = _selectedIds
          .where((id) => _selectedKinds[id] == 'selection')
          .toList(growable: false);

      final castingIds = _selectedIds
          .where((id) => _selectedKinds[id] == 'casting')
          .toList(growable: false);

      await sb.rpc(
        'admin_delete_selection_entities',
        params: {'p_selection_ids': selectionIds, 'p_casting_ids': castingIds},
      );
      await AdminActionLogService(sb).log(
        actionType: 'selection_entities_bulk_deleted',
        title: 'Массовое удаление подборок',
        description:
            'Удалено подборок: ${selectionIds.length}; кастингов: ${castingIds.length}.',
        targetTable: 'selections',
        targetText: '${selectionIds.length + castingIds.length} объектов',
        status: 'deleted',
        metadata: {
          'selection_ids': selectionIds,
          'casting_ids': castingIds,
          'total': selectionIds.length + castingIds.length,
        },
      );

      if (!mounted) return;

      _clearSelected();
      ref.invalidate(adminSelectionListProvider);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${t.deleteUpper}: ${selectionIds.length + castingIds.length}',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${t.errorUpper}: ${AppErrorMapper.message(e, t)}'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _deleteSelectedV2() async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'Удалить выбранное?' : 'Delete selected?'),
        content: Text(
          ru
              ? 'Будут удалены $count объект(ов) вместе с их анкетами и откликами. Это нельзя отменить.'
              : '$count item(s) will be deleted with their profiles and responses. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ru ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
            child: Text(ru ? 'Удалить' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteSelected(skipConfirm: true);
  }

  String _dateV2(dynamic raw, bool ru) {
    final at = DateTime.tryParse('${raw ?? ''}');
    if (at == null) return '';
    final local = at.toLocal();
    const monthsRu = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = ru ? monthsRu[local.month - 1] : monthsEn[local.month - 1];
    final sameYear = local.year == DateTime.now().year;
    if (ru) return sameYear ? '${local.day} $month' : '${local.day} $month ${local.year}';
    return sameYear ? '$month ${local.day}' : '$month ${local.day}, ${local.year}';
  }

  Widget _buildV2(AppLocalizations t, AsyncValue<List<Map<String, dynamic>>> itemsAsync) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    final gutter = wide ? 32.0 : 16.0;
    final items = itemsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final castings = items.where((e) => e['_kind'] == 'casting').length;
    final selections = items.length - castings;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(gutter, wide ? 28 : 20, gutter, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ru ? 'Подборки' : 'Selections',
                  style: AppText.h1.copyWith(fontSize: wide ? 32 : 28),
                ),
                const SizedBox(height: 4),
                Text(
                  itemsAsync.isLoading
                      ? (ru ? 'Загрузка…' : 'Loading…')
                      : items.isEmpty
                      ? (ru ? 'Пока пусто' : 'Nothing yet')
                      : (ru
                            ? 'Подборок: $selections · кастингов: $castings'
                            : 'Selections: $selections · castings: $castings'),
                  style: AppText.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            TextButton(
              onPressed: _clearSelected,
              style: TextButton.styleFrom(foregroundColor: Tokens.textSecondary),
              child: Text(ru ? 'Сбросить' : 'Clear'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _isDeleting ? null : _deleteSelectedV2,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.danger,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                ru
                    ? 'Удалить (${_selectedIds.length})'
                    : 'Delete (${_selectedIds.length})',
              ),
            ),
          ] else
            IconButton(
              tooltip: ru ? 'Обновить' : 'Refresh',
              onPressed: () => ref.invalidate(adminSelectionListProvider),
              style: IconButton.styleFrom(foregroundColor: Tokens.textSecondary),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
        ],
      ),
    );

    final body = itemsAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.all(gutter),
        child: const SkeletonList(rows: 6),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(gutter),
        child: Text(
          AppErrorMapper.message(e, t),
          style: AppText.small.copyWith(color: Tokens.danger),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ru ? 'Подборок пока нет' : 'No selections yet',
                  style: AppText.h2.copyWith(color: Tokens.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  ru
                      ? 'Создайте подборку из каталога или кастинг — они появятся здесь.'
                      : 'Create a selection from the catalogue or a casting — they will show up here.',
                  style: AppText.small.copyWith(color: Tokens.textTertiary),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in items)
              _SelectionRowV2(
                row: row,
                gutter: gutter,
                selected: _selectedIds.contains((row['id'] ?? '').toString()),
                date: _dateV2(row['created_at'], ru),
                onToggle: () => _toggleSelected(
                  (row['id'] ?? '').toString(),
                  (row['_kind'] ?? '').toString(),
                ),
                onOpen: () {
                  final id = (row['id'] ?? '').toString();
                  if (id.isEmpty) return;
                  context.go(
                    row['_kind'] == 'casting'
                        ? '${Routes.adminSelection}/$id'
                        : '${Routes.adminSelectionProject}/$id',
                  );
                },
              ),
          ],
        );
      },
    );

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          header,
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          body,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(adminSelectionListProvider);
    if (kIsWeb) {
      final valid = itemsAsync.valueOrNull;
      if (valid != null) {
        final validIds = valid
            .map((row) => (row['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
        _selectedIds.removeWhere((id) => !validIds.contains(id));
        _selectedKinds.removeWhere((id, _) => !validIds.contains(id));
      }
      return _buildV2(t, itemsAsync);
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              BrandAdminHeader(
                title: _selectedIds.isEmpty
                    ? t.selectionUpper
                    : '${t.selectionUpper} (${_selectedIds.length})',
                onBack: () => context.go(Routes.admin),
                trailing: _selectedIds.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _isDeleting ? null : _deleteSelected,
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                color: BrandTheme.redTop,
                              ),
                        splashRadius: 22,
                      ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: _CardPill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          '${t.errorUpper}: ${AppErrorMapper.message(e, t)}',
                          textAlign: TextAlign.center,
                          style: adminCommandStyle(
                            size: 13,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: _CardPill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              t.noCastingsMessage,
                              textAlign: TextAlign.center,
                              style: adminCommandStyle(
                                size: 13,
                                letterSpacing: 0.9,
                                color: kTextMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final validIds = items
                        .map((row) => (row['id'] ?? '').toString())
                        .where((id) => id.isNotEmpty)
                        .toSet();

                    _selectedIds.removeWhere((id) => !validIds.contains(id));
                    _selectedKinds.removeWhere(
                      (id, _) => !validIds.contains(id),
                    );

                    return _CardPill(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final row = items[i];
                          final id = (row['id'] ?? '').toString();
                          final title = (row['title'] ?? '').toString();
                          final kind = (row['_kind'] ?? '').toString();
                          final isCasting = kind == 'casting';
                          final isSelected = _selectedIds.contains(id);
                          final status = selectionStatusFromString(
                            row['status'],
                          );

                          return Container(
                            decoration: catalogSearchDecoration(
                              radius: kCardRadius,
                              borderColor: kBorderColor,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              leading: Checkbox(
                                value: isSelected,
                                activeColor: BrandTheme.redTop,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: id.isEmpty
                                    ? null
                                    : (_) => _toggleSelected(id, kind),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: adminCommandStyle(
                                        size: 16,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  if (!isCasting)
                                    _SelectionStatusBadge(status: status)
                                  else
                                    const _KindBadge(label: 'CASTING'),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: BrandTheme.redTop,
                              ),
                              onTap: id.isEmpty
                                  ? null
                                  : () => context.go(
                                      isCasting
                                          ? '${Routes.adminSelection}/$id'
                                          : '${Routes.adminSelectionProject}/$id',
                                    ),
                            ),
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
    );
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: child,
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorderColor, width: 1),
      ),
      child: Text(
        label,
        style: adminCommandStyle(size: 11, letterSpacing: 0.8),
      ),
    );
  }
}

class _SelectionStatusBadge extends StatelessWidget {
  const _SelectionStatusBadge({required this.status});

  final SelectionStatus status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final color = selectionStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        selectionStatusLabel(t, status).toUpperCase(),
        style: adminCommandStyle(size: 10, letterSpacing: 0.7, color: color),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: pillDecoration(isDark: isDark, radius: kPillRadius),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: adminCommandStyle(
              letterSpacing: 1.0,
              color: isDark ? Colors.white : _text,
            ),
          ),
        ),
      ),
    );
  }
}


class _SelectionRowV2 extends StatefulWidget {
  const _SelectionRowV2({
    required this.row,
    required this.gutter,
    required this.selected,
    required this.date,
    required this.onToggle,
    required this.onOpen,
  });

  final Map<String, dynamic> row;
  final double gutter;
  final bool selected;
  final String date;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  State<_SelectionRowV2> createState() => _SelectionRowV2State();
}

class _SelectionRowV2State extends State<_SelectionRowV2> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final row = widget.row;
    final title = (row['title'] ?? '').toString().trim();
    final isCasting = row['_kind'] == 'casting';
    final status = selectionStatusFromString(row['status']);
    final kindLabel = isCasting
        ? (ru ? 'Кастинг · отклики' : 'Casting · responses')
        : '${ru ? 'Подборка' : 'Selection'} · ${selectionStatusLabel(t, status)}';
    final selected = widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: selected
            ? Tokens.surfaceAlt
            : (_hovered ? Tokens.surface : Colors.transparent),
        child: InkWell(
          onTap: widget.onOpen,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Tokens.border)),
            ),
            padding: EdgeInsets.fromLTRB(
              widget.gutter - 12,
              10,
              widget.gutter - 8,
              10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => widget.onToggle(),
                    activeColor: Tokens.ink,
                    checkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Tokens.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCasting ? Icons.movie_outlined : Icons.folder_outlined,
                    size: 20,
                    color: Tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty
                            ? (ru ? 'Без названия' : 'Untitled')
                            : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Tokens.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kindLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: Tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.date,
                  style: AppText.caption.copyWith(color: Tokens.textTertiary),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _hovered ? Tokens.text : Tokens.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
