import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'admin_shell_v2.dart';
import '../selection/selection_export_item.dart';
import '../selection/selection_pdf_options.dart';
import '../selection/selection_pdf_options_dialog.dart';
import '../selection/selection_pdf_service.dart';
import '../selection/public_profile_access_link_service.dart';
import '../catalog/model_data.dart';
import '../../core/storage_image_variant.dart';
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

      Future<Map<String, dynamic>> loadCastingMeta() async {
        final data = <String, dynamic>{};
        try {
          final row = await sb
              .from('castings')
              .select('title')
              .eq('id', castingId)
              .maybeSingle();
          data['title'] = (row?['title'] ?? '').toString().trim();
        } on PostgrestException catch (e) {
          final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
              .toLowerCase();
          if (!msg.contains('title') &&
              !msg.contains('schema cache') &&
              !msg.contains('does not exist')) {
            rethrow;
          }
        }

        try {
          final row = await sb
              .from('castings')
              .select('reference_media')
              .eq('id', castingId)
              .maybeSingle();
          final raw = row?['reference_media'];
          data['references'] = raw is List
              ? raw
                    .whereType<Map>()
                    .map((e) => CastingReferenceMedia.fromJson(Map.from(e)))
                    .where((e) => e.url.trim().isNotEmpty)
                    .toList(growable: false)
              : const <CastingReferenceMedia>[];
          return data;
        } on PostgrestException catch (e) {
          final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
              .toLowerCase();
          if (msg.contains('reference_media') ||
              msg.contains('schema cache') ||
              msg.contains('does not exist')) {
            data['references'] = const <CastingReferenceMedia>[];
            return data;
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
          cover_photo_focal_x,
          cover_photo_focal_y,
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
        } else if (msg.contains('focal')) {
          rows = await run(
            profileSelect
                .replaceFirst('cover_photo_focal_x,', '')
                .replaceFirst('cover_photo_focal_y,', ''),
          );
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
      final castingMeta = await loadCastingMeta();

      return {
        'castingTitle': (castingMeta['title'] ?? '').toString().trim(),
        'items': items,
        'exportItems': exportItems,
        'references':
            castingMeta['references'] as List<CastingReferenceMedia>? ??
            const <CastingReferenceMedia>[],
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
      backgroundColor: kIsWeb ? Tokens.bg : _bg,
      body: SafeArea(
        child: Padding(
          padding: kIsWeb ? EdgeInsets.zero : const EdgeInsets.all(16),
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
              final castingTitle = (data['castingTitle'] ?? '')
                  .toString()
                  .trim();

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
                  isRussian: t.localeName == 'ru',
                );
              }

              Future<void> exportPdfScope(_PdfExportScope scope) async {
                final ru = Localizations.localeOf(context).languageCode == 'ru';
                final basePdfTitle = castingTitle.isNotEmpty
                    ? castingTitle
                    : t.responsesUpper;
                switch (scope) {
                  case _PdfExportScope.all:
                    await openPdf(
                      title: basePdfTitle,
                      scopedItems: exportItems,
                    );
                    break;
                  case _PdfExportScope.shortlist:
                    await openPdf(
                      title: '$basePdfTitle - ${ru ? 'Шортлист' : 'Shortlist'}',
                      scopedItems: exportItemsFor(
                        CastingResponseStatus.shortlist,
                      ),
                    );
                    break;
                  case _PdfExportScope.approved:
                    await openPdf(
                      title:
                          '$basePdfTitle - ${ru ? 'Утвержденные' : 'Approved'}',
                      scopedItems: exportItemsFor(
                        CastingResponseStatus.approved,
                      ),
                    );
                    break;
                }
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
                await exportPdfScope(scope);
              }

              Future<void> exportCsvScope(_PdfExportScope scope) async {
                final ru = Localizations.localeOf(context).languageCode == 'ru';
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
                await exportCsvScope(scope);
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

              final backRoute = switch (from) {
                'castings' => Routes.castings,
                'admin_castings' => Routes.adminCastings,
                _ => Routes.adminSelection,
              };

              if (kIsWeb) {
                return _CastingResponsesV2(
                  castingId: castingId,
                  castingTitle: castingTitle,
                  items: items,
                  hasExportItems: exportItems.isNotEmpty,
                  history: ref.watch(castingResponseHistoryProvider(castingId)),
                  onBack: () => context.go(backRoute),
                  backLabel: backRoute == Routes.adminSelection
                      ? (ru ? 'Подборки' : 'Selections')
                      : (ru ? 'Кастинги' : 'Castings'),
                  onRefresh: () {
                    ref.invalidate(castingResponsesProvider(castingId));
                    ref.invalidate(castingResponseHistoryProvider(castingId));
                  },
                  onPdf: exportPdfScope,
                  onCsv: exportCsvScope,
                  onStatusChanged: updateStatus,
                  onBulkStatusChanged: updateBulkStatus,
                  onBulkRemove: removeBulkResponses,
                  onNoteChanged: updateNote,
                );
              }

              return Column(
                children: [
                  BrandAdminHeader(
                    title: t.responsesUpper,
                    onBack: () => context.go(switch (from) {
                      'castings' => Routes.castings,
                      'admin_castings' => Routes.adminCastings,
                      _ => Routes.adminSelection,
                    }),
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
        return SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 1),
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
  });

  final _BoardColumnSpec column;
  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? BrandTheme.redTop : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? BrandTheme.redTop : kBorderColor),
          boxShadow: active ? BrandTheme.basePillShadow(isDark: false) : null,
        ),
        child: Row(
          children: [
            Icon(
              column.icon,
              color: active ? Colors.white : BrandTheme.redTop,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                column.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : _text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
                  fontSize: 11,
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
    final actionChips = [
      _StatusMoveChip(
        label: Localizations.localeOf(context).languageCode == 'ru'
            ? (hasNote ? 'Заметка есть' : 'Заметка')
            : (hasNote ? 'Has note' : 'Note'),
        icon: hasNote ? Icons.sticky_note_2_rounded : Icons.note_add_rounded,
        tone: hasNote ? _StatusMoveChipTone.note : _StatusMoveChipTone.neutral,
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
                : () => onStatusChanged(profileId: profileId, status: status),
            compact: compact,
          ),
    ];

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
            if (compact)
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: actionChips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => actionChips[index],
                ),
              )
            else
              Wrap(spacing: 6, runSpacing: 6, children: actionChips),
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


// ---------------------------------------------------------------------------
// v2 (web): full-width board — three hairline columns, rows instead of
// cards, bulk bar under the header, history as a quiet list.
// ---------------------------------------------------------------------------

String _sentenceCaseResponses(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

class _CastingResponsesV2 extends StatefulWidget {
  const _CastingResponsesV2({
    required this.castingId,
    required this.castingTitle,
    required this.items,
    required this.hasExportItems,
    required this.history,
    required this.onBack,
    required this.backLabel,
    required this.onRefresh,
    required this.onPdf,
    required this.onCsv,
    required this.onStatusChanged,
    required this.onBulkStatusChanged,
    required this.onBulkRemove,
    required this.onNoteChanged,
  });

  final String castingId;
  final String castingTitle;
  final List<Map<String, dynamic>> items;
  final bool hasExportItems;
  final AsyncValue<List<Map<String, dynamic>>> history;
  final VoidCallback onBack;
  final String backLabel;
  final VoidCallback onRefresh;
  final Future<void> Function(_PdfExportScope scope) onPdf;
  final Future<void> Function(_PdfExportScope scope) onCsv;
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

  @override
  State<_CastingResponsesV2> createState() => _CastingResponsesV2State();
}

class _CastingResponsesV2State extends State<_CastingResponsesV2> {
  final Set<String> _selected = <String>{};
  CastingResponseStatus _narrowStatus = CastingResponseStatus.submitted;

  /// Step 38: the row under the mouse — keys 1/2/3 act on it when nothing
  /// is selected.
  String? _hoveredProfileId;
  bool _keysBusy = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    if (kIsWeb) HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  /// 1 / 2 / 3 move the selected profiles (or the hovered row) to the
  /// first / second / third column; Esc clears the selection; C compares.
  bool _handleKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return false;
    }
    // Typing in a field (a note, the search) must stay typing.
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return false;
    }
    // Only while this board is the page on screen.
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_selected.isEmpty) return false;
      setState(_selected.clear);
      return true;
    }
    if (key == LogicalKeyboardKey.keyC && _canCompare) {
      unawaited(_compareSelected());
      return true;
    }
    final index = key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1
        ? 0
        : key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2
        ? 1
        : key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3
        ? 2
        : -1;
    if (index < 0) return false;
    final columns = _boardColumns(context);
    if (index >= columns.length) return false;
    final status = columns[index].status;
    if (_selected.isNotEmpty) {
      unawaited(_bulkMoveGuarded(status));
      return true;
    }
    final hovered = _hoveredProfileId;
    if (hovered == null || hovered.isEmpty) return false;
    final row = widget.items.where((r) {
      final profile = (r['profile'] as Map?) ?? const {};
      return (profile['id'] ?? '').toString() == hovered;
    }).firstOrNull;
    if (row == null) return false;
    if (columns[index].matches((row['status'] ?? '').toString())) return true;
    unawaited(_moveOneGuarded(hovered, status));
    return true;
  }

  Future<void> _moveOneGuarded(
    String profileId,
    CastingResponseStatus status,
  ) async {
    if (_keysBusy) return;
    _keysBusy = true;
    try {
      await _moveOne(profileId, status);
    } finally {
      _keysBusy = false;
    }
  }

  Future<void> _bulkMoveGuarded(CastingResponseStatus status) async {
    if (_keysBusy) return;
    _keysBusy = true;
    try {
      await _bulkMove(status);
    } finally {
      _keysBusy = false;
    }
  }

  void _setHovered(String profileId, bool hovered) {
    if (hovered) {
      _hoveredProfileId = profileId;
    } else if (_hoveredProfileId == profileId) {
      _hoveredProfileId = null;
    }
  }

  bool get _canCompare => _selected.length >= 2 && _selected.length <= 4;

  /// Step 38: 2–4 selected profiles side by side.
  Future<void> _compareSelected() async {
    if (!_canCompare) return;
    final rows = widget.items.where((r) {
      final profile = (r['profile'] as Map?) ?? const {};
      return _selected.contains((profile['id'] ?? '').toString());
    }).toList(growable: false);
    if (rows.length < 2) return;
    final columns = _boardColumns(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CompareDialog(
        rows: rows,
        columns: columns,
        castingId: widget.castingId,
        onMove: (profileId, status) async {
          await widget.onStatusChanged(profileId: profileId, status: status);
        },
      ),
    );
  }

  List<Map<String, dynamic>> _itemsFor(_BoardColumnSpec spec) {
    return widget.items
        .where((row) => spec.matches(row['status']?.toString()))
        .toList(growable: false);
  }

  void _toggle(String profileId, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(profileId);
      } else {
        _selected.remove(profileId);
      }
    });
  }

  Future<void> _moveOne(String profileId, CastingResponseStatus status) async {
    await widget.onStatusChanged(profileId: profileId, status: status);
    if (!mounted) return;
    setState(() => _selected.remove(profileId));
  }

  Future<void> _bulkMove(CastingResponseStatus status) async {
    final ids = _selected.toList(growable: false);
    if (ids.isEmpty) return;
    await widget.onBulkStatusChanged(profileIds: ids, status: status);
    if (!mounted) return;
    setState(_selected.clear);
  }

  Future<void> _removeSelected() async {
    final ids = _selected.toList(growable: false);
    if (ids.isEmpty) return;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'Убрать из откликов?' : 'Remove from responses?'),
        content: Text(
          ru
              ? 'Выбранные анкеты (${ids.length}) исчезнут из откликов этого кастинга.'
              : 'The selected profiles (${ids.length}) will be removed from this casting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ru ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
            child: Text(ru ? 'Убрать' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onBulkRemove(profileIds: ids);
    if (!mounted) return;
    setState(_selected.clear);
  }

  Future<void> _editNote(Map<String, dynamic> row) async {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final profile = Map<String, dynamic>.from((row['profile'] as Map?) ?? {});
    final profileId = (profile['id'] ?? '').toString();
    if (profileId.isEmpty) return;
    final name = (profile['full_name'] ?? '').toString().trim();
    final initial = (row['admin_note'] ?? '').toString().trim();
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'Заметка' : 'Note'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? t.profileUpper : name,
                style: AppText.small.copyWith(color: Tokens.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: ru
                      ? 'Например: сильная камера, уточнить доступность'
                      : 'Example: strong camera presence, check availability',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ru ? 'Отмена' : 'Cancel'),
          ),
          if (initial.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              style: TextButton.styleFrom(foregroundColor: Tokens.danger),
              child: Text(ru ? 'Удалить заметку' : 'Delete note'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(ru ? 'Сохранить' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.onNoteChanged(profileId: profileId, note: result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ru ? 'Не удалось сохранить заметку' : 'Could not save the note',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final columns = _boardColumns(context);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final gutter = wide ? 32.0 : 16.0;
    final counts = {
      for (final column in columns) column.status: _itemsFor(column).length,
    };
    final total = widget.items.length;

    final title = widget.castingTitle.isNotEmpty
        ? widget.castingTitle
        : (ru ? 'Отклики' : 'Responses');
    final summary = total == 0
        ? (ru ? 'Откликов пока нет' : 'No responses yet')
        : [
            ru ? 'Откликов: $total' : 'Responses: $total',
            '${ru ? 'шортлист' : 'shortlist'} ${counts[CastingResponseStatus.shortlist] ?? 0}',
            '${ru ? 'утверждены' : 'approved'} ${counts[CastingResponseStatus.approved] ?? 0}',
          ].join(' · ');

    Widget scopeMenu({
      required String label,
      required IconData icon,
      required bool enabled,
      required Future<void> Function(_PdfExportScope scope) onSelected,
    }) {
      return PopupMenuButton<_PdfExportScope>(
        enabled: enabled,
        tooltip: label,
        position: PopupMenuPosition.under,
        color: Tokens.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          side: const BorderSide(color: Tokens.border),
        ),
        onSelected: onSelected,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _PdfExportScope.all,
            child: Text(ru ? 'Все отклики' : 'All responses'),
          ),
          PopupMenuItem(
            value: _PdfExportScope.shortlist,
            child: Text(ru ? 'Только шортлист' : 'Shortlist only'),
          ),
          PopupMenuItem(
            value: _PdfExportScope.approved,
            child: Text(ru ? 'Только утверждённые' : 'Approved only'),
          ),
        ],
        child: IgnorePointer(
          child: OutlinedButton.icon(
            onPressed: enabled ? () {} : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: Icon(icon, size: 18),
            label: Text(label),
          ),
        ),
      );
    }

    // The admin shell draws the title row; these are its actions.
    final headerActions = <Widget>[
      IconButton(
        tooltip: ru ? 'Обновить' : 'Refresh',
        onPressed: widget.onRefresh,
        style: IconButton.styleFrom(foregroundColor: Tokens.textSecondary),
        icon: const Icon(Icons.refresh_rounded, size: 20),
      ),
      scopeMenu(
        label: 'PDF',
        icon: Icons.picture_as_pdf_outlined,
        enabled: widget.hasExportItems,
        onSelected: widget.onPdf,
      ),
      scopeMenu(
        label: ru ? 'Таблица' : 'Table',
        icon: Icons.table_chart_outlined,
        enabled: total > 0,
        onSelected: widget.onCsv,
      ),
    ];

    final bulkBar = _selected.isEmpty
        ? const SizedBox.shrink()
        : Container(
            margin: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            decoration: BoxDecoration(
              color: Tokens.ink,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    ru
                        ? 'Выбрано: ${_selected.length}'
                        : 'Selected: ${_selected.length}',
                    style: AppText.smallStrong.copyWith(color: Colors.white),
                  ),
                ),
                for (var i = 0; i < columns.length; i++)
                  TextButton(
                    onPressed: () => _bulkMove(columns[i].status),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('→ ${_sentenceCaseResponses(columns[i].title)}'),
                        if (wide) ...[
                          const SizedBox(width: 6),
                          _KeyHint('${i + 1}', onDark: true),
                        ],
                      ],
                    ),
                  ),
                if (wide)
                  TextButton(
                    onPressed: _canCompare ? _compareSelected : null,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      minimumSize: const Size(0, 34),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _canCompare
                              ? (ru ? 'Сравнить' : 'Compare')
                              : (ru ? 'Сравнить (2–4)' : 'Compare (2–4)'),
                        ),
                        if (_canCompare) ...[
                          const SizedBox(width: 6),
                          const _KeyHint('C', onDark: true),
                        ],
                      ],
                    ),
                  ),
                TextButton(
                  onPressed: _removeSelected,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8A8A),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(ru ? 'Убрать' : 'Remove'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(ru ? 'Сбросить' : 'Clear'),
                ),
              ],
            ),
          );

    Widget columnFor(_BoardColumnSpec spec, {required bool showHeader}) {
      final rows = _itemsFor(spec);
      return _BoardColumnV2(
        spec: spec,
        rows: rows,
        castingId: widget.castingId,
        showHeader: showHeader,
        gutter: wide ? 24 : gutter,
        selected: _selected,
        onToggle: _toggle,
        onMove: _moveOne,
        onNote: _editNote,
        onHover: wide ? _setHovered : null,
        keyHint: wide ? '${columns.indexOf(spec) + 1}' : null,
        allColumns: columns,
        t: t,
      );
    }

    final Widget board;
    if (total == 0) {
      board = Padding(
        padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ru ? 'Откликов пока нет' : 'No responses yet',
              style: AppText.h2.copyWith(color: Tokens.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              ru
                  ? 'Когда модели откликнутся на кастинг, они появятся здесь.'
                  : 'When models respond to the casting, they will show up here.',
              style: AppText.small.copyWith(color: Tokens.textTertiary),
            ),
          ],
        ),
      );
    } else if (wide) {
      board = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Tokens.border,
                ),
              Expanded(child: columnFor(columns[i], showHeader: true)),
            ],
          ],
        ),
      );
    } else {
      final active = columns.firstWhere(
        (e) => e.status == _narrowStatus,
        orElse: () => columns.first,
      );
      board = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Row(
              children: [
                for (final column in columns)
                  _StatusTabV2(
                    label: _sentenceCaseResponses(column.title),
                    count: counts[column.status] ?? 0,
                    active: column.status == active.status,
                    onTap: () => setState(() => _narrowStatus = column.status),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          columnFor(active, showHeader: false),
        ],
      );
    }

    final history = widget.history.maybeWhen(
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, 32, gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (ru ? 'История' : 'History').toUpperCase(),
                style: AppText.label.copyWith(color: Tokens.textTertiary),
              ),
              const SizedBox(height: 8),
              for (final row in rows.take(10)) _HistoryRowV2(row: row),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );

    return AdminShellV2(
      title: title,
      subtitle: summary,
      onBack: widget.onBack,
      actions: headerActions,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          if (_selected.isNotEmpty) ...[bulkBar, const SizedBox(height: 20)],
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          board,
          history,
        ],
      ),
    );
  }
}

class _StatusTabV2 extends StatelessWidget {
  const _StatusTabV2({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 14, 16, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? Tokens.ink : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.smallStrong.copyWith(
                color: active ? Tokens.text : Tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: AppText.caption.copyWith(color: Tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardColumnV2 extends StatelessWidget {
  const _BoardColumnV2({
    required this.spec,
    required this.rows,
    required this.castingId,
    required this.showHeader,
    required this.gutter,
    required this.selected,
    required this.onToggle,
    required this.onMove,
    required this.onNote,
    required this.allColumns,
    required this.t,
    this.onHover,
    this.keyHint,
  });

  final _BoardColumnSpec spec;
  final List<Map<String, dynamic>> rows;
  final String castingId;
  final bool showHeader;
  final double gutter;
  final Set<String> selected;
  final void Function(String profileId, bool selected) onToggle;
  final Future<void> Function(String profileId, CastingResponseStatus status)
  onMove;
  final Future<void> Function(Map<String, dynamic> row) onNote;
  final List<_BoardColumnSpec> allColumns;
  final AppLocalizations t;

  /// Step 38: hover tracking for the 1/2/3 keys and the key shown in the
  /// column header.
  final void Function(String profileId, bool hovered)? onHover;
  final String? keyHint;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return DragTarget<_BoardDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.status != spec.status &&
          details.data.profileId.isNotEmpty,
      onAcceptWithDetails: (details) =>
          onMove(details.data.profileId, spec.status),
      builder: (context, candidate, _) {
        final highlighted = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: Tokens.fast,
          color: highlighted ? Tokens.surface : Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 10),
                  child: Row(
                    children: [
                      Text(
                        _sentenceCaseResponses(spec.title),
                        style: AppText.smallStrong.copyWith(fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${rows.length}',
                        style: AppText.caption.copyWith(
                          color: Tokens.textTertiary,
                        ),
                      ),
                      if (keyHint != null) ...[
                        const Spacer(),
                        Tooltip(
                          message: ru
                              ? 'Клавиша $keyHint — переместить сюда выбранные или анкету под курсором'
                              : 'Key $keyHint moves the selected (or hovered) profile here',
                          child: _KeyHint(keyHint!),
                        ),
                      ],
                    ],
                  ),
                ),
              if (rows.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
                  child: Text(
                    ru ? 'Пусто' : 'Empty',
                    style: AppText.small.copyWith(color: Tokens.textTertiary),
                  ),
                )
              else
                for (final row in rows)
                  _ResponseRowV2(
                    row: row,
                    castingId: castingId,
                    currentStatus: spec.status,
                    allColumns: allColumns,
                    gutter: gutter,
                    selected: selected,
                    onToggle: onToggle,
                    onMove: onMove,
                    onNote: onNote,
                    onHover: onHover,
                    t: t,
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Step 38: a small keyboard-key label.
class _KeyHint extends StatelessWidget {
  const _KeyHint(this.label, {this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: onDark ? Colors.white38 : Tokens.borderStrong,
        ),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: onDark ? Colors.white70 : Tokens.textSecondary,
        ),
      ),
    );
  }
}

class _ResponseRowV2 extends StatefulWidget {
  const _ResponseRowV2({
    required this.row,
    required this.castingId,
    required this.currentStatus,
    required this.allColumns,
    required this.gutter,
    required this.selected,
    required this.onToggle,
    required this.onMove,
    required this.onNote,
    required this.t,
    this.onHover,
  });

  final Map<String, dynamic> row;
  final String castingId;
  final CastingResponseStatus currentStatus;
  final List<_BoardColumnSpec> allColumns;
  final double gutter;
  final Set<String> selected;
  final void Function(String profileId, bool selected) onToggle;
  final Future<void> Function(String profileId, CastingResponseStatus status)
  onMove;
  final Future<void> Function(Map<String, dynamic> row) onNote;
  final AppLocalizations t;
  final void Function(String profileId, bool hovered)? onHover;

  @override
  State<_ResponseRowV2> createState() => _ResponseRowV2State();
}

class _ResponseRowV2State extends State<_ResponseRowV2> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final profile = Map<String, dynamic>.from(
      (widget.row['profile'] as Map?) ?? {},
    );
    final profileId = (profile['id'] ?? '').toString();
    final name = (profile['full_name'] ?? '').toString().trim();
    final city = (profile['city'] ?? '').toString().trim();
    final age = ModelVm.displayAgeFromMap(profile);
    final height = int.tryParse((profile['height'] ?? '').toString()) ?? 0;
    final meta = [
      if (age > 0) (ru ? '$age лет' : '$age y.o.'),
      if (height > 0) '$height ${ru ? 'см' : 'cm'}',
      if (city.isNotEmpty) city,
    ].join(' · ');
    final photoUrlsRaw = profile['photo_urls'];
    final photoUrls = photoUrlsRaw is List
        ? photoUrlsRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final coverUrl = (profile['cover_photo_url'] ?? '').toString().trim();
    final thumbUrl = coverUrl.isNotEmpty
        ? coverUrl
        : (photoUrls.isNotEmpty ? photoUrls.first : '');
    double focal(dynamic v, double fallback) =>
        v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? fallback);
    final focalX = focal(profile['cover_photo_focal_x'], 0);
    final focalY = focal(profile['cover_photo_focal_y'], -0.72);
    final note = (widget.row['admin_note'] ?? '').toString().trim();
    final isSelected = widget.selected.contains(profileId);

    final rowWidget = MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHover?.call(profileId, true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
        widget.onHover?.call(profileId, false);
      },
      child: Material(
        color: isSelected
            ? Tokens.surfaceAlt
            : (_hovered ? Tokens.surface : Colors.transparent),
        child: InkWell(
          onTap: profileId.isEmpty
              ? null
              : () => context.go(
                  '${Routes.modelPrefix}$profileId?from=casting&castingId=${widget.castingId}',
                ),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: profileId.isEmpty
                        ? null
                        : (value) => widget.onToggle(profileId, value ?? false),
                    activeColor: Tokens.ink,
                    checkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: thumbUrl.isEmpty
                        ? const ColoredBox(
                            color: Tokens.surfaceAlt,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: Tokens.textTertiary,
                              size: 20,
                            ),
                          )
                        : FocalImage(
                            url: storageImageVariant(thumbUrl, width: 240),
                            focalX: focalX,
                            focalY: focalY,
                            memCacheWidth: 240,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? t.profileUpper : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Tokens.text,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: Tokens.textSecondary,
                          ),
                        ),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 13,
                              color: Tokens.accent,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(
                                  color: Tokens.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  duration: Tokens.fast,
                  opacity: _hovered || isSelected ? 1 : 0,
                  child: IconButton(
                    tooltip: note.isEmpty
                        ? (ru ? 'Заметка' : 'Note')
                        : (ru ? 'Изменить заметку' : 'Edit note'),
                    onPressed: profileId.isEmpty
                        ? null
                        : () => widget.onNote(widget.row),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: Tokens.textSecondary,
                    ),
                    icon: Icon(
                      note.isEmpty
                          ? Icons.sticky_note_2_outlined
                          : Icons.sticky_note_2_rounded,
                      size: 18,
                    ),
                  ),
                ),
                PopupMenuButton<CastingResponseStatus>(
                  tooltip: ru ? 'Переместить' : 'Move',
                  position: PopupMenuPosition.under,
                  color: Tokens.bg,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    side: const BorderSide(color: Tokens.border),
                  ),
                  enabled: profileId.isNotEmpty,
                  onSelected: (status) => widget.onMove(profileId, status),
                  itemBuilder: (context) => [
                    for (final column in widget.allColumns)
                      if (column.status != widget.currentStatus)
                        PopupMenuItem(
                          value: column.status,
                          child: Text(
                            '→ ${_sentenceCaseResponses(column.title)}',
                          ),
                        ),
                  ],
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: Tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (profileId.isEmpty) return rowWidget;

    final data = _BoardDragData(
      profileId: profileId,
      status: widget.currentStatus,
    );
    final feedback = Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: Tokens.border),
          boxShadow: Tokens.popoverShadow,
        ),
        child: Text(
          name.isEmpty ? t.profileUpper : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.smallStrong,
        ),
      ),
    );
    return Draggable<_BoardDragData>(
      data: data,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.4, child: rowWidget),
      child: rowWidget,
    );
  }
}

class _HistoryRowV2 extends StatelessWidget {
  const _HistoryRowV2({required this.row});

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
    final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());
    String when = '';
    if (createdAt != null) {
      final local = createdAt.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      when =
          '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              when,
              style: AppText.caption.copyWith(color: Tokens.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              '${name.isEmpty ? t.profileUpper : name}: '
              '${_sentenceCaseResponses(castingResponseStatusLabel(t, oldStatus))} → '
              '${_sentenceCaseResponses(castingResponseStatusLabel(t, newStatus))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.small.copyWith(color: Tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 38: 2–4 responses side by side — cover, name, parameters, note and
/// the current column, with a quick move for each.
class _CompareDialog extends StatefulWidget {
  const _CompareDialog({
    required this.rows,
    required this.columns,
    required this.castingId,
    required this.onMove,
  });

  final List<Map<String, dynamic>> rows;
  final List<_BoardColumnSpec> columns;
  final String castingId;
  final Future<void> Function(String profileId, CastingResponseStatus status)
  onMove;

  @override
  State<_CompareDialog> createState() => _CompareDialogState();
}

class _CompareDialogState extends State<_CompareDialog> {
  late final Map<String, String> _status = {
    for (final row in widget.rows)
      _profileId(row): (row['status'] ?? '').toString(),
  };
  String? _busyId;

  static String _profileId(Map<String, dynamic> row) {
    final profile = (row['profile'] as Map?) ?? const {};
    return (profile['id'] ?? '').toString();
  }

  Future<void> _move(String profileId, CastingResponseStatus status) async {
    if (_busyId != null) return;
    setState(() => _busyId = profileId);
    try {
      await widget.onMove(profileId, status);
      if (!mounted) return;
      setState(
        () => _status[profileId] = castingResponseStatusToString(status),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final t = AppLocalizations.of(context)!;
    final count = widget.rows.length;
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = (count * 260 + 48).toDouble().clamp(560.0, width - 48);

    String text(Map<String, dynamic> p, String key) =>
        (p[key] ?? '').toString().trim();
    int intOf(Map<String, dynamic> p, String key) =>
        int.tryParse((p[key] ?? '').toString()) ?? 0;

    final labels = <String>[
      ru ? 'Возраст' : 'Age',
      ru ? 'Рост' : 'Height',
      ru ? 'Параметры' : 'Measurements',
      ru ? 'Обувь' : 'Shoes',
      ru ? 'Глаза' : 'Eyes',
      ru ? 'Волосы' : 'Hair',
      ru ? 'Город' : 'City',
      ru ? 'Ставка' : 'Rate',
      ru ? 'Заметка' : 'Note',
    ];

    List<String> values(Map<String, dynamic> row) {
      final p = Map<String, dynamic>.from((row['profile'] as Map?) ?? {});
      final age = ModelVm.displayAgeFromMap(p);
      final height = intOf(p, 'height');
      final bust = intOf(p, 'bust');
      final waist = intOf(p, 'waist');
      final hips = intOf(p, 'hips');
      final shoe = intOf(p, 'shoe_size');
      final hourly = intOf(p, 'min_hourly_rate');
      final daily = intOf(p, 'min_daily_fee');
      final city = [
        text(p, 'city'),
        text(p, 'country'),
      ].where((e) => e.isNotEmpty).join(', ');
      return [
        age > 0 ? (ru ? '$age лет' : '$age y.o.') : '—',
        height > 0 ? '$height ${ru ? 'см' : 'cm'}' : '—',
        bust > 0 || waist > 0 || hips > 0
            ? '${bust > 0 ? bust : '–'} / ${waist > 0 ? waist : '–'} / ${hips > 0 ? hips : '–'}'
            : '—',
        shoe > 0 ? '$shoe' : '—',
        text(p, 'eye_color').isEmpty ? '—' : text(p, 'eye_color'),
        text(p, 'hair_color').isEmpty ? '—' : text(p, 'hair_color'),
        city.isEmpty ? '—' : city,
        hourly > 0 || daily > 0
            ? [
                if (hourly > 0) '$hourly ₽/${ru ? 'ч' : 'h'}',
                if (daily > 0) '$daily ₽/${ru ? 'день' : 'day'}',
              ].join(' · ')
            : '—',
        (row['admin_note'] ?? '').toString().trim().isEmpty
            ? '—'
            : (row['admin_note'] ?? '').toString().trim(),
      ];
    }

    Widget column(Map<String, dynamic> row) {
      final p = Map<String, dynamic>.from((row['profile'] as Map?) ?? {});
      final id = _profileId(row);
      final name = text(p, 'full_name');
      final photoUrlsRaw = p['photo_urls'];
      final photoUrls = photoUrlsRaw is List
          ? photoUrlsRaw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      final cover = text(p, 'cover_photo_url').isNotEmpty
          ? text(p, 'cover_photo_url')
          : (photoUrls.isNotEmpty ? photoUrls.first : '');
      double focal(dynamic v, double fallback) => v is num
          ? v.toDouble()
          : (double.tryParse('${v ?? ''}') ?? fallback);
      final currentColumn = widget.columns.firstWhere(
        (c) => c.matches(_status[id]),
        orElse: () => widget.columns.first,
      );
      final rowValues = values(row);
      final busy = _busyId == id;

      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: cover.isEmpty
                    ? const ColoredBox(
                        color: Tokens.surfaceAlt,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Tokens.textTertiary,
                          size: 40,
                        ),
                      )
                    : FocalImage(
                        url: storageImageVariant(cover, width: 600),
                        focalX: focal(p['cover_photo_focal_x'], 0),
                        focalY: focal(p['cover_photo_focal_y'], -0.72),
                        memCacheWidth: 600,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: id.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      context.go(
                        '${Routes.modelPrefix}$id?from=casting&castingId=${widget.castingId}',
                      );
                    },
              child: Text(
                name.isEmpty ? t.profileUpper : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.smallStrong.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _sentenceCaseResponses(currentColumn.title),
              style: AppText.caption.copyWith(
                color: currentColumn.status == CastingResponseStatus.approved
                    ? Tokens.success
                    : Tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < labels.length; i++) ...[
              Text(labels[i], style: AppText.caption),
              const SizedBox(height: 1),
              Text(
                rowValues[i],
                maxLines: i == labels.length - 1 ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(
                  color: rowValues[i] == '—' ? Tokens.textTertiary : Tokens.text,
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in widget.columns)
                  if (c.status != currentColumn.status)
                    OutlinedButton(
                      onPressed: busy || id.isEmpty
                          ? null
                          : () => _move(id, c.status),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: AppText.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text('→ ${_sentenceCaseResponses(c.title)}'),
                    ),
              ],
            ),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        side: const BorderSide(color: Tokens.border),
      ),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ru ? 'Сравнение · $count' : 'Compare · $count',
                      style: AppText.h2.copyWith(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: ru ? 'Закрыть' : 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < widget.rows.length; i++) ...[
                      if (i > 0) const SizedBox(width: 20),
                      column(widget.rows[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
