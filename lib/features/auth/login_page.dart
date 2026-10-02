import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:modelapp/core/app_error_mapper.dart';
import 'package:modelapp/core/supabase_provider.dart';
import 'package:modelapp/core/router.dart';
import '../../ui/brand/brand_logo.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../core/locale_provider.dart';
import '../../core/user_security_audit_service.dart';
import '../notifications/app_notifications.dart';
import 'auth_rate_limiter.dart';
import 'auth_split_layout.dart';
import 'auth_controller.dart';
import 'phone_number_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

enum _LoginMode { email, phone }

class _LoginPageState extends ConsumerState<LoginPage> {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _phoneC = TextEditingController();
  final _phonePassC = TextEditingController();

  final _emailF = FocusNode();
  final _passF = FocusNode();
  final _phonePassF = FocusNode();

  _LoginMode _mode = _LoginMode.email;
  String _phoneIso = 'RU';
  bool _loading = false;
  bool isPasswordHidden = true;
  bool _phonePasswordHidden = true;
  String? _error;

  String _langCodeFor(BuildContext context, Locale? appLocale) {
    final deviceLang = Localizations.localeOf(context).languageCode;
    return appLocale?.languageCode ?? deviceLang;
  }

  void _submitIfNotLoading() {
    if (_loading) return;
    if (_mode == _LoginMode.email) {
      _signIn();
      return;
    }
    _signInWithPhonePassword();
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _phoneC.dispose();
    _phonePassC.dispose();
    _emailF.dispose();
    _passF.dispose();
    _phonePassF.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations t) {
    final email = _emailC.text.trim();
    final pass = _passC.text;

    if (email.isEmpty) return t.enterEmail;
    final emailOk = _emailRegex.hasMatch(email);
    if (!emailOk) return t.invalidEmail;
    if (pass.isEmpty) return t.enterPassword;
    if (pass.length < kPasswordMinLen) return t.passwordMin6;
    return null;
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    final t = AppLocalizations.of(context)!;
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    setState(() => _error = null);

    final msg = _validate(t);
    if (msg != null) {
      setState(() => _error = msg);
      if (msg == t.enterEmail || msg == t.invalidEmail) {
        _emailF.requestFocus();
      } else {
        _passF.requestFocus();
      }
      return;
    }

    final subject = _emailC.text.trim();
    final limiterState = await AuthRateLimiter.instance.check(
      AuthRateLimitAction.signIn,
      subject,
    );
    if (!limiterState.allowed) {
      setState(() => _error = limiterState.message(isRussian));
      return;
    }

    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);

      final res = await supabase.auth.signInWithPassword(
        email: _emailC.text.trim(),
        password: _passC.text,
      );

      final userId = res.user?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _error = t.signInUserIdMissing);
        return;
      }

      await AuthRateLimiter.instance.recordSuccess(
        AuthRateLimitAction.signIn,
        subject,
      );
      await ref
          .read(securityNotificationsServiceProvider)
          .notifyNewLogin(method: 'email');
      await ref
          .read(userSecurityAuditServiceProvider)
          .log(
            eventType: UserSecurityAuditEvent.loginEmail,
            label: isRussian ? 'Вход по email' : 'Email sign-in',
            metadata: {'method': 'email'},
          );
      if (!mounted) return;
      context.go(Routes.search);
    } on AuthException catch (e) {
      if (!mounted) return;
      await AuthRateLimiter.instance.recordFailure(
        AuthRateLimitAction.signIn,
        subject,
      );
      setState(
        () => _error = AppErrorMapper.message(
          e,
          t,
          context: AppErrorContext.signIn,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await AuthRateLimiter.instance.recordFailure(
        AuthRateLimitAction.signIn,
        subject,
      );
      setState(
        () => _error = AppErrorMapper.message(
          e,
          t,
          context: AppErrorContext.signIn,
        ),
      );
    } finally {
      TextInput.finishAutofillContext(shouldSave: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizedPhone() => composeInternationalPhone(
    code: phoneCountryCodeForIso(_phoneIso).code,
    number: _phoneC.text,
  );

  List<String> _phoneSignInCandidates(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return [phone, if (digits.isNotEmpty && digits != phone) digits];
  }

  Future<void> _signInWithPhonePassword() async {
    FocusScope.of(context).unfocus();
    final t = AppLocalizations.of(context)!;
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final phone = _normalizedPhone();
    final password = _phonePassC.text;
    if (phone.isEmpty) {
      setState(() => _error = t.phoneInternationalHint);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = t.enterPassword);
      _phonePassF.requestFocus();
      return;
    }
    if (password.length < kPasswordMinLen) {
      setState(() => _error = t.passwordMin6);
      _phonePassF.requestFocus();
      return;
    }

    final limiterState = await AuthRateLimiter.instance.check(
      AuthRateLimitAction.phoneSignIn,
      phone,
    );
    if (!limiterState.allowed) {
      setState(() => _error = limiterState.message(isRussian));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authControllerProvider);
      AuthException? lastAuthError;
      AuthResponse? res;
      for (final candidate in _phoneSignInCandidates(phone)) {
        try {
          res = await auth.signInWithPhonePassword(
            phone: candidate,
            password: password,
          );
          break;
        } on AuthException catch (e) {
          lastAuthError = e;
        }
      }
      if (res == null) {
        throw lastAuthError ?? AuthException(t.signInGenericError);
      }
      final userId = res.user?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _error = t.signInUserIdMissing);
        return;
      }
      await AuthRateLimiter.instance.recordSuccess(
        AuthRateLimitAction.phoneSignIn,
        phone,
      );
      await ref
          .read(securityNotificationsServiceProvider)
          .notifyNewLogin(method: 'phone');
      await ref
          .read(userSecurityAuditServiceProvider)
          .log(
            eventType: UserSecurityAuditEvent.loginPhone,
            label: isRussian ? 'Вход по телефону' : 'Phone sign-in',
            metadata: {'method': 'phone'},
          );
      if (!mounted) return;
      context.go(Routes.search);
    } on AuthException catch (e) {
      if (!mounted) return;
      await AuthRateLimiter.instance.recordFailure(
        AuthRateLimitAction.phoneSignIn,
        phone,
      );
      setState(
        () => _error = AppErrorMapper.message(
          e,
          t,
          context: AppErrorContext.phoneSignIn,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await AuthRateLimiter.instance.recordFailure(
        AuthRateLimitAction.phoneSignIn,
        phone,
      );
      setState(() => _error = t.signInGenericError);
    } finally {
      TextInput.finishAutofillContext(shouldSave: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchMode(_LoginMode mode) {
    if (_loading || _mode == mode) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  void _goIfNotLoading(String route) {
    if (_loading) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appLocale = ref.watch(localeProvider);
    final lang = _langCodeFor(context, appLocale);

    final isDesktop =
        MediaQuery.sizeOf(context).width >= kAuthDesktopBreakpoint;

    final card = _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const BrandLogo(height: kLoginLogoH),

              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    kLangToggleRadius,
                  ),
                  onTap: _loading
                      ? null
                      : () => ref
                            .read(localeProvider.notifier)
                            .toggle(),
                  child: Container(
                    padding: kLangTogglePad,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        kLangToggleRadius,
                      ),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: Text(
                      lang == 'ru' ? 'RU' : 'EN',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: kLoginGapAfterLogo),

          // On phones the public sections are big pill buttons
          // inside the card; on desktop they become text links
          // above it (see below).
          if (!isDesktop) ...[
            SizedBox(
              width: double.infinity,
              height: kLoginButtonH,
              child: BrandPillButton(
                label: t.castingsUpper,
                style: BrandPillStyle.dark,
                onTap: () => _goIfNotLoading(Routes.castings),
              ),
            ),

            const SizedBox(height: kLoginGapButtons),

            SizedBox(
              width: double.infinity,
              height: kLoginButtonH,
              child: BrandPillButton(
                label: t.catalogUpper,
                style: BrandPillStyle.dark,
                onTap: () => _goIfNotLoading(Routes.search),
              ),
            ),

            const SizedBox(height: kLoginGapSection),
          ],

          AbsorbPointer(
            absorbing: _loading,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: kAnim200,
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(
                              bottom: kLoginGapFields,
                            ),
                            child: Text(
                              _error!,
                              key: ValueKey<String?>(_error),
                              style: const TextStyle(
                                color: kTextDanger,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                  _LoginModeTabs(
                    mode: _mode,
                    emailLabel: 'Email',
                    phoneLabel: t.phoneNumber,
                    onChanged: _switchMode,
                  ),
                  const SizedBox(height: kLoginGapFields),
                  AnimatedSwitcher(
                    duration: kAnim200,
                    child: _mode == _LoginMode.email
                        ? _EmailLoginFields(
                            key: const ValueKey('email-login'),
                            emailController: _emailC,
                            passwordController: _passC,
                            emailFocus: _emailF,
                            passwordFocus: _passF,
                            passwordHidden: isPasswordHidden,
                            onTogglePassword: () => setState(
                              () => isPasswordHidden =
                                  !isPasswordHidden,
                            ),
                            onSubmit: _submitIfNotLoading,
                            t: t,
                          )
                        : _PhoneLoginFields(
                            key: const ValueKey('phone-login'),
                            phoneController: _phoneC,
                            passwordController: _phonePassC,
                            passwordFocus: _phonePassF,
                            phoneIso: _phoneIso,
                            loading: _loading,
                            passwordHidden: _phonePasswordHidden,
                            t: t,
                            onCountryIsoChanged: (value) =>
                                setState(() => _phoneIso = value),
                            onTogglePassword: () => setState(
                              () => _phonePasswordHidden =
                                  !_phonePasswordHidden,
                            ),
                            onSubmit: _submitIfNotLoading,
                          ),
                  ),
                  const SizedBox(height: kLoginGapActions),

                  SizedBox(
                    width: double.infinity,
                    height: kLoginButtonH,
                    child: BrandPillButton(
                      label: _loading
                          ? t.loadingDots
                          : t.signInUpper,
                      style: BrandPillStyle.dark,
                      onTap: _submitIfNotLoading,
                    ),
                  ),

                  const SizedBox(height: kLoginGapBottomRow),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        t.noAccount,
                        style: const TextStyle(
                          color: kTextDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      BrandPillButton(
                        label: t.registerUpper,
                        style: BrandPillStyle.light,
                        onTap: () =>
                            _goIfNotLoading(Routes.register),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _LoginLegalLinks(isRussian: lang == 'ru'),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      // v2: brand panel on the left, a 360 px form on the right.
      return Scaffold(
        body: AuthSplitLayout(
          topBar: Row(
            children: [
              _DesktopPublicLinks(
                castingsLabel: t.castingsTab,
                catalogLabel: t.catalogTab,
                onCastings: () => _goIfNotLoading(Routes.castings),
                onCatalog: () => _goIfNotLoading(Routes.search),
              ),
              const Spacer(),
              _LangToggle(
                lang: lang,
                onTap: _loading
                    ? null
                    : () => ref.read(localeProvider.notifier).toggle(),
              ),
            ],
          ),
          child: _buildDesktopForm(t),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(padding: kLoginPagePad, children: [card]),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopForm(AppLocalizations t) {
    final fields = AnimatedSwitcher(
      duration: kAnim200,
      child: _mode == _LoginMode.email
          ? _EmailLoginFields(
              key: const ValueKey('email-login-desktop'),
              emailController: _emailC,
              passwordController: _passC,
              emailFocus: _emailF,
              passwordFocus: _passF,
              passwordHidden: isPasswordHidden,
              onTogglePassword: () =>
                  setState(() => isPasswordHidden = !isPasswordHidden),
              onSubmit: _submitIfNotLoading,
              t: t,
            )
          : _PhoneLoginFields(
              key: const ValueKey('phone-login-desktop'),
              phoneController: _phoneC,
              passwordController: _phonePassC,
              passwordFocus: _phonePassF,
              phoneIso: _phoneIso,
              loading: _loading,
              passwordHidden: _phonePasswordHidden,
              t: t,
              onCountryIsoChanged: (value) =>
                  setState(() => _phoneIso = value),
              onTogglePassword: () => setState(
                () => _phonePasswordHidden = !_phonePasswordHidden,
              ),
              onSubmit: _submitIfNotLoading,
            ),
    );

    return AbsorbPointer(
      absorbing: _loading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/pk-logo-red-512.png',
              height: 64,
              semanticLabel: 'PK Management',
            ),
          ),
          const SizedBox(height: 28),
          Text(t.signInTitle, style: AppText.h1),
          const SizedBox(height: 6),
          Text(
            t.signInHint,
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
          const SizedBox(height: 28),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Tokens.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: AppText.small.copyWith(color: Tokens.danger),
              ),
            ),
            const SizedBox(height: 16),
          ],
          AuthModeSwitch(
            labels: ['Email', t.phoneNumber],
            selectedIndex: _mode == _LoginMode.email ? 0 : 1,
            onChanged: (index) =>
                _switchMode(index == 0 ? _LoginMode.email : _LoginMode.phone),
          ),
          const SizedBox(height: 16),
          fields,
          const SizedBox(height: 20),
          SizedBox(
            height: Tokens.inputHeight,
            child: FilledButton(
              onPressed: _submitIfNotLoading,
              child: Text(_loading ? t.loadingDots : t.signInTitle),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t.noAccount,
                style: AppText.small.copyWith(color: Tokens.textSecondary),
              ),
              TextButton(
                onPressed: () => _goIfNotLoading(Routes.register),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(t.createAccount),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _LoginLegalLinks(isRussian: t.localeName.startsWith('ru')),
        ],
      ),
    );
  }
}

/// Language chip (RU / EN) used on the wide layout.
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.lang, required this.onTap});

  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: Tokens.border),
        textStyle: AppText.smallStrong,
      ),
      child: Text(lang == 'ru' ? 'RU' : 'EN'),
    );
  }
}

/// «Кастинги · Каталог» links shown above the login card on wide screens.
class _DesktopPublicLinks extends StatelessWidget {
  const _DesktopPublicLinks({
    required this.castingsLabel,
    required this.catalogLabel,
    required this.onCastings,
    required this.onCatalog,
  });

  final String castingsLabel;
  final String catalogLabel;
  final VoidCallback onCastings;
  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DesktopPublicLink(label: castingsLabel, onTap: onCastings),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('·', style: TextStyle(color: Tokens.textTertiary)),
        ),
        _DesktopPublicLink(label: catalogLabel, onTap: onCatalog),
      ],
    );
  }
}

class _DesktopPublicLink extends StatelessWidget {
  const _DesktopPublicLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Tokens.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        textStyle: AppText.smallStrong,
      ),
      child: Text(label),
    );
  }
}

class _LoginLegalLinks extends StatelessWidget {
  const _LoginLegalLinks({required this.isRussian});

  final bool isRussian;

  @override
  Widget build(BuildContext context) {
    final links = <({String label, String route})>[
      (label: isRussian ? 'Условия' : 'Terms', route: Routes.termsOfService),
      (
        label: isRussian ? 'Реквизиты' : 'Legal details',
        route: Routes.requisites,
      ),
      (
        label: isRussian ? 'Конфиденциальность' : 'Privacy',
        route: Routes.privacyPolicy,
      ),
      (
        label: isRussian ? 'Безопасность детей' : 'Child safety',
        route: Routes.childSafety,
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final link in links)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(link.route),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                link.label,
                style: TextStyle(
                  color: kTextMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: kTextMuted.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LoginModeTabs extends StatelessWidget {
  const _LoginModeTabs({
    required this.mode,
    required this.emailLabel,
    required this.phoneLabel,
    required this.onChanged,
  });

  final _LoginMode mode;
  final String emailLabel;
  final String phoneLabel;
  final ValueChanged<_LoginMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9F9F9), Color(0xFFEDEDED)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.88),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _LoginModeTabButton(
              label: emailLabel,
              selected: mode == _LoginMode.email,
              onTap: () => onChanged(_LoginMode.email),
            ),
          ),
          Expanded(
            child: _LoginModeTabButton(
              label: phoneLabel,
              selected: mode == _LoginMode.phone,
              onTap: () => onChanged(_LoginMode.phone),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginModeTabButton extends StatelessWidget {
  const _LoginModeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kAnim200,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: selected ? BrandTheme.darkPillGradient : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: BrandTheme.pillText.copyWith(
                color: selected ? Colors.white : kTextDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _authFieldDecoration({
  required String label,
  Widget? suffixIcon,
}) {
  InputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Tokens.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(Tokens.border),
    enabledBorder: border(Tokens.border),
    focusedBorder: border(Tokens.text, 1.5),
    errorBorder: border(Tokens.danger),
    focusedErrorBorder: border(Tokens.danger, 1.5),
    labelStyle: AppText.small.copyWith(color: Tokens.textSecondary),
    floatingLabelStyle: AppText.caption.copyWith(color: Tokens.text),
    suffixIcon: suffixIcon,
  );
}

class _EmailLoginFields extends StatelessWidget {
  const _EmailLoginFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.passwordHidden,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.t,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool passwordHidden;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        children: [
          TextField(
            controller: emailController,
            focusNode: emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSubmitted: (_) => passwordFocus.requestFocus(),
            style: AppText.body,
            decoration: _authFieldDecoration(label: t.email),
          ),
          const SizedBox(height: kLoginGapFields),
          TextField(
            controller: passwordController,
            focusNode: passwordFocus,
            obscureText: passwordHidden,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => onSubmit(),
            style: AppText.body,
            decoration: _authFieldDecoration(
              label: t.password,
              suffixIcon: IconButton(
                tooltip: passwordHidden ? t.showPassword : t.hidePassword,
                onPressed: onTogglePassword,
                icon: Icon(
                  passwordHidden ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneLoginFields extends StatelessWidget {
  const _PhoneLoginFields({
    super.key,
    required this.phoneController,
    required this.passwordController,
    required this.passwordFocus,
    required this.phoneIso,
    required this.loading,
    required this.passwordHidden,
    required this.t,
    required this.onCountryIsoChanged,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;
  final String phoneIso;
  final bool loading;
  final bool passwordHidden;
  final AppLocalizations t;
  final ValueChanged<String> onCountryIsoChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthPhoneNumberField(
          controller: phoneController,
          enabled: !loading,
          countryIso: phoneIso,
          codeLabel: isRu ? 'Код' : 'Code',
          phoneLabel: t.phoneNumber,
          onCountryIsoChanged: onCountryIsoChanged,
        ),
        const SizedBox(height: kLoginGapFields),
        TextField(
          controller: passwordController,
          focusNode: passwordFocus,
          obscureText: passwordHidden,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => loading ? null : onSubmit(),
          style: AppText.body,
          decoration: _authFieldDecoration(
            label: t.password,
            suffixIcon: IconButton(
              tooltip: passwordHidden ? t.showPassword : t.hidePassword,
              onPressed: onTogglePassword,
              icon: Icon(
                passwordHidden ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kLoginCardPad,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.98),
            Colors.white.withValues(alpha: 0.92),
            const Color(0xFFF4F4F4).withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.86),
            blurRadius: 16,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            right: 18,
            top: 0,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
