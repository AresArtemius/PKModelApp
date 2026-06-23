import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import 'brand_theme.dart';
import 'ui_constants.dart';

enum BrandCalendarSelectionMode { single, multiple }

class BrandCalendar extends StatefulWidget {
  const BrandCalendar({
    super.key,
    required this.selectionMode,
    this.selectedDate,
    this.selectedDates = const <DateTime>{},
    this.onDateSelected,
    this.onDateToggled,
    this.allowPastDates = false,
    this.allowPreviousMonths = false,
    this.initialMonth,
    this.titleBuilder,
  });

  final BrandCalendarSelectionMode selectionMode;

  final DateTime? selectedDate;
  final Set<DateTime> selectedDates;

  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<DateTime>? onDateToggled;

  final bool allowPastDates;
  final bool allowPreviousMonths;
  final DateTime? initialMonth;

  final String Function(DateTime month, AppLocalizations t)? titleBuilder;

  @override
  State<BrandCalendar> createState() => _BrandCalendarState();
}

class _BrandCalendarState extends State<BrandCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();

    final now = _dateOnly(DateTime.now());
    final selectedSingle = widget.selectedDate != null
        ? _dateOnly(widget.selectedDate!)
        : null;

    final selectedMulti = widget.selectedDates.isNotEmpty
        ? _dateOnly(widget.selectedDates.first)
        : null;

    final base = widget.initialMonth != null
        ? _dateOnly(widget.initialMonth!)
        : selectedSingle ?? selectedMulti ?? now;

    _month = DateTime(base.year, base.month, 1);
  }

  @override
  void didUpdateWidget(covariant BrandCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentMonthStart = DateTime(_month.year, _month.month, 1);

    if (widget.selectionMode == BrandCalendarSelectionMode.single) {
      final newSelected = widget.selectedDate != null
          ? _dateOnly(widget.selectedDate!)
          : null;
      if (newSelected != null && !_sameMonth(currentMonthStart, newSelected)) {
        _month = DateTime(newSelected.year, newSelected.month, 1);
      }
    }
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
    final firstWeekday = (first.weekday + 6) % 7;

    final currentMonth = DateTime(now.year, now.month, 1);
    final canGoPrev = widget.allowPreviousMonths
        ? true
        : _month.isAfter(currentMonth);

    final cells = <Widget>[];

    for (final w in weekdays) {
      cells.add(
        Center(
          child: Text(
            w,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
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
      final disabled = !widget.allowPastDates && d.isBefore(now);
      final selected = _isSelected(d);

      cells.add(
        _BrandCalendarCell(
          day: day,
          disabled: disabled,
          selected: selected,
          onTap: disabled
              ? null
              : () {
                  switch (widget.selectionMode) {
                    case BrandCalendarSelectionMode.single:
                      widget.onDateSelected?.call(d);
                      break;
                    case BrandCalendarSelectionMode.multiple:
                      widget.onDateToggled?.call(d);
                      break;
                  }
                },
        ),
      );
    }

    final title =
        widget.titleBuilder?.call(_month, t) ?? _defaultMonthTitle(_month, t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(kPillRadius),
                onTap: canGoPrev
                    ? () => setState(() {
                        _month = DateTime(_month.year, _month.month - 1, 1);
                      })
                    : null,
                child: Opacity(
                  opacity: canGoPrev ? 1 : 0.25,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: kIconSizeChevron,
                      color: kTextDark,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: kTextDark,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(kPillRadius),
                onTap: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1, 1);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: kIconSizeChevron,
                    color: kTextDark,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: kGap10),
        GridView.count(
          crossAxisCount: kCalendarCols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: kCalendarGap,
          crossAxisSpacing: kCalendarGap,
          children: cells,
        ),
      ],
    );
  }

  bool _isSelected(DateTime d) {
    switch (widget.selectionMode) {
      case BrandCalendarSelectionMode.single:
        final selected = widget.selectedDate != null
            ? _dateOnly(widget.selectedDate!)
            : null;
        return selected != null && selected == d;
      case BrandCalendarSelectionMode.multiple:
        return widget.selectedDates.map(_dateOnly).contains(d);
    }
  }
}

class _BrandCalendarCell extends StatelessWidget {
  const _BrandCalendarCell({
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCalendarDayRadius),
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
            style: TextStyle(fontWeight: FontWeight.w900, color: fg),
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

String _defaultMonthTitle(DateTime m, AppLocalizations t) {
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
