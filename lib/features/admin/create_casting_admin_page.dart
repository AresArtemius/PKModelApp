import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../core/admin_action_log_service.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../castings/castings_provider.dart';
import '../castings/casting_project_stage.dart';
import '../castings/casting_reference_media.dart';
import 'selection_providers.dart';
import 'admin_style.dart';

class CreateCastingAdminPage extends ConsumerStatefulWidget {
  const CreateCastingAdminPage({super.key});

  @override
  ConsumerState<CreateCastingAdminPage> createState() =>
      _CreateCastingAdminPageState();
}

class _CreateCastingAdminPageState
    extends ConsumerState<CreateCastingAdminPage> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _rightsC = TextEditingController();
  final _feeC = TextEditingController();

  final _selectedDates = <DateTime>{};
  final _pendingReferences = <PendingCastingReferenceMedia>[];
  CastingProjectStage _stage = defaultCastingProjectStage;
  bool _creating = false;
  bool _pickingReferences = false;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _rightsC.dispose();
    _feeC.dispose();
    super.dispose();
  }

  Future<void> _createCasting() async {
    if (_creating || _pickingReferences) return;
    final sb = ref.read(supabaseProvider);

    final title = _titleC.text.trim();
    final desc = _descC.text.trim();
    final rights = _rightsC.text.trim();
    final fee = _feeC.text.trim();

    // Минимальная валидация без лишнего UI: не создаём пустое
    if (title.isEmpty) return;

    setState(() => _creating = true);

    try {
      final dates = _selectedDates.toList()..sort((a, b) => a.compareTo(b));
      final userId = sb.auth.currentUser?.id.trim() ?? '';
      final referenceMedia = await uploadCastingReferenceMedia(
        supabase: sb,
        ownerId: userId,
        items: _pendingReferences,
      );

      // ВАЖНО: тут предполагается таблица "castings".
      // Поля можно подстроить под твою схему.
      final payload = {
        'title': title,
        'description': desc,
        'rights': rights,
        'fee': fee,
        'project_stage': castingProjectStageToString(_stage),
        'reference_media': referenceMedia.map((item) => item.toJson()).toList(),
        // храню как список ISO-дат (YYYY-MM-DD)
        'dates': dates.map((d) => _dateOnly(d).toIso8601String()).toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await sb.from('castings').insert(payload);
      } on PostgrestException catch (e) {
        if (!SupabaseCompat.isMissingAnyColumn(e, [
          'project_stage',
          'reference_media',
        ])) {
          rethrow;
        }
        final legacyPayload = Map<String, dynamic>.from(payload)
          ..remove('project_stage')
          ..remove('reference_media');
        await sb.from('castings').insert(legacyPayload);
      }
      await AdminActionLogService(sb).log(
        actionType: 'casting_created',
        title: 'Кастинг создан',
        description: desc,
        targetTable: 'castings',
        targetText: title,
        status: 'created',
      );
      ref
        ..invalidate(castingsProvider)
        ..invalidate(myCastingResponseStatusesProvider)
        ..invalidate(actionableCastingsCountProvider)
        ..invalidate(adminSelectionListProvider)
        ..invalidate(adminSelectionCountProvider);

      if (!mounted) return;
      context.go(_returnRoute(context));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось создать кастинг: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickReferences() async {
    if (_creating || _pickingReferences) return;
    setState(() => _pickingReferences = true);
    try {
      final picked = await pickCastingReferenceMedia();
      if (!mounted || picked.isEmpty) return;
      setState(() => _pendingReferences.addAll(picked));
    } finally {
      if (mounted) setState(() => _pickingReferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: BrandTheme.greyMid,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              BrandAdminHeader(
                title: t.adminCreateCastingUpper,
                onBack: () => context.go(_returnRoute(context)),
                sideWidth: 172,
                trailing: TextButton(
                  onPressed: _creating ? null : _createCasting,
                  style: TextButton.styleFrom(
                    foregroundColor: BrandTheme.redTop,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Localizations.localeOf(context).languageCode == 'ru'
                                ? 'ОПУБЛИКОВАТЬ'
                                : 'PUBLISH',
                            maxLines: 1,
                            style: BrandTheme.pillText.copyWith(
                              color: BrandTheme.redTop,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _CardPill(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle(t.castingTitle),
                        _TextField(controller: _titleC),
                        const SizedBox(height: 12),

                        _SectionTitle(t.projectDescription),
                        _TextField(controller: _descC, maxLines: 4),
                        const SizedBox(height: 12),

                        _SectionTitle(t.rights),
                        _TextField(controller: _rightsC, maxLines: 3),
                        const SizedBox(height: 12),

                        _SectionTitle(t.fee),
                        _TextField(controller: _feeC),
                        const SizedBox(height: 12),

                        _SectionTitle(
                          Localizations.localeOf(context).languageCode == 'ru'
                              ? 'РЕФЕРЕНСЫ'
                              : 'REFERENCES',
                        ),
                        _ReferencesPicker(
                          items: _pendingReferences,
                          picking: _pickingReferences,
                          onPick: _pickReferences,
                          onMove: (from, to) {
                            setState(() {
                              final item = _pendingReferences.removeAt(from);
                              _pendingReferences.insert(to, item);
                            });
                          },
                          onRemove: (index) {
                            setState(() => _pendingReferences.removeAt(index));
                          },
                        ),
                        const SizedBox(height: 12),

                        _SectionTitle(t.dates),
                        _MultiMonthCalendar(
                          initialSelected: _selectedDates,
                          onToggle: (d) {
                            setState(() {
                              final dd = _dateOnly(d);
                              if (_selectedDates.contains(dd)) {
                                _selectedDates.remove(dd);
                              } else {
                                _selectedDates.add(dd);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        _SectionTitle(
                          Localizations.localeOf(context).languageCode == 'ru'
                              ? 'ЭТАП ПРОЕКТА'
                              : 'PROJECT STAGE',
                        ),
                        _StageSelector(
                          value: _stage,
                          onChanged: (stage) => setState(() => _stage = stage),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _returnRoute(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    return from == 'admin' ? Routes.admin : Routes.castings;
  }
}

class _ReferencesPicker extends StatelessWidget {
  const _ReferencesPicker({
    required this.items,
    required this.picking,
    required this.onPick,
    required this.onMove,
    required this.onRemove,
  });

  final List<PendingCastingReferenceMedia> items;
  final bool picking;
  final VoidCallback onPick;
  final void Function(int from, int to) onMove;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: BrandTheme.pillHeight,
          child: OutlinedButton.icon(
            onPressed: picking ? null : onPick,
            style: castingDialogOutlinedButtonStyle(),
            icon: Icon(
              picking ? Icons.hourglass_top_rounded : Icons.attach_file_rounded,
              size: 18,
            ),
            label: Text(
              picking
                  ? (isRu ? 'ВЫБОР...' : 'PICKING...')
                  : (isRu ? 'ДОБАВИТЬ ФАЙЛЫ' : 'ADD FILES'),
              style: adminCommandStyle(size: 12, letterSpacing: 0.9),
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            _ReferenceDraftTile(
              item: items[i],
              canMoveUp: i > 0,
              canMoveDown: i < items.length - 1,
              onMoveUp: () => onMove(i, i - 1),
              onMoveDown: () => onMove(i, i + 1),
              onRemove: () => onRemove(i),
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ReferenceDraftTile extends StatelessWidget {
  const _ReferenceDraftTile({
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final PendingCastingReferenceMedia item;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final icon = switch (item.kind) {
      CastingReferenceMediaKind.image => Icons.image_rounded,
      CastingReferenceMediaKind.video => Icons.videocam_rounded,
      CastingReferenceMediaKind.file => Icons.insert_drive_file_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: BrandTheme.redTop, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminBodyStyle(
                    size: 13,
                    color: kTextDark,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    castingReferenceMediaKindLabel(item.kind, isRu: isRu),
                    formatCastingReferenceSize(item.sizeBytes),
                  ].where((part) => part.trim().isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminBodyStyle(
                    size: 11,
                    color: kTextMuted,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.arrow_upward_rounded),
            color: BrandTheme.redTop,
            visualDensity: VisualDensity.compact,
            tooltip: isRu ? 'Выше' : 'Move up',
          ),
          IconButton(
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.arrow_downward_rounded),
            color: BrandTheme.redTop,
            visualDensity: VisualDensity.compact,
            tooltip: isRu ? 'Ниже' : 'Move down',
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: kTextMuted,
            visualDensity: VisualDensity.compact,
            tooltip: isRu ? 'Удалить' : 'Remove',
          ),
        ],
      ),
    );
  }
}

class _StageSelector extends StatelessWidget {
  const _StageSelector({required this.value, required this.onChanged});

  final CastingProjectStage value;
  final ValueChanged<CastingProjectStage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final stage in CastingProjectStage.values)
          ChoiceChip(
            selected: value == stage,
            label: Text(castingProjectStageLabel(context, stage).toUpperCase()),
            avatar: Icon(
              castingProjectStageIcon(stage),
              size: 17,
              color: value == stage ? Colors.white : kTextDark,
            ),
            selectedColor: castingProjectStageColor(stage),
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            labelStyle: adminCommandStyle(
              size: 11,
              letterSpacing: 0.7,
              color: value == stage ? Colors.white : kTextDark,
            ),
            onSelected: (_) => onChanged(stage),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: adminCommandStyle(size: 14, letterSpacing: 1.0)),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, this.maxLines = 1});

  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: adminBodyStyle(
        size: 15,
        color: kTextDark,
        weight: FontWeight.w600,
      ),
      decoration: pillInputDecoration(
        hint: '',
        focusColor: BrandTheme.redTop,
        focusWidth: 1.2,
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
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: child,
    );
  }
}

/// Календарь по образцу из catalog_page, но с мультивыбором.
class _MultiMonthCalendar extends StatefulWidget {
  const _MultiMonthCalendar({
    required this.onToggle,
    this.initialSelected = const {},
  });

  final void Function(DateTime d) onToggle;
  final Set<DateTime> initialSelected;

  @override
  State<_MultiMonthCalendar> createState() => _MultiMonthCalendarState();
}

class _MultiMonthCalendarState extends State<_MultiMonthCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = _dateOnly(DateTime.now());
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final weekdays = [
      t.weekdayMonUpper,
      t.weekdayTueUpper,
      t.weekdayWedUpper,
      t.weekdayThuUpper,
      t.weekdayFriUpper,
      t.weekdaySatUpper,
      t.weekdaySunUpper,
    ];

    final now = _dateOnly(DateTime.now());
    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final firstWeekday = (first.weekday + 6) % 7; // monday=0

    final cells = <Widget>[];
    for (final w in weekdays) {
      cells.add(
        Center(
          child: Text(
            w,
            style: adminCommandStyle(
              size: 11,
              letterSpacing: 0.8,
              color: kTextMid,
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final d = _dateOnly(DateTime(first.year, first.month, day));
      final disabled = d.isBefore(now);
      final selected = widget.initialSelected.contains(d);

      cells.add(
        _DowCell(
          day: day,
          disabled: disabled,
          selected: selected,
          onTap: disabled ? null : () => widget.onToggle(d),
        ),
      );
    }

    final currentMonth = DateTime(now.year, now.month, 1);
    final canGoPrev = _month.isAfter(currentMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: canGoPrev
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1, 1),
                    )
                  : null,
              child: Opacity(
                opacity: canGoPrev ? 1 : 0.25,
                child: const Icon(
                  Icons.chevron_left_rounded,
                  size: 28,
                  color: kTextDark,
                ),
              ),
            ),
            Expanded(
              child: Text(
                _ruMonth(_month, t),
                textAlign: TextAlign.center,
                style: adminCommandStyle(
                  size: 15,
                  letterSpacing: 1.0,
                  color: kTextDark,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1, 1),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 28,
                color: kTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: cells,
        ),
      ],
    );
  }
}

class _DowCell extends StatelessWidget {
  const _DowCell({
    required this.day,
    required this.disabled,
    required this.selected,
    this.onTap,
  });
  final int day;
  final bool disabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? BrandTheme.redTop
        : Colors.white.withValues(alpha: kWhiteOpacity92);
    final fg = selected ? Colors.white : (disabled ? kDisabledText : kTextDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kCalendarDayRadius),
          border: Border.all(color: kBorderColor, width: 1),
        ),
        child: Text(
          '$day',
          style: adminCommandStyle(size: 13, color: fg, letterSpacing: 0.4),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _ruMonth(DateTime m, AppLocalizations t) {
  final months = [
    t.monthJanuaryUpper,
    t.monthFebruaryUpper,
    t.monthMarchUpper,
    t.monthAprilUpper,
    t.monthMayUpper,
    t.monthJuneUpper,
    t.monthJulyUpper,
    t.monthAugustUpper,
    t.monthSeptemberUpper,
    t.monthOctoberUpper,
    t.monthNovemberUpper,
    t.monthDecemberUpper,
  ];
  return '${months[m.month - 1]} ${m.year}';
}
