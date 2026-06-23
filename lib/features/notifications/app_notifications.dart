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

final appNotificationsServiceProvider = Provider<AppNotificationsService>((
  ref,
) {
  return AppNotificationsService(ref.read(supabaseProvider));
});

final appNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      ref.watch(currentUserIdProvider);
      return ref.read(appNotificationsServiceProvider).loadForCurrentUser();
    });
