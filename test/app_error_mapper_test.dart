import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/core/app_error_mapper.dart';
import 'package:modelapp/gen_l10n/app_localizations_en.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final t = AppLocalizationsEn();

  test('maps network lookup failures to a friendly connection message', () {
    final message = AppErrorMapper.message(
      "ClientException with SocketException: Failed host lookup: 'example.supabase.co'",
      t,
    );

    expect(message, t.networkConnectionError);
  });

  test('maps disabled phone provider errors to phone-specific copy', () {
    final message = AppErrorMapper.message(
      const AuthException('Unsupported provider: phone provider'),
      t,
      context: AppErrorContext.phoneSignIn,
    );

    expect(message, t.phoneProviderDisabled);
  });

  test('maps signup database trigger failures to the setup hint', () {
    final message = AppErrorMapper.message(
      const AuthException('Database error saving new user'),
      t,
      context: AppErrorContext.signUp,
    );

    expect(message, t.signUpDatabaseError);
  });

  test('maps email rate limits to localized copy', () {
    final message = AppErrorMapper.message(
      const AuthException('email rate limit exceeded'),
      t,
      context: AppErrorContext.signUp,
    );

    expect(message, t.emailRateLimitExceeded);
    expect(message, isNot(contains('email rate limit exceeded')));
  });

  test('hides Postgrest details from UI messages', () {
    final message = AppErrorMapper.message(
      const PostgrestException(
        message: 'Could not find the table',
        code: 'PGRST205',
        details: 'Not Found',
        hint: 'Check schema cache',
      ),
      t,
    );

    expect(message, t.unknownError);
    expect(message, isNot(contains('Could not find the table')));
    expect(message, isNot(contains('PGRST205')));
  });

  test('hides technical string details from UI messages', () {
    final message = AppErrorMapper.message(
      'PostgrestException(message: Could not find table, code: PGRST205)',
      t,
    );

    expect(message, t.unknownError);
  });
}
