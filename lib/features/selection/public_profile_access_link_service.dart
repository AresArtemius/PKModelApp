import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/public_links.dart';

class PublicProfileAccessLinkService {
  const PublicProfileAccessLinkService(this._sb);

  final SupabaseClient _sb;

  Future<Map<String, String>> createLinks({
    required Iterable<String> profileIds,
    required String source,
    required String relatedId,
  }) async {
    final links = <String, String>{};
    final ids = profileIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    for (final id in ids) {
      links[id] = await _createLink(
        profileId: id,
        source: source,
        relatedId: relatedId,
      );
    }
    return links;
  }

  Future<String> _createLink({
    required String profileId,
    required String source,
    required String relatedId,
  }) async {
    try {
      final token = await _sb.rpc<String>(
        'create_public_profile_access_token',
        params: {
          'p_profile_id': profileId,
          'p_source': source,
          'p_related_id': relatedId,
        },
      );
      return publicProfileTokenLink(profileId: profileId, token: token);
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
          .toLowerCase();
      final missingRpc =
          msg.contains('create_public_profile_access_token') ||
          msg.contains('schema cache') ||
          msg.contains('function');
      if (!missingRpc) rethrow;
      return publicProfileLink(profileId);
    }
  }
}
