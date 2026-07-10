import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:modelapp/core/app_error_mapper.dart';
import 'package:modelapp/core/roles_provider.dart';
import 'package:modelapp/core/supabase_provider.dart';
import 'package:modelapp/core/router.dart';
import '../../ui/brand/ui_constants.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../gen_l10n/app_localizations.dart';
import '../legal/legal_consent_service.dart';
import '../legal/legal_documents.dart';
import 'auth_controller.dart';
import 'password_strength.dart';
import 'phone_number_field.dart';

const _legalRequiredMessage =
    'Примите документы и согласие на обработку данных, чтобы продолжить.';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _pass2C = TextEditingController();

  final _emailF = FocusNode();
  final _passF = FocusNode();
  final _pass2F = FocusNode();

  bool _loading = false;
  bool _hide1 = true;
  bool _hide2 = true;
  bool _isClient = false;
  bool _acceptedLegal = false;
  RegistrationAccountType _selectedClientType =
      RegistrationAccountType.castingDirector;
  String? _error;

  void _submitIfNotLoading() {
    if (_loading) return;
    _signUp();
  }

  void _goLoginOrPop() {
    if (_loading) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(Routes.login);
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _pass2C.dispose();
    _emailF.dispose();
    _passF.dispose();
    _pass2F.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations t) {
    final email = _emailC.text.trim();
    final p1 = _passC.text;
    final p2 = _pass2C.text;

    if (email.isEmpty) return t.enterEmail;
    if (!_emailRegex.hasMatch(email)) return t.invalidEmail;
    if (p1.isEmpty) return t.enterPassword;
    final passwordMessage = newPasswordValidationMessage(
      p1,
      isRussian: _isRussian,
      email: email,
    );
    if (passwordMessage != null) return passwordMessage;
    if (p2.isEmpty) return t.enterPassword;
    if (p1 != p2) return t.passwordsDontMatch;
    if (!_acceptedLegal) return _legalRequiredMessage;
    return null;
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    final t = AppLocalizations.of(context)!;
    final msg = _validate(t);
    if (msg != null) {
      setState(() => _error = msg);
      if (msg == t.enterEmail || msg == t.invalidEmail) {
        _emailF.requestFocus();
      } else if (msg == t.passwordsDontMatch) {
        _pass2F.requestFocus();
      } else if (msg != _legalRequiredMessage) {
        _passF.requestFocus();
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = ref.read(authControllerProvider);
      final supabase = ref.read(supabaseProvider);
      final email = _emailC.text.trim();
      final registrationType = _registrationAccountType;
      final res = await auth.signUp(
        email: _emailC.text.trim(),
        password: _passC.text,
        data: {
          'account_type': registrationType.storageValue,
          'requested_account_type': registrationType.storageValue,
          'role': AccountRole.user.storageValue,
          ...legalConsentMetadata(source: 'email_registration'),
        },
      );

      if (!auth.isEmailConfirmed(res.user)) {
        ref.read(pendingEmailConfirmationProvider.notifier).state =
            PendingEmailConfirmation(email: email, password: _passC.text);
        await supabase.auth.signOut();
        if (!mounted) return;
        context.go(
          '${Routes.emailVerification}?email=${Uri.encodeComponent(email)}',
        );
        return;
      }

      await _saveInitialRoleIfSessionAvailable(
        supabase,
        res.user?.id,
        registrationType,
      );
      await recordLegalConsentIfPossible(
        supabase,
        source: 'email_registration',
      );
      ref.read(pendingEmailConfirmationProvider.notifier).state = null;

      if (!mounted) return;
      context.go(Routes.accountProfile);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppErrorMapper.message(
          e,
          t,
          context: AppErrorContext.signUp,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppErrorMapper.message(
          e,
          t,
          context: AppErrorContext.signUp,
        ),
      );
    } finally {
      TextInput.finishAutofillContext(shouldSave: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPhoneSignUp() async {
    if (_loading) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _PhoneOtpDialog(),
    );
    if (!mounted || ok != true) return;
    context.go(Routes.accountProfile);
  }

  Future<void> _saveInitialRoleIfSessionAvailable(
    SupabaseClient supabase,
    String? userId,
    RegistrationAccountType registrationType,
  ) async {
    if (userId == null || supabase.auth.currentSession == null) return;

    try {
      await supabase.from('user_profiles').upsert({
        'user_id': userId,
        'email': _emailC.text.trim(),
        'account_type': AccountRole.user.storageValue,
      }, onConflict: 'user_id');
    } catch (_) {
      // The profile sync in main.dart will retry after the user signs in.
    }

    try {
      await supabase.from('user_roles').upsert({
        'user_id': userId,
        'role': AccountRole.user.storageValue,
      }, onConflict: 'user_id');
      ref.invalidate(accountRoleProvider);
      ref.invalidate(isAdminProvider);
      ref.invalidate(canCreateSelectionsProvider);
    } catch (_) {
      // SQL policies may not be applied yet. Metadata/profile fallback still works.
    }
  }

  RegistrationAccountType get _registrationAccountType {
    if (!_isClient) return RegistrationAccountType.user;
    return _selectedClientType;
  }

  bool get _isRussian {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
  }

  String get _clientToggleLabel {
    return _isRussian ? 'Я заказчик' : 'I am hiring talent';
  }

  String get _clientTypeLabel {
    return _isRussian ? 'Кто вы?' : 'Who are you?';
  }

  String _registrationTypeLabel(RegistrationAccountType type) {
    final ru = _isRussian;
    return switch (type) {
      RegistrationAccountType.user => ru ? 'Участник' : 'Talent account',
      RegistrationAccountType.castingDirector =>
        ru ? 'Кастинг-директор' : 'Casting director',
      RegistrationAccountType.castingAgent =>
        ru ? 'Кастинг-агент' : 'Casting agent',
      RegistrationAccountType.directorProducer =>
        ru ? 'Режиссер / продюсер' : 'Director / producer',
      RegistrationAccountType.brandClient =>
        ru ? 'Бренд / заказчик' : 'Brand / client',
      RegistrationAccountType.agency => ru ? 'Агентство' : 'Agency',
      RegistrationAccountType.productionAgency =>
        ru ? 'Продакшн / рекламное агентство' : 'Production / ad agency',
      RegistrationAccountType.photoVideo =>
        ru ? 'Фотограф / видеограф' : 'Photographer / videographer',
      RegistrationAccountType.scoutBooker =>
        ru ? 'Скаут / буккер' : 'Scout / booker',
    };
  }

  Widget _passwordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hidden,
    required VoidCallback toggleHidden,
    required String label,
    required String tooltipShow,
    required String tooltipHide,
    required TextInputAction action,
    required VoidCallback onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: hidden,
      style: const TextStyle(
        color: kTextDark,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      textInputAction: action,
      autofillHints: const [AutofillHints.newPassword],
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
      decoration: _registerFieldDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: toggleHidden,
          tooltip: hidden ? tooltipShow : tooltipHide,
          color: kTextDark.withValues(alpha: 0.82),
          icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Column(
              children: [
                _TopBarWithBack(title: t.registerTitle, onBack: _goLoginOrPop),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _loading,
                    child: ListView(
                      padding: kRegisterPagePad,
                      children: [
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(t.signUp, style: kRegisterTitleStyle),
                              const SizedBox(height: kRegisterGap6),
                              Text(
                                t.registerFillBelow,
                                style: kRegisterHintStyle,
                              ),
                              const SizedBox(height: kRegisterGap16),

                              if (_error != null) ...[
                                Text(
                                  _error!,
                                  style: const TextStyle(color: kTextDanger),
                                ),
                                const SizedBox(height: kRegisterGap12),
                              ],

                              TextField(
                                controller: _emailC,
                                focusNode: _emailF,
                                style: const TextStyle(
                                  color: kTextDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                                onSubmitted: (_) => _passF.requestFocus(),
                                decoration: _registerFieldDecoration(
                                  labelText: t.email,
                                ),
                              ),

                              const SizedBox(height: kRegisterGap12),

                              _passwordField(
                                controller: _passC,
                                focusNode: _passF,
                                hidden: _hide1,
                                toggleHidden: () =>
                                    setState(() => _hide1 = !_hide1),
                                label: t.password,
                                tooltipShow: t.showPassword,
                                tooltipHide: t.hidePassword,
                                action: TextInputAction.next,
                                onSubmitted: () => _pass2F.requestFocus(),
                                onChanged: (_) {
                                  setState(() => _error = null);
                                },
                              ),
                              const SizedBox(height: 10),
                              PasswordStrengthMeter(
                                password: _passC.text,
                                isRussian: _isRussian,
                                email: _emailC.text,
                              ),
                              const SizedBox(height: kRegisterGap12),

                              _passwordField(
                                controller: _pass2C,
                                focusNode: _pass2F,
                                hidden: _hide2,
                                toggleHidden: () =>
                                    setState(() => _hide2 = !_hide2),
                                label: t.passwordRepeat,
                                tooltipShow: t.showPassword,
                                tooltipHide: t.hidePassword,
                                action: TextInputAction.done,
                                onSubmitted: _submitIfNotLoading,
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                              ),

                              const SizedBox(height: kRegisterGap16),

                              _ClientRoleSelector(
                                isClient: _isClient,
                                selectedType: _selectedClientType,
                                toggleLabel: _clientToggleLabel,
                                typeLabel: _clientTypeLabel,
                                typeName: _registrationTypeLabel,
                                onClientChanged: (value) {
                                  setState(() {
                                    _isClient = value;
                                    _error = null;
                                  });
                                },
                                onTypeChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedClientType = value;
                                    _error = null;
                                  });
                                },
                              ),

                              const SizedBox(height: kRegisterGap16),

                              _LegalConsentBox(
                                accepted: _acceptedLegal,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptedLegal = value;
                                    if (_error == _legalRequiredMessage) {
                                      _error = null;
                                    }
                                  });
                                },
                              ),

                              const SizedBox(height: kRegisterGap16),

                              SizedBox(
                                width: double.infinity,
                                height: kRegisterButtonH,
                                child: BrandPillButton(
                                  label: _loading
                                      ? t.loadingDots
                                      : t.registerUpper,
                                  style: BrandPillStyle.dark,
                                  onTap: _submitIfNotLoading,
                                ),
                              ),

                              const SizedBox(height: kRegisterGap14),

                              _AuthDivider(text: t.continueWith),

                              const SizedBox(height: kRegisterGap12),

                              _AuthOptionButton(
                                label: t.continueSignUpWithPhone,
                                icon: Icons.phone_iphone_rounded,
                                onTap: _openPhoneSignUp,
                              ),

                              const SizedBox(height: kRegisterGap14),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    t.alreadyHaveAccount,
                                    style: _registerBodyText(
                                      color: kTextDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  BrandPillButton(
                                    label: t.signInUpper,
                                    style: BrandPillStyle.light,
                                    onTap: _goLoginOrPop,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientRoleSelector extends StatelessWidget {
  const _ClientRoleSelector({
    required this.isClient,
    required this.selectedType,
    required this.toggleLabel,
    required this.typeLabel,
    required this.typeName,
    required this.onClientChanged,
    required this.onTypeChanged,
  });

  static const _clientTypes = [
    RegistrationAccountType.castingDirector,
    RegistrationAccountType.castingAgent,
    RegistrationAccountType.directorProducer,
    RegistrationAccountType.brandClient,
    RegistrationAccountType.agency,
    RegistrationAccountType.productionAgency,
    RegistrationAccountType.photoVideo,
    RegistrationAccountType.scoutBooker,
  ];

  final bool isClient;
  final RegistrationAccountType selectedType;
  final String toggleLabel;
  final String typeLabel;
  final String Function(RegistrationAccountType type) typeName;
  final ValueChanged<bool> onClientChanged;
  final ValueChanged<RegistrationAccountType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFDFD), Color(0xFFF2F2F2)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.90),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  toggleLabel,
                  style: _registerBodyText(
                    color: kTextDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch.adaptive(
                value: isClient,
                activeThumbColor: BrandTheme.redTop,
                activeTrackColor: BrandTheme.redTop.withValues(alpha: 0.22),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.black.withValues(alpha: 0.08),
                onChanged: onClientChanged,
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: !isClient
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _ClientTypePickerField(
                      selectedType: selectedType,
                      typeLabel: typeLabel,
                      typeName: typeName,
                      clientTypes: _clientTypes,
                      onChanged: onTypeChanged,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClientTypePickerField extends StatelessWidget {
  const _ClientTypePickerField({
    required this.selectedType,
    required this.typeLabel,
    required this.typeName,
    required this.clientTypes,
    required this.onChanged,
  });

  final RegistrationAccountType selectedType;
  final String typeLabel;
  final String Function(RegistrationAccountType type) typeName;
  final List<RegistrationAccountType> clientTypes;
  final ValueChanged<RegistrationAccountType?> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<RegistrationAccountType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) => _ClientTypePickerSheet(
        title: typeLabel,
        selectedType: selectedType,
        typeName: typeName,
        clientTypes: clientTypes,
      ),
    );
    if (selected == null) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openPicker(context),
      child: InputDecorator(
        decoration: _registerFieldDecoration(labelText: typeLabel),
        child: Row(
          children: [
            Expanded(
              child: Text(
                typeName(selectedType),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _registerBodyText(
                  color: kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kTextDark.withValues(alpha: 0.76),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientTypePickerSheet extends StatelessWidget {
  const _ClientTypePickerSheet({
    required this.title,
    required this.selectedType,
    required this.typeName,
    required this.clientTypes,
  });

  final String title;
  final RegistrationAccountType selectedType;
  final String Function(RegistrationAccountType type) typeName;
  final List<RegistrationAccountType> clientTypes;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.58,
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kCardRadius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F1F1)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
          boxShadow: kRegisterCardShadow,
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
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: _registerBodyText(
                        color: kTextDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 10),
                itemCount: clientTypes.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: kBorderColor.withValues(alpha: 0.70),
                ),
                itemBuilder: (context, index) {
                  final type = clientTypes[index];
                  final selected = type == selectedType;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 3,
                    ),
                    title: Text(
                      typeName(type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _registerBodyText(
                        color: selected ? BrandTheme.redTop : kTextDark,
                        fontSize: 17,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: BrandTheme.redTop,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(type),
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

class _PhoneOtpDialog extends ConsumerStatefulWidget {
  const _PhoneOtpDialog();

  @override
  ConsumerState<_PhoneOtpDialog> createState() => _PhoneOtpDialogState();
}

class _PhoneOtpDialogState extends ConsumerState<_PhoneOtpDialog> {
  final _phoneC = TextEditingController();
  final _codeC = TextEditingController();
  final _passC = TextEditingController();
  final _pass2C = TextEditingController();
  String _phoneIso = 'RU';
  bool _codeSent = false;
  bool _loading = false;
  bool _hide1 = true;
  bool _hide2 = true;
  bool _acceptedLegal = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  String? _error;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneC.dispose();
    _codeC.dispose();
    _passC.dispose();
    _pass2C.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  String _normalizedPhone() => composeInternationalPhone(
    code: phoneCountryCodeForIso(_phoneIso).code,
    number: _phoneC.text,
  );

  Future<void> _sendCode() async {
    final t = AppLocalizations.of(context)!;
    final phone = _normalizedPhone();
    if (phone.isEmpty) {
      setState(() => _error = t.phoneInternationalHint);
      return;
    }
    if (_passC.text.isEmpty) {
      setState(() => _error = t.enterPassword);
      return;
    }
    final passwordMessage = newPasswordValidationMessage(
      _passC.text,
      isRussian: Localizations.localeOf(context).languageCode == 'ru',
      phone: phone,
    );
    if (passwordMessage != null) {
      setState(() => _error = passwordMessage);
      return;
    }
    if (_passC.text != _pass2C.text) {
      setState(() => _error = t.passwordsDontMatch);
      return;
    }
    if (!_acceptedLegal) {
      setState(() => _error = _legalRequiredMessage);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).sendPhoneOtp(phone: phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _codeC.clear();
      });
      _startResendTimer();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppErrorMapper.message(
          e,
          AppLocalizations.of(context)!,
          context: AppErrorContext.phoneSignIn,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = t.phoneOtpSendFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final t = AppLocalizations.of(context)!;
    final code = _codeC.text.trim();
    if (code.isEmpty) {
      setState(() => _error = t.phoneOtpEnterCode);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider)
          .verifyPhoneOtp(phone: _normalizedPhone(), token: code);
      await ref
          .read(authControllerProvider)
          .setCurrentUserPassword(password: _passC.text);
      await recordLegalConsentIfPossible(
        ref.read(supabaseProvider),
        source: 'phone_registration',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppErrorMapper.message(
          e,
          t,
          context: AppErrorContext.phoneSignIn,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = t.phoneOtpVerifyFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    return AlertDialog(
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      elevation: 18,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      title: Text(
        isRu ? 'Регистрация по телефону' : 'Phone sign-up',
        textAlign: TextAlign.center,
        style: kRegisterTitleStyle.copyWith(fontSize: 30, letterSpacing: 0.2),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextDanger,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
          ],
          AuthPhoneNumberField(
            controller: _phoneC,
            enabled: !_codeSent && !_loading,
            countryIso: _phoneIso,
            codeLabel: Localizations.localeOf(context).languageCode == 'ru'
                ? 'Код'
                : 'Code',
            phoneLabel: t.phoneNumber,
            onCountryIsoChanged: (value) => setState(() => _phoneIso = value),
          ),
          if (!_codeSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _passC,
              enabled: !_loading,
              obscureText: _hide1,
              style: const TextStyle(
                color: kTextDark,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _registerFieldDecoration(
                labelText: t.password,
                suffixIcon: IconButton(
                  tooltip: _hide1 ? t.showPassword : t.hidePassword,
                  onPressed: () => setState(() => _hide1 = !_hide1),
                  color: kTextDark.withValues(alpha: 0.82),
                  icon: Icon(_hide1 ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            PasswordStrengthMeter(
              password: _passC.text,
              isRussian: isRu,
              phone: _normalizedPhone(),
              compact: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass2C,
              enabled: !_loading,
              obscureText: _hide2,
              style: const TextStyle(
                color: kTextDark,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _loading ? null : _sendCode(),
              decoration: _registerFieldDecoration(
                labelText: t.passwordRepeat,
                suffixIcon: IconButton(
                  tooltip: _hide2 ? t.showPassword : t.hidePassword,
                  onPressed: () => setState(() => _hide2 = !_hide2),
                  color: kTextDark.withValues(alpha: 0.82),
                  icon: Icon(_hide2 ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _LegalConsentBox(
              accepted: _acceptedLegal,
              compact: true,
              onChanged: (value) {
                setState(() {
                  _acceptedLegal = value;
                  if (_error == _legalRequiredMessage) {
                    _error = null;
                  }
                });
              },
            ),
          ],
          if (_codeSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _codeC,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) => _loading ? null : _verifyCode(),
              style: const TextStyle(
                color: kTextDark,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              decoration: _registerFieldDecoration(labelText: t.phoneOtpCode),
            ),
          ],
        ],
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_codeSent) ...[
              _DialogInlineButton(
                label: _resendSeconds > 0
                    ? (isRu
                          ? 'ПОВТОРНО ЧЕРЕЗ $_resendSeconds'
                          : 'RESEND IN $_resendSeconds')
                    : (isRu ? 'ОТПРАВИТЬ ЕЩЁ' : 'SEND AGAIN'),
                style: BrandPillStyle.light,
                muted: _resendSeconds > 0,
                onTap: (_loading || _resendSeconds > 0) ? null : _sendCode,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: _DialogInlineButton(
                    label: t.cancel.toUpperCase(),
                    style: BrandPillStyle.light,
                    onTap: _loading
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogInlineButton(
                    label: _loading
                        ? t.loadingDots
                        : (_codeSent
                              ? (isRu ? 'ЗАВЕРШИТЬ' : 'FINISH')
                              : t.phoneOtpSend),
                    style: BrandPillStyle.dark,
                    onTap: _loading
                        ? null
                        : (_codeSent ? _verifyCode : _sendCode),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogInlineButton extends StatelessWidget {
  const _DialogInlineButton({
    required this.label,
    required this.style,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final BrandPillStyle style;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final isDark = style == BrandPillStyle.dark;
    final enabled = onTap != null && !muted;
    final textColor = muted
        ? kTextMuted
        : isDark
        ? Colors.white.withValues(alpha: 0.95)
        : kTextDark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.62,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandTheme.pillRadius),
            gradient: isDark
                ? BrandTheme.darkPillGradient
                : BrandTheme.lightPillGradient,
            border: isDark
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.10)),
            boxShadow: BrandTheme.basePillShadow(isDark: isDark),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: _registerCommandText(
                color: textColor,
                fontSize: 14,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== UI =====

class _LegalConsentBox extends StatelessWidget {
  const _LegalConsentBox({
    required this.accepted,
    required this.onChanged,
    this.compact = false,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(!accepted),
      child: Ink(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: BrandTheme.lightPillGradient,
          border: Border.all(
            color: accepted
                ? BrandTheme.redTop.withValues(alpha: 0.38)
                : Colors.black.withValues(alpha: 0.10),
          ),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: compact ? 28 : 32,
              height: compact ? 28 : 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: accepted
                    ? BrandTheme.darkPillGradient
                    : BrandTheme.lightPillGradient,
                border: Border.all(
                  color: accepted
                      ? Colors.transparent
                      : Colors.black.withValues(alpha: 0.16),
                ),
              ),
              child: accepted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 19,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRu
                        ? 'Я принимаю документы и согласие на обработку данных'
                        : 'I accept the documents and data processing consent',
                    style: _registerBodyText(
                      color: kTextDark,
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _LegalLink(
                        label: isRu ? 'Конфиденциальность' : 'Privacy',
                        route: legalDocumentByKind(
                          LegalDocumentKind.privacy,
                        ).route,
                      ),
                      _LegalLink(
                        label: isRu ? 'Условия' : 'Terms',
                        route: legalDocumentByKind(
                          LegalDocumentKind.terms,
                        ).route,
                      ),
                      _LegalLink(
                        label: 'Cookies',
                        route: legalDocumentByKind(
                          LegalDocumentKind.cookies,
                        ).route,
                      ),
                      _LegalLink(
                        label: isRu ? 'Обработка данных' : 'Processing',
                        route: legalDocumentByKind(
                          LegalDocumentKind.processingNotice,
                        ).route,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          label,
          style: _registerBodyText(
            color: BrandTheme.redTop,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: kBorderColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(text, style: _registerBodyText(color: kTextMuted)),
        ),
        const Expanded(child: Divider(color: kBorderColor)),
      ],
    );
  }
}

class _AuthOptionButton extends StatelessWidget {
  const _AuthOptionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kLoginButtonH,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kPillRadius),
            gradient: BrandTheme.lightPillGradient,
            border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
            boxShadow: BrandTheme.basePillShadow(isDark: false),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: kTextDark.withValues(alpha: 0.88), size: 21),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: _registerCommandText(
                      color: kTextDark,
                      fontSize: 15,
                      letterSpacing: 1.15,
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

class _TopBarWithBack extends StatelessWidget {
  const _TopBarWithBack({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kRegisterTopBarPad,
      child: Row(
        children: [
          _IconPill(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: kRegisterGap12),
          Expanded(
            child: Text(
              title,
              style: kRegisterTopBarTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(kBackPillRadius),
      onTap: onTap,
      child: Ink(
        padding: kBackPillPad,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
          ),
          borderRadius: BorderRadius.circular(kBackPillRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
          boxShadow: kBackPillShadow,
        ),
        child: Icon(icon, size: kBackIconSize, color: kTextDark),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kRegisterCardPad,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: kRegisterCardWhiteOpacity),
            const Color(0xFFF6F6F6).withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        boxShadow: kRegisterCardShadow,
      ),
      child: child,
    );
  }
}

InputDecoration _registerFieldDecoration({
  required String labelText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.86),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
    labelStyle: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w600),
    floatingLabelStyle: const TextStyle(
      color: BrandTheme.redTop,
      fontWeight: FontWeight.w700,
    ),
    suffixIcon: suffixIcon,
  );
}

TextStyle _registerBodyText({
  Color color = kTextDark,
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w500,
  double height = 1.2,
}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: 0,
  );
}

TextStyle _registerCommandText({
  Color color = kTextDark,
  double fontSize = 16,
  double letterSpacing = 1.35,
}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: fontSize,
    letterSpacing: letterSpacing,
  );
}
