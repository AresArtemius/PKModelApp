import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/admin_action_log_service.dart';
import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'account_merge_requests_page.dart';
import 'admin_style.dart';
import 'selection_providers.dart';
import 'casting_agent_applications_page.dart';
import 'moderation_admin_page.dart';
import '../profile/profile_model.dart';
import 'safety_admin_page.dart';

const _kAdminBg = BrandTheme.greyMid;

const double _kAdminPad = 14;
const double _kAdminPagePad = 16;
const double _kAdminSectionGap = 12;
const double _kAdminMessagePadV = 18;
const double _kAdminMaxCardWidth = 460;

final _adminTaskAssignmentsProvider = FutureProvider<List<_AdminTaskAssignment>>((
  ref,
) async {
  final sb = ref.watch(supabaseProvider);
  try {
    final rows = await sb
        .from('admin_task_assignments')
        .select(
          'id,target_table,target_id,assigned_to_user_id,assigned_to_name,assigned_at,priority,due_at',
        )
        .order('assigned_at', ascending: false);
    return (rows as List)
        .map(
          (row) => _AdminTaskAssignment.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['admin_task_assignments'])) {
      return const <_AdminTaskAssignment>[];
    }
    if (SupabaseCompat.isMissingAnyColumn(e, const ['priority', 'due_at'])) {
      final rows = await sb
          .from('admin_task_assignments')
          .select(
            'id,target_table,target_id,assigned_to_user_id,assigned_to_name,assigned_at',
          )
          .order('assigned_at', ascending: false);
      return (rows as List)
          .map(
            (row) => _AdminTaskAssignment.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    }
    rethrow;
  }
});

class _AdminTaskAssignment {
  const _AdminTaskAssignment({
    required this.id,
    required this.targetTable,
    required this.targetId,
    required this.assignedToUserId,
    required this.assignedToName,
    required this.assignedAt,
    required this.priority,
    required this.dueAt,
  });

  factory _AdminTaskAssignment.fromMap(Map<String, dynamic> map) {
    return _AdminTaskAssignment(
      id: (map['id'] ?? '').toString(),
      targetTable: (map['target_table'] ?? '').toString().trim(),
      targetId: (map['target_id'] ?? '').toString().trim(),
      assignedToUserId: (map['assigned_to_user_id'] ?? '').toString().trim(),
      assignedToName: (map['assigned_to_name'] ?? '').toString().trim(),
      assignedAt: DateTime.tryParse((map['assigned_at'] ?? '').toString()),
      priority: _normalizeAdminTaskPriority(map['priority']),
      dueAt: DateTime.tryParse((map['due_at'] ?? '').toString()),
    );
  }

  final String id;
  final String targetTable;
  final String targetId;
  final String assignedToUserId;
  final String assignedToName;
  final DateTime? assignedAt;
  final String priority;
  final DateTime? dueAt;

  String get key => '$targetTable:$targetId';
}

String _normalizeAdminTaskPriority(Object? value) {
  final raw = (value ?? '').toString().trim().toLowerCase();
  if (raw == 'critical' || raw == 'urgent' || raw == 'normal') return raw;
  return 'normal';
}

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
              final selectionCount = ref
                  .watch(adminSelectionCountProvider)
                  .maybeWhen(data: (value) => value, orElse: () => 0);
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
                    onTap: () =>
                        context.go('${Routes.createCastingAdmin}?from=admin'),
                  ),
                  _AdminAction(
                    label: ru ? 'ПОЛЬЗОВАТЕЛИ' : 'USERS',
                    description: ru
                        ? 'Аккаунты, роли, контакты'
                        : 'Accounts, roles, contacts',
                    icon: Icons.groups_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.adminUsers),
                  ),
                  _AdminAction(
                    label: ru ? 'ВСЕ АНКЕТЫ' : 'ALL PROFILES',
                    description: ru
                        ? 'Статусы, роли, медиа'
                        : 'Statuses, roles, media',
                    icon: Icons.view_list_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.adminProfiles),
                  ),
                  _AdminAction(
                    label: ru ? 'ВСЕ КАСТИНГИ' : 'ALL CASTINGS',
                    description: ru
                        ? 'Этапы, отклики, референсы'
                        : 'Stages, responses, refs',
                    icon: Icons.table_chart_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.adminCastings),
                  ),
                  _AdminAction(
                    label: ru ? 'ВСЕ ПОДБОРКИ' : 'ALL SELECTIONS',
                    description: ru
                        ? 'Статусы, клиенты, PDF'
                        : 'Statuses, clients, PDF',
                    icon: Icons.folder_copy_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.adminSelectionsTable),
                  ),
                  _AdminAction(
                    label: t.selectionUpper,
                    description: ru
                        ? 'Подборки и кастинги'
                        : 'Selections and castings',
                    icon: Icons.dashboard_customize_rounded,
                    group: _AdminActionGroup.operations,
                    badge: selectionCount,
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
                    description: ru ? 'История действий' : 'Audit and history',
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
                title: ru ? 'АДМИН-ПАНЕЛЬ' : 'BACK OFFICE',
                subtitle: ru
                    ? 'Заявки, безопасность, подборки, кастинги, SLA и журнал действий'
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

enum _AdminBulkActionType { approveProfiles, rejectProfiles, closeSafety }

class _AdminBulkRowResult {
  const _AdminBulkRowResult({
    required this.id,
    required this.title,
    required this.success,
    this.message = '',
  });

  final String id;
  final String title;
  final bool success;
  final String message;
}

class _AdminBulkResult {
  const _AdminBulkResult({
    required this.actionType,
    required this.title,
    required this.rows,
  });

  final _AdminBulkActionType actionType;
  final String title;
  final List<_AdminBulkRowResult> rows;

  Iterable<_AdminBulkRowResult> get failedRows =>
      rows.where((row) => !row.success);
  int get successCount => rows.where((row) => row.success).length;
  int get failedCount => failedRows.length;
}

class _AdminWorkspaceRow {
  const _AdminWorkspaceRow({
    required this.id,
    required this.targetTable,
    required this.targetId,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.dateText,
    required this.route,
    required this.filter,
    this.assignedToUserId = '',
    this.assignedToName = '',
    this.priority = 'normal',
    this.dueAt,
  });

  final String id;
  final String targetTable;
  final String targetId;
  final String kind;
  final String title;
  final String subtitle;
  final String status;
  final String dateText;
  final String route;
  final _AdminWorkspaceFilter filter;
  final String assignedToUserId;
  final String assignedToName;
  final String priority;
  final DateTime? dueAt;

  String get assignmentKey => '$targetTable:$targetId';
  String get assignmentLabel => assignedToName.trim().isNotEmpty
      ? assignedToName.trim()
      : assignedToUserId.trim();
  bool get isOverdue =>
      dueAt != null && dueAt!.isBefore(DateTime.now().toUtc());
  int get priorityRank => switch (priority) {
    'critical' => 3,
    'urgent' => 2,
    _ => 1,
  };
  String priorityLabel(bool ru) => switch (priority) {
    'critical' => ru ? 'Критично' : 'Critical',
    'urgent' => ru ? 'Срочно' : 'Urgent',
    _ => ru ? 'Обычно' : 'Normal',
  };
  String dueLabel(bool ru) {
    final due = dueAt;
    if (due == null) return ru ? 'Без срока' : 'No due date';
    final local = due.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
    if (isOverdue) return ru ? 'Просрочено: $date' : 'Overdue: $date';
    return ru ? 'До $date' : 'Due $date';
  }

  String slaLabel(bool ru) => '${priorityLabel(ru)} • ${dueLabel(ru)}';

  String get searchable =>
      '$kind $title $subtitle $status $dateText $assignmentLabel $priority'
          .toLowerCase();
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
  bool _bulkBusy = false;
  bool _mineOnly = false;
  _AdminBulkResult? _lastBulkResult;

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
    final assignmentsAsync = ref.watch(_adminTaskAssignmentsProvider);
    final assignmentsByKey = <String, _AdminTaskAssignment>{
      for (final assignment
          in assignmentsAsync.valueOrNull ?? const <_AdminTaskAssignment>[])
        assignment.key: assignment,
    };
    final currentUserId =
        ref.watch(supabaseProvider).auth.currentUser?.id ?? '';

    _AdminTaskAssignment? assignmentFor(String table, String id) =>
        assignmentsByKey['$table:$id'];

    final loading =
        profiles.isLoading ||
        applications.isLoading ||
        merges.isLoading ||
        safety.isLoading ||
        assignmentsAsync.isLoading;
    final rows = <_AdminWorkspaceRow>[
      for (final item in profiles.valueOrNull ?? const [])
        _AdminWorkspaceRow(
          id: 'profile:${item.id}',
          targetTable: 'profiles',
          targetId: item.id,
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
          assignedToUserId:
              assignmentFor('profiles', item.id)?.assignedToUserId ?? '',
          assignedToName:
              assignmentFor('profiles', item.id)?.assignedToName ?? '',
          priority: assignmentFor('profiles', item.id)?.priority ?? 'normal',
          dueAt: assignmentFor('profiles', item.id)?.dueAt,
        ),
      for (final item in applications.valueOrNull ?? const [])
        _AdminWorkspaceRow(
          id: 'application:${item.id}',
          targetTable: 'casting_agent_applications',
          targetId: item.id,
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
          assignedToUserId:
              assignmentFor(
                'casting_agent_applications',
                item.id,
              )?.assignedToUserId ??
              '',
          assignedToName:
              assignmentFor(
                'casting_agent_applications',
                item.id,
              )?.assignedToName ??
              '',
          priority:
              assignmentFor('casting_agent_applications', item.id)?.priority ??
              'normal',
          dueAt: assignmentFor('casting_agent_applications', item.id)?.dueAt,
        ),
      for (final item in merges.valueOrNull ?? const [])
        _AdminWorkspaceRow(
          id: 'merge:${item.id}',
          targetTable: 'account_merge_requests',
          targetId: item.id,
          kind: ru ? 'Объединение' : 'Merge',
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
          assignedToUserId:
              assignmentFor(
                'account_merge_requests',
                item.id,
              )?.assignedToUserId ??
              '',
          assignedToName:
              assignmentFor(
                'account_merge_requests',
                item.id,
              )?.assignedToName ??
              '',
          priority:
              assignmentFor('account_merge_requests', item.id)?.priority ??
              'normal',
          dueAt: assignmentFor('account_merge_requests', item.id)?.dueAt,
        ),
      for (final row in safety.valueOrNull ?? const <Map<String, dynamic>>[])
        _AdminWorkspaceRow(
          id: 'safety:${(row['id'] ?? '').toString()}',
          targetTable: 'profile_reports',
          targetId: (row['id'] ?? '').toString(),
          kind: ru ? 'Безопасность' : 'Safety',
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
          assignedToUserId:
              assignmentFor(
                'profile_reports',
                (row['id'] ?? '').toString(),
              )?.assignedToUserId ??
              '',
          assignedToName:
              assignmentFor(
                'profile_reports',
                (row['id'] ?? '').toString(),
              )?.assignedToName ??
              '',
          priority:
              assignmentFor(
                'profile_reports',
                (row['id'] ?? '').toString(),
              )?.priority ??
              'normal',
          dueAt: assignmentFor(
            'profile_reports',
            (row['id'] ?? '').toString(),
          )?.dueAt,
        ),
    ];

    rows.sort((a, b) {
      final overdue = (b.isOverdue ? 1 : 0).compareTo(a.isOverdue ? 1 : 0);
      if (overdue != 0) return overdue;
      final priority = b.priorityRank.compareTo(a.priorityRank);
      if (priority != 0) return priority;
      final aDue = a.dueAt;
      final bDue = b.dueAt;
      if (aDue != null && bDue != null) return aDue.compareTo(bDue);
      if (aDue != null) return -1;
      if (bDue != null) return 1;
      return b.dateText.compareTo(a.dateText);
    });

    final query = _searchC.text.trim().toLowerCase();
    final filtered = rows
        .where((row) {
          final filterOk =
              _filter == _AdminWorkspaceFilter.all || row.filter == _filter;
          final searchOk = query.isEmpty || row.searchable.contains(query);
          final mineOk =
              !_mineOnly ||
              (currentUserId.isNotEmpty &&
                  row.assignedToUserId == currentUserId);
          return filterOk && searchOk && mineOk;
        })
        .toList(growable: false);

    _selected.removeWhere((id) => !filtered.any((row) => row.id == id));

    final selectedRows = filtered
        .where((row) => _selected.contains(row.id))
        .toList(growable: false);
    final profileById = <String, MyProfileState>{
      for (final item in profiles.valueOrNull ?? const <MyProfileState>[])
        item.id: item,
    };
    final selectedProfiles = selectedRows
        .where((row) => row.filter == _AdminWorkspaceFilter.profiles)
        .map((row) => profileById[row.targetId])
        .whereType<MyProfileState>()
        .toList(growable: false);
    final selectedSafetyIds = selectedRows
        .where((row) => row.filter == _AdminWorkspaceFilter.safety)
        .map((row) => row.targetId.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final selectedSafetyRows = selectedRows
        .where((row) => row.filter == _AdminWorkspaceFilter.safety)
        .toList(growable: false);

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
            mineOnly: _mineOnly,
            onChanged: (value) => setState(() => _filter = value),
            onMineOnlyChanged: (value) => setState(() => _mineOnly = value),
          ),
          const SizedBox(height: 12),
          if (_selected.isNotEmpty) ...[
            _AdminBulkBar(
              count: _selected.length,
              profileCount: selectedProfiles.length,
              safetyCount: selectedSafetyIds.length,
              busy: _bulkBusy,
              onClear: () => setState(_selected.clear),
              onOpen: () {
                final first = filtered.firstWhere(
                  (row) => _selected.contains(row.id),
                  orElse: () => filtered.first,
                );
                context.go(first.route);
              },
              onApproveProfiles: selectedProfiles.isEmpty || _bulkBusy
                  ? null
                  : () => _bulkApproveProfiles(selectedProfiles),
              onRejectProfiles: selectedProfiles.isEmpty || _bulkBusy
                  ? null
                  : () => _bulkRejectProfiles(selectedProfiles),
              onCloseSafety: selectedSafetyIds.isEmpty || _bulkBusy
                  ? null
                  : () => _bulkCloseSafetyReports(selectedSafetyRows),
              onExport: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _exportRows(selectedRows),
              onAssignToMe: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _assignRowsToMe(selectedRows),
              onUnassign: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _unassignRows(selectedRows),
              onSetNormal: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _setRowsPriority(selectedRows, 'normal'),
              onSetUrgent: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _setRowsPriority(selectedRows, 'urgent'),
              onSetCritical: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _setRowsPriority(selectedRows, 'critical'),
              onDue24h: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _setRowsDue(selectedRows, const Duration(hours: 24)),
              onDue48h: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _setRowsDue(selectedRows, const Duration(hours: 48)),
              onDue7d: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _setRowsDue(selectedRows, const Duration(days: 7)),
              onClearDue: selectedRows.isEmpty || _bulkBusy
                  ? null
                  : () => _clearRowsDue(selectedRows),
            ),
            const SizedBox(height: 12),
          ],
          if (_lastBulkResult != null) ...[
            _AdminBulkResultPanel(
              result: _lastBulkResult!,
              busy: _bulkBusy,
              onRetryFailed: _lastBulkResult!.failedCount == 0 || _bulkBusy
                  ? null
                  : () => _retryFailedRows(_lastBulkResult!),
              onClear: _bulkBusy
                  ? null
                  : () => setState(() => _lastBulkResult = null),
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

  Future<void> _bulkApproveProfiles(List<MyProfileState> profiles) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await _confirmBulkAction(
      title: ru ? 'ОДОБРИТЬ АНКЕТЫ?' : 'APPROVE PROFILES?',
      message: ru
          ? 'Будет опубликовано анкет: ${profiles.length}. После одобрения они появятся в каталоге.'
          : '${profiles.length} profiles will be published to the catalog.',
      confirmLabel: ru ? 'ОДОБРИТЬ' : 'APPROVE',
      destructive: false,
    );
    if (!confirmed) return;
    await _runProfileBulkAction(
      actionType: _AdminBulkActionType.approveProfiles,
      title: ru ? 'Одобрение анкет' : 'Profile approval',
      profiles: profiles,
      actionTypeForLog: 'bulk_profiles_approved',
      logTitle: ru ? 'Анкеты одобрены массово' : 'Profiles bulk approved',
      successSnack: ru ? 'Одобрено' : 'Approved',
      runOne: (sb, profile) => _publishProfile(sb, profile),
      logStatus: 'approved',
    );
  }

  Future<void> _bulkRejectProfiles(List<MyProfileState> profiles) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await _confirmBulkAction(
      title: ru ? 'ОТКЛОНИТЬ АНКЕТЫ?' : 'REJECT PROFILES?',
      message: ru
          ? 'Будет отклонено анкет: ${profiles.length}. Пользователь увидит статус отклонения.'
          : '${profiles.length} profiles will be rejected.',
      confirmLabel: ru ? 'ОТКЛОНИТЬ' : 'REJECT',
      destructive: true,
    );
    if (!confirmed) return;
    await _runProfileBulkAction(
      actionType: _AdminBulkActionType.rejectProfiles,
      title: ru ? 'Отклонение анкет' : 'Profile rejection',
      profiles: profiles,
      actionTypeForLog: 'bulk_profiles_rejected',
      logTitle: ru ? 'Анкеты отклонены массово' : 'Profiles bulk rejected',
      successSnack: ru ? 'Отклонено' : 'Rejected',
      runOne: (sb, profile) async {
        await sb
            .from('profiles')
            .update(<String, dynamic>{
              'status': 'rejected',
              'moderation_comment': ru
                  ? 'Отклонено массовым действием администратора.'
                  : 'Rejected by admin bulk action.',
            })
            .eq('id', profile.id);
      },
      logStatus: 'rejected',
    );
  }

  Future<void> _bulkCloseSafetyReports(List<_AdminWorkspaceRow> reports) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await _confirmBulkAction(
      title: ru ? 'ЗАКРЫТЬ ЖАЛОБЫ?' : 'CLOSE SAFETY REPORTS?',
      message: ru
          ? 'Будет закрыто жалоб: ${reports.length}. Они уйдут из очереди безопасности.'
          : '${reports.length} safety reports will be closed.',
      confirmLabel: ru ? 'ЗАКРЫТЬ' : 'CLOSE',
      destructive: true,
    );
    if (!confirmed) return;
    await _runSafetyBulkAction(reports);
  }

  Future<void> _runProfileBulkAction({
    required _AdminBulkActionType actionType,
    required String title,
    required List<MyProfileState> profiles,
    required String actionTypeForLog,
    required String logTitle,
    required String successSnack,
    required Future<void> Function(SupabaseClient sb, MyProfileState profile)
    runOne,
    required String logStatus,
  }) async {
    if (_bulkBusy) return;
    setState(() => _bulkBusy = true);
    final sb = ref.read(supabaseProvider);
    final results = <_AdminBulkRowResult>[];
    try {
      for (final profile in profiles) {
        try {
          await runOne(sb, profile);
          results.add(
            _AdminBulkRowResult(
              id: profile.id,
              title: profile.fullName.trim().isEmpty
                  ? profile.id
                  : profile.fullName.trim(),
              success: true,
            ),
          );
        } catch (e) {
          results.add(
            _AdminBulkRowResult(
              id: profile.id,
              title: profile.fullName.trim().isEmpty
                  ? profile.id
                  : profile.fullName.trim(),
              success: false,
              message: _errorText(e),
            ),
          );
        }
      }
      await _logBulkResult(
        sb: sb,
        actionType: actionTypeForLog,
        title: logTitle,
        targetTable: 'profiles',
        status: _bulkLogStatus(results, successStatus: logStatus),
        results: results,
      );
      ref.invalidate(pendingProfilesProvider);
      ref.invalidate(adminDashboardCountsProvider);
      if (!mounted) return;
      setState(() {
        _lastBulkResult = _AdminBulkResult(
          actionType: actionType,
          title: title,
          rows: results,
        );
        _selected.removeWhere(
          (id) =>
              results.any((row) => row.success && id == 'profile:${row.id}'),
        );
      });
      _showBulkSnack(successSnack, results);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _runSafetyBulkAction(List<_AdminWorkspaceRow> reports) async {
    if (_bulkBusy) return;
    setState(() => _bulkBusy = true);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final sb = ref.read(supabaseProvider);
    final results = <_AdminBulkRowResult>[];
    try {
      for (final report in reports) {
        try {
          await sb
              .from('profile_reports')
              .update(<String, dynamic>{'status': 'closed'})
              .eq('id', report.targetId);
          results.add(
            _AdminBulkRowResult(
              id: report.targetId,
              title: report.title,
              success: true,
            ),
          );
        } catch (e) {
          results.add(
            _AdminBulkRowResult(
              id: report.targetId,
              title: report.title,
              success: false,
              message: _errorText(e),
            ),
          );
        }
      }
      await _logBulkResult(
        sb: sb,
        actionType: 'bulk_safety_closed',
        title: ru
            ? 'Жалобы безопасности закрыты массово'
            : 'Safety reports bulk closed',
        targetTable: 'profile_reports',
        status: _bulkLogStatus(results, successStatus: 'closed'),
        results: results,
      );
      ref.invalidate(safetyReportsProvider);
      ref.invalidate(adminDashboardCountsProvider);
      if (!mounted) return;
      setState(() {
        _lastBulkResult = _AdminBulkResult(
          actionType: _AdminBulkActionType.closeSafety,
          title: ru ? 'Закрытие жалоб' : 'Safety closing',
          rows: results,
        );
        _selected.removeWhere(
          (id) => results.any((row) => row.success && id == 'safety:${row.id}'),
        );
      });
      _showBulkSnack(ru ? 'Закрыто' : 'Closed', results);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _retryFailedRows(_AdminBulkResult result) async {
    final failedIds = result.failedRows.map((row) => row.id).toSet();
    if (failedIds.isEmpty) return;
    switch (result.actionType) {
      case _AdminBulkActionType.approveProfiles:
        final profiles =
            (ref.read(pendingProfilesProvider).valueOrNull ??
                    const <MyProfileState>[])
                .where((profile) => failedIds.contains(profile.id))
                .toList(growable: false);
        if (profiles.isNotEmpty) await _bulkApproveProfiles(profiles);
        break;
      case _AdminBulkActionType.rejectProfiles:
        final profiles =
            (ref.read(pendingProfilesProvider).valueOrNull ??
                    const <MyProfileState>[])
                .where((profile) => failedIds.contains(profile.id))
                .toList(growable: false);
        if (profiles.isNotEmpty) await _bulkRejectProfiles(profiles);
        break;
      case _AdminBulkActionType.closeSafety:
        final safetyRows =
            (ref.read(safetyReportsProvider).valueOrNull ??
                    const <Map<String, dynamic>>[])
                .where(
                  (row) => failedIds.contains((row['id'] ?? '').toString()),
                )
                .map(
                  (row) => _AdminWorkspaceRow(
                    id: 'safety:${(row['id'] ?? '').toString()}',
                    targetTable: 'profile_reports',
                    targetId: (row['id'] ?? '').toString(),
                    kind: 'Безопасность',
                    title: (row['reason'] ?? '').toString().trim().isEmpty
                        ? 'Жалоба'
                        : (row['reason'] ?? '').toString().trim(),
                    subtitle: (row['comment'] ?? '').toString(),
                    status: (row['status'] ?? '').toString(),
                    dateText: _dateText(
                      DateTime.tryParse((row['created_at'] ?? '').toString()),
                    ),
                    route: Routes.safetyAdmin,
                    filter: _AdminWorkspaceFilter.safety,
                  ),
                )
                .toList(growable: false);
        if (safetyRows.isNotEmpty) await _bulkCloseSafetyReports(safetyRows);
        break;
    }
  }

  Future<bool> _confirmBulkAction({
    required String title,
    required String message,
    required String confirmLabel,
    required bool destructive,
  }) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: adminCommandStyle(size: 18, letterSpacing: 1.2),
        ),
        content: Text(
          message,
          style: adminBodyStyle(size: 14, color: kTextMuted),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ru ? 'ОТМЕНА' : 'CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: destructive ? BrandTheme.redTop : kTextDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _logBulkResult({
    required SupabaseClient sb,
    required String actionType,
    required String title,
    required String targetTable,
    required String status,
    required List<_AdminBulkRowResult> results,
  }) async {
    await AdminActionLogService(sb).log(
      actionType: actionType,
      title: title,
      description: results
          .map((row) => '${row.success ? 'OK' : 'ERR'}:${row.title}')
          .join(' • '),
      targetTable: targetTable,
      targetText: '${results.length}',
      status: status,
      metadata: <String, dynamic>{
        'success_ids': results
            .where((row) => row.success)
            .map((row) => row.id)
            .toList(growable: false),
        'failed_ids': results
            .where((row) => !row.success)
            .map((row) => row.id)
            .toList(growable: false),
        'errors': <Map<String, String>>[
          for (final row in results.where((row) => !row.success))
            {'id': row.id, 'title': row.title, 'message': row.message},
        ],
      },
    );
  }

  String _bulkLogStatus(
    List<_AdminBulkRowResult> results, {
    required String successStatus,
  }) {
    final failed = results.where((row) => !row.success).length;
    if (failed == 0) return successStatus;
    if (failed == results.length) return 'failed';
    return 'partial';
  }

  void _showBulkSnack(String action, List<_AdminBulkRowResult> results) {
    if (!mounted) return;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final failed = results.where((row) => !row.success).length;
    final success = results.length - failed;
    final message = ru
        ? '$action: $success успешно, $failed ошибок'
        : '$action: $success succeeded, $failed failed';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _assignRowsToMe(List<_AdminWorkspaceRow> rows) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final sb = ref.read(supabaseProvider);
    final user = sb.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ru ? 'Нужен вход администратора' : 'Admin sign-in required',
            ),
          ),
        );
      return;
    }
    final confirmed = await _confirmBulkAction(
      title: ru ? 'ВЗЯТЬ ЗАДАЧИ?' : 'ASSIGN TASKS?',
      message: ru
          ? 'Выбранные строки будут назначены на вас: ${rows.length}.'
          : '${rows.length} selected rows will be assigned to you.',
      confirmLabel: ru ? 'ВЗЯТЬ' : 'ASSIGN',
      destructive: false,
    );
    if (!confirmed) return;
    await _runBulkAction(
      successMessage: ru
          ? 'Назначено: ${rows.length}'
          : 'Assigned: ${rows.length}',
      action: () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final assigneeName = await _loadCurrentAdminName(
          sb,
          user.id,
          fallbackName: ru ? 'Оператор' : 'Operator',
        );
        await sb.from('admin_task_assignments').upsert(<Map<String, dynamic>>[
          for (final row in rows)
            <String, dynamic>{
              'target_table': row.targetTable,
              'target_id': row.targetId,
              'assigned_to_user_id': user.id,
              'assigned_to_name': assigneeName,
              'assigned_by_user_id': user.id,
              'assigned_at': now,
              'updated_at': now,
            },
        ], onConflict: 'target_table,target_id');
        await AdminActionLogService(sb).log(
          actionType: 'admin_tasks_assigned_to_me',
          title: ru
              ? 'Задачи назначены оператору'
              : 'Tasks assigned to operator',
          description: rows.map((row) => row.title).join(' • '),
          targetTable: 'admin_task_assignments',
          targetText: '${rows.length}',
          status: 'assigned',
          metadata: <String, dynamic>{
            'assignee_user_id': user.id,
            'assignee_name': assigneeName,
            'rows': _assignmentLogRows(rows),
          },
        );
        ref.invalidate(_adminTaskAssignmentsProvider);
      },
    );
  }

  Future<void> _unassignRows(List<_AdminWorkspaceRow> rows) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await _confirmBulkAction(
      title: ru ? 'СНЯТЬ ОТВЕТСТВЕННОГО?' : 'UNASSIGN TASKS?',
      message: ru
          ? 'Ответственный будет снят со строк: ${rows.length}.'
          : 'Assignee will be removed from ${rows.length} rows.',
      confirmLabel: ru ? 'СНЯТЬ' : 'UNASSIGN',
      destructive: true,
    );
    if (!confirmed) return;
    await _runBulkAction(
      successMessage: ru ? 'Ответственный снят' : 'Unassigned',
      action: () async {
        final sb = ref.read(supabaseProvider);
        for (final row in rows) {
          await sb
              .from('admin_task_assignments')
              .delete()
              .eq('target_table', row.targetTable)
              .eq('target_id', row.targetId);
        }
        await AdminActionLogService(sb).log(
          actionType: 'admin_tasks_unassigned',
          title: ru ? 'Ответственный снят с задач' : 'Tasks unassigned',
          description: rows.map((row) => row.title).join(' • '),
          targetTable: 'admin_task_assignments',
          targetText: '${rows.length}',
          status: 'unassigned',
          metadata: <String, dynamic>{'rows': _assignmentLogRows(rows)},
        );
        ref.invalidate(_adminTaskAssignmentsProvider);
      },
    );
  }

  Future<void> _setRowsPriority(
    List<_AdminWorkspaceRow> rows,
    String priority,
  ) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final normalized = _normalizeAdminTaskPriority(priority);
    final label = _priorityLabel(normalized, ru);
    await _upsertTaskMeta(
      rows: rows,
      successMessage: ru ? 'Приоритет: $label' : 'Priority: $label',
      actionType: 'admin_tasks_priority_updated',
      title: ru ? 'Приоритет задач обновлен' : 'Task priority updated',
      status: normalized,
      values: <String, dynamic>{'priority': normalized},
      extraMetadata: <String, dynamic>{'priority': normalized},
    );
  }

  Future<void> _setRowsDue(
    List<_AdminWorkspaceRow> rows,
    Duration duration,
  ) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final dueAt = DateTime.now().toUtc().add(duration);
    await _upsertTaskMeta(
      rows: rows,
      successMessage: ru ? 'Срок обновлен' : 'Due date updated',
      actionType: 'admin_tasks_due_updated',
      title: ru ? 'Срок задач обновлен' : 'Task due date updated',
      status: 'due_updated',
      values: <String, dynamic>{'due_at': dueAt.toIso8601String()},
      extraMetadata: <String, dynamic>{
        'due_at': dueAt.toIso8601String(),
        'duration_hours': duration.inHours,
      },
    );
  }

  Future<void> _clearRowsDue(List<_AdminWorkspaceRow> rows) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    await _upsertTaskMeta(
      rows: rows,
      successMessage: ru ? 'Срок снят' : 'Due date cleared',
      actionType: 'admin_tasks_due_cleared',
      title: ru ? 'Срок задач снят' : 'Task due date cleared',
      status: 'due_cleared',
      values: <String, dynamic>{'due_at': null},
      extraMetadata: const <String, dynamic>{'due_at': null},
    );
  }

  Future<void> _upsertTaskMeta({
    required List<_AdminWorkspaceRow> rows,
    required String successMessage,
    required String actionType,
    required String title,
    required String status,
    required Map<String, dynamic> values,
    required Map<String, dynamic> extraMetadata,
  }) async {
    await _runBulkAction(
      successMessage: successMessage,
      action: () async {
        final sb = ref.read(supabaseProvider);
        final user = sb.auth.currentUser;
        final now = DateTime.now().toUtc().toIso8601String();
        await sb.from('admin_task_assignments').upsert(<Map<String, dynamic>>[
          for (final row in rows)
            <String, dynamic>{
              'target_table': row.targetTable,
              'target_id': row.targetId,
              'updated_at': now,
              if (user != null) 'assigned_by_user_id': user.id,
              ...values,
            },
        ], onConflict: 'target_table,target_id');
        await AdminActionLogService(sb).log(
          actionType: actionType,
          title: title,
          description: rows.map((row) => row.title).join(' • '),
          targetTable: 'admin_task_assignments',
          targetText: '${rows.length}',
          status: status,
          metadata: <String, dynamic>{
            ...extraMetadata,
            'rows': _assignmentLogRows(rows),
          },
        );
        ref.invalidate(_adminTaskAssignmentsProvider);
      },
    );
  }

  String _priorityLabel(String priority, bool ru) => switch (priority) {
    'critical' => ru ? 'Критично' : 'Critical',
    'urgent' => ru ? 'Срочно' : 'Urgent',
    _ => ru ? 'Обычно' : 'Normal',
  };

  Future<String> _loadCurrentAdminName(
    SupabaseClient sb,
    String userId, {
    required String fallbackName,
  }) async {
    try {
      final row = await sb
          .from('user_profiles')
          .select('full_name,company_name')
          .eq('user_id', userId)
          .maybeSingle();
      final map = row == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(row);
      for (final key in ['full_name', 'company_name']) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}
    final email = sb.auth.currentUser?.email?.trim() ?? '';
    if (email.isNotEmpty) return email;
    return fallbackName;
  }

  List<Map<String, String>> _assignmentLogRows(List<_AdminWorkspaceRow> rows) {
    return <Map<String, String>>[
      for (final row in rows)
        <String, String>{
          'id': row.targetId,
          'table': row.targetTable,
          'type': row.kind,
          'title': row.title,
          'priority': row.priority,
          'due_at': row.dueAt?.toUtc().toIso8601String() ?? '',
        },
    ];
  }

  Future<void> _exportRows(List<_AdminWorkspaceRow> rows) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    await _runBulkAction(
      successMessage: ru
          ? 'CSV скопирован: ${rows.length} строк'
          : 'CSV copied: ${rows.length} rows',
      action: () async {
        final csv = _rowsToCsv(rows);
        await Clipboard.setData(ClipboardData(text: csv));
        final sb = ref.read(supabaseProvider);
        await AdminActionLogService(sb).log(
          actionType: 'bulk_rows_exported',
          title: ru ? 'Строки экспортированы' : 'Rows exported',
          description: rows.map((e) => e.title).join(' • '),
          targetTable: 'admin_workspace',
          targetText: '${rows.length}',
          status: 'exported',
          metadata: <String, dynamic>{
            'row_ids': rows.map((e) => e.id).toList(growable: false),
          },
        );
      },
    );
  }

  Future<void> _runBulkAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_bulkBusy) return;
    setState(() => _bulkBusy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_adminBulkErrorText(e))));
    } catch (_) {
      if (!mounted) return;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ru ? 'Не удалось выполнить действие' : 'Action failed',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _publishProfile(
    SupabaseClient sb,
    MyProfileState profile,
  ) async {
    final photoUrls = _mergeUniqueMedia(
      profile.photoUrls,
      profile.pendingPhotoUrls,
    );
    final videoUrls = _mergeUniqueMedia(
      profile.videoUrls,
      profile.pendingVideoUrls,
    );
    final preferredCover = profile.pendingCoverPhotoUrl.trim().isNotEmpty
        ? profile.pendingCoverPhotoUrl
        : profile.coverPhotoUrl;
    final preferredCoverFocalX = profile.pendingCoverPhotoUrl.trim().isNotEmpty
        ? profile.pendingCoverPhotoFocalX
        : profile.coverPhotoFocalX;
    final preferredCoverFocalY = profile.pendingCoverPhotoUrl.trim().isNotEmpty
        ? profile.pendingCoverPhotoFocalY
        : profile.coverPhotoFocalY;
    final preferredShowreel = profile.pendingShowreelUrl.trim().isNotEmpty
        ? profile.pendingShowreelUrl
        : profile.showreelUrl;

    try {
      await sb
          .from('profiles')
          .update(<String, dynamic>{
            'status': 'approved',
            'moderation_comment': null,
            'photo_urls': photoUrls,
            'photo_category_labels': <String>[
              ..._alignedLabels(
                profile.photoCategoryLabels,
                profile.photoUrls.length,
                fallback: 'Портфолио',
              ),
              ..._alignedLabels(
                profile.pendingPhotoCategoryLabels,
                profile.pendingPhotoUrls.length,
                fallback: 'Портфолио',
              ),
            ],
            'cover_photo_url': _coverPhotoFrom(preferredCover, photoUrls),
            'cover_photo_focal_x': preferredCoverFocalX.clamp(-1.0, 1.0),
            'cover_photo_focal_y': preferredCoverFocalY.clamp(-1.0, 1.0),
            'video_urls': videoUrls,
            'video_preview_urls': _mergeUniqueMedia(
              profile.videoPreviewUrls,
              profile.pendingVideoPreviewUrls,
            ),
            'video_category_labels': <String>[
              ..._alignedLabels(
                profile.videoCategoryLabels,
                profile.videoUrls.length,
                fallback: 'Видео',
              ),
              ..._alignedLabels(
                profile.pendingVideoCategoryLabels,
                profile.pendingVideoUrls.length,
                fallback: 'Видео',
              ),
            ],
            'showreel_url': videoUrls.contains(preferredShowreel.trim())
                ? preferredShowreel.trim()
                : '',
            'showreel_preview_url': videoUrls.contains(preferredShowreel.trim())
                ? (profile.pendingShowreelPreviewUrl.trim().isNotEmpty
                      ? profile.pendingShowreelPreviewUrl.trim()
                      : profile.showreelPreviewUrl.trim())
                : '',
            'pending_photo_urls': const <String>[],
            'pending_cover_photo_url': '',
            'pending_cover_photo_focal_x': 0,
            'pending_cover_photo_focal_y': -0.72,
            'pending_video_urls': const <String>[],
            'pending_video_preview_urls': const <String>[],
            'pending_photo_category_labels': const <String>[],
            'pending_video_category_labels': const <String>[],
            'pending_showreel_url': '',
            'pending_showreel_preview_url': '',
            'has_pending_media': false,
          })
          .eq('id', profile.id);
    } on PostgrestException catch (directError) {
      if (directError.code == '22P02') rethrow;
      await sb.rpc(
        'admin_publish_profile',
        params: {'p_profile_id': profile.id},
      );
    }
  }

  String _rowsToCsv(List<_AdminWorkspaceRow> rows) {
    final buffer = StringBuffer(
      'type,title,details,sla,assignee,status,date,id\n',
    );
    for (final row in rows) {
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      buffer.writeln(
        [
          row.kind,
          row.title,
          row.subtitle,
          row.slaLabel(ru),
          row.assignmentLabel,
          row.status,
          row.dateText,
          row.targetId,
        ].map(_csvCell).join(','),
      );
    }
    return buffer.toString();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _adminBulkErrorText(PostgrestException error) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    if (SupabaseCompat.isMissingRelation(error, const [
          'admin_task_assignments',
        ]) ||
        SupabaseCompat.isMissingAnyColumn(error, const [
          'priority',
          'due_at',
        ])) {
      return ru
          ? 'Примените SQL supabase/sql/admin_task_assignments.sql'
          : 'Apply supabase/sql/admin_task_assignments.sql';
    }
    final message = error.message.trim();
    if (message.isNotEmpty) return ru ? 'Ошибка Supabase: $message' : message;
    return ru ? 'Не удалось выполнить действие' : 'Action failed';
  }

  String _errorText(Object error) {
    if (error is PostgrestException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
      if ((error.code ?? '').trim().isNotEmpty) return error.code!;
    }
    final message = error.toString().trim();
    return message.isEmpty ? 'Unknown error' : message;
  }

  List<String> _mergeUniqueMedia(List<String> published, List<String> pending) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in [...published, ...pending]) {
      final url = raw.trim();
      if (url.isEmpty || !seen.add(url)) continue;
      result.add(url);
    }
    return result;
  }

  List<String> _alignedLabels(
    List<String> labels,
    int length, {
    required String fallback,
  }) {
    return [
      for (var i = 0; i < length; i++)
        if (i < labels.length && labels[i].trim().isNotEmpty)
          labels[i].trim()
        else
          fallback,
    ];
  }

  String _coverPhotoFrom(String preferred, List<String> photoUrls) {
    final cover = preferred.trim();
    final photos = photoUrls.map((e) => e.trim()).where((e) => e.isNotEmpty);
    if (cover.isNotEmpty && photos.contains(cover)) return cover;
    return photos.isEmpty ? '' : photos.first;
  }
}

class _AdminWorkspaceFilters extends StatelessWidget {
  const _AdminWorkspaceFilters({
    required this.selected,
    required this.mineOnly,
    required this.onChanged,
    required this.onMineOnlyChanged,
  });

  final _AdminWorkspaceFilter selected;
  final bool mineOnly;
  final ValueChanged<_AdminWorkspaceFilter> onChanged;
  final ValueChanged<bool> onMineOnlyChanged;

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
      (
        value: _AdminWorkspaceFilter.safety,
        label: ru ? 'БЕЗОПАСНОСТЬ' : 'SAFETY',
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          selected: mineOnly,
          label: Text(ru ? 'МОИ' : 'MINE'),
          onSelected: onMineOnlyChanged,
          selectedColor: BrandTheme.redTop,
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          labelStyle: adminCommandStyle(
            size: 11,
            letterSpacing: 0.9,
            color: mineOnly ? Colors.white : kTextDark,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: mineOnly ? BrandTheme.redTop : kBorderColor,
            ),
          ),
        ),
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
    required this.profileCount,
    required this.safetyCount,
    required this.busy,
    required this.onClear,
    required this.onOpen,
    required this.onApproveProfiles,
    required this.onRejectProfiles,
    required this.onCloseSafety,
    required this.onExport,
    required this.onAssignToMe,
    required this.onUnassign,
    required this.onSetNormal,
    required this.onSetUrgent,
    required this.onSetCritical,
    required this.onDue24h,
    required this.onDue48h,
    required this.onDue7d,
    required this.onClearDue,
  });

  final int count;
  final int profileCount;
  final int safetyCount;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback onOpen;
  final VoidCallback? onApproveProfiles;
  final VoidCallback? onRejectProfiles;
  final VoidCallback? onCloseSafety;
  final VoidCallback? onExport;
  final VoidCallback? onAssignToMe;
  final VoidCallback? onUnassign;
  final VoidCallback? onSetNormal;
  final VoidCallback? onSetUrgent;
  final VoidCallback? onSetCritical;
  final VoidCallback? onDue24h;
  final VoidCallback? onDue48h;
  final VoidCallback? onDue7d;
  final VoidCallback? onClearDue;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: catalogSearchDecoration(
        radius: 18,
        borderColor: BrandTheme.redTop.withValues(alpha: 0.42),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          final title = Text(
            busy
                ? (ru ? 'Выполняю действие...' : 'Running action...')
                : (ru ? 'Выбрано: $count' : 'Selected: $count'),
            style: adminCommandStyle(size: 12, letterSpacing: 0.8),
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _AdminBulkButton(
                label: ru ? 'ОДОБРИТЬ $profileCount' : 'APPROVE $profileCount',
                icon: Icons.check_rounded,
                onTap: onApproveProfiles,
                dark: true,
              ),
              _AdminBulkButton(
                label: ru ? 'ОТКЛОНИТЬ $profileCount' : 'REJECT $profileCount',
                icon: Icons.close_rounded,
                onTap: onRejectProfiles,
              ),
              _AdminBulkButton(
                label: ru ? 'ЗАКРЫТЬ $safetyCount' : 'CLOSE $safetyCount',
                icon: Icons.shield_rounded,
                onTap: onCloseSafety,
              ),
              _AdminBulkButton(
                label: ru ? 'ВЗЯТЬ' : 'ASSIGN ME',
                icon: Icons.person_add_alt_1_rounded,
                onTap: onAssignToMe,
                dark: true,
              ),
              _AdminBulkButton(
                label: ru ? 'СНЯТЬ ОТВ.' : 'UNASSIGN',
                icon: Icons.person_remove_rounded,
                onTap: onUnassign,
              ),
              _AdminBulkButton(
                label: ru ? 'ОБЫЧНО' : 'NORMAL',
                icon: Icons.low_priority_rounded,
                onTap: onSetNormal,
              ),
              _AdminBulkButton(
                label: ru ? 'СРОЧНО' : 'URGENT',
                icon: Icons.priority_high_rounded,
                onTap: onSetUrgent,
              ),
              _AdminBulkButton(
                label: ru ? 'КРИТИЧНО' : 'CRITICAL',
                icon: Icons.local_fire_department_rounded,
                onTap: onSetCritical,
                dark: true,
              ),
              _AdminBulkButton(
                label: '24Ч',
                icon: Icons.timer_rounded,
                onTap: onDue24h,
              ),
              _AdminBulkButton(
                label: '48Ч',
                icon: Icons.av_timer_rounded,
                onTap: onDue48h,
              ),
              _AdminBulkButton(
                label: '7Д',
                icon: Icons.event_available_rounded,
                onTap: onDue7d,
              ),
              _AdminBulkButton(
                label: ru ? 'БЕЗ СРОКА' : 'NO DUE',
                icon: Icons.event_busy_rounded,
                onTap: onClearDue,
              ),
              _AdminBulkButton(
                label: ru ? 'CSV' : 'CSV',
                icon: Icons.file_download_rounded,
                onTap: onExport,
              ),
              _AdminBulkButton(
                label: ru ? 'ОТКРЫТЬ' : 'OPEN',
                icon: Icons.open_in_new_rounded,
                onTap: busy ? null : onOpen,
              ),
              _AdminBulkButton(
                label: ru ? 'СБРОС' : 'CLEAR',
                icon: Icons.clear_rounded,
                onTap: busy ? null : onClear,
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 10), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              Flexible(flex: 2, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _AdminBulkButton extends StatelessWidget {
  const _AdminBulkButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: dark
            ? kTextDark
            : Colors.white.withValues(alpha: 0.86),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.34),
        foregroundColor: dark ? Colors.white : kTextDark,
        disabledForegroundColor: kTextMuted.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: dark ? kTextDark : kBorderColor),
        ),
        textStyle: adminCommandStyle(size: 10.5, letterSpacing: 0.8),
      ),
    );
  }
}

class _AdminBulkResultPanel extends StatelessWidget {
  const _AdminBulkResultPanel({
    required this.result,
    required this.busy,
    required this.onRetryFailed,
    required this.onClear,
  });

  final _AdminBulkResult result;
  final bool busy;
  final VoidCallback? onRetryFailed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final failedRows = result.failedRows.toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: catalogSearchDecoration(
        radius: 18,
        borderColor: result.failedCount == 0
            ? Colors.green.withValues(alpha: 0.35)
            : BrandTheme.redTop.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title.toUpperCase(),
                    style: adminCommandStyle(size: 12, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ru
                        ? 'Успешно: ${result.successCount} • Ошибок: ${result.failedCount}'
                        : 'Succeeded: ${result.successCount} • Failed: ${result.failedCount}',
                    style: adminBodyStyle(
                      size: 12,
                      color: kTextMuted,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: compact ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  _AdminBulkButton(
                    label: ru ? 'ПОВТОРИТЬ ОШИБКИ' : 'RETRY FAILED',
                    icon: Icons.refresh_rounded,
                    onTap: onRetryFailed,
                    dark: true,
                  ),
                  _AdminBulkButton(
                    label: ru ? 'СКРЫТЬ' : 'HIDE',
                    icon: Icons.close_rounded,
                    onTap: busy ? null : onClear,
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const SizedBox(height: 10), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
          if (failedRows.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final row in failedRows.take(6)) ...[
              _AdminBulkFailedRow(row: row),
              const SizedBox(height: 6),
            ],
            if (failedRows.length > 6)
              Text(
                ru
                    ? 'Еще ошибок: ${failedRows.length - 6}'
                    : '${failedRows.length - 6} more failures',
                style: adminBodyStyle(size: 12, color: kTextMuted),
              ),
          ],
        ],
      ),
    );
  }
}

class _AdminBulkFailedRow extends StatelessWidget {
  const _AdminBulkFailedRow({required this.row});

  final _AdminBulkRowResult row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BrandTheme.redTop.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandTheme.redTop.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: BrandTheme.redTop,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminBodyStyle(
                    size: 12,
                    color: kTextDark,
                    weight: FontWeight.w900,
                  ),
                ),
                if (row.message.isNotEmpty)
                  Text(
                    row.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: adminBodyStyle(size: 11, color: kTextMuted),
                  ),
              ],
            ),
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
          2: FlexColumnWidth(1.25),
          3: FlexColumnWidth(1.05),
          4: FixedColumnWidth(142),
          5: FixedColumnWidth(128),
          6: FixedColumnWidth(112),
          7: FixedColumnWidth(86),
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
            cells: const [
              '',
              'ТИП',
              'НАЗВАНИЕ',
              'ДЕТАЛИ',
              'SLA',
              'ОТВЕТСТВ.',
              'СТАТУС',
              'ДАТА',
            ],
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
                _TableCellBox(
                  text: row.slaLabel(
                    Localizations.localeOf(context).languageCode == 'ru',
                  ),
                  accent: row.isOverdue || row.priorityRank > 1,
                  strong: row.isOverdue || row.priority == 'critical',
                ),
                _TableCellBox(
                  text: row.assignmentLabel.isEmpty ? '—' : row.assignmentLabel,
                  accent: row.assignedToUserId.isNotEmpty,
                ),
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
                const SizedBox(height: 4),
                Text(
                  row.slaLabel(
                    Localizations.localeOf(context).languageCode == 'ru',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminBodyStyle(
                    size: 11,
                    color: row.isOverdue || row.priorityRank > 1
                        ? BrandTheme.redTop
                        : kTextMuted,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.assignmentLabel.isEmpty
                      ? (Localizations.localeOf(context).languageCode == 'ru'
                            ? 'Без ответственного'
                            : 'Unassigned')
                      : (Localizations.localeOf(context).languageCode == 'ru'
                            ? 'Ответственный: ${row.assignmentLabel}'
                            : 'Assignee: ${row.assignmentLabel}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminBodyStyle(
                    size: 11,
                    color: row.assignmentLabel.isEmpty
                        ? kTextMuted
                        : BrandTheme.redTop,
                    weight: FontWeight.w800,
                  ),
                ),
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
      (label: ru ? 'ОБЪЕДИНЕНИЯ' : 'MERGES', value: counts.accountMerges),
      (label: ru ? 'БЕЗОПАСНОСТЬ' : 'SAFETY', value: counts.safety),
      (label: ru ? 'ПРОСРОЧЕНО' : 'OVERDUE', value: counts.overdueTasks),
      (label: ru ? 'КРИТИЧНО' : 'CRITICAL', value: counts.criticalTasks),
      (label: ru ? 'МОИ ПРОСРОЧ.' : 'MY OVERDUE', value: counts.myOverdueTasks),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1280
            ? 4
            : constraints.maxWidth >= 760
            ? 3
            : 2;
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
