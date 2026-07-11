import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/mfa_recovery_code_service.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../core/user_security_audit_service.dart';
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
    final factors = _sb.auth.currentUser?.factors ?? const <Factor>[];
    final aal = _sb.auth.mfa.getAuthenticatorAssuranceLevel();
    return AccountMfaStatus(
      role: role,
      factors: factors,
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
  List<String> _recoveryCodes = const [];
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
      await ref
          .read(userSecurityAuditServiceProvider)
          .log(
            eventType: UserSecurityAuditEvent.mfaEnabled,
            label: _isRussian ? '2FA включена' : '2FA enabled',
            metadata: {'factor_type': 'totp'},
          );
      final recoveryCodes = await _rotateRecoveryCodesFromMfaFlow();
      if (!mounted) return;
      _enrollCodeC.clear();
      setState(() {
        _enrollment = null;
        _recoveryCodes = recoveryCodes ?? const [];
        _message = recoveryCodes == null
            ? (_isRussian
                  ? '2FA включена. Для recovery codes примените SQL mfa_recovery_codes.sql.'
                  : '2FA enabled. Apply mfa_recovery_codes.sql for recovery codes.')
            : (_isRussian
                  ? '2FA включена. Сохраните recovery codes.'
                  : '2FA enabled. Save your recovery codes.');
      });
      ref.invalidate(accountMfaStatusProvider);
      ref.invalidate(mfaRecoveryCodeStatusProvider);
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
      await ref
          .read(userSecurityAuditServiceProvider)
          .log(
            eventType: UserSecurityAuditEvent.mfaSessionVerified,
            label: _isRussian
                ? 'Сессия подтверждена 2FA'
                : 'Session verified with 2FA',
            metadata: {'factor_type': 'totp'},
          );
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
      await ref
          .read(userSecurityAuditServiceProvider)
          .log(
            eventType: UserSecurityAuditEvent.mfaDisabled,
            label: _isRussian ? '2FA отключена' : '2FA disabled',
            metadata: {'factor_type': factor.factorType.name},
          );
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

  Future<List<String>?> _rotateRecoveryCodesFromMfaFlow() async {
    final codes = await ref.read(mfaRecoveryCodeServiceProvider).rotateCodes();
    if (codes == null || codes.isEmpty) return null;
    await ref
        .read(userSecurityAuditServiceProvider)
        .log(
          eventType: UserSecurityAuditEvent.mfaRecoveryCodesGenerated,
          label: _isRussian
              ? 'Recovery codes созданы'
              : 'Recovery codes generated',
          metadata: {'count': codes.length},
        );
    return codes;
  }

  Future<void> _generateRecoveryCodes() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final codes = await _rotateRecoveryCodesFromMfaFlow();
      if (!mounted) return;
      setState(() {
        _recoveryCodes = codes ?? const [];
        _message = codes == null
            ? (_isRussian
                  ? 'Recovery codes пока не настроены на сервере. Нужно применить mfa_recovery_codes.sql.'
                  : 'Recovery codes are not configured on the server yet. Apply mfa_recovery_codes.sql.')
            : (_isRussian
                  ? 'Новые recovery codes созданы. Сохраните их сейчас.'
                  : 'New recovery codes generated. Save them now.');
      });
      ref.invalidate(mfaRecoveryCodeStatusProvider);
      ref.invalidate(userSecurityAuditEntriesProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyRecoveryCodes() async {
    if (_recoveryCodes.isEmpty) return;
    await _copy(
      _recoveryCodes.join('\n'),
      _isRussian ? 'Recovery codes скопированы.' : 'Recovery codes copied.',
    );
  }

  Future<void> _copy(String value, String done) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _message = done);
  }

  String _errorText(Object error) {
    if (error is PostgrestException) {
      return _postgrestErrorText(error);
    }
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
    if (raw.contains('rotate_my_mfa_recovery_codes') ||
        raw.contains('mfa_recovery_codes')) {
      return _isRussian
          ? 'Recovery codes пока не настроены на сервере. Нужно применить mfa_recovery_codes.sql.'
          : 'Recovery codes are not configured on the server yet. Apply mfa_recovery_codes.sql.';
    }
    return raw;
  }

  String _postgrestErrorText(PostgrestException error) {
    final parts = <String>[];
    if (error.code != null && error.code!.trim().isNotEmpty) {
      parts.add('code: ${error.code}');
    }
    if (error.message.trim().isNotEmpty) {
      parts.add('message: ${error.message}');
    }
    final details = error.details?.toString().trim() ?? '';
    if (details.isNotEmpty) {
      parts.add('details: $details');
    }
    final hint = error.hint?.toString().trim() ?? '';
    if (hint.isNotEmpty) {
      parts.add('hint: $hint');
    }
    final text = parts.join('\n');
    if (text.isEmpty) return error.toString();
    return _isRussian
        ? 'Ошибка Supabase при операции безопасности:\n$text'
        : 'Supabase error during security operation:\n$text';
  }

  @override
  Widget build(BuildContext context) {
    final asyncStatus = ref.watch(accountMfaStatusProvider);
    final asyncRecovery = ref.watch(mfaRecoveryCodeStatusProvider);
    final asyncAudit = ref.watch(userSecurityAuditEntriesProvider);
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
                    recoveryCodes: _recoveryCodes,
                    recoveryStatus: asyncRecovery.valueOrNull,
                    recoveryLoading: asyncRecovery.isLoading,
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
                    onGenerateRecoveryCodes: _generateRecoveryCodes,
                    onCopyRecoveryCodes: _copyRecoveryCodes,
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
                const SizedBox(height: kGap14),
                _SecurityAuditCard(
                  entries: asyncAudit.valueOrNull ?? const [],
                  loading: asyncAudit.isLoading,
                  isRussian: _isRussian,
                  onRefresh: () =>
                      ref.invalidate(userSecurityAuditEntriesProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityAuditCard extends StatelessWidget {
  const _SecurityAuditCard({
    required this.entries,
    required this.loading,
    required this.isRussian,
    required this.onRefresh,
  });

  final List<UserSecurityAuditEntry> entries;
  final bool loading;
  final bool isRussian;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: kTextDark, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRussian ? 'ЖУРНАЛ БЕЗОПАСНОСТИ' : 'SECURITY LOG',
                  style: _titleStyle(),
                ),
              ),
              IconButton(
                tooltip: isRussian ? 'Обновить' : 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, color: kTextDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isRussian ? 'Загрузка...' : 'Loading...',
                style: _bodyStyle(),
              ),
            )
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isRussian
                    ? 'Пока нет событий. Если SQL еще не применен, журнал начнет заполняться после user_security_audit_events.sql.'
                    : 'No events yet. If SQL is not applied yet, the log will start after user_security_audit_events.sql.',
                style: _bodyStyle(),
              ),
            )
          else
            for (final entry in entries.take(12)) ...[
              _SecurityAuditRow(entry: entry, isRussian: isRussian),
              if (entry != entries.take(12).last)
                Divider(color: Colors.black.withValues(alpha: 0.08)),
            ],
        ],
      ),
    );
  }
}

class _SecurityAuditRow extends StatelessWidget {
  const _SecurityAuditRow({required this.entry, required this.isRussian});

  final UserSecurityAuditEntry entry;
  final bool isRussian;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(entry.eventType), color: kTextDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleFor(entry, isRussian),
                  style: _bodyStyle(color: kTextDark),
                ),
                const SizedBox(height: 3),
                Text(_dateLabel(entry.createdAt), style: _bodyStyle(size: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String eventType) {
    switch (eventType) {
      case UserSecurityAuditEvent.loginEmail:
      case UserSecurityAuditEvent.loginPhone:
        return Icons.login_rounded;
      case UserSecurityAuditEvent.emailChangeRequested:
        return Icons.alternate_email_rounded;
      case UserSecurityAuditEvent.phoneChanged:
        return Icons.phone_iphone_rounded;
      case UserSecurityAuditEvent.passwordChanged:
        return Icons.password_rounded;
      case UserSecurityAuditEvent.mfaEnabled:
      case UserSecurityAuditEvent.mfaSessionVerified:
      case UserSecurityAuditEvent.mfaDisabled:
      case UserSecurityAuditEvent.mfaRecoveryCodesGenerated:
        return Icons.verified_user_rounded;
      case UserSecurityAuditEvent.dataExported:
        return Icons.download_rounded;
      case UserSecurityAuditEvent.accountDeletionRequested:
        return Icons.delete_outline_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  String _titleFor(UserSecurityAuditEntry entry, bool isRussian) {
    if (entry.eventLabel.isNotEmpty) return entry.eventLabel;
    switch (entry.eventType) {
      case UserSecurityAuditEvent.loginEmail:
        return isRussian ? 'Вход по email' : 'Email sign-in';
      case UserSecurityAuditEvent.loginPhone:
        return isRussian ? 'Вход по телефону' : 'Phone sign-in';
      case UserSecurityAuditEvent.emailChangeRequested:
        return isRussian ? 'Запрошена смена email' : 'Email change requested';
      case UserSecurityAuditEvent.phoneChanged:
        return isRussian ? 'Телефон изменен' : 'Phone changed';
      case UserSecurityAuditEvent.passwordChanged:
        return isRussian ? 'Пароль изменен' : 'Password changed';
      case UserSecurityAuditEvent.mfaEnabled:
        return isRussian ? '2FA включена' : '2FA enabled';
      case UserSecurityAuditEvent.mfaSessionVerified:
        return isRussian
            ? 'Сессия подтверждена 2FA'
            : 'Session verified with 2FA';
      case UserSecurityAuditEvent.mfaDisabled:
        return isRussian ? '2FA отключена' : '2FA disabled';
      case UserSecurityAuditEvent.mfaRecoveryCodesGenerated:
        return isRussian
            ? 'Recovery codes созданы'
            : 'Recovery codes generated';
      case UserSecurityAuditEvent.dataExported:
        return isRussian ? 'Данные экспортированы' : 'Data exported';
      case UserSecurityAuditEvent.accountDeletionRequested:
        return isRussian
            ? 'Запрошено удаление аккаунта'
            : 'Account deletion requested';
      default:
        return entry.eventType;
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _MfaContent extends StatelessWidget {
  const _MfaContent({
    required this.status,
    required this.enrollment,
    required this.enrollCodeC,
    required this.sessionCodeC,
    required this.recoveryCodes,
    required this.recoveryStatus,
    required this.recoveryLoading,
    required this.busy,
    required this.isRussian,
    required this.onStartEnrollment,
    required this.onVerifyEnrollment,
    required this.onVerifySession,
    required this.onRemoveFactor,
    required this.onCopySecret,
    required this.onCopyUri,
    required this.onGenerateRecoveryCodes,
    required this.onCopyRecoveryCodes,
  });

  final AccountMfaStatus status;
  final AccountMfaEnrollment? enrollment;
  final TextEditingController enrollCodeC;
  final TextEditingController sessionCodeC;
  final List<String> recoveryCodes;
  final MfaRecoveryCodeStatus? recoveryStatus;
  final bool recoveryLoading;
  final bool busy;
  final bool isRussian;
  final VoidCallback onStartEnrollment;
  final VoidCallback onVerifyEnrollment;
  final VoidCallback? onVerifySession;
  final ValueChanged<Factor> onRemoveFactor;
  final VoidCallback? onCopySecret;
  final VoidCallback? onCopyUri;
  final VoidCallback onGenerateRecoveryCodes;
  final VoidCallback onCopyRecoveryCodes;

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
        if (verified) ...[
          const SizedBox(height: kGap12),
          _RecoveryCodesCard(
            codes: recoveryCodes,
            status: recoveryStatus,
            loading: recoveryLoading,
            busy: busy,
            isRussian: isRussian,
            onGenerate: onGenerateRecoveryCodes,
            onCopy: onCopyRecoveryCodes,
          ),
        ],
      ],
    );
  }
}

class _RecoveryCodesCard extends StatelessWidget {
  const _RecoveryCodesCard({
    required this.codes,
    required this.status,
    required this.loading,
    required this.busy,
    required this.isRussian,
    required this.onGenerate,
    required this.onCopy,
  });

  final List<String> codes;
  final MfaRecoveryCodeStatus? status;
  final bool loading;
  final bool busy;
  final bool isRussian;
  final VoidCallback onGenerate;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final hasCodesToShow = codes.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isRussian ? 'RECOVERY CODES' : 'RECOVERY CODES',
            style: _titleStyle(),
          ),
          const SizedBox(height: 8),
          Text(
            hasCodesToShow
                ? (isRussian
                      ? 'Сохраните эти коды сейчас. После ухода со страницы мы больше не покажем их полностью.'
                      : 'Save these codes now. After leaving this page, we will not show them in full again.')
                : (isRussian
                      ? 'Одноразовые коды помогут восстановить доступ, если Authenticator будет потерян.'
                      : 'One-time codes help recover access if Authenticator is lost.'),
            style: _bodyStyle(),
          ),
          const SizedBox(height: 10),
          if (loading)
            Text(isRussian ? 'Загрузка...' : 'Loading...', style: _bodyStyle())
          else if (status == null)
            Text(
              isRussian
                  ? 'Для включения recovery codes примените SQL mfa_recovery_codes.sql.'
                  : 'Apply mfa_recovery_codes.sql to enable recovery codes.',
              style: _bodyStyle(color: BrandTheme.redTop),
            )
          else
            Text(
              isRussian
                  ? 'Активных кодов: ${status!.activeCount} • использовано/заменено: ${status!.usedCount}'
                  : 'Active codes: ${status!.activeCount} • used/replaced: ${status!.usedCount}',
              style: _bodyStyle(color: kTextDark),
            ),
          if (hasCodesToShow) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final code in codes)
                    SelectableText(
                      code,
                      style: const TextStyle(
                        color: kTextDark,
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: BrandPillButton(
                label: isRussian ? 'СКОПИРОВАТЬ КОДЫ' : 'COPY CODES',
                style: BrandPillStyle.light,
                onTap: busy ? null : onCopy,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: BrandPillButton(
              label: busy
                  ? '...'
                  : (status?.hasCodes ?? false)
                  ? (isRussian ? 'СОЗДАТЬ НОВЫЕ' : 'GENERATE NEW')
                  : (isRussian ? 'СОЗДАТЬ КОДЫ' : 'GENERATE CODES'),
              style: BrandPillStyle.dark,
              onTap: busy ? null : onGenerate,
            ),
          ),
        ],
      ),
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

TextStyle _bodyStyle({Color color = kTextMuted, double size = 14}) {
  return TextStyle(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.28,
  );
}
