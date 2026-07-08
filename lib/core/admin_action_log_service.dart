import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_compat.dart';

class AdminActionLogEntry {
  const AdminActionLogEntry({
    required this.id,
    required this.actorUserId,
    required this.actorName,
    required this.actorCompany,
    required this.actionType,
    required this.title,
    required this.description,
    required this.targetTable,
    required this.targetId,
    required this.targetText,
    required this.status,
    required this.createdAt,
  });

  factory AdminActionLogEntry.fromMap(Map<String, dynamic> map) {
    return AdminActionLogEntry(
      id: (map['id'] ?? '').toString().trim(),
      actorUserId: (map['actor_user_id'] ?? '').toString().trim(),
      actorName: (map['actor_name'] ?? '').toString().trim(),
      actorCompany: (map['actor_company'] ?? '').toString().trim(),
      actionType: (map['action_type'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      targetTable: (map['target_table'] ?? '').toString().trim(),
      targetId: (map['target_id'] ?? '').toString().trim(),
      targetText: (map['target_text'] ?? '').toString().trim(),
      status: (map['status'] ?? '').toString().trim(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  final String id;
  final String actorUserId;
  final String actorName;
  final String actorCompany;
  final String actionType;
  final String title;
  final String description;
  final String targetTable;
  final String targetId;
  final String targetText;
  final String status;
  final DateTime? createdAt;

  String get actorLabel {
    if (actorCompany.isNotEmpty && actorName.isNotEmpty) {
      return '$actorCompany • $actorName';
    }
    if (actorCompany.isNotEmpty) return actorCompany;
    if (actorName.isNotEmpty) return actorName;
    return actorUserId;
  }
}

class AdminActionLogService {
  const AdminActionLogService(this._sb);

  final SupabaseClient _sb;

  static const _selectColumns =
      'id,actor_user_id,actor_name,actor_company,action_type,title,'
      'description,target_table,target_id,target_text,status,created_at';

  Future<List<AdminActionLogEntry>?> fetch({int limit = 200}) async {
    try {
      final rows = await _sb
          .from('admin_action_logs')
          .select(_selectColumns)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map(
            (row) => AdminActionLogEntry.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['admin_action_logs'])) {
        return null;
      }
      if (SupabaseCompat.isMissingAnyColumn(e, const [
        'actor_name',
        'actor_company',
        'target_table',
        'target_text',
      ])) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> clearAllAuditLogs() async {
    try {
      await _sb.rpc('clear_action_audit_logs');
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRpc(e, 'clear_action_audit_logs')) {
        throw const AdminActionLogSetupRequiredException();
      }
      rethrow;
    }
  }

  Future<void> deleteByIds(Iterable<String> ids) async {
    final cleanIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleanIds.isEmpty) return;
    await _sb.from('admin_action_logs').delete().inFilter('id', cleanIds);
  }

  Future<void> log({
    required String actionType,
    required String title,
    String description = '',
    String targetTable = '',
    String targetId = '',
    String targetText = '',
    String status = 'done',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final actorUserId = _sb.auth.currentUser?.id ?? '';
    if (actorUserId.isEmpty || actionType.trim().isEmpty) return;

    try {
      final actor = await _loadActorSnapshot(actorUserId);
      await _sb.from('admin_action_logs').insert({
        'actor_user_id': actorUserId,
        'actor_name': actor.name,
        'actor_company': actor.company,
        'action_type': actionType.trim(),
        'title': title.trim(),
        'description': description.trim(),
        'target_table': targetTable.trim(),
        'target_id': _nullIfEmpty(targetId),
        'target_text': targetText.trim(),
        'status': status.trim().isEmpty ? 'done' : status.trim(),
        'metadata': metadata,
      });
    } on PostgrestException {
      // Audit is intentionally best-effort: admin operations must not fail
      // because the optional log table/policies have not been applied yet.
      return;
    }
  }

  Future<_AdminActionActorSnapshot> _loadActorSnapshot(String userId) async {
    try {
      final row = await _sb
          .from('user_profiles')
          .select('full_name,company_name')
          .eq('user_id', userId)
          .maybeSingle();
      final map = row ?? const <String, dynamic>{};
      return _AdminActionActorSnapshot(
        name: (map['full_name'] ?? '').toString().trim(),
        company: (map['company_name'] ?? '').toString().trim(),
      );
    } on PostgrestException {
      return const _AdminActionActorSnapshot();
    }
  }

  String? _nullIfEmpty(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }
}

class AdminActionLogSetupRequiredException implements Exception {
  const AdminActionLogSetupRequiredException();
}

class _AdminActionActorSnapshot {
  const _AdminActionActorSnapshot({this.name = '', this.company = ''});

  final String name;
  final String company;
}
