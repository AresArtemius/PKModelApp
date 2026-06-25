import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import 'casting_response_status.dart';
import 'casting_model.dart';

class CastingsException implements Exception {
  CastingsException(this.message, {this.original});
  final String message;
  final Object? original;

  @override
  String toString() => message;
}

class CastingsService {
  const CastingsService(this._sb);
  final SupabaseClient _sb;

  static const int castingsPageLimit = 80;

  Future<List<CastingModel>> fetchCastings() async {
    try {
      final rows = await _sb
          .from('castings')
          .select('id,title,description,rights,fee,dates,created_at')
          .order('created_at', ascending: false)
          .limit(castingsPageLimit);

      return (rows as List<dynamic>)
          .map((e) => CastingModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw CastingsException('Failed to fetch castings', original: e);
    } catch (e) {
      throw CastingsException('Failed to fetch castings', original: e);
    }
  }

  Future<void> respond({
    required String castingId,
    required String profileId,
    required String userId,
  }) async {
    try {
      await _sb
          .from('casting_responses')
          .upsert(
            {
              'casting_id': castingId,
              'profile_id': profileId,
              'user_id': userId,
            },
            onConflict: 'casting_id,profile_id',
            ignoreDuplicates: true,
          );
    } on PostgrestException catch (e) {
      throw CastingsException('Failed to respond', original: e);
    } catch (e) {
      throw CastingsException('Failed to respond', original: e);
    }
  }

  Future<void> respondMany({
    required String castingId,
    required List<String> profileIds,
    required String userId,
  }) async {
    final rows = profileIds
        .where((e) => e.trim().isNotEmpty)
        .map(
          (pid) => {
            'casting_id': castingId,
            'profile_id': pid,
            'user_id': userId,
          },
        )
        .toList(growable: false);

    if (rows.isEmpty) return;

    try {
      await _sb
          .from('casting_responses')
          .upsert(
            rows,
            onConflict: 'casting_id,profile_id',
            ignoreDuplicates: true,
          );
    } on PostgrestException catch (e) {
      throw CastingsException('Failed to respond', original: e);
    } catch (e) {
      throw CastingsException('Failed to respond', original: e);
    }
  }

  Future<Map<String, CastingResponseStatus>> fetchMyCastingStatuses({
    required String userId,
  }) async {
    try {
      final rows = await _sb
          .from('casting_responses')
          .select('casting_id,status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(300);

      final grouped = <String, List<CastingResponseStatus>>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final castingId = (map['casting_id'] ?? '').toString().trim();
        if (castingId.isEmpty) continue;

        grouped
            .putIfAbsent(castingId, () => <CastingResponseStatus>[])
            .add(castingResponseStatusFromString(map['status']?.toString()));
      }

      return grouped.map(
        (castingId, statuses) =>
            MapEntry(castingId, mergeCastingResponseStatuses(statuses)),
      );
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingColumn(e, 'status')) {
        return const <String, CastingResponseStatus>{};
      }
      throw CastingsException('Failed to fetch response statuses', original: e);
    } catch (e) {
      throw CastingsException('Failed to fetch response statuses', original: e);
    }
  }

  Future<void> deleteCasting(String castingId) async {
    final id = castingId.trim();
    if (id.isEmpty) return;

    try {
      await _sb.rpc('admin_delete_casting', params: {'p_casting_id': id});
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'admin_delete_casting')) {
        throw CastingsException('Failed to delete casting', original: e);
      }
      try {
        await _deleteCastingDirectly(id);
      } on PostgrestException catch (second) {
        throw CastingsException('Failed to delete casting', original: second);
      }
    } catch (e) {
      throw CastingsException('Failed to delete casting', original: e);
    }
  }

  Future<void> _deleteCastingDirectly(String castingId) async {
    try {
      await _sb.from('casting_responses').delete().eq('casting_id', castingId);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRelation(e, const ['casting_responses'])) {
        rethrow;
      }
    }

    try {
      await _sb.from('casting_chats').delete().eq('casting_id', castingId);
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRelation(e, const ['casting_chats'])) {
        rethrow;
      }
    }

    await _sb.from('castings').delete().eq('id', castingId);
  }
}
