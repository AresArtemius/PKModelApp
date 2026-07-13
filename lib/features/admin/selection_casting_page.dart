import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../selection/selection_export_item.dart';
import '../selection/selection_pdf_options.dart';
import '../selection/selection_pdf_options_dialog.dart';
import '../selection/selection_pdf_service.dart';
import '../selection/public_profile_access_link_service.dart';
import '../catalog/model_data.dart';
import '../castings/casting_reference_media.dart';
import '../castings/casting_response_status.dart';

const _bg = BrandTheme.greyMid;
const _text = kTextDark;

enum _PdfExportScope { all, shortlist, approved }

List<_BoardColumnSpec> _boardColumns(BuildContext context) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return [
    _BoardColumnSpec(
      title: ru ? 'ОТКЛИКИ' : 'RESPONSES',
      status: CastingResponseStatus.submitted,
      aliases: const {
        CastingResponseStatus.callback,
        CastingResponseStatus.invited,
        CastingResponseStatus.reserve,
        CastingResponseStatus.rejected,
      },
      icon: Icons.inbox_rounded,
    ),
    _BoardColumnSpec(
      title: ru ? 'ШОРТЛИСТ' : 'SHORTLIST',
      status: CastingResponseStatus.shortlist,
      aliases: const {CastingResponseStatus.viewed},
      icon: Icons.playlist_add_check_rounded,
    ),
    _BoardColumnSpec(
      title: ru ? 'УТВЕРЖДЕННЫЕ' : 'APPROVED',
      status: CastingResponseStatus.approved,
      aliases: const {},
      icon: Icons.verified_rounded,
    ),
  ];
}

final castingResponsesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, castingId) async {
      ref.watch(authStateProvider);
      final sb = ref.read(supabaseProvider);

      Future<List<dynamic>> run(String select) {
        return sb
            .from('casting_responses')
            .select(select)
            .eq('casting_id', castingId)
            .order('created_at', ascending: false)
            .limit(400);
      }

      Future<List<CastingReferenceMedia>> loadCastingReferences() async {
        try {
          final row = await sb
              .from('castings')
              .select('reference_media')
              .eq('id', castingId)
              .maybeSingle();
          final raw = row?['reference_media'];
          if (raw is! List) return const <CastingReferenceMedia>[];
          return raw
              .whereType<Map>()
              .map((e) => CastingReferenceMedia.fromJson(Map.from(e)))
              .where((e) => e.url.trim().isNotEmpty)
              .toList(growable: false);
        } on PostgrestException catch (e) {
          final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
              .toLowerCase();
          if (msg.contains('reference_media') ||
              msg.contains('schema cache') ||
              msg.contains('does not exist')) {
            return const <CastingReferenceMedia>[];
          }
          rethrow;
        }
      }

      const profileSelect = '''
        status,
        admin_note,
        created_at,
        profile:profiles(
          id,
          full_name,
          birth_date,
          age,
          height,
          city,
          country,
          eye_color,
          hair_color,
          bust,
          waist,
          hips,
          shoe_size,
          min_hourly_rate,
          min_daily_fee,
          cover_photo_url,
          photo_urls
        )
        ''';

      late final List<dynamic> rows;
      try {
        rows = await run(profileSelect);
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
            .toLowerCase();
        if (msg.contains('admin_note')) {
          rows = await run(profileSelect.replaceFirst('admin_note,', ''));
        } else if (msg.contains('status')) {
          rows = await run(profileSelect.replaceFirst('status,', ''));
        } else {
          rethrow;
        }
      }

      final items = rows
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final exportItems = items
          .map((row) => (row['profile'] as Map?) ?? const {})
          .map((profile) => Map<String, dynamic>.from(profile))
          .where(
            (profile) => (profile['id'] ?? '').toString().trim().isNotEmpty,
          )
          .map(SelectionExportItem.fromProfileMap)
          .toList(growable: false);
      final references = await loadCastingReferences();

      return {
        'items': items,
        'exportItems': exportItems,
        'references': references,
      };
    });

final castingResponseHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, castingId) async {
      ref.watch(authStateProvider);
      final sb = ref.read(supabaseProvider);

      try {
        final rows = await sb
            .from('casting_response_status_history')
            .select(
              'old_status,new_status,note,created_at,profile:profiles(id,full_name)',
            )
            .eq('casting_id', castingId)
            .order('created_at', ascending: false)
            .limit(40);
        return rows
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
            .toLowerCase();
        if (msg.contains('casting_response_status_history') ||
            msg.contains('schema cache') ||
            msg.contains('does not exist')) {
          return const <Map<String, dynamic>>[];
        }
        rethrow;
      }
    });

class SelectionCastingPage extends ConsumerWidget {
  const SelectionCastingPage({super.key, required this.castingId, this.from});

  final String castingId;
  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final res = ref.watch(castingResponsesProvider(castingId));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: _CardPill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '${t.errorUpper}: ${AppErrorMapper.message(e, t)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: _text,
                    ),
                  ),
                ),
              ),
            ),
            data: (data) {
              final items = List<Map<String, dynamic>>.from(
                data['items'] as List<dynamic>,
              );
              final exportItems = List<SelectionExportItem>.from(
                data['exportItems'] as List<dynamic>,
              );
              final references =
                  (data['references'] as List?)
                      ?.whereType<CastingReferenceMedia>()
                      .toList(growable: false) ??
                  const <CastingReferenceMedia>[];

              List<Map<String, dynamic>> rowsForStatus(
                CastingResponseStatus status,
              ) {
                final columns = _boardColumns(context);
                final spec = columns.firstWhere((e) => e.status == status);
                return items
                    .where((row) => spec.matches(row['status']?.toString()))
                    .toList(growable: false);
              }

              List<SelectionExportItem> exportItemsFor(
                CastingResponseStatus? status,
              ) {
                if (status == null) return exportItems;
                return rowsForStatus(status)
                    .map((row) => (row['profile'] as Map?) ?? const {})
                    .map((profile) => Map<String, dynamic>.from(profile))
                    .where(
                      (profile) =>
                          (profile['id'] ?? '').toString().trim().isNotEmpty,
                    )
                    .map(SelectionExportItem.fromProfileMap)
                    .toList(growable: false);
              }

              List<Map<String, dynamic>> rowsForCsvScope(
                CastingResponseStatus? status,
              ) {
                if (status == null) return items;
                return rowsForStatus(status);
              }

              Future<void> openPdf({
                required String title,
                required List<SelectionExportItem> scopedItems,
              }) async {
                if (scopedItems.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        Localizations.localeOf(context).languageCode == 'ru'
                            ? 'В этой подборке пока нет анкет.'
                            : 'There are no profiles in this set yet.',
                      ),
                    ),
                  );
                  return;
                }
                final options = await showDialog<SelectionPdfOptions>(
                  context: context,
                  barrierDismissible: true,
                  builder: (_) => const SelectionPdfOptionsDialog(),
                );
                if (options == null) return;

                final modelLinks =
                    await PublicProfileAccessLinkService(
                      ref.read(supabaseProvider),
                    ).createLinks(
                      profileIds: scopedItems.map((e) => e.id),
                      source: 'casting_pdf',
                      relatedId: castingId,
                    );
                final service = SelectionPdfService();
                await service.previewSelectionPdf(
                  title: title,
                  items: scopedItems,
                  options: options,
                  references: references,
                  modelLinks: modelLinks,
                );
              }

              Future<void> choosePdfExport() async {
                final ru = Localizations.localeOf(context).languageCode == 'ru';
                final scope = await showModalBottomSheet<_PdfExportScope>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _ExportScopeSheet(
                    title: ru ? 'PDF-ПОДБОРКА' : 'PDF SELECTION',
                  ),
                );
                if (scope == null) return;
                switch (scope) {
                  case _PdfExportScope.all:
                    await openPdf(
                      title: t.responsesUpper,
                      scopedItems: exportItems,
                    );
                    break;
                  case _PdfExportScope.shortlist:
                    await openPdf(
                      title: ru ? 'Шортлист' : 'Shortlist',
                      scopedItems: exportItemsFor(
                        CastingResponseStatus.shortlist,
                      ),
                    );
                    break;
                  case _PdfExportScope.approved:
                    await openPdf(
                      title: ru ? 'Утвержденные' : 'Approved',
                      scopedItems: exportItemsFor(
                        CastingResponseStatus.approved,
                      ),
                    );
                    break;
                }
              }

              Future<void> copyCsvExport() async {
                final ru = Localizations.localeOf(context).languageCode == 'ru';
                final scope = await showModalBottomSheet<_PdfExportScope>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _ExportScopeSheet(
                    title: ru ? 'CSV-ЭКСПОРТ' : 'CSV EXPORT',
                  ),
                );
                if (scope == null) return;
                if (!context.mounted) return;
                final scopedRows = switch (scope) {
                  _PdfExportScope.all => rowsForCsvScope(null),
                  _PdfExportScope.shortlist => rowsForCsvScope(
                    CastingResponseStatus.shortlist,
                  ),
                  _PdfExportScope.approved => rowsForCsvScope(
                    CastingResponseStatus.approved,
                  ),
                };
                if (scopedRows.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ru
                            ? 'В этой выгрузке пока нет анкет.'
                            : 'There are no profiles in this export yet.',
                      ),
                    ),
                  );
                  return;
                }
                final csv = _castingResponsesToCsv(scopedRows, t);
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: csv));
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        ru
                            ? 'CSV скопирован: ${scopedRows.length} строк'
                            : 'CSV copied: ${scopedRows.length} rows',
                      ),
                    ),
                  );
              }

              Future<void> updateStatus({
                required String profileId,
                required CastingResponseStatus status,
              }) async {
                if (profileId.trim().isEmpty) return;
                final sb = ref.read(supabaseProvider);
                try {
                  await sb.rpc(
                    'set_casting_response_status',
                    params: {
                      'p_casting_id': castingId,
                      'p_profile_id': profileId,
                      'p_status': castingResponseStatusToString(status),
                    },
                  );
                } on PostgrestException catch (e) {
                  final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
                      .toLowerCase();
                  final missingRpc =
                      msg.contains('set_casting_response_status') ||
                      msg.contains('schema cache') ||
                      msg.contains('function');
                  if (!missingRpc) rethrow;
                  await sb
                      .from('casting_responses')
                      .update({'status': castingResponseStatusToString(status)})
                      .eq('casting_id', castingId)
                      .eq('profile_id', profileId);
                }
                ref.invalidate(castingResponsesProvider(castingId));
                ref.invalidate(castingResponseHistoryProvider(castingId));
              }

              Future<void> updateBulkStatus({
                required List<String> profileIds,
                required CastingResponseStatus status,
              }) async {
                final ids = profileIds
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(growable: false);
                if (ids.isEmpty) return;
                final sb = ref.read(supabaseProvider);
                for (final profileId in ids) {
                  try {
                    await sb.rpc(
                      'set_casting_response_status',
                      params: {
                        'p_casting_id': castingId,
                        'p_profile_id': profileId,
                        'p_status': castingResponseStatusToString(status),
                        'p_note': 'bulk',
                      },
                    );
                  } on PostgrestException catch (e) {
                    final msg =
                        '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
                            .toLowerCase();
                    final missingRpc =
                        msg.contains('set_casting_response_status') ||
                        msg.contains('schema cache') ||
                        msg.contains('function');
                    if (!missingRpc) rethrow;
                    await sb
                        .from('casting_responses')
                        .update({
                          'status': castingResponseStatusToString(status),
                        })
                        .eq('casting_id', castingId)
                        .eq('profile_id', profileId);
                  }
                }
                ref.invalidate(castingResponsesProvider(castingId));
                ref.invalidate(castingResponseHistoryProvider(castingId));
              }

              Future<void> updateNote({
                required String profileId,
                required String note,
              }) async {
                if (profileId.trim().isEmpty) return;
                final sb = ref.read(supabaseProvider);
                try {
                  await sb.rpc(
                    'set_casting_response_admin_note',
                    params: {
                      'p_casting_id': castingId,
                      'p_profile_id': profileId,
                      'p_admin_note': note,
                    },
                  );
                } on PostgrestException catch (e) {
                  final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
                      .toLowerCase();
                  final missingRpc =
                      msg.contains('set_casting_response_admin_note') ||
                      msg.contains('schema cache') ||
                      msg.contains('function');
                  if (!missingRpc) rethrow;
                  await sb
                      .from('casting_responses')
                      .update({'admin_note': note.trim()})
                      .eq('casting_id', castingId)
                      .eq('profile_id', profileId);
                }
                ref.invalidate(castingResponsesProvider(castingId));
              }

              Future<void> removeBulkResponses({
                required List<String> profileIds,
              }) async {
                final ids = profileIds
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(growable: false);
                if (ids.isEmpty) return;
                final sb = ref.read(supabaseProvider);
                for (final profileId in ids) {
                  await sb
                      .from('casting_responses')
                      .delete()
                      .eq('casting_id', castingId)
                      .eq('profile_id', profileId);
                }
                ref.invalidate(castingResponsesProvider(castingId));
                ref.invalidate(castingResponseHistoryProvider(castingId));
              }

              return Column(
                children: [
                  BrandAdminHeader(
                    title: t.responsesUpper,
                    onBack: () => context.go(
                      from == 'castings'
                          ? Routes.castings
                          : Routes.adminSelection,
                    ),
                    sideWidth: 104,
                    trailing: BrandAdminHeaderActions(
                      actions: [
                        BrandAdminHeaderAction(
                          label: ru ? 'Обновить' : 'Refresh',
                          icon: Icons.refresh_rounded,
                          onPressed: () {
                            ref.invalidate(castingResponsesProvider(castingId));
                          },
                        ),
                        BrandAdminHeaderAction(
                          label: 'PDF',
                          icon: Icons.picture_as_pdf_rounded,
                          onPressed: exportItems.isEmpty
                              ? null
                              : choosePdfExport,
                        ),
                        BrandAdminHeaderAction(
                          label: ru ? 'Таблица' : 'Table',
                          icon: Icons.table_chart_rounded,
                          onPressed: items.isEmpty ? null : copyCsvExport,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: _CardPill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                child: Text(
                                  t.noResponsesMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    color: _text,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : _CastingShortlistBoard(
                            items: items,
                            castingId: castingId,
                            onStatusChanged: updateStatus,
                            onBulkStatusChanged: updateBulkStatus,
                            onBulkRemove: removeBulkResponses,
                            onNoteChanged: updateNote,
                            history: ref.watch(
                              castingResponseHistoryProvider(castingId),
                            ),
                          ),
                  ),
                ],
              );
            },
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: BrandTheme.lightPillGradient,
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: child,
    );
  }
}

class _ExportScopeSheet extends StatelessWidget {
  const _ExportScopeSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: BrandTheme.lightPillGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kBorderColor),
            boxShadow: BrandTheme.basePillShadow(isDark: false),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _PdfScopeTile(
                icon: Icons.inbox_rounded,
                label: ru ? 'Все отклики' : 'All responses',
                onTap: () => Navigator.of(context).pop(_PdfExportScope.all),
              ),
              const SizedBox(height: 8),
              _PdfScopeTile(
                icon: Icons.playlist_add_check_rounded,
                label: ru ? 'Шортлист' : 'Shortlist',
                onTap: () =>
                    Navigator.of(context).pop(_PdfExportScope.shortlist),
              ),
              const SizedBox(height: 8),
              _PdfScopeTile(
                icon: Icons.verified_rounded,
                label: ru ? 'Утвержденные' : 'Approved',
                onTap: () =>
                    Navigator.of(context).pop(_PdfExportScope.approved),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfScopeTile extends StatelessWidget {
  const _PdfScopeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: BrandTheme.redTop),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}

String _castingResponsesToCsv(
  List<Map<String, dynamic>> rows,
  AppLocalizations t,
) {
  final ru = t.localeName == 'ru';
  final headers = ru
      ? [
          'ФИО',
          'Возраст',
          'Рост',
          'Город',
          'Страна',
          'Статус',
          'Заметка',
          'Дата отклика',
          'ID анкеты',
        ]
      : [
          'Name',
          'Age',
          'Height',
          'City',
          'Country',
          'Status',
          'Note',
          'Response date',
          'Profile ID',
        ];
  final buffer = StringBuffer('${headers.map(_csvCell).join(',')}\n');
  for (final row in rows) {
    final profile = Map<String, dynamic>.from((row['profile'] as Map?) ?? {});
    final profileId = (profile['id'] ?? '').toString();
    final status = castingResponseStatusFromString(row['status']?.toString());
    final age = ModelVm.displayAgeFromMap(profile);
    final height = (profile['height'] ?? '').toString();
    final cells = <String>[
      (profile['full_name'] ?? '').toString(),
      age > 0 ? '$age' : '',
      height == 'null' ? '' : height,
      (profile['city'] ?? '').toString(),
      (profile['country'] ?? '').toString(),
      castingResponseStatusLabel(t, status),
      (row['admin_note'] ?? '').toString(),
      (row['created_at'] ?? '').toString(),
      profileId,
    ];
    buffer.writeln(cells.map(_csvCell).join(','));
  }
  return buffer.toString();
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

class _CastingShortlistBoard extends StatefulWidget {
  const _CastingShortlistBoard({
    required this.items,
    required this.castingId,
    required this.onStatusChanged,
    required this.onBulkStatusChanged,
    required this.onBulkRemove,
    required this.onNoteChanged,
    required this.history,
  });

  final List<Map<String, dynamic>> items;
  final String castingId;
  final Future<void> Function({
    required String profileId,
    required CastingResponseStatus status,
  })
  onStatusChanged;
  final Future<void> Function({
    required List<String> profileIds,
    required CastingResponseStatus status,
  })
  onBulkStatusChanged;
  final Future<void> Function({required List<String> profileIds}) onBulkRemove;
  final Future<void> Function({required String profileId, required String note})
  onNoteChanged;
  final AsyncValue<List<Map<String, dynamic>>> history;

  @override
  State<_CastingShortlistBoard> createState() => _CastingShortlistBoardState();
}

class _CastingShortlistBoardState extends State<_CastingShortlistBoard> {
  final Set<String> _selectedProfileIds = <String>{};
  CastingResponseStatus _compactStatus = CastingResponseStatus.submitted;

  void _toggleSelection(String profileId, bool selected) {
    setState(() {
      if (selected) {
        _selectedProfileIds.add(profileId);
      } else {
        _selectedProfileIds.remove(profileId);
      }
    });
  }

  Future<void> _bulkMove(CastingResponseStatus status) async {
    final ids = _selectedProfileIds.toList(growable: false);
    if (ids.isEmpty) return;
    await widget.onBulkStatusChanged(profileIds: ids, status: status);
    if (!mounted) return;
    setState(_selectedProfileIds.clear);
  }

  Future<void> _removeSelected() async {
    final ids = _selectedProfileIds.toList(growable: false);
    if (ids.isEmpty) return;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'УДАЛИТЬ ИЗ ОТКЛИКОВ?' : 'REMOVE FROM RESPONSES?'),
        content: Text(
          ru
              ? 'Выбранные анкеты будут убраны из откликов этого кастинга.'
              : 'Selected profiles will be removed from this casting response list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ru ? 'Отмена' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              ru ? 'Удалить' : 'Remove',
              style: const TextStyle(color: BrandTheme.redTop),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onBulkRemove(profileIds: ids);
    if (!mounted) return;
    setState(_selectedProfileIds.clear);
  }

  Future<void> _moveOne({
    required String profileId,
    required CastingResponseStatus status,
  }) async {
    await widget.onStatusChanged(profileId: profileId, status: status);
    if (!mounted) return;
    setState(() => _selectedProfileIds.remove(profileId));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final columns = _boardColumns(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final statuses = columns.map((e) => e.status).toList(growable: false);
        final compactColumn = columns.firstWhere(
          (e) => e.status == _compactStatus,
          orElse: () => columns.first,
        );
        final board = SizedBox(
          width: constraints.maxWidth,
          child: compact
              ? _CastingBoardColumn(
                  spec: compactColumn,
                  items: _itemsFor(compactColumn.status),
                  castingId: widget.castingId,
                  selectedProfileIds: _selectedProfileIds,
                  onSelectionChanged: _toggleSelection,
                  onStatusChanged: _moveOne,
                  onNoteChanged: widget.onNoteChanged,
                  allStatuses: statuses,
                  t: t,
                  compact: compact,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final column in columns) ...[
                      Expanded(
                        child: _CastingBoardColumn(
                          spec: column,
                          items: _itemsFor(column.status),
                          castingId: widget.castingId,
                          selectedProfileIds: _selectedProfileIds,
                          onSelectionChanged: _toggleSelection,
                          onStatusChanged: _moveOne,
                          onNoteChanged: widget.onNoteChanged,
                          allStatuses: statuses,
                          t: t,
                          compact: compact,
                        ),
                      ),
                      if (column != columns.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
        );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BulkToolbar(
              selectedCount: _selectedProfileIds.length,
              statuses: columns.map((e) => e.status).toList(growable: false),
              onMove: _bulkMove,
              onRemove: () {
                _removeSelected();
              },
              onClear: () => setState(_selectedProfileIds.clear),
              t: t,
            ),
            if (_selectedProfileIds.isNotEmpty) const SizedBox(height: 10),
            if (compact) ...[
              _StatusSelector(
                columns: columns,
                selected: compactColumn.status,
                counts: {
                  for (final column in columns)
                    column.status: _itemsFor(column.status).length,
                },
                onChanged: (status) => setState(() {
                  _compactStatus = status;
                }),
              ),
              const SizedBox(height: 10),
            ],
            board,
            const SizedBox(height: 12),
            _HistoryPanel(history: widget.history),
          ],
        );

        if (compact) {
          return SingleChildScrollView(child: content);
        }

        return SingleChildScrollView(child: content);
      },
    );
  }

  List<Map<String, dynamic>> _itemsFor(CastingResponseStatus status) {
    final spec = _boardColumns(context).firstWhere((e) => e.status == status);
    return widget.items
        .where((row) => spec.matches(row['status']?.toString()))
        .toList(growable: false);
  }
}

class _BoardColumnSpec {
  const _BoardColumnSpec({
    required this.title,
    required this.status,
    required this.aliases,
    required this.icon,
  });

  final String title;
  final CastingResponseStatus status;
  final Set<CastingResponseStatus> aliases;
  final IconData icon;

  bool matches(String? value) {
    final parsed = castingResponseStatusFromString(value);
    return parsed == status || aliases.contains(parsed);
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.columns,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final List<_BoardColumnSpec> columns;
  final CastingResponseStatus selected;
  final Map<CastingResponseStatus, int> counts;
  final ValueChanged<CastingResponseStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 520;
        if (tight) {
          return SizedBox(
            height: 46,
            child: Row(
              children: [
                for (var index = 0; index < columns.length; index++) ...[
                  Expanded(
                    child: _StatusSelectorChip(
                      column: columns[index],
                      active: columns[index].status == selected,
                      count: counts[columns[index].status] ?? 0,
                      tight: true,
                      onTap: () => onChanged(columns[index].status),
                    ),
                  ),
                  if (index != columns.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          );
        }

        return SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: columns.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final column = columns[index];
              return _StatusSelectorChip(
                column: column,
                active: column.status == selected,
                count: counts[column.status] ?? 0,
                onTap: () => onChanged(column.status),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusSelectorChip extends StatelessWidget {
  const _StatusSelectorChip({
    required this.column,
    required this.active,
    required this.count,
    required this.onTap,
    this.tight = false,
  });

  final _BoardColumnSpec column;
  final bool active;
  final int count;
  final VoidCallback onTap;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: tight ? 9 : 14),
        decoration: BoxDecoration(
          color: active ? BrandTheme.redTop : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? BrandTheme.redTop : kBorderColor),
          boxShadow: active ? BrandTheme.basePillShadow(isDark: false) : null,
        ),
        child: Row(
          mainAxisAlignment: tight
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              column.icon,
              color: active ? Colors.white : BrandTheme.redTop,
              size: tight ? 16 : 18,
            ),
            SizedBox(width: tight ? 5 : 8),
            Flexible(
              child: Text(
                column.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : _text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: tight ? 0.4 : 1,
                  fontSize: tight ? 10 : 12,
                ),
              ),
            ),
            SizedBox(width: tight ? 5 : 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tight ? 6 : 7,
                vertical: tight ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : BrandTheme.redTop,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tight ? 10 : 11,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastingBoardColumn extends StatelessWidget {
  const _CastingBoardColumn({
    required this.spec,
    required this.items,
    required this.castingId,
    required this.selectedProfileIds,
    required this.onSelectionChanged,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.allStatuses,
    required this.t,
    required this.compact,
  });

  final _BoardColumnSpec spec;
  final List<Map<String, dynamic>> items;
  final String castingId;
  final Set<String> selectedProfileIds;
  final void Function(String profileId, bool selected) onSelectionChanged;
  final Future<void> Function({
    required String profileId,
    required CastingResponseStatus status,
  })
  onStatusChanged;
  final Future<void> Function({required String profileId, required String note})
  onNoteChanged;
  final List<CastingResponseStatus> allStatuses;
  final AppLocalizations t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_BoardDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.status != spec.status &&
          details.data.profileId.isNotEmpty,
      onAcceptWithDetails: (details) {
        onStatusChanged(profileId: details.data.profileId, status: spec.status);
      },
      builder: (context, candidateData, _) {
        final highlighted = candidateData.isNotEmpty;
        return _CardPill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: highlighted ? const EdgeInsets.all(6) : EdgeInsets.zero,
            decoration: highlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BrandTheme.redTop, width: 1.5),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(spec.icon, color: BrandTheme.redTop, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        spec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                          color: _text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: BrandTheme.redTop,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  Container(
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.28),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'ru'
                          ? 'ПУСТО'
                          : 'EMPTY',
                      style: const TextStyle(
                        color: kTextMuted,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < items.length; i++) ...[
                    _CastingBoardCard(
                      row: items[i],
                      castingId: castingId,
                      currentStatus: spec.status,
                      allStatuses: allStatuses,
                      selectedProfileIds: selectedProfileIds,
                      onSelectionChanged: onSelectionChanged,
                      onStatusChanged: onStatusChanged,
                      onNoteChanged: onNoteChanged,
                      t: t,
                      compact: compact,
                    ),
                    if (i != items.length - 1) const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoardDragData {
  const _BoardDragData({required this.profileId, required this.status});

  final String profileId;
  final CastingResponseStatus status;
}

class _BulkToolbar extends StatelessWidget {
  const _BulkToolbar({
    required this.selectedCount,
    required this.statuses,
    required this.onMove,
    required this.onRemove,
    required this.onClear,
    required this.t,
  });

  final int selectedCount;
  final List<CastingResponseStatus> statuses;
  final Future<void> Function(CastingResponseStatus status) onMove;
  final VoidCallback onRemove;
  final VoidCallback onClear;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();

    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return _CardPill(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            ru ? 'ВЫБРАНО: $selectedCount' : 'SELECTED: $selectedCount',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: _text,
            ),
          ),
          for (final status in statuses)
            _StatusMoveChip(
              label: castingResponseStatusLabel(t, status).toUpperCase(),
              onTap: () => onMove(status),
            ),
          _StatusMoveChip(
            label: ru ? 'УДАЛИТЬ' : 'REMOVE',
            onTap: onRemove,
            tone: _StatusMoveChipTone.danger,
          ),
          _StatusMoveChip(label: ru ? 'СБРОС' : 'CLEAR', onTap: onClear),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.history});

  final AsyncValue<List<Map<String, dynamic>>> history;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return history.maybeWhen(
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return _CardPill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ru ? 'ИСТОРИЯ ПЕРЕМЕЩЕНИЙ' : 'MOVE HISTORY',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: _text,
                ),
              ),
              const SizedBox(height: 8),
              for (final row in rows.take(8)) ...[
                _HistoryRow(row: row),
                if (row != rows.take(8).last) const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final profile = Map<String, dynamic>.from((row['profile'] as Map?) ?? {});
    final name = (profile['full_name'] ?? '').toString().trim();
    final oldStatus = castingResponseStatusFromString(
      row['old_status']?.toString(),
    );
    final newStatus = castingResponseStatusFromString(
      row['new_status']?.toString(),
    );
    final createdAt = (row['created_at'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.36),
        border: Border.all(color: kBorderColor),
      ),
      child: Text(
        '${name.isEmpty ? t.profileUpper : name}: '
        '${castingResponseStatusLabel(t, oldStatus)} → '
        '${castingResponseStatusLabel(t, newStatus)}'
        '${createdAt.isEmpty ? '' : ' · ${createdAt.split('.').first}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _text,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CastingBoardCard extends StatelessWidget {
  const _CastingBoardCard({
    required this.row,
    required this.castingId,
    required this.currentStatus,
    required this.allStatuses,
    required this.selectedProfileIds,
    required this.onSelectionChanged,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.t,
    required this.compact,
  });

  final Map<String, dynamic> row;
  final String castingId;
  final CastingResponseStatus currentStatus;
  final List<CastingResponseStatus> allStatuses;
  final Set<String> selectedProfileIds;
  final void Function(String profileId, bool selected) onSelectionChanged;
  final Future<void> Function({
    required String profileId,
    required CastingResponseStatus status,
  })
  onStatusChanged;
  final Future<void> Function({required String profileId, required String note})
  onNoteChanged;
  final AppLocalizations t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final profile = (row['profile'] as Map?) ?? {};
    final profileMap = Map<String, dynamic>.from(profile);
    final profileId = (profileMap['id'] ?? '').toString();
    final name = (profileMap['full_name'] ?? '').toString();
    final city = (profileMap['city'] ?? '').toString();
    final subtitleParts = <String>[];
    final age = ModelVm.displayAgeFromMap(profileMap);
    final height = profileMap['height'];
    if (age > 0) subtitleParts.add('${t.ageShort}: $age');
    if (height != null) subtitleParts.add('${t.heightShort}: $height');
    if (city.isNotEmpty) subtitleParts.add(city);

    final photoUrlsRaw = profileMap['photo_urls'];
    final photoUrls = photoUrlsRaw is List
        ? photoUrlsRaw
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : <String>[];
    final coverUrl = (profileMap['cover_photo_url'] ?? '').toString().trim();
    final thumbUrl = coverUrl.isNotEmpty
        ? coverUrl
        : (photoUrls.isNotEmpty ? photoUrls.first : '');
    final selected = selectedProfileIds.contains(profileId);
    final adminNote = (row['admin_note'] ?? '').toString().trim();
    final hasNote = adminNote.isNotEmpty;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.34),
        border: Border.all(
          color: selected ? BrandTheme.redTop : kBorderColor,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: profileId.isEmpty
                  ? null
                  : () => context.go(
                      '${Routes.modelPrefix}$profileId?from=casting&castingId=$castingId',
                    ),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: profileId.isEmpty
                        ? null
                        : (value) =>
                              onSelectionChanged(profileId, value ?? false),
                    activeColor: BrandTheme.redTop,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  _SelectionProfileThumb(url: thumbUrl, compact: compact),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : t.profileUpper,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _text,
                            fontSize: 14,
                          ),
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitleParts.join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kTextMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (hasNote) ...[
              _CandidateNotePreview(note: adminNote),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusMoveChip(
                  label: Localizations.localeOf(context).languageCode == 'ru'
                      ? (hasNote ? 'Заметка есть' : 'Заметка')
                      : (hasNote ? 'Has note' : 'Note'),
                  icon: hasNote
                      ? Icons.sticky_note_2_rounded
                      : Icons.note_add_rounded,
                  tone: hasNote
                      ? _StatusMoveChipTone.note
                      : _StatusMoveChipTone.neutral,
                  onTap: profileId.isEmpty
                      ? null
                      : () => _editCandidateNote(
                          context: context,
                          profileName: name.isNotEmpty ? name : t.profileUpper,
                          initialNote: adminNote,
                          onSave: (note) =>
                              onNoteChanged(profileId: profileId, note: note),
                        ),
                  compact: compact,
                ),
                for (final status in allStatuses)
                  if (status != currentStatus)
                    _StatusMoveChip(
                      label: castingResponseStatusLabel(t, status),
                      onTap: profileId.isEmpty
                          ? null
                          : () => onStatusChanged(
                              profileId: profileId,
                              status: status,
                            ),
                      compact: compact,
                    ),
              ],
            ),
          ],
        ),
      ),
    );

    if (profileId.isEmpty) return card;

    return LongPressDraggable<_BoardDragData>(
      data: _BoardDragData(profileId: profileId, status: currentStatus),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 230, child: Opacity(opacity: 0.9, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: card),
      child: card,
    );
  }
}

Future<void> _editCandidateNote({
  required BuildContext context,
  required String profileName,
  required String initialNote,
  required Future<void> Function(String note) onSave,
}) async {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final controller = TextEditingController(text: initialNote);
  var saving = false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: BrandTheme.lightPillGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kBorderColor),
                  boxShadow: BrandTheme.basePillShadow(isDark: false),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sticky_note_2_rounded,
                          color: BrandTheme.redTop,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ru ? 'ЗАМЕТКА ПО КАНДИДАТУ' : 'CANDIDATE NOTE',
                            style: const TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      minLines: 4,
                      maxLines: 8,
                      enabled: !saving,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: ru
                            ? 'Например: сильная камера, уточнить доступность'
                            : 'Example: strong camera presence, check availability',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.66),
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
                          borderSide: const BorderSide(
                            color: BrandTheme.redTop,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CandidateNoteButton(
                            label: ru ? 'Очистить' : 'Clear',
                            onTap: saving
                                ? null
                                : () {
                                    controller.clear();
                                    setSheetState(() {});
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CandidateNoteButton(
                            label: saving
                                ? (ru ? 'Сохранение' : 'Saving')
                                : (ru ? 'Сохранить' : 'Save'),
                            isPrimary: true,
                            onTap: saving
                                ? null
                                : () async {
                                    setSheetState(() => saving = true);
                                    try {
                                      await onSave(controller.text.trim());
                                      if (context.mounted) {
                                        Navigator.of(context).pop(true);
                                      }
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      setSheetState(() => saving = false);
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ru
                                                  ? 'Не удалось сохранить заметку. Проверьте SQL для заметок кандидатов.'
                                                  : 'Could not save the note. Check candidate notes SQL.',
                                            ),
                                          ),
                                        );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(ru ? 'Заметка сохранена' : 'Note saved')),
      );
  }
}

class _CandidateNotePreview extends StatelessWidget {
  const _CandidateNotePreview({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BrandTheme.redTop.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandTheme.redTop.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_rounded,
            size: 16,
            color: BrandTheme.redTop,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateNoteButton extends StatelessWidget {
  const _CandidateNoteButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isPrimary ? _text : Colors.white.withValues(alpha: 0.58),
          border: Border.all(color: kBorderColor),
          boxShadow: isPrimary
              ? BrandTheme.basePillShadow(isDark: false)
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isPrimary ? Colors.white : _text,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

enum _StatusMoveChipTone { neutral, danger, note }

class _StatusMoveChip extends StatelessWidget {
  const _StatusMoveChip({
    required this.label,
    required this.onTap,
    this.tone = _StatusMoveChipTone.neutral,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final _StatusMoveChipTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 9,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: tone == _StatusMoveChipTone.danger
              ? BrandTheme.redTop.withValues(alpha: 0.10)
              : tone == _StatusMoveChipTone.note
              ? BrandTheme.redTop.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.58),
          border: Border.all(
            color: tone == _StatusMoveChipTone.danger
                ? BrandTheme.redTop.withValues(alpha: 0.36)
                : tone == _StatusMoveChipTone.note
                ? BrandTheme.redTop.withValues(alpha: 0.28)
                : kBorderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 13 : 14,
                color: tone == _StatusMoveChipTone.neutral
                    ? _text
                    : BrandTheme.redTop,
              ),
              SizedBox(width: compact ? 4 : 5),
            ],
            Text(
              label,
              style: TextStyle(
                color:
                    tone == _StatusMoveChipTone.danger ||
                        tone == _StatusMoveChipTone.note
                    ? BrandTheme.redTop
                    : _text,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionProfileThumb extends StatelessWidget {
  const _SelectionProfileThumb({required this.url, this.compact = false});

  final String url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: compact ? 48 : 56,
        height: compact ? 48 : 56,
        child: url.trim().isEmpty
            ? Container(
                color: const Color(0x14000000),
                alignment: Alignment.center,
                child: const Icon(Icons.person, color: _text),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                maxWidthDiskCache: 320,
                placeholder: (_, _) =>
                    Container(color: const Color(0x14000000)),
                errorWidget: (_, _, _) => Container(
                  color: const Color(0x14000000),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded, color: _text),
                ),
              ),
      ),
    );
  }
}
