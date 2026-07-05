import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'account_merge_requests_page.dart';
import 'admin_style.dart';
import 'casting_agent_applications_page.dart';
import 'moderation_admin_page.dart';
import 'safety_admin_page.dart';

const _kAdminBg = BrandTheme.greyMid;

const double _kAdminPad = 14;
const double _kAdminPagePad = 16;
const double _kAdminSectionGap = 12;
const double _kAdminMessagePadV = 18;
const double _kAdminMaxCardWidth = 460;

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isAdminAsync = ref.watch(isAdminProvider);

    Future<void> signOutAndGoLogin() async {
      context.go(Routes.login);
      try {
        await ref.read(supabaseProvider).auth.signOut();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Sign out failed')));
        }
      }
    }

    return Scaffold(
      backgroundColor: _kAdminBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_kAdminPagePad),
          child: isAdminAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _ForbiddenView(
              message: t.adminOnlyUpper,
              exitLabel: t.adminExitUpper,
              onExit: signOutAndGoLogin,
            ),
            data: (isAdmin) {
              if (!isAdmin) {
                return _ForbiddenView(
                  message: t.adminOnlyUpper,
                  exitLabel: t.adminExitUpper,
                  onExit: signOutAndGoLogin,
                );
              }

              final countsAsync = ref.watch(adminDashboardCountsProvider);
              return _AdminHome(
                exitLabel: t.adminExitUpper,
                counts: countsAsync.maybeWhen(
                  data: (value) => value,
                  orElse: () => const AdminDashboardCounts(),
                ),
                actions: [
                  _AdminAction(
                    label: t.adminCreateCastingUpper,
                    description: ru ? 'Новый проект' : 'New project',
                    icon: Icons.videocam_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.createCastingAdmin),
                  ),
                  _AdminAction(
                    label: t.selectionUpper,
                    description: ru
                        ? 'Подборки и кастинги'
                        : 'Selections and castings',
                    icon: Icons.dashboard_customize_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.adminSelection),
                  ),
                  _AdminAction(
                    label: t.adminModerationUpper,
                    description: ru ? 'Анкеты на проверке' : 'Pending profiles',
                    icon: Icons.verified_user_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.moderation,
                      orElse: () => 0,
                    ),
                    onTap: () => context.go(Routes.moderationAdmin),
                  ),
                  _AdminAction(
                    label: t.adminAgentApplicationsUpper,
                    description: ru
                        ? 'Статусы заказчиков'
                        : 'Client role requests',
                    icon: Icons.badge_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.agentApplications,
                      orElse: () => 0,
                    ),
                    onTap: () =>
                        context.go(Routes.castingAgentApplicationsAdmin),
                  ),
                  _AdminAction(
                    label: Localizations.localeOf(context).languageCode == 'ru'
                        ? 'ОБЪЕДИНЕНИЕ АККАУНТОВ'
                        : 'ACCOUNT MERGES',
                    description: ru
                        ? 'Заявки на перенос телефона'
                        : 'Phone merge requests',
                    icon: Icons.merge_type_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.accountMerges,
                      orElse: () => 0,
                    ),
                    onTap: () => context.go(Routes.accountMergeRequestsAdmin),
                  ),
                  _AdminAction(
                    label: t.safetyAdminUpper,
                    description: ru
                        ? 'Жалобы и проверки'
                        : 'Reports and safety',
                    icon: Icons.health_and_safety_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.safety,
                      orElse: () => 0,
                    ),
                    onTap: () => context.go(Routes.safetyAdmin),
                  ),
                  _AdminAction(
                    label: Localizations.localeOf(context).languageCode == 'ru'
                        ? 'ЖУРНАЛ ДЕЙСТВИЙ'
                        : 'ACTION LOG',
                    description: ru ? 'Audit и история' : 'Audit and history',
                    icon: Icons.history_rounded,
                    group: _AdminActionGroup.audit,
                    onTap: () => context.go(Routes.profileActionAuditAdmin),
                  ),
                ],
                onExit: signOutAndGoLogin,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ForbiddenView extends StatelessWidget {
  const _ForbiddenView({
    required this.message,
    required this.exitLabel,
    required this.onExit,
  });

  final String message;
  final String exitLabel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminTopBar(exitLabel: exitLabel, onExit: onExit),
        const SizedBox(height: _kAdminSectionGap),
        Expanded(
          child: Center(
            child: _AdminSurface(
              maxWidth: _kAdminMaxCardWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _kAdminMessagePadV,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: adminCommandStyle(size: 14, letterSpacing: 1.1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({
    required this.exitLabel,
    required this.counts,
    required this.actions,
    required this.onExit,
  });

  final String exitLabel;
  final AdminDashboardCounts counts;
  final List<_AdminAction> actions;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final queue = actions
        .where((item) => item.group == _AdminActionGroup.queue)
        .toList(growable: false);
    final operations = actions
        .where((item) => item.group == _AdminActionGroup.operations)
        .toList(growable: false);
    final audit = actions
        .where((item) => item.group == _AdminActionGroup.audit)
        .toList(growable: false);

    return Column(
      children: [
        _AdminTopBar(exitLabel: exitLabel, onExit: onExit),
        const SizedBox(height: _kAdminSectionGap),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              _AdminDashboardHeader(
                title: ru ? 'BACK-OFFICE' : 'BACK OFFICE',
                subtitle: ru
                    ? 'Заявки, безопасность, подборки, кастинги и журнал действий'
                    : 'Requests, safety, selections, castings and audit log',
                total: counts.total,
              ),
              const SizedBox(height: 14),
              _AdminStatGrid(counts: counts),
              const SizedBox(height: 18),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _AdminActionSection(
                        title: ru ? 'ОЧЕРЕДЬ' : 'QUEUE',
                        items: queue,
                        dense: false,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _AdminActionSection(
                            title: ru ? 'ОПЕРАЦИИ' : 'OPERATIONS',
                            items: operations,
                            dense: true,
                          ),
                          const SizedBox(height: 14),
                          _AdminActionSection(
                            title: ru ? 'КОНТРОЛЬ' : 'CONTROL',
                            items: audit,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _AdminActionSection(
                  title: ru ? 'ОЧЕРЕДЬ' : 'QUEUE',
                  items: queue,
                  dense: false,
                ),
                const SizedBox(height: 14),
                _AdminActionSection(
                  title: ru ? 'ОПЕРАЦИИ' : 'OPERATIONS',
                  items: operations,
                  dense: false,
                ),
                const SizedBox(height: 14),
                _AdminActionSection(
                  title: ru ? 'КОНТРОЛЬ' : 'CONTROL',
                  items: audit,
                  dense: false,
                ),
              ],
              const SizedBox(height: 18),
              const _AdminWorkspaceTable(),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AdminWorkspaceFilter { all, profiles, applications, safety }

class _AdminWorkspaceRow {
  const _AdminWorkspaceRow({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.dateText,
    required this.route,
    required this.filter,
  });

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String status;
  final String dateText;
  final String route;
  final _AdminWorkspaceFilter filter;

  String get searchable =>
      '$kind $title $subtitle $status $dateText'.toLowerCase();
}

class _AdminWorkspaceTable extends ConsumerStatefulWidget {
  const _AdminWorkspaceTable();

  @override
  ConsumerState<_AdminWorkspaceTable> createState() =>
      _AdminWorkspaceTableState();
}

class _AdminWorkspaceTableState extends ConsumerState<_AdminWorkspaceTable> {
  final TextEditingController _searchC = TextEditingController();
  final Set<String> _selected = <String>{};
  _AdminWorkspaceFilter _filter = _AdminWorkspaceFilter.all;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final profiles = ref.watch(pendingProfilesProvider);
    final applications = ref.watch(castingAgentApplicationsProvider);
    final merges = ref.watch(accountMergeRequestsProvider);
    final safety = ref.watch(safetyReportsProvider);

    final loading =
        profiles.isLoading ||
        applications.isLoading ||
        merges.isLoading ||
        safety.isLoading;
    final rows = <_AdminWorkspaceRow>[
      for (final item in profiles.valueOrNull ?? const [])
        _AdminWorkspaceRow(
          id: 'profile:${item.id}',
          kind: ru ? 'Анкета' : 'Profile',
          title: item.fullName.trim().isEmpty ? 'Анкета' : item.fullName.trim(),
          subtitle: [
            item.profileTypeLabel(context),
            item.city,
            item.country,
          ].where((part) => part.trim().isNotEmpty).join(' • '),
          status: ru ? 'На модерации' : 'Pending',
          dateText: '',
          route: Routes.moderationAdmin,
          filter: _AdminWorkspaceFilter.profiles,
        ),
      for (final item in applications.valueOrNull ?? const [])
        _AdminWorkspaceRow(
          id: 'application:${item.id}',
          kind: ru ? 'Заявка' : 'Request',
          title: item.owner.displayName.isEmpty
              ? item.userId
              : item.owner.displayName,
          subtitle: [
            item.requestedType.label(context),
            item.owner.companyName,
            item.owner.city,
          ].where((part) => part.trim().isNotEmpty).join(' • '),
          status: ru ? 'Ожидает' : 'Pending',
          dateText: _dateText(item.createdAt),
          route: Routes.castingAgentApplicationsAdmin,
          filter: _AdminWorkspaceFilter.applications,
        ),
      for (final item in merges.valueOrNull ?? const [])
        _AdminWorkspaceRow(
          id: 'merge:${item.id}',
          kind: 'Merge',
          title: item.title,
          subtitle: [
            item.requestedPhone,
            item.requesterEmail,
            item.requesterPhone,
          ].where((part) => part.trim().isNotEmpty).join(' • '),
          status: ru ? 'Ожидает' : 'Pending',
          dateText: _dateText(item.createdAt),
          route: Routes.accountMergeRequestsAdmin,
          filter: _AdminWorkspaceFilter.applications,
        ),
      for (final row in safety.valueOrNull ?? const <Map<String, dynamic>>[])
        _AdminWorkspaceRow(
          id: 'safety:${(row['id'] ?? '').toString()}',
          kind: 'Safety',
          title: (row['reason'] ?? '').toString().trim().isEmpty
              ? (ru ? 'Жалоба' : 'Report')
              : (row['reason'] ?? '').toString().trim(),
          subtitle: [
            (row['profile_id'] ?? '').toString(),
            (row['comment'] ?? '').toString(),
          ].where((part) => part.trim().isNotEmpty).join(' • '),
          status: (row['status'] ?? '').toString().trim().isEmpty
              ? 'open'
              : (row['status'] ?? '').toString().trim(),
          dateText: _dateText(
            DateTime.tryParse((row['created_at'] ?? '').toString()),
          ),
          route: Routes.safetyAdmin,
          filter: _AdminWorkspaceFilter.safety,
        ),
    ];

    rows.sort((a, b) => b.dateText.compareTo(a.dateText));

    final query = _searchC.text.trim().toLowerCase();
    final filtered = rows
        .where((row) {
          final filterOk =
              _filter == _AdminWorkspaceFilter.all || row.filter == _filter;
          final searchOk = query.isEmpty || row.searchable.contains(query);
          return filterOk && searchOk;
        })
        .toList(growable: false);

    _selected.removeWhere((id) => !filtered.any((row) => row.id == id));

    return _AdminPanelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ru ? 'ОПЕРАТОРСКИЙ СТОЛ' : 'WORKSPACE',
                    style: adminCommandStyle(size: 15, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ru
                        ? 'Живые очереди, поиск и выбор строк'
                        : 'Live queues, search and row selection',
                    style: adminBodyStyle(
                      size: 12,
                      color: kTextMuted,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              );
              final search = SizedBox(
                width: compact ? double.infinity : 360,
                child: TextField(
                  controller: _searchC,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: ru ? 'Поиск по таблице' : 'Search table',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.76),
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
                      borderSide: const BorderSide(color: BrandTheme.redTop),
                    ),
                  ),
                  style: adminBodyStyle(size: 14, color: kTextDark),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, const SizedBox(height: 12), search],
                );
              }
              return Row(
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 12),
                  search,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _AdminWorkspaceFilters(
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 12),
          if (_selected.isNotEmpty) ...[
            _AdminBulkBar(
              count: _selected.length,
              onClear: () => setState(_selected.clear),
              onOpen: () {
                final first = filtered.firstWhere(
                  (row) => _selected.contains(row.id),
                  orElse: () => filtered.first,
                );
                context.go(first.route);
              },
            ),
            const SizedBox(height: 12),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                ru ? 'СТРОК НЕТ' : 'NO ROWS',
                textAlign: TextAlign.center,
                style: adminCommandStyle(
                  size: 13,
                  color: kTextMuted,
                  letterSpacing: 1.0,
                ),
              ),
            )
          else
            _AdminRowsTable(
              rows: filtered,
              selected: _selected,
              onToggle: (id) {
                setState(() {
                  if (!_selected.add(id)) _selected.remove(id);
                });
              },
            ),
        ],
      ),
    );
  }

  String _dateText(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}';
  }
}

class _AdminWorkspaceFilters extends StatelessWidget {
  const _AdminWorkspaceFilters({
    required this.selected,
    required this.onChanged,
  });

  final _AdminWorkspaceFilter selected;
  final ValueChanged<_AdminWorkspaceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final items = [
      (value: _AdminWorkspaceFilter.all, label: ru ? 'ВСЕ' : 'ALL'),
      (
        value: _AdminWorkspaceFilter.profiles,
        label: ru ? 'АНКЕТЫ' : 'PROFILES',
      ),
      (
        value: _AdminWorkspaceFilter.applications,
        label: ru ? 'ЗАЯВКИ' : 'REQUESTS',
      ),
      (value: _AdminWorkspaceFilter.safety, label: 'SAFETY'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            selected: selected == item.value,
            label: Text(item.label),
            onSelected: (_) => onChanged(item.value),
            selectedColor: kTextDark,
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            labelStyle: adminCommandStyle(
              size: 11,
              letterSpacing: 0.9,
              color: selected == item.value ? Colors.white : kTextDark,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: selected == item.value ? kTextDark : kBorderColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminBulkBar extends StatelessWidget {
  const _AdminBulkBar({
    required this.count,
    required this.onClear,
    required this.onOpen,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: catalogSearchDecoration(
        radius: 18,
        borderColor: BrandTheme.redTop.withValues(alpha: 0.42),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ru ? 'Выбрано: $count' : 'Selected: $count',
              style: adminCommandStyle(size: 12, letterSpacing: 0.8),
            ),
          ),
          TextButton(onPressed: onClear, child: Text(ru ? 'СБРОС' : 'CLEAR')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onOpen,
            style: ElevatedButton.styleFrom(
              backgroundColor: kTextDark,
              foregroundColor: Colors.white,
            ),
            child: Text(ru ? 'ОТКРЫТЬ' : 'OPEN'),
          ),
        ],
      ),
    );
  }
}

class _AdminRowsTable extends StatelessWidget {
  const _AdminRowsTable({
    required this.rows,
    required this.selected,
    required this.onToggle,
  });

  final List<_AdminWorkspaceRow> rows;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    if (narrow) {
      return Column(
        children: [
          for (final row in rows) ...[
            _AdminMobileRowCard(
              row: row,
              selected: selected.contains(row.id),
              onToggle: () => onToggle(row.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(44),
          1: FixedColumnWidth(112),
          2: FlexColumnWidth(1.4),
          3: FlexColumnWidth(1.2),
          4: FixedColumnWidth(112),
          5: FixedColumnWidth(86),
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: kBorderColor.withValues(alpha: 0.7),
          ),
        ),
        children: [
          _tableRow(
            context,
            header: true,
            cells: const ['', 'ТИП', 'НАЗВАНИЕ', 'ДЕТАЛИ', 'СТАТУС', 'ДАТА'],
          ),
          for (final row in rows)
            TableRow(
              decoration: BoxDecoration(
                color: selected.contains(row.id)
                    ? BrandTheme.redTop.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.42),
              ),
              children: [
                _TableCellBox(
                  child: Checkbox(
                    value: selected.contains(row.id),
                    activeColor: BrandTheme.redTop,
                    onChanged: (_) => onToggle(row.id),
                  ),
                ),
                _TableCellBox(text: row.kind),
                _TableCellBox(text: row.title, strong: true),
                _TableCellBox(text: row.subtitle),
                _TableCellBox(text: row.status, accent: true),
                _TableCellBox(text: row.dateText),
              ],
            ),
        ],
      ),
    );
  }

  TableRow _tableRow(
    BuildContext context, {
    required bool header,
    required List<String> cells,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: header ? kTextDark : Colors.white.withValues(alpha: 0.42),
      ),
      children: [
        for (final cell in cells)
          _TableCellBox(text: cell, header: header, strong: header),
      ],
    );
  }
}

class _TableCellBox extends StatelessWidget {
  const _TableCellBox({
    this.text = '',
    this.child,
    this.header = false,
    this.strong = false,
    this.accent = false,
  });

  final String text;
  final Widget? child;
  final bool header;
  final bool strong;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child:
          child ??
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: header
                ? adminCommandStyle(
                    size: 11,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  )
                : adminBodyStyle(
                    size: 13,
                    color: accent ? BrandTheme.redTop : kTextDark,
                    weight: strong ? FontWeight.w900 : FontWeight.w700,
                  ),
          ),
    );
  }
}

class _AdminMobileRowCard extends StatelessWidget {
  const _AdminMobileRowCard({
    required this.row,
    required this.selected,
    required this.onToggle,
  });

  final _AdminWorkspaceRow row;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: catalogSearchDecoration(
        radius: 18,
        borderColor: selected ? BrandTheme.redTop : kBorderColor,
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            activeColor: BrandTheme.redTop,
            onChanged: (_) => onToggle(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.kind, style: adminCommandStyle(size: 11)),
                const SizedBox(height: 4),
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminCommandStyle(size: 15, letterSpacing: 0.5),
                ),
                if (row.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    row.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminBodyStyle(size: 12, color: kTextMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.status,
            style: adminCommandStyle(
              size: 10,
              color: BrandTheme.redTop,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

enum _AdminActionGroup { queue, operations, audit }

class _AdminAction {
  const _AdminAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.group,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final String description;
  final IconData icon;
  final _AdminActionGroup group;
  final VoidCallback onTap;
  final int badge;
}

class _AdminDashboardHeader extends StatelessWidget {
  const _AdminDashboardHeader({
    required this.title,
    required this.subtitle,
    required this.total,
  });

  final String title;
  final String subtitle;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _AdminPanelSurface(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: adminCommandStyle(size: 24, letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: adminBodyStyle(
                    size: 14,
                    color: kTextMuted,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _AdminBadge(count: total, large: true),
        ],
      ),
    );
  }
}

class _AdminStatGrid extends StatelessWidget {
  const _AdminStatGrid({required this.counts});

  final AdminDashboardCounts counts;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final stats = [
      (label: ru ? 'МОДЕРАЦИЯ' : 'MODERATION', value: counts.moderation),
      (label: ru ? 'ЗАЯВКИ' : 'REQUESTS', value: counts.agentApplications),
      (label: ru ? 'MERGE' : 'MERGE', value: counts.accountMerges),
      (label: ru ? 'SAFETY' : 'SAFETY', value: counts.safety),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 4 : 2;
        final gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in stats)
              SizedBox(
                width: itemWidth,
                child: _AdminPanelSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: adminCommandStyle(
                            size: 12,
                            letterSpacing: 1.0,
                            color: kTextMuted,
                          ),
                        ),
                      ),
                      Text(
                        '${item.value}',
                        style: adminCommandStyle(
                          size: 24,
                          letterSpacing: 0,
                          color: item.value > 0 ? BrandTheme.redTop : kTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminActionSection extends StatelessWidget {
  const _AdminActionSection({
    required this.title,
    required this.items,
    required this.dense,
  });

  final String title;
  final List<_AdminAction> items;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _AdminPanelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: adminCommandStyle(size: 15, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++) ...[
            _AdminActionTile(action: items[i], dense: dense),
            if (i != items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({required this.action, required this.dense});

  final _AdminAction action;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: action.onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 14,
            vertical: dense ? 12 : 14,
          ),
          decoration: catalogSearchDecoration(
            radius: 22,
            borderColor: action.badge > 0
                ? BrandTheme.redTop.withValues(alpha: 0.48)
                : kBorderColor,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: BrandTheme.darkPillGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: adminCommandStyle(
                        size: dense ? 13 : 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: adminBodyStyle(
                        size: 12,
                        color: kTextMuted,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (action.badge > 0) _AdminBadge(count: action.badge),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge({required this.count, this.large = false});

  final int count;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: large ? 42 : 26),
      height: large ? 42 : 26,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8),
      decoration: BoxDecoration(
        color: count > 0
            ? BrandTheme.redTop
            : kTextMuted.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: adminCommandStyle(
          size: large ? 16 : 11,
          letterSpacing: 0,
          color: count > 0 ? Colors.white : kTextMuted,
        ),
      ),
    );
  }
}

class _AdminPanelSurface extends StatelessWidget {
  const _AdminPanelSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: catalogCardDecoration(),
      child: child,
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.exitLabel, required this.onExit});

  final String exitLabel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _AdminSurface(
      child: Align(
        alignment: Alignment.centerLeft,
        child: BrandPillButton(
          label: exitLabel,
          style: BrandPillStyle.dark,
          onTap: onExit,
        ),
      ),
    );
  }
}

class _AdminSurface extends StatelessWidget {
  const _AdminSurface({required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      constraints: maxWidth == null
          ? null
          : const BoxConstraints(maxWidth: _kAdminMaxCardWidth),
      padding: const EdgeInsets.all(_kAdminPad),
      decoration: catalogCardDecoration(),
      child: child,
    );

    if (maxWidth == null) return content;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: content,
    );
  }
}
