import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen_l10n/app_localizations.dart';
import 'app_logger.dart';

enum AppErrorContext { generic, signIn, signUp, phoneSignIn }

class AppErrorMapper {
  const AppErrorMapper._();

  static String message(
    Object? error,
    AppLocalizations t, {
    Object? original,
    AppErrorContext context = AppErrorContext.generic,
  }) {
    final source = original ?? error;
    final rawText = source?.toString().trim() ?? '';

    if (_isNetworkLookupError(rawText)) {
      AppLogger.warning('Network error mapped for UI', error: source);
      return t.networkConnectionError;
    }

    if (source is AuthException) {
      return _authMessage(source, t, context);
    }

    if (source is PostgrestException) {
      AppLogger.error('Supabase request failed', error: source);
      return t.unknownError;
    }

    if (source is String && source.trim().isNotEmpty) {
      final text = source.trim();
      if (_looksTechnical(text)) {
        AppLogger.error('Technical error string mapped for UI', error: text);
        return t.unknownError;
      }
      return text;
    }

    if (source != null) {
      AppLogger.error('Unhandled error mapped for UI', error: source);
    }

    return switch (context) {
      AppErrorContext.signIn ||
      AppErrorContext.phoneSignIn => t.signInGenericError,
      AppErrorContext.signUp => t.signUpGenericError,
      AppErrorContext.generic => t.unknownError,
    };
  }

  static bool _isNetworkLookupError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('nodename nor servname') ||
        lower.contains('could not resolve host');
  }

  static String _authMessage(
    AuthException error,
    AppLocalizations t,
    AppErrorContext context,
  ) {
    final raw = error.message.trim();
    final lower = raw.toLowerCase();
    final providerDisabled =
        lower.contains('unsupported provider') ||
        lower.contains('provider is not enabled') ||
        lower.contains('provider not enabled');

    if (context == AppErrorContext.phoneSignIn &&
        (providerDisabled || lower.contains('phone provider'))) {
      return t.phoneProviderDisabled;
    }

    if (providerDisabled) return t.oauthProviderDisabled;

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return t.localeName == 'ru'
          ? 'Неверный email, телефон или пароль.'
          : 'Invalid email, phone, or password.';
    }

    if (lower.contains('email rate limit') ||
        (lower.contains('rate limit') && lower.contains('email')) ||
        lower.contains('over email send rate limit')) {
      return t.emailRateLimitExceeded;
    }

    if (lower.contains('email not confirmed') ||
        lower.contains('email is not confirmed')) {
      return t.signInEmailNotConfirmed;
    }

    if (context == AppErrorContext.signUp &&
        (lower.contains('database error saving new user') ||
            lower.contains('unexpected_failure'))) {
      return t.signUpDatabaseError;
    }

    if (raw.isNotEmpty) return raw;

    return switch (context) {
      AppErrorContext.signUp => t.signUpGenericError,
      AppErrorContext.signIn ||
      AppErrorContext.phoneSignIn => t.signInGenericError,
      AppErrorContext.generic => t.unknownError,
    };
  }

  static bool _looksTechnical(String text) {
    final lower = text.toLowerCase();
    return lower.contains('postgrestexception') ||
        lower.contains('authexception') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('supabase.co') ||
        lower.contains('/rest/v1/') ||
        lower.contains('pgrst') ||
        lower.contains('sqlstate') ||
        lower.contains('schema cache');
  }
}
