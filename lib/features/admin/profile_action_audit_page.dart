import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/profile_action_log_service.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';

final _profileActionAuditProvider = FutureProvider.autoDispose
    .family<List<ProfileActionLogEntry>?, ProfileActionLogType>((ref, type) {
      return ProfileActionLogService(
        Supabase.instance.client,
      ).fetchAdminLogs(type: type, limit: 120);
    });

class ProfileActionAuditPage extends ConsumerStatefulWidget {
  const ProfileActionAuditPage({super.key});

  @override
  ConsumerState<ProfileActionAuditPage> createState() =>
      _ProfileActionAuditPageState();
}

class _ProfileActionAuditPageState
    extends ConsumerState<ProfileActionAuditPage> {
  ProfileActionLogType _filter = ProfileActionLogType.all;
  String _selectedId = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRu = t.localeName.toLowerCase().startsWith('ru');
    final isAdminAsync = ref.watch(isAdminProvider);
    final logsAsync = ref.watch(_profileActionAuditProvider(_filter));
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
                      data: (logs) {
                        if (logs == null) {
                          return AdminMessageCard(
                            text: isRu
                                ? 'Примените SQL profile_action_logs.sql, чтобы открыть журнал действий.'
                                : 'Apply profile_action_logs.sql to enable the audit log.',
                            maxWidth: 760,
                          );
                        }
                        final selected = _selected(logs);
                        if (logs.isEmpty) {
                          return _AuditPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FilterBar(
                                  value: _filter,
                                  isRu: isRu,
                                  onChanged: _setFilter,
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
                                      _FilterBar(
                                        value: _filter,
                                        isRu: isRu,
                                        onChanged: _setFilter,
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
                              _FilterBar(
                                value: _filter,
                                isRu: isRu,
                                onChanged: _setFilter,
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

  ProfileActionLogEntry? _selected(List<ProfileActionLogEntry> logs) {
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

  void _showDetails(ProfileActionLogEntry entry, bool isRu) {
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.isRu,
    required this.onChanged,
  });

  final ProfileActionLogType value;
  final bool isRu;
  final ValueChanged<ProfileActionLogType> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = ProfileActionLogType.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in filters) ...[
            _AuditFilterChip(
              label: _label(type),
              selected: value == type,
              onTap: () => onChanged(type),
            ),
            if (type != filters.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
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

  final List<ProfileActionLogEntry> logs;
  final String selectedId;
  final bool isRu;
  final ValueChanged<ProfileActionLogEntry> onSelect;

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
                Icon(_icon(log.actionType), color: BrandTheme.redTop, size: 22),
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

  final ProfileActionLogEntry? entry;
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
        _DetailLine(label: isRu ? 'Тип' : 'Type', value: log.actionType),
        _DetailLine(label: isRu ? 'Статус' : 'Status', value: log.status),
        _DetailLine(
          label: isRu ? 'Дата' : 'Date',
          value: _fullDate(log.createdAt),
        ),
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

  final ProfileActionLogEntry entry;
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
