import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class PhoneCountryCode {
  const PhoneCountryCode({
    required this.iso,
    required this.name,
    required this.code,
  });

  final String iso;
  final String name;
  final String code;

  String get shortLabel => '$iso $code';
  String get fullLabel => '$name $code';
}

const phoneCountryCodes = [
  PhoneCountryCode(iso: 'RU', name: 'Russia', code: '+7'),
  PhoneCountryCode(iso: 'US', name: 'United States', code: '+1'),
  PhoneCountryCode(iso: 'CA', name: 'Canada', code: '+1'),
  PhoneCountryCode(iso: 'GB', name: 'United Kingdom', code: '+44'),
  PhoneCountryCode(iso: 'DE', name: 'Germany', code: '+49'),
  PhoneCountryCode(iso: 'FR', name: 'France', code: '+33'),
  PhoneCountryCode(iso: 'IT', name: 'Italy', code: '+39'),
  PhoneCountryCode(iso: 'ES', name: 'Spain', code: '+34'),
  PhoneCountryCode(iso: 'AE', name: 'United Arab Emirates', code: '+971'),
  PhoneCountryCode(iso: 'TR', name: 'Turkey', code: '+90'),
  PhoneCountryCode(iso: 'PL', name: 'Poland', code: '+48'),
  PhoneCountryCode(iso: 'GE', name: 'Georgia', code: '+995'),
  PhoneCountryCode(iso: 'AM', name: 'Armenia', code: '+374'),
  PhoneCountryCode(iso: 'UA', name: 'Ukraine', code: '+380'),
  PhoneCountryCode(iso: 'BY', name: 'Belarus', code: '+375'),
  PhoneCountryCode(iso: 'IL', name: 'Israel', code: '+972'),
  PhoneCountryCode(iso: 'KZ', name: 'Kazakhstan', code: '+7'),
  PhoneCountryCode(iso: 'KG', name: 'Kyrgyzstan', code: '+996'),
  PhoneCountryCode(iso: 'UZ', name: 'Uzbekistan', code: '+998'),
  PhoneCountryCode(iso: 'AZ', name: 'Azerbaijan', code: '+994'),
  PhoneCountryCode(iso: 'MD', name: 'Moldova', code: '+373'),
  PhoneCountryCode(iso: 'LT', name: 'Lithuania', code: '+370'),
  PhoneCountryCode(iso: 'LV', name: 'Latvia', code: '+371'),
  PhoneCountryCode(iso: 'EE', name: 'Estonia', code: '+372'),
  PhoneCountryCode(iso: 'FI', name: 'Finland', code: '+358'),
  PhoneCountryCode(iso: 'SE', name: 'Sweden', code: '+46'),
  PhoneCountryCode(iso: 'NO', name: 'Norway', code: '+47'),
  PhoneCountryCode(iso: 'DK', name: 'Denmark', code: '+45'),
  PhoneCountryCode(iso: 'NL', name: 'Netherlands', code: '+31'),
  PhoneCountryCode(iso: 'BE', name: 'Belgium', code: '+32'),
  PhoneCountryCode(iso: 'CH', name: 'Switzerland', code: '+41'),
  PhoneCountryCode(iso: 'AT', name: 'Austria', code: '+43'),
  PhoneCountryCode(iso: 'CZ', name: 'Czechia', code: '+420'),
  PhoneCountryCode(iso: 'SK', name: 'Slovakia', code: '+421'),
  PhoneCountryCode(iso: 'HU', name: 'Hungary', code: '+36'),
  PhoneCountryCode(iso: 'RO', name: 'Romania', code: '+40'),
  PhoneCountryCode(iso: 'BG', name: 'Bulgaria', code: '+359'),
  PhoneCountryCode(iso: 'GR', name: 'Greece', code: '+30'),
  PhoneCountryCode(iso: 'CY', name: 'Cyprus', code: '+357'),
  PhoneCountryCode(iso: 'RS', name: 'Serbia', code: '+381'),
  PhoneCountryCode(iso: 'ME', name: 'Montenegro', code: '+382'),
  PhoneCountryCode(iso: 'HR', name: 'Croatia', code: '+385'),
  PhoneCountryCode(iso: 'SI', name: 'Slovenia', code: '+386'),
  PhoneCountryCode(iso: 'PT', name: 'Portugal', code: '+351'),
  PhoneCountryCode(iso: 'IE', name: 'Ireland', code: '+353'),
  PhoneCountryCode(iso: 'IN', name: 'India', code: '+91'),
  PhoneCountryCode(iso: 'CN', name: 'China', code: '+86'),
  PhoneCountryCode(iso: 'JP', name: 'Japan', code: '+81'),
  PhoneCountryCode(iso: 'KR', name: 'South Korea', code: '+82'),
  PhoneCountryCode(iso: 'TH', name: 'Thailand', code: '+66'),
  PhoneCountryCode(iso: 'ID', name: 'Indonesia', code: '+62'),
  PhoneCountryCode(iso: 'VN', name: 'Vietnam', code: '+84'),
  PhoneCountryCode(iso: 'PH', name: 'Philippines', code: '+63'),
  PhoneCountryCode(iso: 'AU', name: 'Australia', code: '+61'),
  PhoneCountryCode(iso: 'NZ', name: 'New Zealand', code: '+64'),
  PhoneCountryCode(iso: 'BR', name: 'Brazil', code: '+55'),
  PhoneCountryCode(iso: 'MX', name: 'Mexico', code: '+52'),
  PhoneCountryCode(iso: 'AR', name: 'Argentina', code: '+54'),
  PhoneCountryCode(iso: 'ZA', name: 'South Africa', code: '+27'),
  PhoneCountryCode(iso: 'EG', name: 'Egypt', code: '+20'),
  PhoneCountryCode(iso: 'MA', name: 'Morocco', code: '+212'),
];

String composeInternationalPhone({
  required String code,
  required String number,
}) {
  final cleanCode = code.trim();
  final cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanNumber.isEmpty) return '';
  return '$cleanCode$cleanNumber';
}

PhoneCountryCode phoneCountryCodeForIso(String iso) {
  final normalized = iso.trim().toUpperCase();
  return phoneCountryCodes.firstWhere(
    (item) => item.iso == normalized,
    orElse: () => phoneCountryCodes.first,
  );
}

class AuthPhoneNumberField extends StatelessWidget {
  const AuthPhoneNumberField({
    super.key,
    required this.controller,
    required this.countryIso,
    required this.onCountryIsoChanged,
    required this.enabled,
    required this.phoneLabel,
    required this.codeLabel,
  });

  final TextEditingController controller;
  final String countryIso;
  final ValueChanged<String> onCountryIsoChanged;
  final bool enabled;
  final String phoneLabel;
  final String codeLabel;

  PhoneCountryCode _selectedCountry() {
    return phoneCountryCodeForIso(countryIso);
  }

  Future<void> _showCountryPicker(BuildContext context) async {
    if (!enabled) return;
    final selectedIso = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) =>
          _PhoneCountryPickerSheet(selectedIso: countryIso, title: codeLabel),
    );
    if (selectedIso == null || selectedIso == countryIso) return;
    onCountryIsoChanged(selectedIso);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCountry();

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: phoneLabel,
        hintText: '9990000000',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.86),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: BrandTheme.redTop, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: kTextMuted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: BrandTheme.redTop,
          fontWeight: FontWeight.w700,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 120,
          maxWidth: 132,
          minHeight: 56,
        ),
        prefixIcon: _CountryCodePrefix(
          label: selected.shortLabel,
          enabled: enabled,
          onTap: () => _showCountryPicker(context),
        ),
      ),
    );
  }
}

class _CountryCodePrefix extends StatelessWidget {
  const _CountryCodePrefix({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? kTextDark.withValues(alpha: 0.92)
        : kTextMuted.withValues(alpha: 0.70);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: color.withValues(alpha: 0.82),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 28,
                color: kBorderColor.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneCountryPickerSheet extends StatefulWidget {
  const _PhoneCountryPickerSheet({
    required this.selectedIso,
    required this.title,
  });

  final String selectedIso;
  final String title;

  @override
  State<_PhoneCountryPickerSheet> createState() =>
      _PhoneCountryPickerSheetState();
}

class _PhoneCountryPickerSheetState extends State<_PhoneCountryPickerSheet> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  List<PhoneCountryCode> _filteredCountries() {
    final q = _searchC.text.trim().toLowerCase();
    if (q.isEmpty) return phoneCountryCodes;
    return phoneCountryCodes
        .where((item) {
          return item.iso.toLowerCase().contains(q) ||
              item.name.toLowerCase().contains(q) ||
              item.code.replaceAll('+', '').contains(q.replaceAll('+', '')) ||
              item.code.contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredCountries();
    return FractionallySizedBox(
      heightFactor: 0.62,
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kCardRadius),
          gradient: BrandTheme.lightPillGradient,
          border: Border.all(color: kBorderColor),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: kBorderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: kTextDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: kTextDark),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: TextField(
                controller: _searchC,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'RU, Russia, +7',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.86),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.black.withValues(alpha: 0.10),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.black.withValues(alpha: 0.10),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: BrandTheme.redTop,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: kBorderColor,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = item.iso == widget.selectedIso;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    title: Text(
                      item.fullLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? BrandTheme.redTop : kTextDark,
                        fontSize: 16,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0,
                        height: 1.2,
                      ),
                    ),
                    subtitle: Text(
                      item.iso,
                      style: TextStyle(
                        color: kTextMuted,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: BrandTheme.redTop,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(item.iso),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
