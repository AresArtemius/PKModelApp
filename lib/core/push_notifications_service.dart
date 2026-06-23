import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_logger.dart';
import 'auth_providers.dart';
import 'router.dart';
import 'supabase_provider.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Firebase may be intentionally unconfigured in local/dev builds.
  }
}

final pushNotificationsServiceProvider = Provider<PushNotificationsService>(
  (ref) => PushNotificationsService(ref),
);

final pushRegistrationProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;

  final service = ref.watch(pushNotificationsServiceProvider);
  await service.syncTokenForUser(userId);

  final tokenRefresh = service.listenForTokenRefresh(userId);
  ref.onDispose(() => tokenRefresh?.cancel());
});

class PushNotificationsService {
  PushNotificationsService(this._ref);

  final Ref _ref;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  bool _backgroundHandlerRegistered = false;
  bool _tapHandlingConfigured = false;
  String? _lastOpenedMessageId;

  Future<void> configureTapHandling(GoRouter router) async {
    if (_tapHandlingConfigured) return;
    _tapHandlingConfigured = true;

    final messaging = await _messagingOrNull();
    if (messaging == null) {
      _tapHandlingConfigured = false;
      return;
    }

    _messageOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openMessageRoute(router, message),
    );

    try {
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _openMessageRoute(router, initialMessage);
      }
    } catch (e, stack) {
      AppLogger.warning(
        'Initial push route skipped',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> syncTokenForUser(String userId) async {
    final messaging = await _messagingOrNull();
    if (messaging == null) return;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.debug(
        'Push permission status: ${settings.authorizationStatus.name}',
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        AppLogger.warning('Push token is empty');
        return;
      }

      final apnsToken = await _readApnsToken(messaging);
      await _saveToken(userId: userId, token: token, apnsToken: apnsToken);
      AppLogger.info('Push token saved for user on $_platformName');
    } catch (e, stack) {
      AppLogger.warning('Push token sync skipped', error: e, stackTrace: stack);
    }
  }

  StreamSubscription<String>? listenForTokenRefresh(String userId) {
    if (!_isFirebaseInitialized) return null;

    return FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;

      try {
        final apnsToken = await _readApnsToken(FirebaseMessaging.instance);
        await _saveToken(userId: userId, token: token, apnsToken: apnsToken);
      } catch (e, stack) {
        AppLogger.warning(
          'Push token refresh skipped',
          error: e,
          stackTrace: stack,
        );
      }
    });
  }

  Future<FirebaseMessaging?> _messagingOrNull() async {
    try {
      if (!_isFirebaseInitialized) {
        await Firebase.initializeApp();
      }
      if (!_backgroundHandlerRegistered) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        _backgroundHandlerRegistered = true;
      }
      return FirebaseMessaging.instance;
    } catch (e, stack) {
      AppLogger.warning(
        'Push notifications disabled until Firebase is configured',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  void _openMessageRoute(GoRouter router, RemoteMessage message) {
    final messageId = message.messageId;
    if (messageId != null && messageId == _lastOpenedMessageId) return;
    _lastOpenedMessageId = messageId;

    final route = message.data['route']?.trim();
    if (route == null || route.isEmpty || !_isAllowedRoute(route)) return;

    router.go(route);
  }

  bool _isAllowedRoute(String route) {
    return route == Routes.invitations ||
        route == Routes.me ||
        route.startsWith(Routes.chatPrefix);
  }

  Future<String?> _readApnsToken(FirebaseMessaging messaging) async {
    if (kIsWeb || !Platform.isIOS) return null;

    try {
      return messaging.getAPNSToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
    required String? apnsToken,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final platform = _platformName;
    final sb = _ref.read(supabaseProvider);

    await sb.from('push_device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'apns_token': apnsToken,
      'enabled': true,
      'last_seen_at': now,
      'updated_at': now,
    }, onConflict: 'token');
  }

  bool get _isFirebaseInitialized => Firebase.apps.isNotEmpty;

  String get _platformName {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
