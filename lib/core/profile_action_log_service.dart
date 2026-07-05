import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_compat.dart';

enum ProfileActionLogType { all, invite, selection, folder, message }

class ProfileActionLogEntry {
  const ProfileActionLogEntry({
    required this.id,
    required this.profileId,
    required this.targetUserId,
    required this.actorUserId,
    required this.actorName,
    required this.actorCompany,
    required this.actorAvatarUrl,
    required this.actionType,
    required this.title,
    required this.description,
    required this.templateKey,
    required this.templateBody,
    required this.status,
    required this.relatedTable,
    required this.relatedId,
    required this.relatedText,
    required this.deliveredAt,
    required this.readAt,
    required this.createdAt,
  });

  factory ProfileActionLogEntry.fromMap(Map<String, dynamic> map) {
    return ProfileActionLogEntry(
      id: (map['id'] ?? '').toString().trim(),
      profileId: (map['profile_id'] ?? '').toString().trim(),
      targetUserId: (map['target_user_id'] ?? '').toString().trim(),
      actorUserId: (map['actor_user_id'] ?? '').toString().trim(),
      actorName: (map['actor_name'] ?? '').toString().trim(),
      actorCompany: (map['actor_company'] ?? '').toString().trim(),
      actorAvatarUrl: (map['actor_avatar_url'] ?? '').toString().trim(),
      actionType: (map['action_type'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      templateKey: (map['template_key'] ?? '').toString().trim(),
      templateBody: (map['template_body'] ?? '').toString().trim(),
      status: (map['status'] ?? '').toString().trim(),
      relatedTable: (map['related_table'] ?? '').toString().trim(),
      relatedId: (map['related_id'] ?? '').toString().trim(),
      relatedText: (map['related_text'] ?? '').toString().trim(),
      deliveredAt: DateTime.tryParse((map['delivered_at'] ?? '').toString()),
      readAt: DateTime.tryParse((map['read_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  final String id;
  final String profileId;
  final String targetUserId;
  final String actorUserId;
  final String actorName;
  final String actorCompany;
  final String actorAvatarUrl;
  final String actionType;
  final String title;
  final String description;
  final String templateKey;
  final String templateBody;
  final String status;
  final String relatedTable;
  final String relatedId;
  final String relatedText;
  final DateTime? deliveredAt;
  final DateTime? readAt;
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

class ProfileActionLogService {
  const ProfileActionLogService(this._sb);

  final SupabaseClient _sb;

  static const _selectColumns =
      'id,profile_id,target_user_id,actor_user_id,actor_name,actor_company,'
      'actor_avatar_url,action_type,title,description,template_key,'
      'template_body,status,related_table,related_id,related_text,'
      'delivered_at,read_at,created_at';

  Future<List<ProfileActionLogEntry>?> fetchForProfile({
    required String profileId,
    int limit = 8,
    ProfileActionLogType type = ProfileActionLogType.all,
  }) async {
    final id = profileId.trim();
    if (id.isEmpty) return const <ProfileActionLogEntry>[];
    try {
      var query = _sb
          .from('profile_action_logs')
          .select(_selectColumns)
          .eq('profile_id', id);
      query = _applyTypeFilter(query, type);
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return _rowsFromResponse(rows);
    } on PostgrestException catch (e) {
      if (_isUnavailable(e)) return null;
      rethrow;
    }
  }

  Future<List<ProfileActionLogEntry>?> fetchAdminLogs({
    int limit = 80,
    ProfileActionLogType type = ProfileActionLogType.all,
  }) async {
    try {
      var query = _sb.from('profile_action_logs').select(_selectColumns);
      query = _applyTypeFilter(query, type);
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return _rowsFromResponse(rows);
    } on PostgrestException catch (e) {
      if (_isUnavailable(e)) return null;
      rethrow;
    }
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyTypeFilter(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
    ProfileActionLogType type,
  ) {
    return switch (type) {
      ProfileActionLogType.invite => query.eq('action_type', 'invite'),
      ProfileActionLogType.selection => query.eq('action_type', 'selection'),
      ProfileActionLogType.folder => query.eq('action_type', 'folder'),
      ProfileActionLogType.message => query.eq('action_type', 'message'),
      ProfileActionLogType.all => query,
    };
  }

  List<ProfileActionLogEntry> _rowsFromResponse(dynamic rows) {
    return (rows as List)
        .map(
          (row) => ProfileActionLogEntry.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  bool _isUnavailable(PostgrestException e) {
    return SupabaseCompat.isMissingRelation(e, const ['profile_action_logs']) ||
        SupabaseCompat.isMissingAnyColumn(e, const [
          'actor_name',
          'actor_company',
          'template_key',
          'template_body',
          'delivered_at',
          'read_at',
        ]);
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
