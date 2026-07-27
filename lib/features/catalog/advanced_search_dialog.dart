import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/appearance_lookups.dart';
import '../../ui/brand/brand_calendar.dart';
import '../../ui/brand/location_lookups.dart';
import '../../ui/brand/searchable_choice_field.dart';
import '../../ui/brand/ui_constants.dart';
import '../../ui/brand/brand_theme.dart';

class AdvancedSearchResult {
  const AdvancedSearchResult({
    required this.reset,
    this.ageFrom,
    this.ageTo,
    this.heightFrom,
    this.heightTo,
    this.shoeFrom,
    this.shoeTo,
    this.bustFrom,
    this.bustTo,
    this.waistFrom,
    this.waistTo,
    this.hipsFrom,
    this.hipsTo,
    this.minHourlyRateFrom,
    this.minHourlyRateTo,
    this.minDailyFeeFrom,
    this.minDailyFeeTo,
    this.eyeColor = '',
    this.hairColor = '',
    this.country = '',
    this.city = '',
    this.needDate,
  });

  final bool reset;
  final int? ageFrom;
  final int? ageTo;
  final int? heightFrom;
  final int? heightTo;
  final int? shoeFrom;
  final int? shoeTo;
  final int? bustFrom;
  final int? bustTo;
  final int? waistFrom;
  final int? waistTo;
  final int? hipsFrom;
  final int? hipsTo;
  final int? minHourlyRateFrom;
  final int? minHourlyRateTo;
  final int? minDailyFeeFrom;
  final int? minDailyFeeTo;
  final String eyeColor;
  final String hairColor;
  final String country;
  final String city;
  final DateTime? needDate;
}

class _RangeFilter {
  _RangeFilter({
    required this.min,
    required this.max,
    int? initialFrom,
    int? initialTo,
  }) : values = _buildInitialValues(
         min: min,
         max: max,
         initialFrom: initialFrom,
         initialTo: initialTo,
       );
  final int min;
  final int max;
  RangeValues values;

  static RangeValues _buildInitialValues({
    required int min,
    required int max,
    int? initialFrom,
    int? initialTo,
  }) {
    final start = (initialFrom ?? min).clamp(min, max).toDouble();
    final end = (initialTo ?? max).clamp(min, max).toDouble();
    return start <= end ? RangeValues(start, end) : RangeValues(end, start);
  }

  int? startOrNull() {
    final start = values.start.toInt();
    final end = values.end.toInt();
    if (start <= min && end >= max) return null;
    return start;
  }

  int? endOrNull() {
    final start = values.start.toInt();
    final end = values.end.toInt();
    if (start <= min && end >= max) return null;
    return end;
  }

  void set(RangeValues v) {
    final start = v.start.round().toDouble().clamp(
      min.toDouble(),
      max.toDouble(),
    );
    final end = v.end.round().toDouble().clamp(min.toDouble(), max.toDouble());

    if (start <= end) {
      values = RangeValues(start, end);
    } else {
      values = RangeValues(end, start);
    }
  }
}

class _RangeSectionConfig {
  const _RangeSectionConfig({
    required this.title,
    required this.filter,
    required this.onChanged,
  });

  final String title;
  final _RangeFilter filter;
  final ValueChanged<RangeValues> onChanged;
}

class AdvancedSearchDialog extends StatefulWidget {
  const AdvancedSearchDialog({
    super.key,
    required this.ageMin,
    required this.ageMax,
    required this.heightMin,
    required this.heightMax,
    required this.shoeMin,
    required this.shoeMax,
    required this.bustMin,
    required this.bustMax,
    required this.waistMin,
    required this.waistMax,
    required this.hipsMin,
    required this.hipsMax,
    required this.minHourlyRateMin,
    required this.minHourlyRateMax,
    required this.minDailyFeeMin,
    required this.minDailyFeeMax,
    this.initialAgeFrom,
    this.initialAgeTo,
    this.initialHeightFrom,
    this.initialHeightTo,
    this.initialShoeFrom,
    this.initialShoeTo,
    this.initialBustFrom,
    this.initialBustTo,
    this.initialWaistFrom,
    this.initialWaistTo,
    this.initialHipsFrom,
    this.initialHipsTo,
    this.initialMinHourlyRateFrom,
    this.initialMinHourlyRateTo,
    this.initialMinDailyFeeFrom,
    this.initialMinDailyFeeTo,
    this.initialEyeColor = '',
    this.initialHairColor = '',
    this.initialCountry = '',
    this.initialCity = '',
    this.initialNeedDate,
  });

  final int ageMin;
  final int ageMax;
  final int heightMin;
  final int heightMax;
  final int shoeMin;
  final int shoeMax;
  final int bustMin;
  final int bustMax;
  final int waistMin;
  final int waistMax;
  final int hipsMin;
  final int hipsMax;
  final int minHourlyRateMin;
  final int minHourlyRateMax;
  final int minDailyFeeMin;
  final int minDailyFeeMax;

  final int? initialAgeFrom;
  final int? initialAgeTo;
  final int? initialHeightFrom;
  final int? initialHeightTo;
  final int? initialShoeFrom;
  final int? initialShoeTo;
  final int? initialBustFrom;
  final int? initialBustTo;
  final int? initialWaistFrom;
  final int? initialWaistTo;
  final int? initialHipsFrom;
  final int? initialHipsTo;
  final int? initialMinHourlyRateFrom;
  final int? initialMinHourlyRateTo;
  final int? initialMinDailyFeeFrom;
  final int? initialMinDailyFeeTo;

  final String initialEyeColor;
  final String initialHairColor;
  final String initialCountry;
  final String initialCity;
  final DateTime? initialNeedDate;

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  late _RangeFilter _age;
  late _RangeFilter _height;
  late _RangeFilter _shoe;
  late _RangeFilter _bust;
  late _RangeFilter _waist;
  late _RangeFilter _hips;

  late final TextEditingController _eyeC;
  late final TextEditingController _hairC;
  late final TextEditingController _countryC;
  late final TextEditingController _cityC;
  late final TextEditingController _hourlyFromC;
  late final TextEditingController _hourlyToC;
  late final TextEditingController _dailyFromC;
  late final TextEditingController _dailyToC;

  DateTime? _needDate;
  String? _validationMessage;

  _RangeFilter _range({
    required int min,
    required int max,
    int? from,
    int? to,
  }) {
    return _RangeFilter(min: min, max: max, initialFrom: from, initialTo: to);
  }

  @override
  void initState() {
    super.initState();

    _age = _range(
      min: widget.ageMin,
      max: widget.ageMax,
      from: widget.initialAgeFrom,
      to: widget.initialAgeTo,
    );

    _height = _range(
      min: widget.heightMin,
      max: widget.heightMax,
      from: widget.initialHeightFrom,
      to: widget.initialHeightTo,
    );

    _shoe = _range(
      min: widget.shoeMin,
      max: widget.shoeMax,
      from: widget.initialShoeFrom,
      to: widget.initialShoeTo,
    );

    _bust = _range(
      min: widget.bustMin,
      max: widget.bustMax,
      from: widget.initialBustFrom,
      to: widget.initialBustTo,
    );

    _waist = _range(
      min: widget.waistMin,
      max: widget.waistMax,
      from: widget.initialWaistFrom,
      to: widget.initialWaistTo,
    );

    _hips = _range(
      min: widget.hipsMin,
      max: widget.hipsMax,
      from: widget.initialHipsFrom,
      to: widget.initialHipsTo,
    );

    _eyeC = TextEditingController(text: widget.initialEyeColor);
    _hairC = TextEditingController(text: widget.initialHairColor);
    _countryC = TextEditingController(text: widget.initialCountry);
    _cityC = TextEditingController(text: widget.initialCity);
    _hourlyFromC = TextEditingController(
      text: widget.initialMinHourlyRateFrom?.toString() ?? '',
    );
    _hourlyToC = TextEditingController(
      text: widget.initialMinHourlyRateTo?.toString() ?? '',
    );
    _dailyFromC = TextEditingController(
      text: widget.initialMinDailyFeeFrom?.toString() ?? '',
    );
    _dailyToC = TextEditingController(
      text: widget.initialMinDailyFeeTo?.toString() ?? '',
    );
    _needDate = widget.initialNeedDate;
  }

  @override
  void dispose() {
    _eyeC.dispose();
    _hairC.dispose();
    _countryC.dispose();
    _cityC.dispose();
    _hourlyFromC.dispose();
    _hourlyToC.dispose();
    _dailyFromC.dispose();
    _dailyToC.dispose();
    super.dispose();
  }

  List<String> get _countryOptions =>
      countryOptions(AppLocalizations.of(context)!);
  List<String> get _cityOptions => cityOptionsForCountry(
    AppLocalizations.of(context)!,
    _countryC.text.trim(),
  );

  String _normalizeLookupValue(String value) => value.trim().toLowerCase();

  bool _containsNormalized(List<String> values, String target) {
    final normalizedTarget = _normalizeLookupValue(target);
    return values.any(
      (value) => _normalizeLookupValue(value) == normalizedTarget,
    );
  }

  String _matchAllowedOptionOrEmpty(List<String> options, String value) {
    final normalized = _normalizeLookupValue(value);
    if (normalized.isEmpty) return '';

    for (final option in options) {
      if (_normalizeLookupValue(option) == normalized) {
        return option;
      }
    }
    return '';
  }

  void _onCountryChanged(String value) {
    final normalized = value.trim();

    _countryC.text = normalized;

    final allowedCities = cityOptionsForCountry(
      AppLocalizations.of(context)!,
      normalized,
    );
    final currentCity = _cityC.text.trim();
    if (currentCity.isNotEmpty &&
        !_containsNormalized(allowedCities, currentCity)) {
      _cityC.clear();
    }

    setState(() {});
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  String _text(TextEditingController controller) => controller.text.trim();

  int? _optionalInt(TextEditingController controller) {
    final value = _text(controller);
    return value.isEmpty ? null : int.tryParse(value);
  }

  AdvancedSearchResult _buildResult() {
    final eyeColor = _matchAllowedOptionOrEmpty(eyeColorOptions, _text(_eyeC));
    final hairColor = _matchAllowedOptionOrEmpty(
      hairColorOptions,
      _text(_hairC),
    );
    final country = _matchAllowedOptionOrEmpty(
      _countryOptions,
      _text(_countryC),
    );
    final city = country.isEmpty
        ? ''
        : _matchAllowedOptionOrEmpty(
            cityOptionsForCountry(AppLocalizations.of(context)!, country),
            _text(_cityC),
          );

    return AdvancedSearchResult(
      reset: false,
      ageFrom: _age.startOrNull(),
      ageTo: _age.endOrNull(),
      heightFrom: _height.startOrNull(),
      heightTo: _height.endOrNull(),
      shoeFrom: _shoe.startOrNull(),
      shoeTo: _shoe.endOrNull(),
      bustFrom: _bust.startOrNull(),
      bustTo: _bust.endOrNull(),
      waistFrom: _waist.startOrNull(),
      waistTo: _waist.endOrNull(),
      hipsFrom: _hips.startOrNull(),
      hipsTo: _hips.endOrNull(),
      minHourlyRateFrom: _optionalInt(_hourlyFromC),
      minHourlyRateTo: _optionalInt(_hourlyToC),
      minDailyFeeFrom: _optionalInt(_dailyFromC),
      minDailyFeeTo: _optionalInt(_dailyToC),
      eyeColor: eyeColor,
      hairColor: hairColor,
      country: country,
      city: city,
      needDate: _needDate,
    );
  }

  void _resetAndClose() {
    _unfocus();
    Navigator.of(context).pop(const AdvancedSearchResult(reset: true));
  }

  void _applyAndClose() {
    _unfocus();
    final t = AppLocalizations.of(context)!;
    final invalidField = _firstInvalidLookupField(t);
    if (invalidField != null) {
      setState(() {
        _validationMessage = t.advancedChooseListedValue(invalidField);
      });
      return;
    }
    if (!_validFeeRange(_hourlyFromC, _hourlyToC) ||
        !_validFeeRange(_dailyFromC, _dailyToC)) {
      setState(() {
        _validationMessage = t.advancedInvalidFeeRange;
      });
      return;
    }
    Navigator.of(context).pop(_buildResult());
  }

  bool _validFeeRange(
    TextEditingController fromController,
    TextEditingController toController,
  ) {
    final from = _optionalInt(fromController);
    final to = _optionalInt(toController);
    return from == null || to == null || from <= to;
  }

  String? _firstInvalidLookupField(AppLocalizations t) {
    bool invalid(TextEditingController controller, List<String> options) {
      final value = _text(controller);
      return value.isNotEmpty && !_containsNormalized(options, value);
    }

    if (invalid(_eyeC, eyeColorOptions)) return t.eyeColor;
    if (invalid(_hairC, hairColorOptions)) return t.hairColor;
    if (invalid(_countryC, _countryOptions)) return t.country;
    if (invalid(_cityC, _cityOptions)) return t.city;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final hasValidCountry =
        _text(_countryC).isNotEmpty &&
        _containsNormalized(_countryOptions, _text(_countryC));

    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: kTextDark,
      inactiveTrackColor: Colors.black.withValues(alpha: 0.14),
      thumbColor: BrandTheme.redTop,
      overlayColor: BrandTheme.redTop.withValues(alpha: 0.14),
      rangeThumbShape: const RoundRangeSliderThumbShape(
        enabledThumbRadius: kRangeThumbRadius,
        elevation: 3,
        pressedElevation: 5,
      ),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      trackHeight: kSliderTrackH,
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
    );

    final rangeSections = <_RangeSectionConfig>[
      _RangeSectionConfig(
        title: t.age,
        filter: _age,
        onChanged: (v) => setState(() => _age.set(v)),
      ),
      _RangeSectionConfig(
        title: '${t.height} (${t.cm})',
        filter: _height,
        onChanged: (v) => setState(() => _height.set(v)),
      ),
      _RangeSectionConfig(
        title: t.shoeSize,
        filter: _shoe,
        onChanged: (v) => setState(() => _shoe.set(v)),
      ),
      _RangeSectionConfig(
        title: t.bust,
        filter: _bust,
        onChanged: (v) => setState(() => _bust.set(v)),
      ),
      _RangeSectionConfig(
        title: t.waist,
        filter: _waist,
        onChanged: (v) => setState(() => _waist.set(v)),
      ),
      _RangeSectionConfig(
        title: t.hips,
        filter: _hips,
        onChanged: (v) => setState(() => _hips.set(v)),
      ),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kDialogInsetPad,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: catalogDialogDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.advancedSearchUpper,
                textAlign: TextAlign.center,
                style: BrandTheme.pillText.copyWith(
                  fontSize: 17,
                  letterSpacing: 1.7,
                  color: kTextDark,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: kGap16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final section in rangeSections) ...[
                        _rangeSection(
                          title: section.title,
                          filter: section.filter,
                          sliderTheme: sliderTheme,
                          onChanged: section.onChanged,
                          labelBuilder: (v) =>
                              t.rangeFromTo(v.start.toInt(), v.end.toInt()),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _feeRangeSection(
                        title: t.advancedMinHourlyRateUpper,
                        fromController: _hourlyFromC,
                        toController: _hourlyToC,
                        fromHint: t.advancedFeeFrom(widget.minHourlyRateMin),
                        toHint: t.advancedFeeTo(widget.minHourlyRateMax),
                      ),
                      const SizedBox(height: 18),
                      _feeRangeSection(
                        title: t.advancedMinDailyFeeUpper,
                        fromController: _dailyFromC,
                        toController: _dailyToC,
                        fromHint: t.advancedFeeFrom(widget.minDailyFeeMin),
                        toHint: t.advancedFeeTo(widget.minDailyFeeMax),
                      ),
                      const SizedBox(height: 18),

                      _sectionTitle(t.eyeColor),
                      SearchableChoiceField(
                        controller: _eyeC,
                        options: eyeColorOptions,
                      ),
                      const SizedBox(height: kGap12),

                      _sectionTitle(t.hairColor),
                      SearchableChoiceField(
                        controller: _hairC,
                        options: hairColorOptions,
                      ),
                      const SizedBox(height: kGap12),

                      _sectionTitle(t.country),
                      SearchableChoiceField(
                        controller: _countryC,
                        options: _countryOptions,
                        onChanged: _onCountryChanged,
                      ),
                      const SizedBox(height: kGap12),

                      _sectionTitle(t.city),
                      SearchableChoiceField(
                        controller: _cityC,
                        options: _cityOptions,
                        enabled: hasValidCountry,
                      ),
                      const SizedBox(height: kGap12),

                      _sectionTitle(t.date),
                      BrandCalendar(
                        selectionMode: BrandCalendarSelectionMode.single,
                        selectedDate: _needDate,
                        allowPastDates: false,
                        allowPreviousMonths: false,
                        onDateSelected: (d) => setState(() => _needDate = d),
                      ),
                      if (_needDate != null) ...[
                        const SizedBox(height: kGap10),
                        _DialogPillButton(
                          label: t.advancedClearDateUpper,
                          isDark: false,
                          onTap: () => setState(() => _needDate = null),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: kGap16),
              if (_validationMessage != null) ...[
                Text(
                  _validationMessage!,
                  textAlign: TextAlign.center,
                  style: BrandTheme.pillText.copyWith(
                    fontSize: 12,
                    color: BrandTheme.redTop,
                  ),
                ),
                const SizedBox(height: kGap10),
              ],
              Row(
                children: [
                  Expanded(
                    child: _DialogPillButton(
                      label: t.resetUpper,
                      isDark: false,
                      onTap: _resetAndClose,
                    ),
                  ),
                  const SizedBox(width: kDialogActionsGap),
                  Expanded(
                    child: _DialogPillButton(
                      label: t.applyUpper,
                      isDark: true,
                      onTap: _applyAndClose,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: BrandTheme.pillText.copyWith(
        fontSize: 12,
        letterSpacing: 1.45,
        color: kTextMid,
        height: 1.1,
      ),
    );
  }

  Widget _rangeSection({
    required String title,
    required _RangeFilter filter,
    required SliderThemeData sliderTheme,
    required ValueChanged<RangeValues> onChanged,
    required String Function(RangeValues) labelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        const SizedBox(height: kGap6),
        _FilterValuePill(text: labelBuilder(filter.values)),
        const SizedBox(height: kGap10),
        Theme(
          data: Theme.of(context).copyWith(sliderTheme: sliderTheme),
          child: RangeSlider(
            values: filter.values,
            min: filter.min.toDouble(),
            max: filter.max.toDouble(),
            divisions: filter.max > filter.min ? filter.max - filter.min : null,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _feeRangeSection({
    required String title,
    required TextEditingController fromController,
    required TextEditingController toController,
    required String fromHint,
    required String toHint,
  }) {
    Widget field(TextEditingController controller, String hint) {
      return TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: pillInputDecoration(hint: hint),
        onChanged: (_) {
          if (_validationMessage != null) {
            setState(() => _validationMessage = null);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        const SizedBox(height: kGap6),
        Row(
          children: [
            Expanded(child: field(fromController, fromHint)),
            const SizedBox(width: kGap10),
            Expanded(child: field(toController, toHint)),
          ],
        ),
      ],
    );
  }
}

class _FilterValuePill extends StatelessWidget {
  const _FilterValuePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kFilterPillPad,
      decoration: catalogSearchDecoration(),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: BrandTheme.pillText.copyWith(
          fontSize: 14,
          letterSpacing: 0.9,
          color: kTextDark,
        ),
      ),
    );
  }
}

class _DialogPillButton extends StatelessWidget {
  const _DialogPillButton({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BrandTheme.pillRadius),
        onTap: onTap,
        child: Container(
          height: BrandTheme.pillHeight,
          alignment: Alignment.center,
          decoration: pillDecoration(
            isDark: isDark,
            radius: BrandTheme.pillRadius,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: BrandTheme.pillText.copyWith(
              fontSize: 15,
              letterSpacing: 1.45,
              color: isDark ? Colors.white : kTextDark,
            ),
          ),
        ),
      ),
    );
  }
}
