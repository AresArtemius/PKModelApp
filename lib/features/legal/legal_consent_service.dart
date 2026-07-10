import 'package:supabase_flutter/supabase_flutter.dart';

import 'legal_client_info_stub.dart';
import 'legal_documents.dart';

Map<String, dynamic> legalConsentMetadata({required String source}) {
  return legalConsentVersionsMetadata(
    source: source,
    userAgent: legalUserAgent(),
  );
}

Future<void> recordLegalConsentIfPossible(
  SupabaseClient supabase, {
  required String source,
}) async {
  final session = supabase.auth.currentSession;
  final user = supabase.auth.currentUser;
  if (session == null || user == null) return;

  final metadata = legalConsentMetadata(source: source);

  try {
    await supabase.auth.updateUser(UserAttributes(data: metadata));
  } catch (_) {
    // The sign-up metadata remains the primary fallback when auth metadata
    // cannot be updated in this client state.
  }

  try {
    await supabase.rpc<void>(
      'record_user_legal_consent',
      params: {
        'p_privacy_policy_version': kLegalVersion,
        'p_terms_version': kLegalVersion,
        'p_cookie_policy_version': kLegalVersion,
        'p_processing_notice_version': kLegalVersion,
        'p_source': source,
        'p_user_agent': metadata['legal_consent_user_agent'] as String? ?? '',
        'p_client_ip': '',
      },
    );
  } catch (_) {
    // SQL can be applied after deploy; auth metadata still preserves consent.
  }
}
