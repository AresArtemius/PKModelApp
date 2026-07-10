import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';
import 'selection_status.dart';

const _kSelectionsBg = BrandTheme.greyMid;
const _kSelectionsPad = 16.0;
const _kSelectionsDesktopBreakpoint = 920.0;
const _kSelectionsListCacheExtent = 900.0;
const _kSelectionsPageSize = 80;

class _AdminSelectionsPageData {
  const _AdminSelectionsPageData({required this.rows, required this.hasMore});

  final List<_AdminSelectionRow> rows;
  final bool hasMore;
}

final _adminSelectionsProvider = FutureProvider.autoDispose
    .family<_AdminSelectionsPageData, int>((ref, limit) async {
      final sb = ref.watch(supabaseProvider);
      try {
        final rows = await sb
            .from('selections')
            .select(
              'id,title,status,is_public,client_name,brand_name,location,project_dates,created_by,created_at',
            )
            .order('created_at', ascending: false)
            .range(0, limit);
        final owners = await _loadSelectionOwnerLabels(sb);
        final counts = await _loadSelectionItemCounts(sb);
        final list = rows as List;
        return _AdminSelectionsPageData(
          hasMore: list.length > limit,
          rows: list
              .take(limit)
              .map((row) {
                final map = Map<String, dynamic>.from(row as Map);
                final id = (map['id'] ?? '').toString();
                final ownerId = (map['created_by'] ?? '').toString();
                return _AdminSelectionRow.fromMap(
                  map,
                  ownerLabel: owners[ownerId] ?? ownerId,
                  itemCount: counts[id] ?? 0,
                );
              })
              .toList(growable: false),
        );
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingAnyColumn(e, [
          'status',
          'is_public',
          'client_name',
          'brand_name',
          'location',
          'project_dates',
          'created_by',
        ])) {
          final rows = await sb
              .from('selections')
              .select('id,title,created_at')
              .order('created_at', ascending: false)
              .range(0, limit);
          final counts = await _loadSelectionItemCounts(sb);
          final list = rows as List;
          return _AdminSelectionsPageData(
            hasMore: list.length > limit,
            rows: list
                .take(limit)
                .map((row) {
                  final map = Map<String, dynamic>.from(row as Map);
                  final id = (map['id'] ?? '').toString();
                  return _AdminSelectionRow.fromMap(
                    map,
                    ownerLabel: '',
                    itemCount: counts[id] ?? 0,
                  );
                })
                .toList(growable: false),
          );
        }
        if (SupabaseCompat.isMissingRelation(e, const ['selections'])) {
          return const _AdminSelectionsPageData(
            rows: <_AdminSelectionRow>[],
            hasMore: false,
          );
        }
        rethrow;
      }
    });

Future<Map<String, int>> _loadSelectionItemCounts(SupabaseClient sb) async {
  try {
    final rows = await sb.from('selection_items').select('selection_id');
    final counts = <String, int>{};
    for (final row in rows as List) {
      final id = ((row as Map)['selection_id'] ?? '').toString();
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['selection_items'])) {
      return const <String, int>{};
    }
    rethrow;
  }
}

Future<Map<String, String>> _loadSelectionOwnerLabels(SupabaseClient sb) async {
  try {
    final rows = await sb
        .from('user_profiles')
        .select('user_id,email,phone,account_tag,full_name,company_name')
        .limit(1000);
    return {
      for (final row in rows as List)
        _ownerId(row): _ownerLabel(Map<String, dynamic>.from(row as Map)),
    };
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['user_profiles'])) {
      return const <String, String>{};
    }
    if (SupabaseCompat.isMissingColumn(e, 'account_tag')) {
      final rows = await sb
          .from('user_profiles')
          .select('user_id,email,phone,full_name,company_name')
          .limit(1000);
      return {
        for (final row in rows as List)
          _ownerId(row): _ownerLabel(Map<String, dynamic>.from(row as Map)),
      };
    }
    rethrow;
  }
}

String _ownerId(Object row) {
  return ((row as Map)['user_id'] ?? '').toString().trim();
}

String _ownerLabel(Map<String, dynamic> map) {
  for (final key in [
    'account_tag',
    'full_name',
    'company_name',
    'email',
    'phone',
  ]) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isEmpty) continue;
    return key == 'account_tag' ? '@$value' : value;
  }
  return '';
}

class AdminSelectionsTablePage extends ConsumerStatefulWidget {
  const AdminSelectionsTablePage({super.key});

  @override
  ConsumerState<AdminSelectionsTablePage> createState() =>
      _AdminSelectionsTablePageState();
}

class _AdminSelectionsTablePageState
    extends ConsumerState<AdminSelectionsTablePage> {
  final TextEditingController _searchC = TextEditingController();
  SelectionStatus? _statusFilter;
  bool? _publicFilter;
  int _selectionsLimit = _kSelectionsPageSize;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete(_AdminSelectionRow selection) async {
    return showAdminConfirmDialog(
      context: context,
      title: 'Удалить подборку',
      message: 'Удалить подборку «${selection.title}»?',
      confirmLabel: 'Удалить',
      destructive: true,
    );
  }

  Future<void> _deleteSelection(_AdminSelectionRow selection) async {
    final confirmed = await _confirmDelete(selection);
    if (!confirmed) return;
    try {
      await ref
          .read(supabaseProvider)
          .rpc(
            'admin_delete_selection',
            params: {'p_selection_id': selection.id},
          );
      ref.invalidate(_adminSelectionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Подборка удалена')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_adminSelectionsActionError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isAdminAsync = ref.watch(isAdminProvider);
    final selectionsAsync = ref.watch(
      _adminSelectionsProvider(_selectionsLimit),
    );

    return Scaffold(
      backgroundColor: _kSelectionsBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_kSelectionsPad),
          child: Column(
            children: [
              BrandAdminHeader(
                title: ru ? 'ВСЕ ПОДБОРКИ' : 'ALL SELECTIONS',
                onBack: () => context.go(Routes.admin),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: isAdminAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => AdminMessageCard(
                    text: ru ? 'Только для администратора' : 'Admins only',
                    isError: true,
                  ),
                  data: (isAdmin) {
                    if (!isAdmin) {
                      return AdminMessageCard(
                        text: ru ? 'Только для администратора' : 'Admins only',
                        isError: true,
                      );
                    }
                    return selectionsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => AdminMessageCard(
                        text: ru
                            ? 'Не удалось загрузить подборки: $error'
                            : 'Could not load selections: $error',
                        isError: true,
                        maxWidth: 680,
                      ),
                      data: (data) => _SelectionsPanel(
                        selections: data.rows,
                        hasMore: data.hasMore,
                        controller: _searchC,
                        statusFilter: _statusFilter,
                        publicFilter: _publicFilter,
                        onStatusChanged: (status) =>
                            setState(() => _statusFilter = status),
                        onPublicChanged: (value) =>
                            setState(() => _publicFilter = value),
                        onSearchChanged: () => setState(() {}),
                        onLoadMore: () => setState(
                          () => _selectionsLimit += _kSelectionsPageSize,
                        ),
                        onDeleteSelection: _deleteSelection,
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

class _SelectionsPanel extends StatelessWidget {
  const _SelectionsPanel({
    required this.selections,
    required this.hasMore,
    required this.controller,
    required this.statusFilter,
    required this.publicFilter,
    required this.onStatusChanged,
    required this.onPublicChanged,
    required this.onSearchChanged,
    required this.onLoadMore,
    required this.onDeleteSelection,
  });

  final List<_AdminSelectionRow> selections;
  final bool hasMore;
  final TextEditingController controller;
  final SelectionStatus? statusFilter;
  final bool? publicFilter;
  final ValueChanged<SelectionStatus?> onStatusChanged;
  final ValueChanged<bool?> onPublicChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onLoadMore;
  final ValueChanged<_AdminSelectionRow> onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final query = controller.text.trim().toLowerCase();
    final filtered = selections
        .where((selection) {
          final statusOk =
              statusFilter == null || selection.status == statusFilter;
          final publicOk =
              publicFilter == null || selection.isPublic == publicFilter;
          final searchOk =
              query.isEmpty || selection.searchable.contains(query);
          return statusOk && publicOk && searchOk;
        })
        .toList(growable: false);
    final publicCount = selections
        .where((selection) => selection.isPublic)
        .length;
    final totalItems = selections.fold<int>(
      0,
      (sum, selection) => sum + selection.itemCount,
    );
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kSelectionsDesktopBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AdminCompactSummary(
            title: ru ? 'Сводка' : 'Summary',
            items: [
              (ru ? 'Всего' : 'Total', selections.length),
              (ru ? 'В выборке' : 'Shown', filtered.length),
              (ru ? 'Публичные' : 'Public', publicCount),
              (ru ? 'Анкеты' : 'Profiles', totalItems),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SelectionsToolbar(
          controller: controller,
          statusFilter: statusFilter,
          publicFilter: publicFilter,
          onStatusChanged: onStatusChanged,
          onPublicChanged: onPublicChanged,
          onSearchChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? Column(
                  children: [
                    Expanded(
                      child: _EmptyState(
                        text: ru ? 'Подборки не найдены' : 'No selections',
                      ),
                    ),
                    if (hasMore)
                      AdminLoadMoreFooter(
                        label: ru ? 'Загрузить еще' : 'Load more',
                        onPressed: onLoadMore,
                      ),
                  ],
                )
              : isDesktop
              ? _SelectionsTable(
                  selections: filtered,
                  hasMore: hasMore,
                  onLoadMore: onLoadMore,
                  onDeleteSelection: onDeleteSelection,
                )
              : _SelectionsMobileList(
                  selections: filtered,
                  hasMore: hasMore,
                  onLoadMore: onLoadMore,
                  onDeleteSelection: onDeleteSelection,
                ),
        ),
      ],
    );
  }
}

class _SelectionsToolbar extends StatelessWidget {
  const _SelectionsToolbar({
    required this.controller,
    required this.statusFilter,
    required this.publicFilter,
    required this.onStatusChanged,
    required this.onPublicChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final SelectionStatus? statusFilter;
  final bool? publicFilter;
  final ValueChanged<SelectionStatus?> onStatusChanged;
  final ValueChanged<bool?> onPublicChanged;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return _ToolbarFrame(
      controller: controller,
      hintText: ru
          ? 'Поиск по подборке, клиенту, локации'
          : 'Search selections',
      onSearchChanged: onSearchChanged,
      filters: [
        AdminMenuFilter<SelectionStatus?>(
          label: ru ? 'Статус' : 'Status',
          valueLabel: statusFilter == null
              ? (ru ? 'Все статусы' : 'All statuses')
              : _selectionStatusText(statusFilter!, ru),
          options: [
            AdminMenuOption<SelectionStatus?>(
              value: null,
              label: ru ? 'Все статусы' : 'All statuses',
            ),
            for (final status in SelectionStatus.values)
              AdminMenuOption(
                value: status,
                label: _selectionStatusText(status, ru),
              ),
          ],
          onSelected: onStatusChanged,
        ),
        AdminMenuFilter<bool?>(
          label: ru ? 'Доступ' : 'Access',
          valueLabel: publicFilter == null
              ? (ru ? 'Любой' : 'Any')
              : publicFilter!
              ? (ru ? 'Публичные' : 'Public')
              : (ru ? 'Закрытые' : 'Private'),
          options: [
            AdminMenuOption<bool?>(
              value: null,
              label: ru ? 'Любой доступ' : 'Any visibility',
            ),
            AdminMenuOption(value: true, label: ru ? 'Публичные' : 'Public'),
            AdminMenuOption(value: false, label: ru ? 'Закрытые' : 'Private'),
          ],
          onSelected: onPublicChanged,
        ),
      ],
    );
  }
}

class _SelectionsTable extends StatelessWidget {
  const _SelectionsTable({
    required this.selections,
    required this.hasMore,
    required this.onLoadMore,
    required this.onDeleteSelection,
  });

  final List<_AdminSelectionRow> selections;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<_AdminSelectionRow> onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return DecoratedBox(
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(color: kBorderColor),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1080),
            child: ListView.separated(
              // ignore: deprecated_member_use
              cacheExtent: _kSelectionsListCacheExtent,
              padding: const EdgeInsets.all(10),
              itemCount: selections.length + 1 + (hasMore ? 1 : 0),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: kBorderColor),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _HeaderRow(
                    cells: [
                      (ru ? 'Подборка' : 'Selection', 300.0),
                      (ru ? 'Статус' : 'Status', 170.0),
                      (ru ? 'Владелец' : 'Owner', 180.0),
                      (ru ? 'Клиент/бренд' : 'Client/brand', 180.0),
                      (ru ? 'Анкеты' : 'Profiles', 90.0),
                      (ru ? 'Доступ' : 'Access', 90.0),
                      ('', 72.0),
                    ],
                  );
                }
                if (hasMore && index == selections.length + 1) {
                  return AdminLoadMoreFooter(
                    label: ru ? 'Загрузить еще' : 'Load more',
                    onPressed: onLoadMore,
                  );
                }
                return _SelectionTableRow(
                  selection: selections[index - 1],
                  onDeleteSelection: onDeleteSelection,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionTableRow extends StatelessWidget {
  const _SelectionTableRow({
    required this.selection,
    required this.onDeleteSelection,
  });

  final _AdminSelectionRow selection;
  final ValueChanged<_AdminSelectionRow> onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          _TextCell(width: 300, text: selection.title, subtitle: selection.id),
          SizedBox(
            width: 170,
            child: _SelectionStatusBadge(status: selection.status),
          ),
          _TextCell(width: 180, text: selection.ownerLabel),
          _TextCell(width: 180, text: selection.clientLabel),
          _TextCell(width: 90, text: '${selection.itemCount}'),
          _TextCell(width: 90, text: selection.isPublic ? 'public' : 'private'),
          SizedBox(
            width: 72,
            child: _SelectionActionsMenu(
              selection: selection,
              onDeleteSelection: onDeleteSelection,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionsMobileList extends StatelessWidget {
  const _SelectionsMobileList({
    required this.selections,
    required this.hasMore,
    required this.onLoadMore,
    required this.onDeleteSelection,
  });

  final List<_AdminSelectionRow> selections;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<_AdminSelectionRow> onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: selections.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= selections.length) {
          final ru = Localizations.localeOf(context).languageCode == 'ru';
          return AdminLoadMoreFooter(
            label: ru ? 'Загрузить еще' : 'Load more',
            onPressed: onLoadMore,
          );
        }
        return _SelectionMobileCard(
          selection: selections[index],
          onDeleteSelection: onDeleteSelection,
        );
      },
    );
  }
}

class _SelectionMobileCard extends StatelessWidget {
  const _SelectionMobileCard({
    required this.selection,
    required this.onDeleteSelection,
  });

  final _AdminSelectionRow selection;
  final ValueChanged<_AdminSelectionRow> onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final meta = [
      selection.ownerLabel,
      selection.clientLabel,
      selection.location,
      selection.projectDates,
      '${ru ? 'Анкеты' : 'Profiles'}: ${selection.itemCount}',
      selection.isPublic ? (ru ? 'Публичная' : 'Public') : '',
    ].where((part) => part.trim().isNotEmpty).join(' • ');
    return _MobileCard(
      title: selection.title,
      subtitle: selection.id,
      badge: _SelectionStatusBadge(status: selection.status),
      meta: meta,
      onOpen: () =>
          context.go('${Routes.adminSelectionProject}/${selection.id}'),
      action: _SelectionActionsMenu(
        selection: selection,
        onDeleteSelection: onDeleteSelection,
      ),
    );
  }
}

class _SelectionActionsMenu extends StatelessWidget {
  const _SelectionActionsMenu({
    required this.selection,
    required this.onDeleteSelection,
  });

  final _AdminSelectionRow selection;
  final ValueChanged<_AdminSelectionRow> onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    return AdminPopupMenuButton<String>(
      tooltip: 'Действия',
      onSelected: (value) {
        switch (value) {
          case 'open':
            context.go('${Routes.adminSelectionProject}/${selection.id}');
            return;
          case 'delete':
            onDeleteSelection(selection);
            return;
        }
      },
      options: const [
        AdminMenuOption(
          value: 'open',
          label: 'Открыть',
          icon: Icons.open_in_new_rounded,
        ),
        AdminMenuOption(
          value: 'delete',
          label: 'Удалить',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
      child: const _AdminActionDots(),
    );
  }
}

class _AdminActionDots extends StatelessWidget {
  const _AdminActionDots();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 40,
      child: Center(child: Icon(Icons.more_horiz_rounded, color: kTextDark)),
    );
  }
}

class _AdminSelectionRow {
  const _AdminSelectionRow({
    required this.id,
    required this.title,
    required this.status,
    required this.isPublic,
    required this.clientName,
    required this.brandName,
    required this.location,
    required this.projectDates,
    required this.ownerLabel,
    required this.itemCount,
    required this.createdAt,
  });

  factory _AdminSelectionRow.fromMap(
    Map<String, dynamic> map, {
    required String ownerLabel,
    required int itemCount,
  }) {
    return _AdminSelectionRow(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString().trim(),
      status: selectionStatusFromString(map['status']),
      isPublic: _boolFromMap(map['is_public']),
      clientName: (map['client_name'] ?? '').toString().trim(),
      brandName: (map['brand_name'] ?? '').toString().trim(),
      location: (map['location'] ?? '').toString().trim(),
      projectDates: (map['project_dates'] ?? '').toString().trim(),
      ownerLabel: ownerLabel,
      itemCount: itemCount,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  final String id;
  final String title;
  final SelectionStatus status;
  final bool isPublic;
  final String clientName;
  final String brandName;
  final String location;
  final String projectDates;
  final String ownerLabel;
  final int itemCount;
  final DateTime? createdAt;

  String get clientLabel =>
      [clientName, brandName].where((part) => part.isNotEmpty).join(' • ');

  String get searchable =>
      '$id $title $clientName $brandName $location $projectDates $ownerLabel ${status.name}'
          .toLowerCase();
}

class _SelectionStatusBadge extends StatelessWidget {
  const _SelectionStatusBadge({required this.status});

  final SelectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = selectionStatusColor(status);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return _SoftBadge(
      label: _selectionStatusText(status, ru),
      color: color,
      filled: status == SelectionStatus.sentToClient,
    );
  }
}

String _selectionStatusText(SelectionStatus status, bool ru) =>
    switch (status) {
      SelectionStatus.draft => ru ? 'Черновик' : 'Draft',
      SelectionStatus.sentToClient => ru ? 'Отправлена' : 'Sent',
      SelectionStatus.clientViewed => ru ? 'Просмотрена' : 'Viewed',
      SelectionStatus.selected => ru ? 'Выбрана' : 'Selected',
      SelectionStatus.rejected => ru ? 'Отклонена' : 'Rejected',
    };

class _ToolbarFrame extends StatelessWidget {
  const _ToolbarFrame({
    required this.controller,
    required this.hintText,
    required this.onSearchChanged,
    required this.filters,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSearchChanged;
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final search = TextField(
          controller: controller,
          onChanged: (_) => onSearchChanged(),
          style: adminBodyStyle(color: kTextDark),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      onSearchChanged();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kTextDark, width: 1.2),
            ),
          ),
        );
        final chips = Wrap(spacing: 8, runSpacing: 8, children: filters);
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 10), chips],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            Flexible(child: chips),
          ],
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.cells});

  final List<(String, double)> cells;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          for (final cell in cells)
            SizedBox(
              width: cell.$2,
              child: Text(
                cell.$1,
                style: adminCommandStyle(
                  size: 11,
                  letterSpacing: 0.8,
                  color: kTextMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.width, required this.text, this.subtitle});

  final double width;
  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.trim().isEmpty ? '—' : text.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminBodyStyle(size: 12, color: kTextDark),
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: adminBodyStyle(size: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminCommandStyle(
              size: 10,
              letterSpacing: 0.4,
              color: filled ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileCard extends StatelessWidget {
  const _MobileCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.meta,
    required this.onOpen,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget badge;
  final String meta;
  final VoidCallback onOpen;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(color: kBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title.trim().isEmpty ? '—' : title.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: adminCommandStyle(
                            size: 14,
                            letterSpacing: 0.1,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminBodyStyle(size: 11),
                  ),
                  if (meta.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: adminBodyStyle(size: 12, color: kTextDark),
                    ),
                  ],
                ],
              ),
            ),
            action ??
                IconButton(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  color: kTextDark,
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(color: kBorderColor),
      ),
      child: Center(
        child: Text(
          text,
          style: adminCommandStyle(
            size: 13,
            letterSpacing: 0.7,
            color: kTextMuted,
          ),
        ),
      ),
    );
  }
}

bool _boolFromMap(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

String _adminSelectionsActionError(Object error) {
  if (error is PostgrestException) {
    final details = [
      error.message,
      if ((error.details ?? '').toString().trim().isNotEmpty) error.details,
      if ((error.hint ?? '').toString().trim().isNotEmpty) error.hint,
      if ((error.code ?? '').toString().trim().isNotEmpty)
        'code: ${error.code}',
    ].map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('\n');
    if (details.toLowerCase().contains('admin_delete_selection')) {
      return 'Не удалось удалить подборку.\nПримените SQL: supabase/sql/admin_backoffice_actions.sql';
    }
    return 'Не удалось удалить: $details';
  }
  return 'Не удалось удалить: $error';
}
