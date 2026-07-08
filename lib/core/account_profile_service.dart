import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'auth_providers.dart';
import 'roles_provider.dart';
import 'supabase_provider.dart';
import 'supabase_compat.dart';

final accountProfileServiceProvider = Provider<AccountProfileService>((ref) {
  return AccountProfileService(ref.read(supabaseProvider));
});

final accountProfileSyncProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  await ref.read(accountProfileServiceProvider).syncUser(user);
});

final accountOwnerProfileProvider = FutureProvider<AccountOwnerProfile>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(AccountOwnerProfile.empty());
  return ref.read(accountProfileServiceProvider).loadOwnerProfile(user);
});

class AccountOwnerProfile {
  const AccountOwnerProfile({
    required this.email,
    required this.phone,
    required this.accountTag,
    required this.avatarUrl,
    required this.fullName,
    required this.companyName,
    required this.position,
    required this.city,
    required this.country,
    required this.website,
    required this.socialUrl,
    required this.bio,
  });

  final String email;
  final String phone;
  final String accountTag;
  final String avatarUrl;
  final String fullName;
  final String companyName;
  final String position;
  final String city;
  final String country;
  final String website;
  final String socialUrl;
  final String bio;

  bool get hasMinimumForRequest {
    final hasName = fullName.trim().isNotEmpty;
    final hasContact = email.trim().isNotEmpty || phone.trim().isNotEmpty;
    return hasName && hasContact;
  }

  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final company = companyName.trim();
    if (company.isNotEmpty) return company;
    final mail = email.trim();
    if (mail.isNotEmpty) return mail;
    return '';
  }

  String get normalizedAccountTag => normalizeAccountTag(accountTag);

  String get publicHandleLabel {
    final tag = normalizedAccountTag;
    if (tag.isNotEmpty) return tag;
    return email.trim();
  }

  AccountOwnerProfile copyWith({
    String? email,
    String? phone,
    String? accountTag,
    String? avatarUrl,
    String? fullName,
    String? companyName,
    String? position,
    String? city,
    String? country,
    String? website,
    String? socialUrl,
    String? bio,
  }) {
    return AccountOwnerProfile(
      email: email ?? this.email,
      phone: phone ?? this.phone,
      accountTag: accountTag ?? this.accountTag,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fullName: fullName ?? this.fullName,
      companyName: companyName ?? this.companyName,
      position: position ?? this.position,
      city: city ?? this.city,
      country: country ?? this.country,
      website: website ?? this.website,
      socialUrl: socialUrl ?? this.socialUrl,
      bio: bio ?? this.bio,
    );
  }

  factory AccountOwnerProfile.empty() {
    return const AccountOwnerProfile(
      email: '',
      phone: '',
      accountTag: '',
      avatarUrl: '',
      fullName: '',
      companyName: '',
      position: '',
      city: '',
      country: '',
      website: '',
      socialUrl: '',
      bio: '',
    );
  }

  factory AccountOwnerProfile.fromMap(Map<String, dynamic>? map, User user) {
    String value(String key) => (map?[key] ?? '').toString().trim();
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final metadataAvatarUrl = _firstNonEmptyValue([
      metadata['avatar_url'],
      metadata['picture'],
    ]);
    final storedAvatarUrl = value('avatar_url');
    return AccountOwnerProfile(
      email: value('email').isNotEmpty ? value('email') : user.email ?? '',
      phone: value('phone').isNotEmpty ? value('phone') : user.phone ?? '',
      accountTag: value('account_tag'),
      avatarUrl: storedAvatarUrl.isNotEmpty
          ? storedAvatarUrl
          : metadataAvatarUrl ?? '',
      fullName: value('full_name'),
      companyName: value('company_name'),
      position: value('position'),
      city: value('city'),
      country: value('country'),
      website: value('website'),
      socialUrl: value('social_url'),
      bio: value('bio'),
    );
  }

  Map<String, dynamic> toPayload(User user) {
    return {
      'user_id': user.id,
      'email': email.trim().isNotEmpty ? email.trim() : user.email,
      'phone': phone.trim().isNotEmpty ? phone.trim() : user.phone,
      'account_tag': normalizedAccountTag,
      'avatar_url': avatarUrl.trim(),
      'full_name': fullName.trim(),
      'company_name': companyName.trim(),
      'position': position.trim(),
      'city': city.trim(),
      'country': country.trim(),
      'website': website.trim(),
      'social_url': socialUrl.trim(),
      'bio': bio.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

String normalizeAccountTag(String value) {
  final lower = value.trim().toLowerCase();
  final withoutAt = lower.startsWith('@') ? lower.substring(1) : lower;
  final cleaned = withoutAt.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  return cleaned.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
}

String? _firstNonEmptyValue(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

class AccountProfileService {
  const AccountProfileService(this._sb);

  final SupabaseClient _sb;

  Future<void> syncUser(User user) async {
    try {
      await _sb
          .from('user_profiles')
          .upsert(_payloadFor(user), onConflict: 'user_id');
      await _syncRoleFromMetadataIfMissing(user);
    } on PostgrestException catch (e, stack) {
      if (_isMissingUserProfilesTable(e)) {
        AppLogger.warning(
          'Account profile sync skipped until SQL is applied',
          error: e,
        );
        return;
      }
      AppLogger.error(
        'Account profile sync failed',
        error: e,
        stackTrace: stack,
      );
    } catch (e, stack) {
      AppLogger.error(
        'Account profile sync failed',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<AccountOwnerProfile> loadOwnerProfile(User user) async {
    try {
      final row = await _loadOwnerProfileRow(user.id, includeAccountTag: true);
      return AccountOwnerProfile.fromMap(row, user);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingColumn(e, 'account_tag')) {
        final row = await _loadOwnerProfileRow(
          user.id,
          includeAccountTag: false,
        );
        return AccountOwnerProfile.fromMap(row, user);
      }
      if (_isMissingUserProfilesTable(e) || _isMissingOwnerProfileColumn(e)) {
        AppLogger.warning(
          'Account owner profile load skipped until SQL is applied',
          error: e,
        );
        return AccountOwnerProfile.fromMap(null, user);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _loadOwnerProfileRow(
    String userId, {
    required bool includeAccountTag,
  }) async {
    final columns = [
      'email',
      'phone',
      if (includeAccountTag) 'account_tag',
      'avatar_url',
      'full_name',
      'company_name',
      'position',
      'city',
      'country',
      'website',
      'social_url',
      'bio',
    ].join(',');
    return _sb
        .from('user_profiles')
        .select(columns)
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
  }

  Future<void> saveOwnerProfile(User user, AccountOwnerProfile profile) async {
    final payload = profile.toPayload(user);
    final avatarUrl = profile.avatarUrl.trim();
    try {
      await _sb.rpc('save_account_profile', params: {'p_profile': payload});
      if (avatarUrl.isNotEmpty) {
        await _persistAvatarUrl(user.id, avatarUrl);
      }
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'save_account_profile')) rethrow;
    }

    try {
      await _sb.from('user_profiles').upsert(payload, onConflict: 'user_id');
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingColumn(e, 'account_tag')) rethrow;
      await _sb
          .from('user_profiles')
          .upsert(
            Map<String, dynamic>.from(payload)..remove('account_tag'),
            onConflict: 'user_id',
          );
    }
    if (avatarUrl.isNotEmpty) {
      await _persistAvatarUrl(user.id, avatarUrl);
    }
  }

  Future<void> _persistAvatarUrl(String userId, String avatarUrl) async {
    await _sb.from('user_profiles').upsert({
      'user_id': userId,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> requestAccountMerge({
    required User user,
    required String requestedPhone,
    required AccountOwnerProfile profile,
  }) async {
    final payload = {
      'requested_phone': requestedPhone.trim(),
      'requester_email': user.email?.trim() ?? profile.email.trim(),
      'requester_phone': user.phone?.trim() ?? profile.phone.trim(),
      'requester_full_name': profile.fullName.trim(),
      'requester_company_name': profile.companyName.trim(),
      'requester_note':
          'Пользователь просит объединить текущий аккаунт с аккаунтом, к которому привязан номер ${requestedPhone.trim()}. Нужно связаться с пользователем и подтвердить, что оба способа входа принадлежат ему.',
    };

    try {
      await _sb.rpc('request_account_merge', params: {'p_request': payload});
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'request_account_merge')) rethrow;
    }

    await _sb.from('account_merge_requests').insert({
      'requester_user_id': user.id,
      ...payload,
      'status': 'pending',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Map<String, dynamic> _payloadFor(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final fullName = _firstNonEmpty([
      metadata['full_name'],
      metadata['name'],
      metadata['display_name'],
    ]);
    final avatarUrl = _firstNonEmpty([
      metadata['avatar_url'],
      metadata['picture'],
    ]);
    final provider = _firstNonEmpty([
      user.appMetadata['provider'],
      (user.appMetadata['providers'] is List &&
              (user.appMetadata['providers'] as List).isNotEmpty)
          ? (user.appMetadata['providers'] as List).first
          : null,
    ]);
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'user_id': user.id,
      'auth_provider': provider,
      'last_seen_at': now,
      'updated_at': now,
    };
    final email = user.email?.trim() ?? '';
    final phone = user.phone?.trim() ?? '';
    if (email.isNotEmpty) {
      payload['email'] = email;
    }
    if (phone.isNotEmpty) {
      payload['phone'] = phone;
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      payload['full_name'] = fullName;
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      payload['avatar_url'] = avatarUrl;
    }
    return payload;
  }

  String? _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  bool _isMissingUserProfilesTable(PostgrestException e) {
    return SupabaseCompat.isMissingRelation(e, const ['user_profiles']);
  }

  bool _isMissingOwnerProfileColumn(PostgrestException e) {
    return SupabaseCompat.isMissingColumn(e, 'company_name') ||
        SupabaseCompat.isMissingColumn(e, 'account_tag') ||
        SupabaseCompat.isMissingColumn(e, 'avatar_url') ||
        SupabaseCompat.isMissingColumn(e, 'position') ||
        SupabaseCompat.isMissingColumn(e, 'website') ||
        SupabaseCompat.isMissingColumn(e, 'social_url') ||
        SupabaseCompat.isMissingColumn(e, 'bio');
  }

  Future<void> _syncRoleFromMetadataIfMissing(User user) async {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final requested = _firstNonEmpty([
      metadata['role'],
      metadata['account_type'],
      metadata['requested_account_type'],
    ]);
    final role = accountRoleFromStorage(requested);
    if (role == AccountRole.user) return;

    try {
      final existing = await _sb
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();
      if (existing != null) return;

      await _sb.from('user_roles').insert({
        'user_id': user.id,
        'role': role.storageValue,
      });
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['user_roles'])) {
        return;
      }
      AppLogger.warning('Account role metadata sync failed', error: e);
    }
  }
}
