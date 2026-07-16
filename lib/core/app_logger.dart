import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  const AppLogger._();

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _write(AppLogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _write(AppLogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _write(AppLogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _write(AppLogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static String report(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String prefix = 'WEB',
  }) {
    final reference =
        '$prefix-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    _write(
      AppLogLevel.error,
      '$message [$reference]',
      error: error,
      stackTrace: stackTrace,
    );
    return reference;
  }

  static void _write(
    AppLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint('[${level.name.toUpperCase()}] $message');
      if (error != null) {
        debugPrint('  error: $error');
      }
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
