import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

final accountMfaServiceProvider = Provider<AccountMfaService>((ref) {
  return AccountMfaService(ref.read(supabaseProvider));
});

final accountMfaStatusProvider = FutureProvider<AccountMfaStatus>((ref) async {
  final role = await ref.watch(accountRoleProvider.future);
  return ref.read(accountMfaServiceProvider).loadStatus(role: role);
});

class AccountMfaStatus {
  const AccountMfaStatus({
    required this.role,
    required this.factors,
    required this.currentLevel,
    required this.nextLevel,
  });

  final AccountRole role;
  final List<Factor> factors;
  final AuthenticatorAssuranceLevels? currentLevel;
  final AuthenticatorAssuranceLevels? nextLevel;

  bool get isAdmin => role == AccountRole.admin;
  bool get hasTotp =>
      factors.any((factor) => factor.factorType == FactorType.totp);
  bool get hasVerifiedTotp => factors.any(
    (factor) =>
        factor.factorType == FactorType.totp &&
        factor.status == FactorStatus.verified,
  );
  bool get sessionVerified => currentLevel == AuthenticatorAssuranceLevels.aal2;
}

class AccountMfaEnrollment {
  const AccountMfaEnrollment({
    required this.factorId,
    required this.secret,
    required this.uri,
  });

  final String factorId;
  final String secret;
  final String uri;
}

class AccountMfaService {
  const AccountMfaService(this._sb);

  final SupabaseClient _sb;

  Future<AccountMfaStatus> loadStatus({required AccountRole role}) async {
    final factors = await _sb.auth.mfa.listFactors();
    final aal = _sb.auth.mfa.getAuthenticatorAssuranceLevel();
    return AccountMfaStatus(
      role: role,
      factors: factors.all,
      currentLevel: aal.currentLevel,
      nextLevel: aal.nextLevel,
    );
  }

  Future<AccountMfaEnrollment> startTotpEnrollment() async {
    final response = await _sb.auth.mfa.enroll(
      issuer: 'PK Management',
      friendlyName: 'PK Management',
    );
    final totp = response.totp;
    if (totp == null) {
      throw const AuthException('TOTP enrollment was not returned');
    }
    return AccountMfaEnrollment(
      factorId: response.id,
      secret: totp.secret,
      uri: totp.uri,
    );
  }

  Future<void> verifyEnrollment({
    required String factorId,
    required String code,
  }) async {
    final challenge = await _sb.auth.mfa.challenge(factorId: factorId);
    await _sb.auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code.trim(),
    );
  }

  Future<void> verifySession({
    required String factorId,
    required String code,
  }) async {
    await _sb.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: code.trim(),
    );
  }

  Future<void> unenroll(String factorId) async {
    await _sb.auth.mfa.unenroll(factorId);
  }
}

class AccountMfaPage extends ConsumerStatefulWidget {
  const AccountMfaPage({super.key});

  @override
  ConsumerState<AccountMfaPage> createState() => _AccountMfaPageState();
}

class _AccountMfaPageState extends ConsumerState<AccountMfaPage> {
  final _enrollCodeC = TextEditingController();
  final _sessionCodeC = TextEditingController();
  AccountMfaEnrollment? _enrollment;
  bool _busy = false;
  String _message = '';

  bool get _isRussian =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

  @override
  void dispose() {
    _enrollCodeC.dispose();
    _sessionCodeC.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final enrollment = await ref
          .read(accountMfaServiceProvider)
          .startTotpEnrollment();
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _message = _isRussian
            ? 'Добавьте secret в Authenticator и введите 6-значный код.'
            : 'Add the secret to Authenticator and enter the 6-digit code.';
      });
      ref.invalidate(accountMfaStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyEnrollment() async {
    final enrollment = _enrollment;
    final code = _enrollCodeC.text.trim();
    if (_busy || enrollment == null || code.length < 6) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await ref
          .read(accountMfaServiceProvider)
          .verifyEnrollment(factorId: enrollment.factorId, code: code);
      if (!mounted) return;
      _enrollCodeC.clear();
      setState(() {
        _enrollment = null;
        _message = _isRussian ? '2FA включена.' : '2FA enabled.';
      });
      ref.invalidate(accountMfaStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifySession(String factorId) async {
    final code = _sessionCodeC.text.trim();
    if (_busy || code.length < 6) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await ref
          .read(accountMfaServiceProvider)
          .verifySession(factorId: factorId, code: code);
      if (!mounted) return;
      _sessionCodeC.clear();
      setState(() {
        _message = _isRussian
            ? 'Текущая сессия подтверждена 2FA.'
            : 'Current session verified with 2FA.';
      });
      ref.invalidate(accountMfaStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFactor(Factor factor, bool sessionVerified) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      if (!sessionVerified && factor.status == FactorStatus.verified) {
        final code = _sessionCodeC.text.trim();
        if (code.length < 6) {
          setState(() {
            _message = _isRussian
                ? 'Введите код 2FA, чтобы отключить фактор.'
                : 'Enter a 2FA code to disable this factor.';
          });
          return;
        }
        await ref
            .read(accountMfaServiceProvider)
            .verifySession(factorId: factor.id, code: code);
      }
      await ref.read(accountMfaServiceProvider).unenroll(factor.id);
      if (!mounted) return;
      _sessionCodeC.clear();
      setState(() {
        _message = _isRussian ? 'Фактор удален.' : 'Factor removed.';
      });
      ref.invalidate(accountMfaStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, String done) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _message = done);
  }

  String _errorText(Object error) {
    final raw = error.toString();
    if (raw.contains('mfa_totp_enroll_not_enabled') ||
        raw.contains('MFA') && raw.contains('disabled')) {
      return _isRussian
          ? 'TOTP MFA не включена в настройках Supabase Auth.'
          : 'TOTP MFA is not enabled in Supabase Auth settings.';
    }
    if (raw.contains('mfa_verification_failed')) {
      return _isRussian ? 'Неверный 2FA код.' : 'Invalid 2FA code.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final asyncStatus = ref.watch(accountMfaStatusProvider);
    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(
              padding: kMyProfilePagePad,
              children: [
                BrandAdminHeader(
                  title: _isRussian ? 'БЕЗОПАСНОСТЬ' : 'SECURITY',
                  onBack: () => context.go(Routes.accountProfile),
                ),
                const SizedBox(height: kGap14),
                asyncStatus.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: kTextDark),
                    ),
                  ),
                  error: (error, _) => _InfoCard(
                    icon: Icons.error_rounded,
                    title: _isRussian
                        ? 'Не удалось загрузить 2FA'
                        : '2FA load failed',
                    body: _errorText(error),
                    danger: true,
                  ),
                  data: (status) => _MfaContent(
                    status: status,
                    enrollment: _enrollment,
                    enrollCodeC: _enrollCodeC,
                    sessionCodeC: _sessionCodeC,
                    busy: _busy,
                    isRussian: _isRussian,
                    onStartEnrollment: _startEnrollment,
                    onVerifyEnrollment: _verifyEnrollment,
                    onVerifySession: status.factors.isEmpty
                        ? null
                        : () => _verifySession(status.factors.first.id),
                    onRemoveFactor: (factor) =>
                        _removeFactor(factor, status.sessionVerified),
                    onCopySecret: _enrollment == null
                        ? null
                        : () => _copy(
                            _enrollment!.secret,
                            _isRussian
                                ? 'Secret скопирован.'
                                : 'Secret copied.',
                          ),
                    onCopyUri: _enrollment == null
                        ? null
                        : () => _copy(
                            _enrollment!.uri,
                            _isRussian
                                ? 'Authenticator URI скопирован.'
                                : 'Authenticator URI copied.',
                          ),
                  ),
                ),
                if (_message.trim().isNotEmpty) ...[
                  const SizedBox(height: kGap12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          _message.contains('Exception') ||
                              _message.contains('failed') ||
                              _message.contains('не ')
                          ? BrandTheme.redTop
                          : kTextMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MfaContent extends StatelessWidget {
  const _MfaContent({
    required this.status,
    required this.enrollment,
    required this.enrollCodeC,
    required this.sessionCodeC,
    required this.busy,
    required this.isRussian,
    required this.onStartEnrollment,
    required this.onVerifyEnrollment,
    required this.onVerifySession,
    required this.onRemoveFactor,
    required this.onCopySecret,
    required this.onCopyUri,
  });

  final AccountMfaStatus status;
  final AccountMfaEnrollment? enrollment;
  final TextEditingController enrollCodeC;
  final TextEditingController sessionCodeC;
  final bool busy;
  final bool isRussian;
  final VoidCallback onStartEnrollment;
  final VoidCallback onVerifyEnrollment;
  final VoidCallback? onVerifySession;
  final ValueChanged<Factor> onRemoveFactor;
  final VoidCallback? onCopySecret;
  final VoidCallback? onCopyUri;

  @override
  Widget build(BuildContext context) {
    final verified = status.hasVerifiedTotp;
    return Column(
      children: [
        _InfoCard(
          icon: verified ? Icons.verified_user_rounded : Icons.security_rounded,
          title: verified
              ? (isRussian ? '2FA включена' : '2FA enabled')
              : (isRussian ? '2FA не включена' : '2FA is off'),
          body: status.isAdmin && !verified
              ? (isRussian
                    ? 'Для админа это важный защитный слой. Включите код из Authenticator перед масштабным запуском.'
                    : 'For admins this is an important protection layer. Enable an Authenticator code before launch.')
              : (isRussian
                    ? 'TOTP-код защищает вход и чувствительные действия аккаунта.'
                    : 'A TOTP code protects sign-in and sensitive account actions.'),
          danger: status.isAdmin && !verified,
        ),
        const SizedBox(height: kGap12),
        if (enrollment == null)
          _ActionCard(
            icon: Icons.add_moderator_rounded,
            title: isRussian
                ? 'Подключить Authenticator'
                : 'Set up Authenticator',
            body: isRussian
                ? 'Используйте Google Authenticator, 1Password, Authy или другой TOTP-клиент.'
                : 'Use Google Authenticator, 1Password, Authy or another TOTP app.',
            button: isRussian ? 'НАЧАТЬ' : 'START',
            busy: busy,
            onTap: onStartEnrollment,
          )
        else
          _EnrollmentCard(
            enrollment: enrollment!,
            controller: enrollCodeC,
            busy: busy,
            isRussian: isRussian,
            onCopySecret: onCopySecret,
            onCopyUri: onCopyUri,
            onVerify: onVerifyEnrollment,
          ),
        if (status.factors.isNotEmpty) ...[
          const SizedBox(height: kGap12),
          _FactorsCard(
            factors: status.factors,
            sessionVerified: status.sessionVerified,
            controller: sessionCodeC,
            busy: busy,
            isRussian: isRussian,
            onVerifySession: onVerifySession,
            onRemoveFactor: onRemoveFactor,
          ),
        ],
      ],
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({
    required this.enrollment,
    required this.controller,
    required this.busy,
    required this.isRussian,
    required this.onCopySecret,
    required this.onCopyUri,
    required this.onVerify,
  });

  final AccountMfaEnrollment enrollment;
  final TextEditingController controller;
  final bool busy;
  final bool isRussian;
  final VoidCallback? onCopySecret;
  final VoidCallback? onCopyUri;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isRussian ? 'SECRET ДЛЯ AUTHENTICATOR' : 'AUTHENTICATOR SECRET',
            style: _titleStyle(),
          ),
          const SizedBox(height: 10),
          SelectableText(
            enrollment.secret,
            style: const TextStyle(
              color: kTextDark,
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BrandPillButton(
                  label: isRussian ? 'КОПИРОВАТЬ SECRET' : 'COPY SECRET',
                  style: BrandPillStyle.light,
                  onTap: onCopySecret,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BrandPillButton(
                  label: isRussian ? 'КОПИРОВАТЬ URI' : 'COPY URI',
                  style: BrandPillStyle.light,
                  onTap: onCopyUri,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CodeField(
            controller: controller,
            label: isRussian ? '6-значный код' : '6-digit code',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: BrandPillButton(
              label: busy ? '...' : (isRussian ? 'ПОДТВЕРДИТЬ' : 'VERIFY'),
              style: BrandPillStyle.dark,
              onTap: busy ? null : onVerify,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorsCard extends StatelessWidget {
  const _FactorsCard({
    required this.factors,
    required this.sessionVerified,
    required this.controller,
    required this.busy,
    required this.isRussian,
    required this.onVerifySession,
    required this.onRemoveFactor,
  });

  final List<Factor> factors;
  final bool sessionVerified;
  final TextEditingController controller;
  final bool busy;
  final bool isRussian;
  final VoidCallback? onVerifySession;
  final ValueChanged<Factor> onRemoveFactor;

  @override
  Widget build(BuildContext context) {
    final verifiedFactors = factors
        .where((factor) => factor.status == FactorStatus.verified)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isRussian ? 'ПОДКЛЮЧЕННЫЕ ФАКТОРЫ' : 'ENROLLED FACTORS',
            style: _titleStyle(),
          ),
          const SizedBox(height: 10),
          for (final factor in factors) ...[
            _FactorRow(factor: factor),
            const SizedBox(height: 8),
          ],
          if (verifiedFactors.isNotEmpty && !sessionVerified) ...[
            const SizedBox(height: 8),
            _CodeField(
              controller: controller,
              label: isRussian
                  ? 'Код для подтверждения сессии / отключения'
                  : 'Code to verify session / disable',
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: BrandPillButton(
                label: busy
                    ? '...'
                    : (isRussian ? 'ПОДТВЕРДИТЬ СЕССИЮ' : 'VERIFY SESSION'),
                style: BrandPillStyle.light,
                onTap: busy ? null : onVerifySession,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final factor in factors)
            SizedBox(
              height: 42,
              child: BrandPillButton(
                label: isRussian ? 'ОТКЛЮЧИТЬ 2FA' : 'DISABLE 2FA',
                style: BrandPillStyle.dark,
                onTap: busy ? null : () => onRemoveFactor(factor),
              ),
            ),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final Factor factor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.key_rounded, color: kTextDark, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${factor.factorType.name.toUpperCase()} • ${factor.status.name}',
            style: _bodyStyle(color: kTextDark),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.button,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String button;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: icon,
      title: title,
      body: body,
      action: SizedBox(
        height: 42,
        child: BrandPillButton(
          label: busy ? '...' : button,
          style: BrandPillStyle.light,
          onTap: busy ? null : onTap,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(
          color: danger
              ? BrandTheme.redTop.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.70),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: danger ? BrandTheme.redTop : kTextDark),
          const SizedBox(width: kGap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle()),
                const SizedBox(height: 6),
                Text(body, style: _bodyStyle()),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.82),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}

TextStyle _titleStyle({Color color = kTextDark}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );
}

TextStyle _bodyStyle({Color color = kTextMuted}) {
  return TextStyle(
    color: color,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.28,
  );
}
