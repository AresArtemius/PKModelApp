import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class SelectionDraft {
  const SelectionDraft({
    required this.title,
    required this.requestVideoIntro,
    required this.videoIntroRequirements,
    this.clientName = '',
    this.brandName = '',
    this.budget = '',
    this.location = '',
    this.projectDates = '',
    this.projectRoles = '',
  });

  final String title;
  final bool requestVideoIntro;
  final String videoIntroRequirements;
  final String clientName;
  final String brandName;
  final String budget;
  final String location;
  final String projectDates;
  final String projectRoles;
}

class CreateSelectionDialog extends StatefulWidget {
  const CreateSelectionDialog({super.key});

  @override
  State<CreateSelectionDialog> createState() => _CreateSelectionDialogState();
}

class _CreateSelectionDialogState extends State<CreateSelectionDialog> {
  late final TextEditingController _titleC;
  late final TextEditingController _clientC;
  late final TextEditingController _brandC;
  late final TextEditingController _budgetC;
  late final TextEditingController _locationC;
  late final TextEditingController _datesC;
  late final TextEditingController _rolesC;
  late final TextEditingController _videoRequirementsC;
  bool _requestVideoIntro = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController();
    _clientC = TextEditingController();
    _brandC = TextEditingController();
    _budgetC = TextEditingController();
    _locationC = TextEditingController();
    _datesC = TextEditingController();
    _rolesC = TextEditingController();
    _videoRequirementsC = TextEditingController();
  }

  @override
  void dispose() {
    _titleC.dispose();
    _clientC.dispose();
    _brandC.dispose();
    _budgetC.dispose();
    _locationC.dispose();
    _datesC.dispose();
    _rolesC.dispose();
    _videoRequirementsC.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _titleC.text.trim();
    final t = AppLocalizations.of(context)!;
    if (value.isEmpty) {
      setState(() {
        _errorText = t.enterProjectTitleError;
      });
      return;
    }

    Navigator.of(context).pop(
      SelectionDraft(
        title: value,
        clientName: _clientC.text.trim(),
        brandName: _brandC.text.trim(),
        budget: _budgetC.text.trim(),
        location: _locationC.text.trim(),
        projectDates: _datesC.text.trim(),
        projectRoles: _rolesC.text.trim(),
        requestVideoIntro: _requestVideoIntro,
        videoIntroRequirements: _requestVideoIntro
            ? _videoRequirementsC.text.trim()
            : '',
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.projectTitleUpper,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: kTextDark,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: kGap14),
              TextField(
                controller: _titleC,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() {
                      _errorText = null;
                    });
                  }
                },
                style: const TextStyle(color: kTextDark),
                decoration: pillInputDecoration(
                  hint: t.enterProjectTitleHint,
                ).copyWith(errorText: _errorText),
              ),
              const SizedBox(height: kGap12),
              TextField(
                controller: _clientC,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: kTextDark),
                decoration: pillInputDecoration(hint: t.projectClientHint),
              ),
              const SizedBox(height: kGap12),
              TextField(
                controller: _brandC,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: kTextDark),
                decoration: pillInputDecoration(hint: t.projectBrandHint),
              ),
              const SizedBox(height: kGap12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _budgetC,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: kTextDark),
                      decoration: pillInputDecoration(
                        hint: t.projectBudgetHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: kGap10),
                  Expanded(
                    child: TextField(
                      controller: _locationC,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: kTextDark),
                      decoration: pillInputDecoration(
                        hint: t.projectLocationHint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kGap12),
              TextField(
                controller: _datesC,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: kTextDark),
                decoration: pillInputDecoration(hint: t.projectDatesHint),
              ),
              const SizedBox(height: kGap12),
              TextField(
                controller: _rolesC,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: kTextDark),
                decoration: pillInputDecoration(hint: t.projectRolesHint),
              ),
              const SizedBox(height: kGap12),
              _VideoIntroToggle(
                value: _requestVideoIntro,
                onChanged: (value) {
                  setState(() => _requestVideoIntro = value);
                },
              ),
              AnimatedSwitcher(
                duration: kAnim180,
                child: !_requestVideoIntro
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: kGap12),
                        child: TextField(
                          controller: _videoRequirementsC,
                          minLines: 2,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(color: kTextDark),
                          decoration: pillInputDecoration(
                            hint: t.videoIntroRequirementsHint,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: kGap14),
              Row(
                children: [
                  Expanded(
                    child: _SelectionDialogButton(
                      label: t.cancelUpper,
                      isDark: false,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: kDialogActionsGap),
                  Expanded(
                    child: _SelectionDialogButton(
                      label: t.saveUpper,
                      isDark: true,
                      onTap: _submit,
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
}

class _VideoIntroToggle extends StatelessWidget {
  const _VideoIntroToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pillDecoration(
            isDark: false,
            radius: kSearchRadius,
          ).copyWith(border: Border.all(color: kBorderColor)),
          child: Row(
            children: [
              Icon(
                value
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: value ? BrandTheme.redTop : kTextMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.requestVideoIntro,
                  style: const TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
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

class _SelectionDialogButton extends StatelessWidget {
  const _SelectionDialogButton({
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
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: onTap,
        child: Container(
          height: kTopBarH,
          alignment: Alignment.center,
          decoration: pillDecoration(isDark: isDark, radius: kSearchRadius),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: isDark ? Colors.white : kTextDark,
            ),
          ),
        ),
      ),
    );
  }
}
