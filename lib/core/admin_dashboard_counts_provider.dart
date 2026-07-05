import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_compat.dart';
import 'supabase_provider.dart';

class AdminDashboardCounts {
  const AdminDashboardCounts({
    this.moderation = 0,
    this.agentApplications = 0,
    this.accountMerges = 0,
    this.safety = 0,
  });

  final int moderation;
  final int agentApplications;
  final int accountMerges;
  final int safety;

  int get total => moderation + agentApplications + accountMerges + safety;
}

final adminDashboardCountsProvider =
    FutureProvider.autoDispose<AdminDashboardCounts>((ref) async {
      final sb = ref.read(supabaseProvider);

      final values = await Future.wait<int>([
        _countPendingProfiles(sb),
        _countPendingRows(sb, 'casting_agent_applications'),
        _countPendingRows(sb, 'account_merge_requests'),
        _countOpenSafetyReports(sb),
      ]);

      return AdminDashboardCounts(
        moderation: values[0],
        agentApplications: values[1],
        accountMerges: values[2],
        safety: values[3],
      );
    });

Future<int> _countPendingProfiles(SupabaseClient sb) async {
  try {
    return await sb
        .from('profiles')
        .count(CountOption.exact)
        .eq('status', 'pending');
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['profiles']) ||
        SupabaseCompat.isMissingAnyColumn(e, const ['status'])) {
      return 0;
    }
    return 0;
  }
}

Future<int> _countPendingRows(SupabaseClient sb, String table) async {
  try {
    return await sb
        .from(table)
        .count(CountOption.exact)
        .eq('status', 'pending');
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, [table]) ||
        SupabaseCompat.isMissingAnyColumn(e, const ['status'])) {
      return 0;
    }
    return 0;
  }
}

Future<int> _countOpenSafetyReports(SupabaseClient sb) async {
  try {
    return await sb
        .from('profile_reports')
        .count(CountOption.exact)
        .or('status.is.null,status.eq.open,status.eq.in_review');
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['profile_reports']) ||
        SupabaseCompat.isMissingAnyColumn(e, const ['status'])) {
      return 0;
    }
    return 0;
  }
}
