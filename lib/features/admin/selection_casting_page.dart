import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../catalog/model_data.dart';
import '../castings/casting_response_status.dart';

const _bg = BrandTheme.greyMid;
const _text = kTextDark;

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

      const profileSelect = '''
        status,
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
        if (!msg.contains('status')) rethrow;
        rows = await run(profileSelect.replaceFirst('status,', ''));
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

      return {'items': items, 'exportItems': exportItems};
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

              Future<void> openPdf() async {
                final options = await showDialog<SelectionPdfOptions>(
                  context: context,
                  barrierDismissible: true,
                  builder: (_) => const SelectionPdfOptionsDialog(),
                );
                if (options == null) return;

                final service = SelectionPdfService();
                await service.previewSelectionPdf(
                  title: t.responsesUpper,
                  items: exportItems,
                  options: options,
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
                    trailing: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            ref.invalidate(castingResponsesProvider(castingId));
                          },
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: BrandTheme.redTop,
                          ),
                          splashRadius: 22,
                        ),
                        IconButton(
                          onPressed: exportItems.isEmpty ? null : openPdf,
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: BrandTheme.redTop,
                          ),
                          splashRadius: 22,
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

class _CastingShortlistBoard extends StatefulWidget {
  const _CastingShortlistBoard({
    required this.items,
    required this.castingId,
    required this.onStatusChanged,
    required this.onBulkStatusChanged,
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
  final AsyncValue<List<Map<String, dynamic>>> history;

  @override
  State<_CastingShortlistBoard> createState() => _CastingShortlistBoardState();
}

class _CastingShortlistBoardState extends State<_CastingShortlistBoard> {
  final Set<String> _selectedProfileIds = <String>{};

  List<_BoardColumnSpec> _columns(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return [
      _BoardColumnSpec(
        title: ru ? 'НОВЫЕ' : 'NEW',
        status: CastingResponseStatus.submitted,
        aliases: const {},
        icon: Icons.inbox_rounded,
      ),
      _BoardColumnSpec(
        title: ru ? 'ШОРТЛИСТ' : 'SHORTLIST',
        status: CastingResponseStatus.shortlist,
        aliases: const {CastingResponseStatus.viewed},
        icon: Icons.playlist_add_check_rounded,
      ),
      _BoardColumnSpec(
        title: ru ? 'CALLBACK' : 'CALLBACK',
        status: CastingResponseStatus.callback,
        aliases: const {CastingResponseStatus.invited},
        icon: Icons.record_voice_over_rounded,
      ),
      _BoardColumnSpec(
        title: ru ? 'APPROVED' : 'APPROVED',
        status: CastingResponseStatus.approved,
        aliases: const {},
        icon: Icons.verified_rounded,
      ),
      _BoardColumnSpec(
        title: ru ? 'РЕЗЕРВ' : 'RESERVE',
        status: CastingResponseStatus.reserve,
        aliases: const {},
        icon: Icons.bookmark_added_rounded,
      ),
      _BoardColumnSpec(
        title: ru ? 'ОТКАЗ' : 'REJECTED',
        status: CastingResponseStatus.rejected,
        aliases: const {},
        icon: Icons.block_rounded,
      ),
    ];
  }

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
    final columns = _columns(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final boardWidth = compact ? 1540.0 : constraints.maxWidth;
        final board = SizedBox(
          width: boardWidth,
          child: compact
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final column in columns) ...[
                      SizedBox(
                        width: 245,
                        child: _CastingBoardColumn(
                          spec: column,
                          items: _itemsFor(column.status),
                          castingId: widget.castingId,
                          selectedProfileIds: _selectedProfileIds,
                          onSelectionChanged: _toggleSelection,
                          onStatusChanged: _moveOne,
                          allStatuses: columns.map((e) => e.status).toList(),
                          t: t,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
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
                          allStatuses: columns.map((e) => e.status).toList(),
                          t: t,
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
              onClear: () => setState(_selectedProfileIds.clear),
              t: t,
            ),
            if (_selectedProfileIds.isNotEmpty) const SizedBox(height: 10),
            compact
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: board,
                  )
                : board,
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
    final spec = _columns(context).firstWhere((e) => e.status == status);
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

class _CastingBoardColumn extends StatelessWidget {
  const _CastingBoardColumn({
    required this.spec,
    required this.items,
    required this.castingId,
    required this.selectedProfileIds,
    required this.onSelectionChanged,
    required this.onStatusChanged,
    required this.allStatuses,
    required this.t,
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
  final List<CastingResponseStatus> allStatuses;
  final AppLocalizations t;

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
                          ? 'ПЕРЕТАЩИТЬ СЮДА'
                          : 'DROP HERE',
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
                      t: t,
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
    required this.onClear,
    required this.t,
  });

  final int selectedCount;
  final List<CastingResponseStatus> statuses;
  final Future<void> Function(CastingResponseStatus status) onMove;
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
    required this.t,
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
  final AppLocalizations t;

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
        padding: const EdgeInsets.all(10),
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
                  _SelectionProfileThumb(url: thumbUrl),
                  const SizedBox(width: 10),
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
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

class _StatusMoveChip extends StatelessWidget {
  const _StatusMoveChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.58),
          border: Border.all(color: kBorderColor),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _text,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SelectionProfileThumb extends StatelessWidget {
  const _SelectionProfileThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
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
