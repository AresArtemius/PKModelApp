import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'supabase_compat.dart';
import 'supabase_provider.dart';

final userSecurityAuditServiceProvider = Provider<UserSecurityAuditService>((
  ref,
) {
  return UserSecurityAuditService(ref.read(supabaseProvider));
});

final userSecurityAuditEntriesProvider =
    FutureProvider.autoDispose<List<UserSecurityAuditEntry>>((ref) {
      return ref.read(userSecurityAuditServiceProvider).loadRecent();
    });

class UserSecurityAuditEvent {
  const UserSecurityAuditEvent._();

  static const loginEmail = 'login_email';
  static const loginPhone = 'login_phone';
  static const emailChangeRequested = 'email_change_requested';
  static const phoneChanged = 'phone_changed';
  static const passwordChanged = 'password_changed';
  static const mfaEnabled = 'mfa_enabled';
  static const mfaSessionVerified = 'mfa_session_verified';
  static const mfaDisabled = 'mfa_disabled';
  static const dataExported = 'data_exported';
  static const accountDeletionRequested = 'account_deletion_requested';
}

class UserSecurityAuditEntry {
  const UserSecurityAuditEntry({
    required this.id,
    required this.eventType,
    required this.eventLabel,
    required this.metadata,
    required this.createdAt,
  });

  factory UserSecurityAuditEntry.fromMap(Map<String, dynamic> map) {
    return UserSecurityAuditEntry(
      id: (map['id'] ?? '').toString().trim(),
      eventType: (map['event_type'] ?? '').toString().trim(),
      eventLabel: (map['event_label'] ?? '').toString().trim(),
      metadata: _metadataFromMap(map['metadata']),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  final String id;
  final String eventType;
  final String eventLabel;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
}

class UserSecurityAuditService {
  const UserSecurityAuditService(this._sb);

  final SupabaseClient _sb;

  static const table = 'user_security_audit_events';
  static const _selectColumns = 'id,event_type,event_label,metadata,created_at';

  Future<List<UserSecurityAuditEntry>> loadRecent({int limit = 30}) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    try {
      final rows = await _sb
          .from(table)
          .select(_selectColumns)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map(
            (row) =>
                UserSecurityAuditEntry.fromMap(Map<String, dynamic>.from(row)),
          )
          .where((entry) => entry.id.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table]) ||
          SupabaseCompat.isMissingAnyColumn(e, const [
            'event_type',
            'event_label',
            'metadata',
          ])) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> log({
    required String eventType,
    String label = '',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final userId = _sb.auth.currentUser?.id;
    final cleanType = eventType.trim();
    if (userId == null || userId.isEmpty || cleanType.isEmpty) return;

    try {
      await _sb.from(table).insert({
        'user_id': userId,
        'event_type': cleanType,
        'event_label': label.trim(),
        'metadata': metadata,
      });
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const [table])) return;
      AppLogger.warning('Security audit log skipped', error: e);
    } catch (e) {
      AppLogger.warning('Security audit log skipped', error: e);
    }
  }
}

Map<String, dynamic> _metadataFromMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
