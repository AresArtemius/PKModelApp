import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/admin_action_log_service.dart';
import '../../core/profile_action_log_service.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';

final _profileActionAuditProvider = FutureProvider.autoDispose<AuditLogData>((
  ref,
) async {
  final sb = Supabase.instance.client;
  final profileLogs = await ProfileActionLogService(
    sb,
  ).fetchAdminLogs(limit: 300);
  final adminLogs = await AdminActionLogService(sb).fetch(limit: 300);
  return AuditLogData(
    profileLogs: profileLogs,
    adminLogs: adminLogs,
    profileLogAvailable: profileLogs != null,
    adminLogAvailable: adminLogs != null,
  );
});

enum AuditLogScope { all, profile, admin }

class AuditLogData {
  const AuditLogData({
    required this.profileLogs,
    required this.adminLogs,
    required this.profileLogAvailable,
    required this.adminLogAvailable,
  });

  final List<ProfileActionLogEntry>? profileLogs;
  final List<AdminActionLogEntry>? adminLogs;
  final bool profileLogAvailable;
  final bool adminLogAvailable;

  List<AuditLogItem> get items {
    final result = <AuditLogItem>[
      for (final item in profileLogs ?? const <ProfileActionLogEntry>[])
        AuditLogItem.profile(item),
      for (final item in adminLogs ?? const <AdminActionLogEntry>[])
        AuditLogItem.admin(item),
    ];
    result.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return result;
  }
}

class AuditLogItem {
  const AuditLogItem._({
    required this.id,
    required this.scope,
    required this.actionType,
    required this.title,
    required this.description,
    required this.actorLabel,
    required this.actorUserId,
    required this.status,
    required this.relatedTable,
    required this.relatedId,
    required this.relatedText,
    required this.templateKey,
    required this.templateBody,
    required this.profileId,
    required this.createdAt,
    required this.deliveredAt,
    required this.readAt,
  });

  factory AuditLogItem.profile(ProfileActionLogEntry item) {
    return AuditLogItem._(
      id: 'profile:${item.id}',
      scope: AuditLogScope.profile,
      actionType: item.actionType,
      title: item.title,
      description: item.description,
      actorLabel: item.actorLabel,
      actorUserId: item.actorUserId,
      status: item.status,
      relatedTable: item.relatedTable,
      relatedId: item.relatedId,
      relatedText: item.relatedText,
      templateKey: item.templateKey,
      templateBody: item.templateBody,
      profileId: item.profileId,
      createdAt: item.createdAt,
      deliveredAt: item.deliveredAt,
      readAt: item.readAt,
    );
  }

  factory AuditLogItem.admin(AdminActionLogEntry item) {
    return AuditLogItem._(
      id: 'admin:${item.id}',
      scope: AuditLogScope.admin,
      actionType: item.actionType,
      title: item.title,
      description: item.description,
      actorLabel: item.actorLabel,
      actorUserId: item.actorUserId,
      status: item.status,
      relatedTable: item.targetTable,
      relatedId: item.targetId,
      relatedText: item.targetText,
      templateKey: '',
      templateBody: '',
      profileId: '',
      createdAt: item.createdAt,
      deliveredAt: null,
      readAt: null,
    );
  }

  final String id;
  final AuditLogScope scope;
  final String actionType;
  final String title;
  final String description;
  final String actorLabel;
  final String actorUserId;
  final String status;
  final String relatedTable;
  final String relatedId;
  final String relatedText;
  final String templateKey;
  final String templateBody;
  final String profileId;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  bool get isAdminAction => scope == AuditLogScope.admin;
}

class ProfileActionAuditPage extends ConsumerStatefulWidget {
  const ProfileActionAuditPage({super.key});

  @override
  ConsumerState<ProfileActionAuditPage> createState() =>
      _ProfileActionAuditPageState();
}

class _ProfileActionAuditPageState
    extends ConsumerState<ProfileActionAuditPage> {
  ProfileActionLogType _filter = ProfileActionLogType.all;
  AuditLogScope _scope = AuditLogScope.all;
  String _selectedId = '';
  String _query = '';
  String _actorQuery = '';
  String _profileQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isClearingAudit = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRu = t.localeName.toLowerCase().startsWith('ru');
    final isAdminAsync = ref.watch(isAdminProvider);
    final logsAsync = ref.watch(_profileActionAuditProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;

    return Scaffold(
      backgroundColor: BrandTheme.greyMid,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              BrandAdminHeader(
                title: isRu ? 'ЖУРНАЛ ДЕЙСТВИЙ' : 'ACTION AUDIT LOG',
                onBack: () => context.go(Routes.admin),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: isAdminAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => AdminMessageCard(
                    text: e.toString(),
                    isError: true,
                    maxWidth: 720,
                  ),
                  data: (isAdmin) {
                    if (!isAdmin) {
                      return AdminMessageCard(
                        text: isRu ? 'ТОЛЬКО ДЛЯ АДМИНА' : 'ADMIN ONLY',
                        isError: true,
                        maxWidth: 720,
                      );
                    }
                    return logsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => AdminMessageCard(
                        text: e.toString(),
                        isError: true,
                        maxWidth: 720,
                      ),
                      data: (data) {
                        if (!data.profileLogAvailable &&
                            !data.adminLogAvailable) {
                          return AdminMessageCard(
                            text: isRu
                                ? 'Примените SQL profile_action_logs.sql и admin_action_logs.sql, чтобы открыть журнал действий.'
                                : 'Apply profile_action_logs.sql and admin_action_logs.sql to enable the audit log.',
                            maxWidth: 760,
                          );
                        }
                        final logs = _filtered(data.items);
                        final selected = _selected(logs);
                        if (logs.isEmpty) {
                          return _AuditPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AuditToolbar(
                                  scope: _scope,
                                  value: _filter,
                                  isRu: isRu,
                                  query: _query,
                                  actorQuery: _actorQuery,
                                  profileQuery: _profileQuery,
                                  dateFrom: _dateFrom,
                                  dateTo: _dateTo,
                                  onScopeChanged: _setScope,
                                  onTypeChanged: _setFilter,
                                  onQueryChanged: (value) =>
                                      setState(() => _query = value),
                                  onActorChanged: (value) =>
                                      setState(() => _actorQuery = value),
                                  onProfileChanged: (value) =>
                                      setState(() => _profileQuery = value),
                                  onPickDateFrom: () => _pickDate(isFrom: true),
                                  onPickDateTo: () => _pickDate(isFrom: false),
                                  onClear: _clearFilters,
                                  onClearLogs: _isClearingAudit
                                      ? null
                                      : () => _clearAuditLogs(isRu),
                                  onExport: logs.isEmpty
                                      ? null
                                      : () => _copyCsv(logs, isRu),
                                ),
                                const Spacer(),
                                AdminMessageCard(
                                  text: isRu ? 'ДЕЙСТВИЙ НЕТ' : 'NO ACTIONS',
                                  maxWidth: 520,
                                ),
                                const Spacer(),
                              ],
                            ),
                          );
                        }
                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _AuditPanel(
                                  child: Column(
                                    children: [
                                      _AuditToolbar(
                                        scope: _scope,
                                        value: _filter,
                                        isRu: isRu,
                                        query: _query,
                                        actorQuery: _actorQuery,
                                        profileQuery: _profileQuery,
                                        dateFrom: _dateFrom,
                                        dateTo: _dateTo,
                                        onScopeChanged: _setScope,
                                        onTypeChanged: _setFilter,
                                        onQueryChanged: (value) =>
                                            setState(() => _query = value),
                                        onActorChanged: (value) =>
                                            setState(() => _actorQuery = value),
                                        onProfileChanged: (value) => setState(
                                          () => _profileQuery = value,
                                        ),
                                        onPickDateFrom: () =>
                                            _pickDate(isFrom: true),
                                        onPickDateTo: () =>
                                            _pickDate(isFrom: false),
                                        onClear: _clearFilters,
                                        onClearLogs: _isClearingAudit
                                            ? null
                                            : () => _clearAuditLogs(isRu),
                                        onExport: () => _copyCsv(logs, isRu),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: _AuditList(
                                          logs: logs,
                                          selectedId: selected?.id ?? '',
                                          isRu: isRu,
                                          onSelect: (entry) => setState(
                                            () => _selectedId = entry.id,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 6,
                                child: _AuditPanel(
                                  child: SingleChildScrollView(
                                    child: _AuditDetails(
                                      entry: selected,
                                      isRu: isRu,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return _AuditPanel(
                          child: Column(
                            children: [
                              _AuditToolbar(
                                scope: _scope,
                                value: _filter,
                                isRu: isRu,
                                query: _query,
                                actorQuery: _actorQuery,
                                profileQuery: _profileQuery,
                                dateFrom: _dateFrom,
                                dateTo: _dateTo,
                                onScopeChanged: _setScope,
                                onTypeChanged: _setFilter,
                                onQueryChanged: (value) =>
                                    setState(() => _query = value),
                                onActorChanged: (value) =>
                                    setState(() => _actorQuery = value),
                                onProfileChanged: (value) =>
                                    setState(() => _profileQuery = value),
                                onPickDateFrom: () => _pickDate(isFrom: true),
                                onPickDateTo: () => _pickDate(isFrom: false),
                                onClear: _clearFilters,
                                onClearLogs: _isClearingAudit
                                    ? null
                                    : () => _clearAuditLogs(isRu),
                                onExport: () => _copyCsv(logs, isRu),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _AuditList(
                                  logs: logs,
                                  selectedId: selected?.id ?? '',
                                  isRu: isRu,
                                  onSelect: (entry) =>
                                      _showDetails(entry, isRu),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  List<AuditLogItem> _filtered(List<AuditLogItem> source) {
    final query = _query.trim().toLowerCase();
    final actor = _actorQuery.trim().toLowerCase();
    final profile = _profileQuery.trim().toLowerCase();
    return source
        .where((item) {
          if (_scope != AuditLogScope.all && item.scope != _scope) return false;
          if (_filter != ProfileActionLogType.all &&
              item.scope == AuditLogScope.profile) {
            if (item.actionType != _filter.name) return false;
          }
          if (_filter != ProfileActionLogType.all &&
              item.scope == AuditLogScope.admin) {
            return false;
          }
          final created = item.createdAt;
          if (_dateFrom != null &&
              created != null &&
              created.isBefore(_dateFrom!)) {
            return false;
          }
          if (_dateTo != null && created != null) {
            final end = DateTime(
              _dateTo!.year,
              _dateTo!.month,
              _dateTo!.day + 1,
            );
            if (!created.isBefore(end)) return false;
          }
          if (actor.isNotEmpty &&
              !('${item.actorLabel} ${item.actorUserId}'.toLowerCase())
                  .contains(actor)) {
            return false;
          }
          if (profile.isNotEmpty &&
              !('${item.profileId} ${item.relatedId} ${item.relatedText}'
                      .toLowerCase())
                  .contains(profile)) {
            return false;
          }
          if (query.isEmpty) return true;
          final haystack =
              '${item.title} ${item.description} ${item.actionType} ${item.status} '
                      '${item.relatedTable} ${item.relatedText} ${item.templateBody}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  AuditLogItem? _selected(List<AuditLogItem> logs) {
    if (logs.isEmpty) return null;
    for (final log in logs) {
      if (log.id == _selectedId) return log;
    }
    return logs.first;
  }

  void _setFilter(ProfileActionLogType type) {
    setState(() {
      _filter = type;
      _selectedId = '';
    });
  }

  void _setScope(AuditLogScope scope) {
    setState(() {
      _scope = scope;
      _selectedId = '';
      if (scope == AuditLogScope.admin) _filter = ProfileActionLogType.all;
    });
  }

  void _clearFilters() {
    setState(() {
      _scope = AuditLogScope.all;
      _filter = ProfileActionLogType.all;
      _query = '';
      _actorQuery = '';
      _profileQuery = '';
      _dateFrom = null;
      _dateTo = null;
      _selectedId = '';
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = DateTime(picked.year, picked.month, picked.day);
      } else {
        _dateTo = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _copyCsv(List<AuditLogItem> logs, bool isRu) async {
    final rows = <List<String>>[
      [
        'created_at',
        'scope',
        'action_type',
        'status',
        'actor',
        'profile_id',
        'related_table',
        'related_id',
        'related_text',
        'title',
        'description',
      ],
      for (final item in logs)
        [
          item.createdAt?.toIso8601String() ?? '',
          item.scope.name,
          item.actionType,
          item.status,
          item.actorLabel,
          item.profileId,
          item.relatedTable,
          item.relatedId,
          item.relatedText,
          item.title,
          item.description,
        ],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'CSV скопирован в буфер обмена' : 'CSV copied to clipboard',
          ),
        ),
      );
  }

  Future<void> _clearAuditLogs(bool isRu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRu ? 'Очистить журнал?' : 'Clear audit log?'),
        content: Text(
          isRu
              ? 'Будут удалены все записи журнала действий: профильные события и действия админки. Это действие нельзя отменить.'
              : 'All action audit records will be deleted: profile events and back-office actions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isRu ? 'ОТМЕНА' : 'CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isRu ? 'ОЧИСТИТЬ' : 'CLEAR',
              style: const TextStyle(color: BrandTheme.redTop),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClearingAudit = true);
    try {
      await AdminActionLogService(Supabase.instance.client).clearAllAuditLogs();
      if (!mounted) return;
      _selectedId = '';
      ref.invalidate(_profileActionAuditProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isRu ? 'Журнал действий очищен' : 'Action audit log cleared',
            ),
          ),
        );
    } on AdminActionLogSetupRequiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isRu
                  ? 'Примените SQL clear_action_audit_logs.sql в Supabase.'
                  : 'Apply clear_action_audit_logs.sql in Supabase.',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isRu
                  ? 'Не удалось очистить журнал. Попробуйте еще раз.'
                  : 'Could not clear the audit log. Please try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isClearingAudit = false);
    }
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  void _showDetails(AuditLogItem entry, bool isRu) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AuditPanel(
            child: SingleChildScrollView(
              child: _AuditDetails(entry: entry, isRu: isRu),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditPanel extends StatelessWidget {
  const _AuditPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration(),
      child: child,
    );
  }
}

class _AuditToolbar extends StatelessWidget {
  const _AuditToolbar({
    required this.scope,
    required this.value,
    required this.isRu,
    required this.query,
    required this.actorQuery,
    required this.profileQuery,
    required this.dateFrom,
    required this.dateTo,
    required this.onScopeChanged,
    required this.onTypeChanged,
    required this.onQueryChanged,
    required this.onActorChanged,
    required this.onProfileChanged,
    required this.onPickDateFrom,
    required this.onPickDateTo,
    required this.onClear,
    required this.onClearLogs,
    required this.onExport,
  });

  final AuditLogScope scope;
  final ProfileActionLogType value;
  final bool isRu;
  final String query;
  final String actorQuery;
  final String profileQuery;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<AuditLogScope> onScopeChanged;
  final ValueChanged<ProfileActionLogType> onTypeChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onActorChanged;
  final ValueChanged<String> onProfileChanged;
  final VoidCallback onPickDateFrom;
  final VoidCallback onPickDateTo;
  final VoidCallback onClear;
  final VoidCallback? onClearLogs;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final filters = ProfileActionLogType.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _AuditTextField(
                initialValue: query,
                hint: isRu ? 'Поиск по журналу' : 'Search audit log',
                icon: Icons.search_rounded,
                onChanged: onQueryChanged,
              ),
            ),
            const SizedBox(width: 8),
            _AuditIconButton(
              icon: Icons.content_copy_rounded,
              tooltip: isRu ? 'Скопировать CSV' : 'Copy CSV',
              onTap: onExport,
            ),
            const SizedBox(width: 8),
            _AuditIconButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: isRu ? 'Очистить журнал' : 'Clear audit log',
              onTap: onClearLogs,
              isDanger: true,
            ),
            const SizedBox(width: 8),
            _AuditIconButton(
              icon: Icons.close_rounded,
              tooltip: isRu ? 'Сбросить фильтры' : 'Clear filters',
              onTap: onClear,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final currentScope in AuditLogScope.values) ...[
                _AuditFilterChip(
                  label: _scopeLabel(currentScope),
                  selected: scope == currentScope,
                  onTap: () => onScopeChanged(currentScope),
                ),
                const SizedBox(width: 8),
              ],
              if (scope != AuditLogScope.admin)
                for (final type in filters) ...[
                  _AuditFilterChip(
                    label: _label(type),
                    selected: value == type,
                    onTap: () => onTypeChanged(type),
                  ),
                  if (type != filters.last) const SizedBox(width: 8),
                ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 560;
            final fields = [
              _AuditTextField(
                initialValue: actorQuery,
                hint: isRu ? 'Автор' : 'Actor',
                icon: Icons.person_search_rounded,
                onChanged: onActorChanged,
              ),
              _AuditTextField(
                initialValue: profileQuery,
                hint: isRu ? 'Анкета / связь' : 'Profile / related',
                icon: Icons.badge_rounded,
                onChanged: onProfileChanged,
              ),
            ];
            if (isNarrow) {
              return Column(
                children: [
                  for (final field in fields) ...[
                    field,
                    const SizedBox(height: 8),
                  ],
                  _DateFilters(
                    isRu: isRu,
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                    onPickDateFrom: onPickDateFrom,
                    onPickDateTo: onPickDateTo,
                  ),
                ],
              );
            }
            return Row(
              children: [
                for (final field in fields) ...[
                  Expanded(child: field),
                  const SizedBox(width: 8),
                ],
                _DateFilters(
                  isRu: isRu,
                  dateFrom: dateFrom,
                  dateTo: dateTo,
                  onPickDateFrom: onPickDateFrom,
                  onPickDateTo: onPickDateTo,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _scopeLabel(AuditLogScope scope) {
    return switch (scope) {
      AuditLogScope.all => isRu ? 'Все' : 'All',
      AuditLogScope.profile => isRu ? 'Профили' : 'Profiles',
      AuditLogScope.admin => isRu ? 'Админка' : 'Back office',
    };
  }

  String _label(ProfileActionLogType type) {
    return switch (type) {
      ProfileActionLogType.all => isRu ? 'Все' : 'All',
      ProfileActionLogType.invite => isRu ? 'Приглашения' : 'Invites',
      ProfileActionLogType.selection => isRu ? 'Подборки' : 'Selections',
      ProfileActionLogType.folder => isRu ? 'Папки' : 'Folders',
      ProfileActionLogType.message => isRu ? 'Чат' : 'Chat',
    };
  }
}

class _AuditTextField extends StatefulWidget {
  const _AuditTextField({
    required this.initialValue,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  final String initialValue;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  State<_AuditTextField> createState() => _AuditTextFieldState();
}

class _AuditTextFieldState extends State<_AuditTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _AuditTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: adminBodyStyle(size: 13, color: kTextDark),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(widget.icon, size: 18, color: kTextMuted),
        hintText: widget.hint,
        hintStyle: adminBodyStyle(size: 13, color: kTextMuted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.84),
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
    );
  }
}

class _DateFilters extends StatelessWidget {
  const _DateFilters({
    required this.isRu,
    required this.dateFrom,
    required this.dateTo,
    required this.onPickDateFrom,
    required this.onPickDateTo,
  });

  final bool isRu;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final VoidCallback onPickDateFrom;
  final VoidCallback onPickDateTo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DateButton(
          label: isRu ? 'С' : 'From',
          value: _date(dateFrom),
          onTap: onPickDateFrom,
        ),
        const SizedBox(width: 8),
        _DateButton(
          label: isRu ? 'ПО' : 'To',
          value: _date(dateTo),
          onTap: onPickDateTo,
        ),
      ],
    );
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}';
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AuditFilterChip(
      label: value.isEmpty ? label : '$label $value',
      selected: value.isNotEmpty,
      onTap: onTap,
    );
  }
}

class _AuditIconButton extends StatelessWidget {
  const _AuditIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: onTap == null
                ? Colors.white.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kBorderColor),
          ),
          child: Icon(
            icon,
            color: onTap == null
                ? kTextMuted
                : isDanger
                ? BrandTheme.redTop
                : kTextDark,
          ),
        ),
      ),
    );
  }
}

class _AuditFilterChip extends StatelessWidget {
  const _AuditFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kTextDark : Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? kTextDark : kBorderColor),
        ),
        child: Text(
          label,
          style: adminBodyStyle(
            size: 12,
            color: selected ? Colors.white : kTextDark,
            weight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({
    required this.logs,
    required this.selectedId,
    required this.isRu,
    required this.onSelect,
  });

  final List<AuditLogItem> logs;
  final String selectedId;
  final bool isRu;
  final ValueChanged<AuditLogItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = logs[index];
        final selected = log.id == selectedId;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelect(log),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? BrandTheme.redTop.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? BrandTheme.redTop : kBorderColor,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  log.isAdminAction
                      ? Icons.admin_panel_settings_rounded
                      : _icon(log.actionType),
                  color: log.isAdminAction ? kTextDark : BrandTheme.redTop,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.title.isEmpty ? _kind(log.actionType) : log.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: adminBodyStyle(
                          size: 14,
                          weight: FontWeight.w900,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          log.isAdminAction
                              ? (isRu ? 'Админка' : 'Back office')
                              : '',
                          log.actorLabel,
                          _status(log.status),
                        ].where((e) => e.trim().isNotEmpty).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: adminBodyStyle(size: 12, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _date(log.createdAt),
                  style: adminCommandStyle(
                    size: 11,
                    letterSpacing: 0.4,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _icon(String type) {
    return switch (type) {
      'invite' => Icons.send_rounded,
      'selection' => Icons.dashboard_customize_rounded,
      'folder' => Icons.folder_rounded,
      'message' => Icons.chat_bubble_rounded,
      _ => Icons.history_rounded,
    };
  }

  String _kind(String type) {
    return switch (type) {
      'invite' => isRu ? 'Приглашение' : 'Invitation',
      'selection' => isRu ? 'Подборка' : 'Selection',
      'folder' => isRu ? 'Папка' : 'Folder',
      'message' => isRu ? 'Чат' : 'Chat',
      _ => type,
    };
  }

  String _status(String status) {
    return switch (status) {
      'sent' => isRu ? 'отправлено' : 'sent',
      'delivered' => isRu ? 'доставлено' : 'delivered',
      'read' => isRu ? 'прочитано' : 'read',
      'failed' => isRu ? 'ошибка' : 'failed',
      _ => status,
    };
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }
}

class _AuditDetails extends StatelessWidget {
  const _AuditDetails({required this.entry, required this.isRu});

  final AuditLogItem? entry;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final log = entry;
    if (log == null) {
      return Center(
        child: Text(
          isRu ? 'Выберите действие' : 'Select an action',
          style: adminCommandStyle(size: 14, color: kTextMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isRu ? 'ДЕТАЛИ ДЕЙСТВИЯ' : 'ACTION DETAILS',
          style: adminCommandStyle(size: 18, letterSpacing: 2.2),
        ),
        const SizedBox(height: 14),
        _DetailLine(label: isRu ? 'Автор' : 'Actor', value: log.actorLabel),
        _DetailLine(
          label: isRu ? 'Источник' : 'Scope',
          value: log.isAdminAction
              ? (isRu ? 'Админка' : 'Back office')
              : (isRu ? 'Профиль' : 'Profile'),
        ),
        _DetailLine(label: isRu ? 'Тип' : 'Type', value: log.actionType),
        _DetailLine(label: isRu ? 'Статус' : 'Status', value: log.status),
        _DetailLine(
          label: isRu ? 'Дата' : 'Date',
          value: _fullDate(log.createdAt),
        ),
        if (log.profileId.isNotEmpty)
          _DetailLine(label: 'Profile ID', value: log.profileId),
        _DetailLine(
          label: isRu ? 'Связь' : 'Related',
          value: [
            log.relatedTable,
            log.relatedId,
            log.relatedText,
          ].where((e) => e.isNotEmpty).join(' • '),
        ),
        if (log.templateBody.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextBox(title: isRu ? 'ШАБЛОН' : 'TEMPLATE', text: log.templateBody),
        ],
        if (log.title.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextBox(
            title: isRu ? 'ТЕКСТ / НАЗВАНИЕ' : 'TEXT / TITLE',
            text: log.title,
          ),
        ],
        if (log.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextBox(
            title: isRu ? 'ОПИСАНИЕ' : 'DESCRIPTION',
            text: log.description,
          ),
        ],
        const SizedBox(height: 14),
        _AuditTimeline(entry: log, isRu: isRu),
      ],
    );
  }

  String _fullDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: adminCommandStyle(
                size: 11,
                color: kTextMuted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: adminBodyStyle(size: 13, color: kTextDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBox extends StatelessWidget {
  const _TextBox({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminCommandStyle(size: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: adminBodyStyle(size: 13, color: kTextDark),
          ),
        ],
      ),
    );
  }
}

class _AuditTimeline extends StatelessWidget {
  const _AuditTimeline({required this.entry, required this.isRu});

  final AuditLogItem entry;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        label: isRu ? 'Создано' : 'Created',
        date: entry.createdAt,
        active: entry.createdAt != null,
      ),
      (
        label: isRu ? 'Отправлено' : 'Sent',
        date: entry.createdAt,
        active: _hasReached('sent'),
      ),
      (
        label: isRu ? 'Доставлено' : 'Delivered',
        date: entry.deliveredAt,
        active: _hasReached('delivered'),
      ),
      (
        label: isRu ? 'Прочитано' : 'Read',
        date: entry.readAt,
        active: _hasReached('read'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIMELINE', style: adminCommandStyle(size: 12, letterSpacing: 1)),
        const SizedBox(height: 8),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  step.active
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: step.active ? BrandTheme.redTop : kTextMuted,
                  size: 17,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    step.label,
                    style: adminBodyStyle(
                      size: 13,
                      color: step.active ? kTextDark : kTextMuted,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(_date(step.date), style: adminBodyStyle(size: 12)),
              ],
            ),
          ),
      ],
    );
  }

  bool _hasReached(String step) {
    final order = {'created': 0, 'sent': 1, 'delivered': 2, 'read': 3};
    final current = order[entry.status] ?? 0;
    return current >= (order[step] ?? 0);
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
