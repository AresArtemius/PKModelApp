import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'roles_provider.dart';
import 'supabase_provider.dart';

enum BillingPlan {
  free('free'),
  modelPro('model_pro'),
  castingAgentPro('casting_agent_pro'),
  agencyAdmin('agency_admin');

  const BillingPlan(this.storageValue);

  final String storageValue;
}

BillingPlan billingPlanFromStorage(Object? value) {
  final plan = value?.toString().toLowerCase().trim();
  return switch (plan) {
    'model_pro' => BillingPlan.modelPro,
    'casting_agent_pro' => BillingPlan.castingAgentPro,
    'agency_admin' => BillingPlan.agencyAdmin,
    _ => BillingPlan.free,
  };
}

@immutable
class AccountEntitlements {
  const AccountEntitlements({
    required this.plan,
    required this.role,
    required this.isPaidActive,
    required this.maxProfilesPerSelection,
    required this.maxActiveSelections,
    required this.canExportBrandedPdf,
    required this.canUseAgentFolders,
    required this.canUseAgentNotes,
    required this.canBoostProfiles,
    required this.canUseSelectionChat,
    required this.includedProfileBoosts,
  });

  final BillingPlan plan;
  final AccountRole role;
  final bool isPaidActive;
  final int? maxProfilesPerSelection;
  final int? maxActiveSelections;
  final bool canExportBrandedPdf;
  final bool canUseAgentFolders;
  final bool canUseAgentNotes;
  final bool canBoostProfiles;
  final bool canUseSelectionChat;
  final int includedProfileBoosts;

  bool get hasSelectionSizeLimit => maxProfilesPerSelection != null;

  bool allowsSelectionSize(int count) {
    final limit = maxProfilesPerSelection;
    return limit == null || count <= limit;
  }

  static AccountEntitlements free(AccountRole role) {
    final canCreateSelections = accountRoleCanCreateSelections(role);
    return AccountEntitlements(
      plan: BillingPlan.free,
      role: role,
      isPaidActive: false,
      maxProfilesPerSelection: canCreateSelections ? 10 : 0,
      maxActiveSelections: canCreateSelections ? 3 : 0,
      canExportBrandedPdf: false,
      canUseAgentFolders: false,
      canUseAgentNotes: false,
      canBoostProfiles: false,
      canUseSelectionChat: false,
      includedProfileBoosts: 0,
    );
  }

  static AccountEntitlements fromPlan({
    required BillingPlan plan,
    required AccountRole role,
    required bool isPaidActive,
  }) {
    if (role == AccountRole.admin || plan == BillingPlan.agencyAdmin) {
      return AccountEntitlements(
        plan: plan == BillingPlan.free ? BillingPlan.agencyAdmin : plan,
        role: role,
        isPaidActive: true,
        maxProfilesPerSelection: null,
        maxActiveSelections: null,
        canExportBrandedPdf: true,
        canUseAgentFolders: true,
        canUseAgentNotes: true,
        canBoostProfiles: true,
        canUseSelectionChat: true,
        includedProfileBoosts: 10,
      );
    }

    if (!isPaidActive) return AccountEntitlements.free(role);

    return switch (plan) {
      BillingPlan.modelPro => AccountEntitlements(
        plan: plan,
        role: role,
        isPaidActive: true,
        maxProfilesPerSelection: accountRoleCanCreateSelections(role) ? 10 : 0,
        maxActiveSelections: accountRoleCanCreateSelections(role) ? 3 : 0,
        canExportBrandedPdf: false,
        canUseAgentFolders: false,
        canUseAgentNotes: false,
        canBoostProfiles: true,
        canUseSelectionChat: true,
        includedProfileBoosts: 3,
      ),
      BillingPlan.castingAgentPro => AccountEntitlements(
        plan: plan,
        role: role,
        isPaidActive: true,
        maxProfilesPerSelection: null,
        maxActiveSelections: null,
        canExportBrandedPdf: true,
        canUseAgentFolders: true,
        canUseAgentNotes: true,
        canBoostProfiles: false,
        canUseSelectionChat: true,
        includedProfileBoosts: 0,
      ),
      BillingPlan.agencyAdmin => AccountEntitlements(
        plan: plan,
        role: role,
        isPaidActive: true,
        maxProfilesPerSelection: null,
        maxActiveSelections: null,
        canExportBrandedPdf: true,
        canUseAgentFolders: true,
        canUseAgentNotes: true,
        canBoostProfiles: true,
        canUseSelectionChat: true,
        includedProfileBoosts: 10,
      ),
      BillingPlan.free => AccountEntitlements.free(role),
    };
  }
}

final accountEntitlementsProvider = FutureProvider<AccountEntitlements>((
  ref,
) async {
  final role = await ref.watch(accountRoleProvider.future);
  final sb = ref.read(supabaseProvider);
  final user = sb.auth.currentUser;
  if (user == null) return AccountEntitlements.free(role);

  try {
    final row = await sb
        .from('user_billing_profiles')
        .select('plan,status,current_period_end')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();

    final plan = billingPlanFromStorage(row?['plan']);
    final status = row?['status']?.toString().toLowerCase().trim() ?? '';
    final endRaw = row?['current_period_end']?.toString().trim() ?? '';
    final currentPeriodEnd = endRaw.isEmpty ? null : DateTime.tryParse(endRaw);
    final notExpired =
        currentPeriodEnd == null || currentPeriodEnd.isAfter(DateTime.now());
    final paidActive =
        (status == 'active' || status == 'trialing') && notExpired;

    return AccountEntitlements.fromPlan(
      plan: plan,
      role: role,
      isPaidActive: paidActive,
    );
  } on PostgrestException catch (e) {
    AppLogger.warning('Account entitlements DB fallback', error: e);
    return AccountEntitlements.free(role);
  } catch (e, st) {
    AppLogger.error(
      'Account entitlements load failed',
      error: e,
      stackTrace: st,
    );
    return AccountEntitlements.free(role);
  }
});
