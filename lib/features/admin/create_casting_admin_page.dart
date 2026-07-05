import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_provider.dart';
import '../../core/admin_action_log_service.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
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

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _rightsC.dispose();
    _feeC.dispose();
    super.dispose();
  }

  Future<void> _createCasting() async {
    final sb = ref.read(supabaseProvider);

    final title = _titleC.text.trim();
    final desc = _descC.text.trim();
    final rights = _rightsC.text.trim();
    final fee = _feeC.text.trim();

    // Минимальная валидация без лишнего UI: не создаём пустое
    if (title.isEmpty) return;

    final dates = _selectedDates.toList()..sort((a, b) => a.compareTo(b));

    // ВАЖНО: тут предполагается таблица "castings".
    // Поля можно подстроить под твою схему.
    await sb.from('castings').insert({
      'title': title,
      'description': desc,
      'rights': rights,
      'fee': fee,
      // храню как список ISO-дат (YYYY-MM-DD)
      'dates': dates.map((d) => _dateOnly(d).toIso8601String()).toList(),
      'created_at': DateTime.now().toIso8601String(),
    });
    await AdminActionLogService(sb).log(
      actionType: 'casting_created',
      title: 'Кастинг создан',
      description: desc,
      targetTable: 'castings',
      targetText: title,
      status: 'created',
    );

    if (!mounted) return;
    context.go('/castings');
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
                onBack: () => context.go('/admin'),
                trailing: IconButton(
                  onPressed: _createCasting,
                  icon: const Icon(
                    Icons.check_rounded,
                    color: BrandTheme.redTop,
                  ),
                  splashRadius: 22,
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
