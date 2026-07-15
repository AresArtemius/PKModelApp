import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

final pushDeviceStatusProvider = FutureProvider.autoDispose<PushDeviceStatus>((
  ref,
) async {
  ref.watch(currentUserIdProvider);
  return ref.read(pushNotificationsServiceProvider).readDeviceStatus();
});

enum PushPermissionState {
  unsupported,
  notConfigured,
  notDetermined,
  denied,
  enabled,
}

class PushDeviceStatus {
  const PushDeviceStatus({
    required this.state,
    required this.platform,
    required this.canRequestPermission,
    required this.canDisable,
  });

  final PushPermissionState state;
  final String platform;
  final bool canRequestPermission;
  final bool canDisable;

  bool get isEnabled => state == PushPermissionState.enabled;
}

class PushNotificationsService {
  PushNotificationsService(this._ref);

  final Ref _ref;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  bool _backgroundHandlerRegistered = false;
  bool _tapHandlingConfigured = false;
  String? _lastOpenedMessageId;
  String? _lastForegroundMessageId;

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
    _foregroundMessageSub ??= FirebaseMessaging.onMessage.listen(
      (message) => _showForegroundMessage(router, message),
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

      final token = await messaging.getToken(vapidKey: _webVapidKeyOrNull);
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

  Future<PushDeviceStatus> readDeviceStatus() async {
    final messaging = await _messagingOrNull();
    if (messaging == null) {
      return PushDeviceStatus(
        state: PushPermissionState.notConfigured,
        platform: _platformName,
        canRequestPermission: false,
        canDisable: false,
      );
    }

    try {
      final supported = await messaging.isSupported();
      if (!supported) {
        return PushDeviceStatus(
          state: PushPermissionState.unsupported,
          platform: _platformName,
          canRequestPermission: false,
          canDisable: false,
        );
      }

      final settings = await messaging.getNotificationSettings();
      final state = switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermissionState.enabled,
        AuthorizationStatus.denied => PushPermissionState.denied,
        AuthorizationStatus.notDetermined => PushPermissionState.notDetermined,
      };

      return PushDeviceStatus(
        state: state,
        platform: _platformName,
        canRequestPermission:
            state == PushPermissionState.notDetermined ||
            state == PushPermissionState.denied,
        canDisable: state == PushPermissionState.enabled,
      );
    } catch (e, stack) {
      AppLogger.warning(
        'Push status read skipped',
        error: e,
        stackTrace: stack,
      );
      return PushDeviceStatus(
        state: PushPermissionState.notConfigured,
        platform: _platformName,
        canRequestPermission: false,
        canDisable: false,
      );
    }
  }

  Future<void> enableForCurrentUser() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) return;
    await syncTokenForUser(userId);
  }

  Future<void> disableForCurrentDevice() async {
    final messaging = await _messagingOrNull();
    if (messaging == null) return;

    final token = await messaging.getToken(vapidKey: _webVapidKeyOrNull);
    if (token != null && token.trim().isNotEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      await _ref
          .read(supabaseProvider)
          .from('push_device_tokens')
          .update({'enabled': false, 'updated_at': now})
          .eq('token', token.trim());
    }

    await messaging.deleteToken();
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
        if (kIsWeb) {
          final options = _firebaseWebOptionsOrNull;
          if (options == null) {
            AppLogger.warning(
              'Web push disabled: Firebase Web options are not configured',
            );
            return null;
          }
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
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

  void _showForegroundMessage(GoRouter router, RemoteMessage message) {
    final messageId = message.messageId;
    if (messageId != null && messageId == _lastForegroundMessageId) return;
    _lastForegroundMessageId = messageId;

    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final title = _displayText(message.notification?.title).isEmpty
        ? _displayText(message.data['title'])
        : _displayText(message.notification?.title);
    final body = _displayText(message.notification?.body).isEmpty
        ? _displayText(message.data['body'])
        : _displayText(message.notification?.body);
    final route = _displayText(message.data['route']);
    final text = [
      if (title.isNotEmpty) title,
      if (body.isNotEmpty) body,
    ].join('\n');

    if (text.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final canOpen = route.isNotEmpty && _isAllowedRoute(route);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(child: Text(text)),
              TextButton(
                onPressed: messenger.hideCurrentSnackBar,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: Text(isRussian ? 'СКРЫТЬ' : 'HIDE'),
              ),
              if (canOpen)
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    router.go(route);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(isRussian ? 'ОТКРЫТЬ' : 'OPEN'),
                ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
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

  String? get _webVapidKeyOrNull {
    if (!kIsWeb) return null;
    const key = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
    return key.trim().isEmpty ? null : key.trim();
  }

  FirebaseOptions? get _firebaseWebOptionsOrNull {
    const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
    const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
    const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
    );
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const measurementId = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');

    final required = [
      apiKey,
      authDomain,
      projectId,
      storageBucket,
      messagingSenderId,
      appId,
    ];
    if (required.any((value) => value.trim().isEmpty)) return null;

    return FirebaseOptions(
      apiKey: apiKey,
      authDomain: authDomain,
      projectId: projectId,
      storageBucket: storageBucket,
      messagingSenderId: messagingSenderId,
      appId: appId,
      measurementId: measurementId.trim().isEmpty ? null : measurementId,
    );
  }

  String _displayText(Object? value) {
    return (value ?? '').toString().trim();
  }

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
