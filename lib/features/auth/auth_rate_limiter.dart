import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

enum AuthRateLimitAction {
  signIn,
  phoneSignIn,
  phoneOtpSend,
  phoneOtpVerify,
  emailVerificationResend,
}

class AuthRateLimitState {
  const AuthRateLimitState({
    required this.allowed,
    this.messageRu = '',
    this.messageEn = '',
  });

  final bool allowed;
  final String messageRu;
  final String messageEn;

  String message(bool isRussian) => isRussian ? messageRu : messageEn;
}

class _AuthRateLimitConfig {
  const _AuthRateLimitConfig({
    required this.maxAttempts,
    required this.window,
    required this.lock,
    this.cooldown = Duration.zero,
  });

  final int maxAttempts;
  final Duration window;
  final Duration lock;
  final Duration cooldown;
}

class AuthRateLimiter {
  const AuthRateLimiter._();

  static const instance = AuthRateLimiter._();
  static const _prefix = 'auth_rate_limit_v1';

  Future<AuthRateLimitState> check(
    AuthRateLimitAction action,
    String subject,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = _baseKey(action, subject);
    final lockUntil = prefs.getInt('$base:lock') ?? 0;
    if (lockUntil > now) {
      return _blockedState(lockUntil - now);
    }

    final cooldownUntil = prefs.getInt('$base:cooldown') ?? 0;
    if (cooldownUntil > now) {
      return _cooldownState(cooldownUntil - now);
    }

    return const AuthRateLimitState(allowed: true);
  }

  Future<void> recordFailure(AuthRateLimitAction action, String subject) async {
    final config = _config(action);
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = _baseKey(action, subject);
    final windowStart = now - config.window.inMilliseconds;
    final attempts =
        (prefs.getStringList('$base:attempts') ?? const <String>[])
            .map((value) => int.tryParse(value) ?? 0)
            .where((value) => value >= windowStart)
            .toList(growable: true)
          ..add(now);

    if (attempts.length >= config.maxAttempts) {
      await prefs.setInt('$base:lock', now + config.lock.inMilliseconds);
      await prefs.remove('$base:attempts');
      return;
    }

    await prefs.setStringList(
      '$base:attempts',
      attempts.map((value) => value.toString()).toList(growable: false),
    );
  }

  Future<void> recordSuccess(AuthRateLimitAction action, String subject) async {
    final prefs = await SharedPreferences.getInstance();
    final base = _baseKey(action, subject);
    await prefs.remove('$base:attempts');
    await prefs.remove('$base:lock');
  }

  Future<void> recordSent(AuthRateLimitAction action, String subject) async {
    final config = _config(action);
    if (config.cooldown == Duration.zero) return;
    final prefs = await SharedPreferences.getInstance();
    final base = _baseKey(action, subject);
    final until =
        DateTime.now().millisecondsSinceEpoch + config.cooldown.inMilliseconds;
    await prefs.setInt('$base:cooldown', until);
  }

  _AuthRateLimitConfig _config(AuthRateLimitAction action) {
    return switch (action) {
      AuthRateLimitAction.signIn => const _AuthRateLimitConfig(
        maxAttempts: 5,
        window: Duration(minutes: 15),
        lock: Duration(minutes: 5),
      ),
      AuthRateLimitAction.phoneSignIn => const _AuthRateLimitConfig(
        maxAttempts: 5,
        window: Duration(minutes: 15),
        lock: Duration(minutes: 5),
      ),
      AuthRateLimitAction.phoneOtpSend => const _AuthRateLimitConfig(
        maxAttempts: 3,
        window: Duration(minutes: 10),
        lock: Duration(minutes: 10),
        cooldown: Duration(seconds: 60),
      ),
      AuthRateLimitAction.phoneOtpVerify => const _AuthRateLimitConfig(
        maxAttempts: 5,
        window: Duration(minutes: 10),
        lock: Duration(minutes: 10),
      ),
      AuthRateLimitAction.emailVerificationResend => const _AuthRateLimitConfig(
        maxAttempts: 3,
        window: Duration(minutes: 10),
        lock: Duration(minutes: 10),
        cooldown: Duration(seconds: 90),
      ),
    };
  }

  String _baseKey(AuthRateLimitAction action, String subject) {
    final cleanSubject = subject.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9а-я@+._-]+'),
      '_',
    );
    final safeSubject = cleanSubject.isEmpty ? 'empty' : cleanSubject;
    return '$_prefix:${action.name}:$safeSubject';
  }

  AuthRateLimitState _blockedState(int remainingMs) {
    final minutes = _ceilMinutes(remainingMs);
    return AuthRateLimitState(
      allowed: false,
      messageRu: 'Слишком много попыток. Попробуйте снова через $minutes мин.',
      messageEn: 'Too many attempts. Try again in $minutes min.',
    );
  }

  AuthRateLimitState _cooldownState(int remainingMs) {
    final seconds = math.max(1, (remainingMs / 1000).ceil());
    return AuthRateLimitState(
      allowed: false,
      messageRu: 'Повторить можно через $seconds сек.',
      messageEn: 'You can try again in $seconds sec.',
    );
  }

  int _ceilMinutes(int milliseconds) {
    return math.max(1, (milliseconds / Duration.millisecondsPerMinute).ceil());
  }
}
