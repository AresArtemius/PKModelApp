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

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _isDeleting) return;

    final t = AppLocalizations.of(context)!;
    final confirmed = await _confirmDelete(count: _selectedIds.length);
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(adminSelectionListProvider);

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
