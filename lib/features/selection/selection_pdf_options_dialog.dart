import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'selection_pdf_options.dart';

const _text = kTextDark;

class SelectionPdfOptionsDialog extends StatefulWidget {
  const SelectionPdfOptionsDialog({super.key});

  @override
  State<SelectionPdfOptionsDialog> createState() =>
      _SelectionPdfOptionsDialogState();
}

class _SelectionPdfOptionsDialogState extends State<SelectionPdfOptionsDialog> {
  bool includePhoto = true;
  bool includeFullName = true;
  bool includeAge = true;
  bool includeHeight = true;
  bool includeCity = false;
  bool includeCountry = false;
  bool includeEyeColor = false;
  bool includeHairColor = false;
  bool includeMeasurements = false;
  bool includeShoeSize = false;
  bool includeHourlyRate = false;
  bool includeDailyFee = false;
  bool includeModelLink = false;

  void _submit() {
    Navigator.of(context).pop(
      SelectionPdfOptions(
        includePhoto: includePhoto,
        includeFullName: includeFullName,
        includeAge: includeAge,
        includeHeight: includeHeight,
        includeCity: includeCity,
        includeCountry: includeCountry,
        includeEyeColor: includeEyeColor,
        includeHairColor: includeHairColor,
        includeMeasurements: includeMeasurements,
        includeShoeSize: includeShoeSize,
        includeHourlyRate: includeHourlyRate,
        includeDailyFee: includeDailyFee,
        includeModelLink: includeModelLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kDialogInsetPad,
      child: Container(
        padding: kDialogBodyPad,
        decoration: pillDecoration(isDark: false, radius: kCardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PDF',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: _text,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _row(
                      t.pdfOptionPhoto,
                      includePhoto,
                      (v) => setState(() => includePhoto = v),
                    ),
                    _row(
                      t.pdfOptionFullName,
                      includeFullName,
                      (v) => setState(() => includeFullName = v),
                    ),
                    _row(
                      t.age,
                      includeAge,
                      (v) => setState(() => includeAge = v),
                    ),
                    _row(
                      t.height,
                      includeHeight,
                      (v) => setState(() => includeHeight = v),
                    ),
                    _row(
                      t.city,
                      includeCity,
                      (v) => setState(() => includeCity = v),
                    ),
                    _row(
                      t.country,
                      includeCountry,
                      (v) => setState(() => includeCountry = v),
                    ),
                    _row(
                      t.eyeColor,
                      includeEyeColor,
                      (v) => setState(() => includeEyeColor = v),
                    ),
                    _row(
                      t.hairColor,
                      includeHairColor,
                      (v) => setState(() => includeHairColor = v),
                    ),
                    _row(
                      t.pdfOptionMeasurements,
                      includeMeasurements,
                      (v) => setState(() => includeMeasurements = v),
                    ),
                    _row(
                      t.shoeSize,
                      includeShoeSize,
                      (v) => setState(() => includeShoeSize = v),
                    ),
                    _row(
                      t.advancedMinHourlyRateUpper,
                      includeHourlyRate,
                      (v) => setState(() => includeHourlyRate = v),
                    ),
                    _row(
                      t.advancedMinDailyFeeUpper,
                      includeDailyFee,
                      (v) => setState(() => includeDailyFee = v),
                    ),
                    _row(
                      t.pdfOptionModelLink,
                      includeModelLink,
                      (v) => setState(() => includeModelLink = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: t.cancelUpper,
                    isDark: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: t.applyUpper,
                    isDark: true,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      value: value,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: BrandTheme.redTop,
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _text),
      ),
      onChanged: (v) => onChanged(v ?? false),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isDark
                ? BrandTheme.darkPillGradient
                : BrandTheme.lightPillGradient,
            border: Border.all(color: kBorderColor, width: 1),
            boxShadow: BrandTheme.basePillShadow(isDark: isDark),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: isDark ? Colors.white : _text,
            ),
          ),
        ),
      ),
    );
  }
}
