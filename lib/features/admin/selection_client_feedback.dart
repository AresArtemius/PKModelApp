import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_provider.dart';

const String _clientKeyPrefsKey = 'public_selection_client_key_v1';

enum SelectionClientVote {
  selected('selected'),
  reserve('reserve'),
  rejected('rejected');

  const SelectionClientVote(this.storageValue);

  final String storageValue;
}

SelectionClientVote? selectionClientVoteFromString(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'selected' || 'chosen' || 'liked' || 'like' => SelectionClientVote.selected,
    'reserve' || 'reserved' => SelectionClientVote.reserve,
    'rejected' || 'reject' => SelectionClientVote.rejected,
    _ => null,
  };
}

class SelectionClientFeedback {
  const SelectionClientFeedback({
    required this.profileId,
    required this.clientKey,
    required this.comment,
    this.vote,
  });

  factory SelectionClientFeedback.fromMap(Map<String, dynamic> map) {
    return SelectionClientFeedback(
      profileId: (map['profile_id'] ?? '').toString(),
      clientKey: (map['client_key'] ?? '').toString(),
      vote: selectionClientVoteFromString(map['vote']),
      comment: (map['comment'] ?? '').toString().trim(),
    );
  }

  final String profileId;
  final String clientKey;
  final SelectionClientVote? vote;
  final String comment;
}

class SelectionClientFeedbackRequest {
  const SelectionClientFeedbackRequest({
    required this.selectionId,
    required this.clientKey,
  });

  final String selectionId;
  final String clientKey;

  @override
  bool operator ==(Object other) {
    return other is SelectionClientFeedbackRequest &&
        selectionId == other.selectionId &&
        clientKey == other.clientKey;
  }

  @override
  int get hashCode => Object.hash(selectionId, clientKey);
}

class SelectionClientFeedbackService {
  const SelectionClientFeedbackService(this._sb);

  final SupabaseClient _sb;

  Future<Map<String, SelectionClientFeedback>> fetchClientFeedback({
    required String selectionId,
    required String clientKey,
  }) async {
    if (selectionId.isEmpty || clientKey.isEmpty) return const {};

    try {
      final rows = await _sb.rpc(
        'get_selection_client_feedback',
        params: {'p_selection_id': selectionId, 'p_client_key': clientKey},
      );
      return _feedbackMapFromRows(rows);
    } on PostgrestException catch (e) {
      if (_isMissingFeedbackSchema(e)) return const {};
      rethrow;
    }
  }

  Future<List<SelectionClientFeedback>> fetchAgentFeedback(
    String selectionId,
  ) async {
    if (selectionId.isEmpty) return const [];

    try {
      final rows = await _sb
          .from('selection_client_feedback')
          .select('profile_id,client_key,vote,comment,updated_at')
          .eq('selection_id', selectionId)
          .order('updated_at', ascending: false);

      return (rows as List)
          .map(
            (row) => SelectionClientFeedback.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (_isMissingFeedbackSchema(e)) return const [];
      rethrow;
    }
  }

  Future<void> saveFeedback({
    required String selectionId,
    required String profileId,
    required String clientKey,
    SelectionClientVote? vote,
    String comment = '',
  }) async {
    if (selectionId.isEmpty || profileId.isEmpty || clientKey.isEmpty) return;

    try {
      await _sb.rpc(
        'save_selection_client_feedback',
        params: {
          'p_selection_id': selectionId,
          'p_profile_id': profileId,
          'p_client_key': clientKey,
          'p_vote': vote?.storageValue,
          'p_comment': comment.trim(),
        },
      );
    } on PostgrestException catch (e) {
      if (!_isMissingFeedbackSchema(e)) rethrow;

      await _sb.from('selection_client_feedback').upsert({
        'selection_id': selectionId,
        'profile_id': profileId,
        'client_key': clientKey,
        'vote': vote?.storageValue,
        'comment': comment.trim(),
      }, onConflict: 'selection_id,profile_id,client_key');
    }
  }

  Map<String, SelectionClientFeedback> _feedbackMapFromRows(Object? rows) {
    if (rows is! List) return const {};

    final result = <String, SelectionClientFeedback>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final feedback = SelectionClientFeedback.fromMap(
        Map<String, dynamic>.from(row),
      );
      if (feedback.profileId.isNotEmpty) {
        result[feedback.profileId] = feedback;
      }
    }
    return result;
  }

  bool _isMissingFeedbackSchema(PostgrestException e) {
    final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'.toLowerCase();
    return (msg.contains('selection_client_feedback') ||
            msg.contains('get_selection_client_feedback') ||
            msg.contains('save_selection_client_feedback') ||
            msg.contains('function') ||
            msg.contains('schema cache')) &&
        (msg.contains('not found') ||
            msg.contains('schema cache') ||
            msg.contains('relation') ||
            msg.contains('table') ||
            msg.contains('function'));
  }
}

final selectionClientFeedbackServiceProvider =
    Provider<SelectionClientFeedbackService>((ref) {
      return SelectionClientFeedbackService(ref.read(supabaseProvider));
    });

final selectionClientKeyProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_clientKeyPrefsKey);
  if (existing != null && existing.trim().isNotEmpty) {
    return existing.trim();
  }

  final random = Random.secure().nextInt(1 << 32);
  final key =
      'client_${DateTime.now().microsecondsSinceEpoch}_${random.toRadixString(16)}';
  await prefs.setString(_clientKeyPrefsKey, key);
  return key;
});

final selectionClientFeedbackProvider = FutureProvider.autoDispose
    .family<
      Map<String, SelectionClientFeedback>,
      SelectionClientFeedbackRequest
    >((ref, request) {
      return ref
          .watch(selectionClientFeedbackServiceProvider)
          .fetchClientFeedback(
            selectionId: request.selectionId,
            clientKey: request.clientKey,
          );
    });

final selectionAgentFeedbackProvider = FutureProvider.autoDispose
    .family<List<SelectionClientFeedback>, String>((ref, selectionId) {
      return ref
          .watch(selectionClientFeedbackServiceProvider)
          .fetchAgentFeedback(selectionId);
    });
