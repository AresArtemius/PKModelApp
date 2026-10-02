import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'release_update.dart';

/// Sentry wiring. Enabled only when the build carries a DSN
/// (`--dart-define=SENTRY_DSN=…`, set by the deploy workflow from a secret).
class ErrorReporting {
  const ErrorReporting._();

  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  static bool get enabled => _dsn.isNotEmpty;

  static Future<void> init() async {
    if (!enabled) return;
    try {
      await _initSentry().timeout(const Duration(seconds: 15));
    } catch (_) {
      // A slow or blocked CDN must never affect the app.
    }
  }

  static Future<void> _initSentry() async {
    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.release = kAppReleaseSha.isEmpty
          ? 'pk-web@dev'
          : 'pk-web@${kAppReleaseSha.substring(0, 12)}';
      options.tracesSampleRate = 0.1;
      options.sendDefaultPii = false;
      options.attachScreenshot = false;
      options.enableAutoSessionTracking = true;
    });
  }

  /// Reports an error; a no-op without a DSN so callers never check.
  static Future<void> capture(
    Object error,
    StackTrace? stackTrace, {
    String? hint,
  }) async {
    if (!enabled) return;
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        hint: hint == null ? null : Hint.withMap({'context': hint}),
      );
    } catch (_) {
      // Reporting must never take the app down.
    }
  }
}
