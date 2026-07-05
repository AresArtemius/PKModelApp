import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_compat.dart';

class ProfileActionLogService {
  const ProfileActionLogService(this._sb);

  final SupabaseClient _sb;

  Future<List<Map<String, dynamic>>?> fetchForProfile({
    required String profileId,
    int limit = 8,
  }) async {
    final id = profileId.trim();
    if (id.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final rows = await _sb
          .from('profile_action_logs')
          .select(
            'id,profile_id,target_user_id,actor_user_id,actor_name,actor_company,'
            'actor_avatar_url,action_type,title,description,template_key,'
            'template_body,status,related_table,related_id,related_text,'
            'delivered_at,read_at,created_at',
          )
          .eq('profile_id', id)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['profile_action_logs'])) {
        return null;
      }
      if (SupabaseCompat.isMissingAnyColumn(e, const [
        'actor_name',
        'actor_company',
        'template_key',
        'template_body',
        'delivered_at',
        'read_at',
      ])) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> log({
    required String profileId,
    required String actionType,
    required String title,
    String targetUserId = '',
    String description = '',
    String templateKey = '',
    String templateBody = '',
    String status = 'created',
    String relatedTable = '',
    String relatedId = '',
    String relatedText = '',
    Map<String, dynamic> metadata = const <String, dynamic>{},
    DateTime? deliveredAt,
    DateTime? readAt,
  }) async {
    final actorUserId = _sb.auth.currentUser?.id ?? '';
    final cleanProfileId = profileId.trim();
    if (actorUserId.isEmpty || cleanProfileId.isEmpty) return;

    try {
      final actor = await _loadActorSnapshot(actorUserId);
      await _sb.from('profile_action_logs').insert({
        'profile_id': cleanProfileId,
        'target_user_id': _nullIfEmpty(targetUserId),
        'actor_user_id': actorUserId,
        'actor_name': actor.name,
        'actor_company': actor.company,
        'actor_avatar_url': actor.avatarUrl,
        'action_type': actionType.trim(),
        'title': title.trim(),
        'description': description.trim(),
        'template_key': templateKey.trim(),
        'template_body': templateBody.trim(),
        'status': status.trim().isEmpty ? 'created' : status.trim(),
        'related_table': relatedTable.trim(),
        'related_id': _nullIfEmpty(relatedId),
        'related_text': relatedText.trim(),
        'metadata': metadata,
        'delivered_at': deliveredAt?.toUtc().toIso8601String(),
        'read_at': readAt?.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      final isMissing =
          SupabaseCompat.isMissingRelation(e, const ['profile_action_logs']) ||
          SupabaseCompat.isMissingAnyColumn(e, const [
            'actor_name',
            'actor_company',
            'template_key',
            'template_body',
            'delivered_at',
            'read_at',
          ]);
      if (!isMissing) rethrow;
    }
  }

  Future<void> markRelatedRead({
    required String relatedTable,
    required String relatedId,
    DateTime? readAt,
  }) async {
    final cleanId = relatedId.trim();
    if (cleanId.isEmpty) return;
    try {
      await _sb
          .from('profile_action_logs')
          .update({
            'status': 'read',
            'read_at': (readAt ?? DateTime.now()).toUtc().toIso8601String(),
          })
          .eq('related_table', relatedTable.trim())
          .eq('related_id', cleanId);
    } on PostgrestException {
      // Audit logging is intentionally best-effort: never block read state updates.
    }
  }

  Future<_ProfileActionActorSnapshot> _loadActorSnapshot(String userId) async {
    try {
      final row = await _sb
          .from('user_profiles')
          .select('full_name,company_name,avatar_url')
          .eq('user_id', userId)
          .maybeSingle();
      final map = row ?? const <String, dynamic>{};
      final fullName = (map['full_name'] ?? '').toString().trim();
      final company = (map['company_name'] ?? '').toString().trim();
      return _ProfileActionActorSnapshot(
        name: fullName,
        company: company,
        avatarUrl: (map['avatar_url'] ?? '').toString().trim(),
      );
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRelation(e, const ['user_profiles'])) {
        rethrow;
      }
    }
    return const _ProfileActionActorSnapshot();
  }

  String? _nullIfEmpty(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }
}

class _ProfileActionActorSnapshot {
  const _ProfileActionActorSnapshot({
    this.name = '',
    this.company = '',
    this.avatarUrl = '',
  });

  final String name;
  final String company;
  final String avatarUrl;
}
