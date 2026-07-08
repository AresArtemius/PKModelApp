import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'supabase_provider.dart';
import 'supabase_compat.dart';

const _adminRole = 'admin';
const _castingAgentRole = 'casting_agent';
const _regularUserRole = 'user';
const _moderatorRole = 'moderator';
const _supportRole = 'support';

const _castingDirectorAccountType = 'casting_director';
const _directorProducerAccountType = 'director_producer';
const _brandClientAccountType = 'brand_client';
const _agencyAccountType = 'agency';
const _productionAgencyAccountType = 'production_agency';
const _photoVideoAccountType = 'photo_video';
const _scoutBookerAccountType = 'scout_booker';

const _castingAgentAccountTypes = {
  _castingAgentRole,
  _castingDirectorAccountType,
  _directorProducerAccountType,
  _brandClientAccountType,
  _agencyAccountType,
  _productionAgencyAccountType,
  _photoVideoAccountType,
  _scoutBookerAccountType,
};

const _adminAccountTypes = {_adminRole, _moderatorRole, _supportRole};

enum AccountRole {
  user(_regularUserRole),
  castingAgent(_castingAgentRole),
  admin(_adminRole);

  const AccountRole(this.storageValue);

  final String storageValue;
}

enum RegistrationAccountType {
  user(_regularUserRole, AccountRole.user),
  castingDirector(_castingDirectorAccountType, AccountRole.castingAgent),
  castingAgent(_castingAgentRole, AccountRole.castingAgent),
  directorProducer(_directorProducerAccountType, AccountRole.castingAgent),
  brandClient(_brandClientAccountType, AccountRole.castingAgent),
  agency(_agencyAccountType, AccountRole.castingAgent),
  productionAgency(_productionAgencyAccountType, AccountRole.castingAgent),
  photoVideo(_photoVideoAccountType, AccountRole.castingAgent),
  scoutBooker(_scoutBookerAccountType, AccountRole.castingAgent);

  const RegistrationAccountType(this.storageValue, this.role);

  final String storageValue;
  final AccountRole role;
}

const publicRegistrationAccountTypes = [
  RegistrationAccountType.user,
  RegistrationAccountType.castingDirector,
  RegistrationAccountType.castingAgent,
  RegistrationAccountType.directorProducer,
  RegistrationAccountType.brandClient,
  RegistrationAccountType.agency,
  RegistrationAccountType.productionAgency,
  RegistrationAccountType.photoVideo,
  RegistrationAccountType.scoutBooker,
];

RegistrationAccountType registrationAccountTypeFromStorage(Object? value) {
  final storage = value?.toString().toLowerCase().trim();
  for (final type in publicRegistrationAccountTypes) {
    if (type.storageValue == storage) return type;
  }
  return switch (accountRoleFromStorage(value)) {
    AccountRole.castingAgent => RegistrationAccountType.castingAgent,
    _ => RegistrationAccountType.user,
  };
}

AccountRole accountRoleFromStorage(Object? value) {
  final role = value?.toString().toLowerCase().trim();
  if (_adminAccountTypes.contains(role)) return AccountRole.admin;
  if (_castingAgentAccountTypes.contains(role)) return AccountRole.castingAgent;
  return AccountRole.user;
}

bool accountRoleCanCreateSelections(AccountRole role) {
  return role == AccountRole.admin || role == AccountRole.castingAgent;
}

bool registrationAccountTypeIsClient(RegistrationAccountType type) {
  return type != RegistrationAccountType.user;
}

Future<Map<String, dynamic>?> _fetchUserRoleRow(
  SupabaseClient sb,
  String userKey,
) async {
  return sb
      .from('user_roles')
      .select('role')
      .eq('user_id', userKey)
      .limit(1)
      .maybeSingle();
}

Future<Map<String, dynamic>?> _fetchAccountProfileRow(
  SupabaseClient sb,
  String userId,
) async {
  return sb
      .from('user_profiles')
      .select('account_type')
      .eq('user_id', userId)
      .limit(1)
      .maybeSingle();
}

final accountRoleProvider = FutureProvider<AccountRole>((ref) async {
  final sb = ref.read(supabaseProvider);
  final user = sb.auth.currentUser;
  if (user == null) return AccountRole.user;

  try {
    Map<String, dynamic>? data = await _fetchUserRoleRow(sb, user.id);

    if (data == null && user.email != null && user.email!.isNotEmpty) {
      try {
        // Legacy compatibility: some old rows may store email in user_id.
        data = await _fetchUserRoleRow(sb, user.email!);
      } on PostgrestException {
        // Ignore legacy fallback failure.
      }
    }

    if (data != null) {
      return accountRoleFromStorage(data['role']);
    }

    try {
      final profile = await _fetchAccountProfileRow(sb, user.id);
      final profileRole = accountRoleFromStorage(profile?['account_type']);
      if (profileRole == AccountRole.admin) return profileRole;
    } on PostgrestException {
      // The account profile table may not exist before SQL is applied.
    }

    return AccountRole.user;
  } on PostgrestException catch (e) {
    AppLogger.warning('Account role DB fallback', error: e);
    return AccountRole.user;
  } catch (e, st) {
    AppLogger.error('Account role load failed', error: e, stackTrace: st);
    return AccountRole.user;
  }
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(accountRoleProvider.future);
  return role == AccountRole.admin;
});

final canCreateSelectionsProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(accountRoleProvider.future);
  return accountRoleCanCreateSelections(role);
});

final accountStatusServiceProvider = Provider<AccountStatusService>((ref) {
  return AccountStatusService(ref.read(supabaseProvider));
});

class AccountStatusSnapshot {
  const AccountStatusSnapshot({
    required this.current,
    required this.role,
    this.pending,
    this.rejected,
    this.rejectedApplicationId,
  });

  final RegistrationAccountType current;
  final AccountRole role;
  final RegistrationAccountType? pending;
  final RegistrationAccountType? rejected;
  final String? rejectedApplicationId;

  bool get hasPending => pending != null;
  bool get isApprovedClient => role == AccountRole.castingAgent;
}

final accountStatusProvider = FutureProvider<AccountStatusSnapshot>((
  ref,
) async {
  final sb = ref.read(supabaseProvider);
  final user = sb.auth.currentUser;
  if (user == null) {
    return const AccountStatusSnapshot(
      current: RegistrationAccountType.user,
      role: AccountRole.user,
    );
  }

  final role = await ref.watch(accountRoleProvider.future);

  try {
    final profile = await _fetchAccountProfileRow(sb, user.id);
    final current = registrationAccountTypeFromStorage(
      profile?['account_type'],
    );
    final application = await _fetchLatestStatusApplication(sb, user.id);
    final visibleCurrent = role == AccountRole.castingAgent
        ? (current == RegistrationAccountType.user
              ? RegistrationAccountType.castingAgent
              : current)
        : RegistrationAccountType.user;
    return AccountStatusSnapshot(
      current: visibleCurrent,
      role: role,
      pending: application.status == 'pending' ? application.type : null,
      rejected: application.status == 'rejected' && !application.rejectionSeen
          ? application.type
          : null,
      rejectedApplicationId:
          application.status == 'rejected' && !application.rejectionSeen
          ? application.id
          : null,
    );
  } on PostgrestException catch (e) {
    AppLogger.warning('Account status DB fallback', error: e);
    return AccountStatusSnapshot(
      current: role == AccountRole.castingAgent
          ? RegistrationAccountType.castingAgent
          : RegistrationAccountType.user,
      role: role,
    );
  } catch (e, st) {
    AppLogger.error('Account status load failed', error: e, stackTrace: st);
    return AccountStatusSnapshot(
      current: RegistrationAccountType.user,
      role: role,
    );
  }
});

class _StatusApplicationSnapshot {
  const _StatusApplicationSnapshot({
    this.id,
    this.status,
    this.type,
    this.rejectionSeen = false,
  });

  final String? id;
  final String? status;
  final RegistrationAccountType? type;
  final bool rejectionSeen;
}

Future<_StatusApplicationSnapshot> _fetchLatestStatusApplication(
  SupabaseClient sb,
  String userId,
) async {
  try {
    Map<String, dynamic>? row;
    try {
      row = await sb
          .from('casting_agent_applications')
          .select('id,status,requested_account_type,comment,rejection_seen_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('requested_account_type')) {
        row = await sb
            .from('casting_agent_applications')
            .select('id,status,comment')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } else if (message.contains('rejection_seen_at')) {
        row = await sb
            .from('casting_agent_applications')
            .select('id,status,requested_account_type,comment')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } else {
        rethrow;
      }
    }
    if (row == null) return const _StatusApplicationSnapshot();
    final requestedRaw = row['requested_account_type']?.toString().trim();
    final commentRaw = row['comment']?.toString().trim();
    final typeRaw =
        requestedRaw == RegistrationAccountType.castingAgent.storageValue &&
            commentRaw != null &&
            commentRaw.isNotEmpty &&
            commentRaw != RegistrationAccountType.castingAgent.storageValue
        ? commentRaw
        : requestedRaw ?? commentRaw;
    return _StatusApplicationSnapshot(
      id: row['id']?.toString().trim(),
      status: row['status']?.toString().toLowerCase().trim(),
      type: registrationAccountTypeFromStorage(typeRaw),
      rejectionSeen: (row['rejection_seen_at'] ?? '')
          .toString()
          .trim()
          .isNotEmpty,
    );
  } on PostgrestException {
    return const _StatusApplicationSnapshot();
  }
}

class AccountStatusService {
  const AccountStatusService(this._sb);

  final SupabaseClient _sb;

  Future<void> updateStatus(RegistrationAccountType type) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    final currentRole = await _currentStoredRole(user.id);
    final requiresApproval =
        currentRole != AccountRole.castingAgent &&
        registrationAccountTypeIsClient(type);
    if (requiresApproval) {
      await _requestClientStatus(type);
      return;
    }

    await _updateAuthMetadata(type);

    try {
      await _sb.rpc(
        'set_account_status',
        params: {'p_account_type': type.storageValue},
      );
      return;
    } on PostgrestException catch (e) {
      if (!_isMissingStatusRpc(e)) rethrow;
    }

    await _sb.from('user_profiles').upsert({
      'user_id': user.id,
      'email': user.email,
      'phone': user.phone,
      'account_type': type.storageValue,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    try {
      await _sb.from('user_roles').upsert({
        'user_id': user.id,
        'role': type.role.storageValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } on PostgrestException catch (e) {
      AppLogger.warning(
        'Account role update skipped until SQL policies are applied',
        error: e,
      );
    }
  }

  Future<AccountRole> _currentStoredRole(String userId) async {
    try {
      final role = await _fetchUserRoleRow(_sb, userId);
      return accountRoleFromStorage(role?['role']);
    } on PostgrestException {
      return AccountRole.user;
    }
  }

  Future<void> _requestClientStatus(RegistrationAccountType type) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    await _updateAuthMetadata(RegistrationAccountType.user);

    try {
      await _sb.rpc(
        'request_account_status',
        params: {'p_account_type': type.storageValue},
      );
      return;
    } on PostgrestException catch (e) {
      AppLogger.warning(
        'Account status request RPC failed; trying direct insert',
        error: e,
      );
    }

    try {
      await _sb.from('user_profiles').upsert({
        'user_id': user.id,
        'email': user.email,
        'phone': user.phone,
        'account_type': RegistrationAccountType.user.storageValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } on PostgrestException catch (e) {
      AppLogger.warning(
        'Account profile status reset skipped until SQL policies are applied',
        error: e,
      );
    }

    try {
      try {
        await _sb.from('casting_agent_applications').insert({
          'user_id': user.id,
          'status': 'pending',
          'requested_account_type': type.storageValue,
          'comment': type.storageValue,
        });
      } on PostgrestException catch (e) {
        if (!e.message.toLowerCase().contains('requested_account_type')) {
          rethrow;
        }
        await _sb.from('casting_agent_applications').insert({
          'user_id': user.id,
          'status': 'pending',
          'comment': type.storageValue,
        });
      }
    } on PostgrestException catch (e) {
      if (!_isDuplicatePendingApplication(e)) rethrow;
    }
  }

  bool _isMissingStatusRpc(PostgrestException e) {
    final message = e.message.toLowerCase();
    return e.code == 'PGRST202' ||
        message.contains('set_account_status') ||
        message.contains('schema cache');
  }

  bool _isDuplicatePendingApplication(PostgrestException e) {
    final message = e.message.toLowerCase();
    return e.code == '23505' ||
        message.contains('duplicate') ||
        message.contains('unique');
  }

  Future<void> markRejectedApplicationSeen(String applicationId) async {
    final cleanId = applicationId.trim();
    if (cleanId.isEmpty) return;

    try {
      await _sb.rpc(
        'mark_casting_agent_application_rejection_seen',
        params: {'p_application_id': cleanId},
      );
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(
        e,
        'mark_casting_agent_application_rejection_seen',
      )) {
        rethrow;
      }
    }

    await _sb
        .from('casting_agent_applications')
        .update({'rejection_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', cleanId)
        .eq('user_id', _sb.auth.currentUser?.id ?? '');
  }

  Future<void> _updateAuthMetadata(RegistrationAccountType type) async {
    try {
      await _sb.auth.updateUser(
        UserAttributes(
          data: {
            'account_type': type.storageValue,
            'requested_account_type': type.storageValue,
            'role': type.role.storageValue,
          },
        ),
      );
    } on AuthException catch (e) {
      AppLogger.warning('Account status auth metadata update failed', error: e);
    }
  }
}
