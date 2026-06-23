import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'auth_controller.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key, this.email = ''});

  final String email;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  bool _loading = false;
  String? _message;
  bool _isError = false;

  String get _email => widget.email.trim();

  Future<void> _resend() async {
    if (_loading || _email.isEmpty) return;

    final t = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _message = null;
      _isError = false;
    });

    try {
      await ref.read(authControllerProvider).resendSignUpEmail(_email);
      if (!mounted) return;
      setState(() {
        _message = t.emailVerificationResent;
        _isError = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = AppErrorMapper.message(e, t);
        _isError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = AppErrorMapper.message(e, t);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goLogin() async {
    if (_loading) return;

    final t = AppLocalizations.of(context)!;
    final pending = ref.read(pendingEmailConfirmationProvider);
    final email = _email.isNotEmpty ? _email : pending?.email.trim() ?? '';

    if (pending == null || pending.email.trim() != email || email.isEmpty) {
      setState(() {
        _message = t.emailVerificationLoginManually;
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = t.emailVerificationChecking;
      _isError = false;
    });

    try {
      final auth = ref.read(authControllerProvider);
      final res = await auth.signInWithResponse(
        email: pending.email,
        password: pending.password,
      );
      if (!auth.isEmailConfirmed(res.user)) {
        await auth.signOut();
        if (!mounted) return;
        setState(() {
          _message = t.emailVerificationStillPending;
          _isError = true;
        });
        return;
      }

      ref.read(pendingEmailConfirmationProvider.notifier).state = null;
      if (!mounted) return;
      context.go(Routes.search);
    } on AuthException catch (e) {
      if (!mounted) return;
      final raw = e.message.toLowerCase();
      final message = AppErrorMapper.message(e, t);
      setState(() {
        _message = raw.contains('confirm') || raw.contains('verified')
            ? t.emailVerificationStillPending
            : message;
        _isError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = AppErrorMapper.message(e, t);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: kRegisterPagePad,
                child: Container(
                  width: double.infinity,
                  padding: kRegisterCardPad,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: kRegisterCardWhiteOpacity,
                    ),
                    borderRadius: BorderRadius.circular(kCardRadius),
                    boxShadow: kRegisterCardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.mark_email_unread_rounded,
                        color: BrandTheme.redTop,
                        size: 52,
                      ),
                      const SizedBox(height: kRegisterGap16),
                      Text(
                        t.emailVerificationTitle,
                        textAlign: TextAlign.center,
                        style: kRegisterTitleStyle,
                      ),
                      const SizedBox(height: kRegisterGap12),
                      Text(
                        _email.isEmpty
                            ? t.emailVerificationSubtitleNoEmail
                            : t.emailVerificationSubtitle(_email),
                        textAlign: TextAlign.center,
                        style: kRegisterHintStyle,
                      ),
                      const SizedBox(height: kRegisterGap12),
                      Text(
                        t.emailVerificationExpires,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: kRegisterGap12),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isError ? kTextDanger : kTextMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: kRegisterGap16),
                      SizedBox(
                        height: kRegisterButtonH,
                        child: BrandPillButton(
                          label: _loading
                              ? t.loadingDots
                              : t.emailVerificationGoLoginUpper,
                          style: BrandPillStyle.dark,
                          onTap: _goLogin,
                        ),
                      ),
                      if (_email.isNotEmpty) ...[
                        const SizedBox(height: kRegisterGap12),
                        SizedBox(
                          height: kRegisterButtonH,
                          child: BrandPillButton(
                            label: _loading
                                ? t.loadingDots
                                : t.emailVerificationResendUpper,
                            style: BrandPillStyle.light,
                            onTap: _resend,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
