import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_logger.dart';
import '../../core/auth_providers.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String route;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    String text(String key) => (map[key] ?? '').toString().trim();
    DateTime? date(String key) {
      final raw = text(key);
      return raw.isEmpty ? null : DateTime.tryParse(raw);
    }

    return AppNotification(
      id: text('id'),
      title: text('title'),
      body: text('body'),
      route: text('route'),
      createdAt: date('created_at'),
      readAt: date('read_at'),
    );
  }
}

class AppNotificationsService {
  const AppNotificationsService(this._sb);

  static const table = 'app_notifications';

  final SupabaseClient _sb;

  Future<List<AppNotification>> loadForCurrentUser() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    try {
      Future<List<dynamic>> run({required bool includeDeletedFilter}) async {
        var query = _sb
            .from(table)
            .select('id,title,body,route,created_at,read_at')
            .eq('user_id', userId);
        if (includeDeletedFilter) {
          query = query.filter('deleted_at', 'is', null);
        }
        return query.order('created_at', ascending: false).limit(100);
      }

      List<dynamic> rows;
      try {
        rows = await run(includeDeletedFilter: true);
      } on PostgrestException catch (e) {
        if (!SupabaseCompat.isMissingColumn(e, 'deleted_at')) rethrow;
        rows = await run(includeDeletedFilter: false);
      }

      return rows
          .map((row) => AppNotification.fromMap(Map<String, dynamic>.from(row)))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table])) {
        AppLogger.warning('Notifications table is not applied yet', error: e);
        return const [];
      }
      rethrow;
    }
  }

  Future<int> unreadCountForCurrentUser() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return 0;

    try {
      Future<List<dynamic>> run({required bool includeDeletedFilter}) async {
        var query = _sb
            .from(table)
            .select('id')
            .eq('user_id', userId)
            .filter('read_at', 'is', null);
        if (includeDeletedFilter) {
          query = query.filter('deleted_at', 'is', null);
        }
        return query.limit(100);
      }

      try {
        return (await run(includeDeletedFilter: true)).length;
      } on PostgrestException catch (e) {
        if (!SupabaseCompat.isMissingColumn(e, 'deleted_at')) rethrow;
        return (await run(includeDeletedFilter: false)).length;
      }
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table])) {
        AppLogger.warning(
          'Notifications unread count skipped: table is not applied yet',
          error: e,
        );
        return 0;
      }
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;

    await _sb
        .from(table)
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', trimmedId);
  }

  Future<void> markAllRead() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    await _sb
        .from(table)
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .filter('read_at', 'is', null);
  }

  Future<void> deleteOne(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;

    try {
      await _sb
          .from(table)
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', trimmedId);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingColumn(e, 'deleted_at')) rethrow;
      await _sb.from(table).delete().eq('id', trimmedId);
    }
  }

  Future<void> deleteAll() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      await _sb
          .from(table)
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingColumn(e, 'deleted_at')) rethrow;
      await _sb.from(table).delete().eq('user_id', userId);
    }
  }
}

class SecurityNotificationsService {
  const SecurityNotificationsService(this._sb);

  final SupabaseClient _sb;

  Future<void> notifyNewLogin({required String method}) {
    return _enqueue(
      type: 'security_new_login',
      titleRu: 'Новый вход в аккаунт',
      titleEn: 'New account sign-in',
      bodyRu: 'В аккаунт выполнен вход через $method.',
      bodyEn: 'Your account was signed in with $method.',
      data: {'method': method},
    );
  }

  Future<void> notifyPasswordChanged() {
    return _enqueue(
      type: 'security_password_changed',
      titleRu: 'Пароль изменен',
      titleEn: 'Password changed',
      bodyRu: 'Пароль для входа в аккаунт был обновлен.',
      bodyEn: 'Your sign-in password was updated.',
    );
  }

  Future<void> notifyEmailChangeRequested(String email) {
    final cleanEmail = email.trim();
    return _enqueue(
      type: 'security_email_change_requested',
      titleRu: 'Запрошена смена email',
      titleEn: 'Email change requested',
      bodyRu: cleanEmail.isEmpty
          ? 'Для аккаунта запрошено изменение email.'
          : 'Для аккаунта запрошено изменение email на $cleanEmail.',
      bodyEn: cleanEmail.isEmpty
          ? 'An email change was requested for your account.'
          : 'An email change to $cleanEmail was requested for your account.',
      data: {'email': cleanEmail},
    );
  }

  Future<void> notifyPhoneChanged(String phone) {
    final cleanPhone = phone.trim();
    return _enqueue(
      type: 'security_phone_changed',
      titleRu: 'Телефон изменен',
      titleEn: 'Phone changed',
      bodyRu: cleanPhone.isEmpty
          ? 'Телефон для входа в аккаунт был обновлен.'
          : 'Телефон для входа обновлен: $cleanPhone.',
      bodyEn: cleanPhone.isEmpty
          ? 'Your sign-in phone was updated.'
          : 'Your sign-in phone was updated: $cleanPhone.',
      data: {'phone': cleanPhone},
    );
  }

  Future<void> _enqueue({
    required String type,
    required String titleRu,
    required String titleEn,
    required String bodyRu,
    required String bodyEn,
    Map<String, dynamic> data = const {},
  }) async {
    final user = _sb.auth.currentUser;
    final userId = user?.id;
    if (userId == null || userId.isEmpty) return;

    final email = (user?.email ?? '').trim();
    final title = titleRu;
    final body = bodyRu;
    final payload = <String, dynamic>{
      ...data,
      'title_en': titleEn,
      'body_en': bodyEn,
      'send_email': email.isNotEmpty,
      'email_to': email,
      'email_subject': title,
      'email_body': body,
      'created_client_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _sb.rpc<void>(
        'enqueue_app_notification',
        params: {
          'p_user_id': userId,
          'p_title': title,
          'p_body': body,
          'p_route': '/notifications',
          'p_type': type,
          'p_data': payload,
        },
      );
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [
        AppNotificationsService.table,
        NotificationPreferencesService.table,
      ])) {
        AppLogger.warning(
          'Security notification skipped until notification SQL is applied',
          error: e,
        );
        return;
      }
      final message = e.message.toLowerCase();
      if (message.contains('enqueue_app_notification')) {
        AppLogger.warning(
          'Security notification RPC is not applied yet',
          error: e,
        );
        return;
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.warning(
        'Security notification enqueue failed',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.chatEnabled,
    required this.castingEnabled,
    required this.profileEnabled,
    required this.systemEnabled,
  });

  static const defaults = NotificationPreferences(
    pushEnabled: true,
    emailEnabled: true,
    chatEnabled: true,
    castingEnabled: true,
    profileEnabled: true,
    systemEnabled: true,
  );

  final bool pushEnabled;
  final bool emailEnabled;
  final bool chatEnabled;
  final bool castingEnabled;
  final bool profileEnabled;
  final bool systemEnabled;

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    bool flag(String key) => map[key] != false;

    return NotificationPreferences(
      pushEnabled: flag('push_enabled'),
      emailEnabled: flag('email_enabled'),
      chatEnabled: flag('chat_enabled'),
      castingEnabled: flag('casting_enabled'),
      profileEnabled: flag('profile_enabled'),
      systemEnabled: flag('system_enabled'),
    );
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? chatEnabled,
    bool? castingEnabled,
    bool? profileEnabled,
    bool? systemEnabled,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      castingEnabled: castingEnabled ?? this.castingEnabled,
      profileEnabled: profileEnabled ?? this.profileEnabled,
      systemEnabled: systemEnabled ?? this.systemEnabled,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'chat_enabled': chatEnabled,
      'casting_enabled': castingEnabled,
      'profile_enabled': profileEnabled,
      'system_enabled': systemEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class NotificationPreferencesService {
  const NotificationPreferencesService(this._sb);

  static const table = 'notification_preferences';

  final SupabaseClient _sb;

  Future<NotificationPreferences> loadForCurrentUser() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return NotificationPreferences.defaults;
    }

    try {
      final row = await _sb
          .from(table)
          .select(
            'push_enabled,email_enabled,chat_enabled,casting_enabled,'
            'profile_enabled,system_enabled',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return NotificationPreferences.defaults;
      return NotificationPreferences.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table])) {
        AppLogger.warning(
          'Notification preferences table is not applied yet',
          error: e,
        );
        return NotificationPreferences.defaults;
      }
      rethrow;
    }
  }

  Future<void> save(NotificationPreferences preferences) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      await _sb
          .from(table)
          .upsert(preferences.toMap(userId), onConflict: 'user_id');
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table])) {
        AppLogger.warning(
          'Notification preferences save skipped until SQL is applied',
          error: e,
        );
        return;
      }
      rethrow;
    }
  }
}

class PushQaDiagnostics {
  const PushQaDiagnostics({
    required this.deviceRegistered,
    required this.tokenFresh,
    required this.workerSent,
    required this.fcmSecretsOk,
    required this.statusClear,
    required this.latestPushStatus,
    required this.latestPushError,
    required this.enabledTokenCount,
    required this.latestTokenSeenAt,
    required this.latestNotificationAt,
  });

  final bool deviceRegistered;
  final bool tokenFresh;
  final bool workerSent;
  final bool fcmSecretsOk;
  final bool statusClear;
  final String latestPushStatus;
  final String latestPushError;
  final int enabledTokenCount;
  final DateTime? latestTokenSeenAt;
  final DateTime? latestNotificationAt;

  int get passedCount {
    return [
      deviceRegistered,
      tokenFresh,
      workerSent,
      fcmSecretsOk,
      statusClear,
    ].where((item) => item).length;
  }
}

class PushQaDiagnosticsService {
  const PushQaDiagnosticsService(this._sb);

  final SupabaseClient _sb;

  Future<PushQaDiagnostics> loadForCurrentUser() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return _empty();
    }

    try {
      final tokenRows = await _sb
          .from('push_device_tokens')
          .select('enabled,last_seen_at')
          .eq('user_id', userId)
          .eq('enabled', true)
          .order('last_seen_at', ascending: false)
          .limit(10);

      final notificationRows = await _sb
          .from(AppNotificationsService.table)
          .select('push_status,push_error,push_sent_at,created_at')
          .eq('user_id', userId)
          .neq('push_status', 'skipped')
          .order('created_at', ascending: false)
          .limit(20);

      final latestTokenSeenAt = tokenRows
          .map((row) => Map<String, dynamic>.from(row))
          .map((row) => _date(row['last_seen_at']))
          .whereType<DateTime>()
          .firstOrNull;
      final latestNotification = notificationRows
          .map((row) => Map<String, dynamic>.from(row))
          .firstOrNull;
      final latestPushStatus = (latestNotification?['push_status'] ?? '')
          .toString()
          .trim();
      final latestPushError = (latestNotification?['push_error'] ?? '')
          .toString()
          .trim();
      final latestNotificationAt = _date(latestNotification?['created_at']);
      final lowerError = latestPushError.toLowerCase();
      final hasAuthError =
          lowerError.contains('third_party_auth_error') ||
          lowerError.contains('unauthenticated') ||
          lowerError.contains('fcm service account secrets');

      return PushQaDiagnostics(
        deviceRegistered: tokenRows.isNotEmpty,
        tokenFresh:
            latestTokenSeenAt != null &&
            DateTime.now()
                    .toUtc()
                    .difference(latestTokenSeenAt.toUtc())
                    .inDays <=
                7,
        workerSent: latestPushStatus == 'sent',
        fcmSecretsOk: !hasAuthError,
        statusClear: latestPushStatus.isEmpty
            ? false
            : const {
                'pending',
                'processing',
                'sent',
                'failed',
                'skipped',
              }.contains(latestPushStatus),
        latestPushStatus: latestPushStatus,
        latestPushError: latestPushError,
        enabledTokenCount: tokenRows.length,
        latestTokenSeenAt: latestTokenSeenAt,
        latestNotificationAt: latestNotificationAt,
      );
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [
        'push_device_tokens',
        AppNotificationsService.table,
      ])) {
        AppLogger.warning('Push QA tables are not applied yet', error: e);
        return _empty();
      }
      rethrow;
    }
  }

  PushQaDiagnostics _empty() {
    return const PushQaDiagnostics(
      deviceRegistered: false,
      tokenFresh: false,
      workerSent: false,
      fcmSecretsOk: false,
      statusClear: false,
      latestPushStatus: '',
      latestPushError: '',
      enabledTokenCount: 0,
      latestTokenSeenAt: null,
      latestNotificationAt: null,
    );
  }

  DateTime? _date(Object? value) {
    final raw = (value ?? '').toString().trim();
    return raw.isEmpty ? null : DateTime.tryParse(raw);
  }
}

final appNotificationsServiceProvider = Provider<AppNotificationsService>((
  ref,
) {
  return AppNotificationsService(ref.read(supabaseProvider));
});

final securityNotificationsServiceProvider =
    Provider<SecurityNotificationsService>((ref) {
      return SecurityNotificationsService(ref.read(supabaseProvider));
    });

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) {
      return NotificationPreferencesService(ref.read(supabaseProvider));
    });

final pushQaDiagnosticsServiceProvider = Provider<PushQaDiagnosticsService>((
  ref,
) {
  return PushQaDiagnosticsService(ref.read(supabaseProvider));
});

final appNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      ref.watch(currentUserIdProvider);
      return ref.read(appNotificationsServiceProvider).loadForCurrentUser();
    });

final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  ref.watch(currentUserIdProvider);
  return ref.read(appNotificationsServiceProvider).unreadCountForCurrentUser();
});

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
      ref.watch(currentUserIdProvider);
      return ref
          .read(notificationPreferencesServiceProvider)
          .loadForCurrentUser();
    });

final pushQaDiagnosticsProvider = FutureProvider.autoDispose<PushQaDiagnostics>(
  (ref) async {
    ref.watch(currentUserIdProvider);
    return ref.read(pushQaDiagnosticsServiceProvider).loadForCurrentUser();
  },
);
