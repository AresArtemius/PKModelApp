import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'auth_providers.dart';
import 'roles_provider.dart';
import 'supabase_provider.dart';
import 'supabase_compat.dart';

enum OnboardingAccountType {
  model('model'),
  actor('actor'),
  castingAgent('casting_agent'),
  brand('brand'),
  photographer('photographer'),
  videographer('videographer'),
  stylist('stylist'),
  makeupArtist('makeup_artist'),
  hairStylist('hair_stylist'),
  agency('agency');

  const OnboardingAccountType(this.storageValue);

  final String storageValue;
}

final accountOnboardingServiceProvider = Provider<AccountOnboardingService>((
  ref,
) {
  return AccountOnboardingService(ref.read(supabaseProvider));
});

final needsOnboardingProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  return ref.read(accountOnboardingServiceProvider).needsOnboarding(user);
});

class AccountOnboardingService {
  const AccountOnboardingService(this._sb);

  final SupabaseClient _sb;

  Future<bool> needsOnboarding(User user) async {
    try {
      if (await _currentUserIsAdmin(user.id)) return false;

      final row = await _sb
          .from('user_profiles')
          .select('account_type,onboarding_completed_at')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();

      if (row == null) return true;

      final completedAt =
          row['onboarding_completed_at']?.toString().trim() ?? '';
      return completedAt.isEmpty;
    } on PostgrestException catch (e) {
      if (_isMissingOnboardingSchema(e)) {
        AppLogger.warning('Onboarding skipped until SQL is applied', error: e);
        return false;
      }
      rethrow;
    }
  }

  Future<bool> _currentUserIsAdmin(String userId) async {
    try {
      final row = await _sb
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      return row?['role']?.toString().toLowerCase().trim() == 'admin';
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['user_roles'])) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> complete({
    required User user,
    required OnboardingAccountType accountType,
  }) async {
    if (await _completeViaRpc(accountType)) return;

    final now = DateTime.now().toUtc().toIso8601String();

    await _sb.from('user_profiles').upsert({
      'user_id': user.id,
      'email': user.email,
      'phone': user.phone,
      'account_type': accountType.storageValue,
      'onboarding_completed_at': now,
      'last_seen_at': now,
      'updated_at': now,
    }, onConflict: 'user_id');

    await _ensureBaseRole(user.id);

    if (accountType == OnboardingAccountType.castingAgent) {
      await _createCastingAgentApplication(userId: user.id, comment: '');
    }
  }

  Future<bool> _completeViaRpc(OnboardingAccountType accountType) async {
    try {
      await _sb.rpc(
        'complete_account_onboarding',
        params: {'p_account_type': accountType.storageValue},
      );
      return true;
    } on PostgrestException catch (e) {
      if (_isMissingCompleteOnboardingRpc(e)) return false;
      rethrow;
    }
  }

  Future<void> _ensureBaseRole(String userId) async {
    try {
      await _sb.from('user_roles').upsert({
        'user_id': userId,
        'role': AccountRole.user.storageValue,
      }, onConflict: 'user_id');
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['user_roles'])) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _createCastingAgentApplication({
    required String userId,
    required String comment,
  }) async {
    try {
      await _sb.from('casting_agent_applications').insert({
        'user_id': userId,
        'status': 'pending',
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      });
    } on PostgrestException catch (e) {
      if (SupabaseCompat.message(e).contains('duplicate') ||
          SupabaseCompat.isMissingRelation(e, const [
            'casting_agent_applications',
          ])) {
        return;
      }
      rethrow;
    }
  }

  bool _isMissingOnboardingSchema(PostgrestException e) {
    return SupabaseCompat.isMissingRelation(e, const ['user_profiles']) ||
        SupabaseCompat.isMissingColumn(e, 'onboarding_completed_at');
  }

  bool _isMissingCompleteOnboardingRpc(PostgrestException e) {
    return SupabaseCompat.isMissingRpc(e, 'complete_account_onboarding');
  }
}
