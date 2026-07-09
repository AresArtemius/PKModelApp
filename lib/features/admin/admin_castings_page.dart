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
import '../castings/casting_project_stage.dart';
import 'admin_style.dart';

const _kCastingsBg = BrandTheme.greyMid;
const _kCastingsPad = 16.0;
const _kCastingsDesktopBreakpoint = 920.0;

final _adminCastingsProvider = FutureProvider.autoDispose<List<_AdminCastingRow>>((
  ref,
) async {
  final sb = ref.watch(supabaseProvider);
  try {
    final rows = await sb
        .from('castings')
        .select(
          'id,title,description,fee,rights,dates,project_stage,reference_media,created_by,created_at',
        )
        .order('created_at', ascending: false)
        .limit(300);
    final owners = await _loadOwnerLabels(sb);
    final counts = await _loadCastingResponseCounts(sb);
    return (rows as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = (map['id'] ?? '').toString();
          final ownerId = (map['created_by'] ?? '').toString();
          return _AdminCastingRow.fromMap(
            map,
            ownerLabel: owners[ownerId] ?? ownerId,
            responseCount: counts[id] ?? 0,
          );
        })
        .toList(growable: false);
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingAnyColumn(e, [
      'project_stage',
      'reference_media',
      'created_by',
    ])) {
      final rows = await sb
          .from('castings')
          .select('id,title,description,fee,rights,dates,created_at')
          .order('created_at', ascending: false)
          .limit(300);
      final counts = await _loadCastingResponseCounts(sb);
      return (rows as List)
          .map((row) {
            final map = Map<String, dynamic>.from(row as Map);
            final id = (map['id'] ?? '').toString();
            return _AdminCastingRow.fromMap(
              map,
              ownerLabel: '',
              responseCount: counts[id] ?? 0,
            );
          })
          .toList(growable: false);
    }
    if (SupabaseCompat.isMissingRelation(e, const ['castings'])) {
      return const <_AdminCastingRow>[];
    }
    rethrow;
  }
});

Future<Map<String, int>> _loadCastingResponseCounts(SupabaseClient sb) async {
  try {
    final rows = await sb.from('casting_responses').select('casting_id');
    final counts = <String, int>{};
    for (final row in rows as List) {
      final id = ((row as Map)['casting_id'] ?? '').toString();
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['casting_responses'])) {
      return const <String, int>{};
    }
    rethrow;
  }
}

Future<Map<String, String>> _loadOwnerLabels(SupabaseClient sb) async {
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

class AdminCastingsPage extends ConsumerStatefulWidget {
  const AdminCastingsPage({super.key});

  @override
  ConsumerState<AdminCastingsPage> createState() => _AdminCastingsPageState();
}

class _AdminCastingsPageState extends ConsumerState<AdminCastingsPage> {
  final TextEditingController _searchC = TextEditingController();
  CastingProjectStage? _stageFilter;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete(_AdminCastingRow casting) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить кастинг'),
        content: Text('Удалить кастинг «${casting.title}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteCasting(_AdminCastingRow casting) async {
    final confirmed = await _confirmDelete(casting);
    if (!confirmed) return;
    try {
      await ref
          .read(supabaseProvider)
          .from('castings')
          .delete()
          .eq('id', casting.id);
      ref.invalidate(_adminCastingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Кастинг удален')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Не удалось удалить: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isAdminAsync = ref.watch(isAdminProvider);
    final castingsAsync = ref.watch(_adminCastingsProvider);

    return Scaffold(
      backgroundColor: _kCastingsBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_kCastingsPad),
          child: Column(
            children: [
              BrandAdminHeader(
                title: ru ? 'ВСЕ КАСТИНГИ' : 'ALL CASTINGS',
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
                    return castingsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => AdminMessageCard(
                        text: ru
                            ? 'Не удалось загрузить кастинги: $error'
                            : 'Could not load castings: $error',
                        isError: true,
                        maxWidth: 680,
                      ),
                      data: (castings) => _CastingsPanel(
                        castings: castings,
                        controller: _searchC,
                        stageFilter: _stageFilter,
                        onStageChanged: (stage) =>
                            setState(() => _stageFilter = stage),
                        onSearchChanged: () => setState(() {}),
                        onDeleteCasting: _deleteCasting,
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

class _CastingsPanel extends StatelessWidget {
  const _CastingsPanel({
    required this.castings,
    required this.controller,
    required this.stageFilter,
    required this.onStageChanged,
    required this.onSearchChanged,
    required this.onDeleteCasting,
  });

  final List<_AdminCastingRow> castings;
  final TextEditingController controller;
  final CastingProjectStage? stageFilter;
  final ValueChanged<CastingProjectStage?> onStageChanged;
  final VoidCallback onSearchChanged;
  final ValueChanged<_AdminCastingRow> onDeleteCasting;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final query = controller.text.trim().toLowerCase();
    final filtered = castings
        .where((casting) {
          final stageOk = stageFilter == null || casting.stage == stageFilter;
          final searchOk = query.isEmpty || casting.searchable.contains(query);
          return stageOk && searchOk;
        })
        .toList(growable: false);
    final activeCount = castings
        .where((casting) => casting.stage != CastingProjectStage.completed)
        .length;
    final totalResponses = castings.fold<int>(
      0,
      (sum, casting) => sum + casting.responseCount,
    );
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kCastingsDesktopBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AdminCompactSummary(
            title: ru ? 'Сводка' : 'Summary',
            items: [
              (ru ? 'Всего' : 'Total', castings.length),
              (ru ? 'В выборке' : 'Shown', filtered.length),
              (ru ? 'Активные' : 'Active', activeCount),
              (ru ? 'Отклики' : 'Responses', totalResponses),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CastingsToolbar(
          controller: controller,
          stageFilter: stageFilter,
          onStageChanged: onStageChanged,
          onSearchChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(text: ru ? 'Кастинги не найдены' : 'No castings')
              : isDesktop
              ? _CastingsTable(
                  castings: filtered,
                  onDeleteCasting: onDeleteCasting,
                )
              : _CastingsMobileList(
                  castings: filtered,
                  onDeleteCasting: onDeleteCasting,
                ),
        ),
      ],
    );
  }
}

class _CastingsToolbar extends StatelessWidget {
  const _CastingsToolbar({
    required this.controller,
    required this.stageFilter,
    required this.onStageChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final CastingProjectStage? stageFilter;
  final ValueChanged<CastingProjectStage?> onStageChanged;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return _ToolbarFrame(
      controller: controller,
      hintText: ru ? 'Поиск по проекту, клиенту, датам' : 'Search castings',
      onSearchChanged: onSearchChanged,
      filters: [
        AdminMenuFilter<CastingProjectStage?>(
          label: ru ? 'Этап' : 'Stage',
          valueLabel: stageFilter == null
              ? (ru ? 'Все этапы' : 'All stages')
              : castingProjectStageLabel(context, stageFilter!),
          options: [
            AdminMenuOption<CastingProjectStage?>(
              value: null,
              label: ru ? 'Все этапы' : 'All stages',
            ),
            for (final stage in CastingProjectStage.values)
              AdminMenuOption(
                value: stage,
                label: castingProjectStageLabel(context, stage),
              ),
          ],
          onSelected: onStageChanged,
        ),
      ],
    );
  }
}

class _CastingsTable extends StatelessWidget {
  const _CastingsTable({required this.castings, required this.onDeleteCasting});

  final List<_AdminCastingRow> castings;
  final ValueChanged<_AdminCastingRow> onDeleteCasting;

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
            constraints: const BoxConstraints(minWidth: 1040),
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: castings.length + 1,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: kBorderColor),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _HeaderRow(
                    cells: [
                      (ru ? 'Кастинг' : 'Casting', 320.0),
                      (ru ? 'Этап' : 'Stage', 170.0),
                      (ru ? 'Владелец' : 'Owner', 180.0),
                      (ru ? 'Даты' : 'Dates', 160.0),
                      (ru ? 'Отклики' : 'Responses', 100.0),
                      ('', 72.0),
                    ],
                  );
                }
                return _CastingTableRow(
                  casting: castings[index - 1],
                  onDeleteCasting: onDeleteCasting,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CastingTableRow extends StatelessWidget {
  const _CastingTableRow({
    required this.casting,
    required this.onDeleteCasting,
  });

  final _AdminCastingRow casting;
  final ValueChanged<_AdminCastingRow> onDeleteCasting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          _TextCell(width: 320, text: casting.title, subtitle: casting.id),
          SizedBox(width: 170, child: _StageBadge(stage: casting.stage)),
          _TextCell(width: 180, text: casting.ownerLabel),
          _TextCell(width: 160, text: casting.datesText),
          _TextCell(width: 100, text: '${casting.responseCount}'),
          SizedBox(
            width: 72,
            child: _CastingActionsMenu(
              casting: casting,
              onDeleteCasting: onDeleteCasting,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingsMobileList extends StatelessWidget {
  const _CastingsMobileList({
    required this.castings,
    required this.onDeleteCasting,
  });

  final List<_AdminCastingRow> castings;
  final ValueChanged<_AdminCastingRow> onDeleteCasting;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: castings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _CastingMobileCard(
        casting: castings[index],
        onDeleteCasting: onDeleteCasting,
      ),
    );
  }
}

class _CastingMobileCard extends StatelessWidget {
  const _CastingMobileCard({
    required this.casting,
    required this.onDeleteCasting,
  });

  final _AdminCastingRow casting;
  final ValueChanged<_AdminCastingRow> onDeleteCasting;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final meta = [
      casting.ownerLabel,
      casting.datesText,
      casting.fee,
      '${ru ? 'Отклики' : 'Responses'}: ${casting.responseCount}',
      if (casting.referenceCount > 0)
        '${ru ? 'Референсы' : 'Refs'}: ${casting.referenceCount}',
    ].where((part) => part.trim().isNotEmpty).join(' • ');
    return _MobileCard(
      title: casting.title,
      subtitle: casting.id,
      badge: _StageBadge(stage: casting.stage),
      meta: meta,
      onOpen: () => context.go('${Routes.adminSelection}/${casting.id}'),
      action: _CastingActionsMenu(
        casting: casting,
        onDeleteCasting: onDeleteCasting,
      ),
    );
  }
}

class _CastingActionsMenu extends StatelessWidget {
  const _CastingActionsMenu({
    required this.casting,
    required this.onDeleteCasting,
  });

  final _AdminCastingRow casting;
  final ValueChanged<_AdminCastingRow> onDeleteCasting;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: kTextDark),
      onSelected: (value) {
        switch (value) {
          case 'open':
            context.go('${Routes.adminSelection}/${casting.id}');
            return;
          case 'delete':
            onDeleteCasting(casting);
            return;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'open', child: Text('Открыть')),
        PopupMenuItem(value: 'delete', child: Text('Удалить')),
      ],
    );
  }
}

class _AdminCastingRow {
  const _AdminCastingRow({
    required this.id,
    required this.title,
    required this.description,
    required this.fee,
    required this.rights,
    required this.datesText,
    required this.stage,
    required this.referenceCount,
    required this.ownerLabel,
    required this.responseCount,
    required this.createdAt,
  });

  factory _AdminCastingRow.fromMap(
    Map<String, dynamic> map, {
    required String ownerLabel,
    required int responseCount,
  }) {
    return _AdminCastingRow(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      fee: (map['fee'] ?? '').toString().trim(),
      rights: (map['rights'] ?? '').toString().trim(),
      datesText: _datesText(map['dates']),
      stage: castingProjectStageFromString(map['project_stage']?.toString()),
      referenceCount: _listCount(map['reference_media']),
      ownerLabel: ownerLabel,
      responseCount: responseCount,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  final String id;
  final String title;
  final String description;
  final String fee;
  final String rights;
  final String datesText;
  final CastingProjectStage stage;
  final int referenceCount;
  final String ownerLabel;
  final int responseCount;
  final DateTime? createdAt;

  String get searchable =>
      '$id $title $description $fee $rights $datesText $ownerLabel ${castingProjectStageToString(stage)}'
          .toLowerCase();
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final CastingProjectStage stage;

  @override
  Widget build(BuildContext context) {
    final color = castingProjectStageColor(stage);
    return _SoftBadge(
      label: castingProjectStageLabel(context, stage),
      color: color,
      filled: stage == CastingProjectStage.acceptingApplications,
    );
  }
}

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

String _datesText(Object? datesRaw) {
  if (datesRaw is List) {
    return datesRaw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .map((item) => item.length >= 10 ? item.substring(0, 10) : item)
        .join(', ');
  }
  final text = datesRaw?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  return text.length >= 10 ? text.substring(0, 10) : text;
}

int _listCount(Object? value) {
  if (value is List) return value.length;
  return 0;
}
