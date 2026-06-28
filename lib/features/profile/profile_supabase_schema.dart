import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';

class ProfileSupabaseSchema {
  const ProfileSupabaseSchema._();

  static const table = 'profiles';

  static const professionalColumns = <String>[
    'profile_type',
    'experience',
    'skills',
    'services',
    'genres',
    'equipment',
  ];

  static const verificationColumns = <String>[
    'is_verified',
    'verification_status',
    'verification_requested_at',
  ];

  static const catalogOptionalColumns = <String>[
    'birth_date',
    'unavailable_days',
    'is_pro',
    'pro_until',
    'is_verified',
  ];

  static const proColumns = <String>['is_pro', 'pro_until'];

  static const _identityColumns = <String>['id', 'user_id'];
  static const _publicIdentityColumns = <String>['id', 'user_id', 'full_name'];
  static const _birthDateColumns = <String>['birth_date'];
  static const _measurementColumns = <String>[
    'age',
    'height',
    'bust',
    'waist',
    'hips',
    'shoe_size',
  ];
  static const _appearanceColumns = <String>[
    'eye_color',
    'hair_color',
    'country',
    'city',
  ];
  static const _rateColumns = <String>['min_hourly_rate', 'min_daily_fee'];
  static const _mediaColumns = <String>[
    'photo_urls',
    'video_urls',
    'video_preview_urls',
  ];
  static const _pendingMediaColumns = <String>[
    'pending_photo_urls',
    'pending_video_urls',
    'pending_video_preview_urls',
    'has_pending_media',
  ];
  static const _moderationColumns = <String>['status', 'moderation_comment'];

  static String selectOwn({required bool includeOptional}) {
    return _join([
      ..._identityColumns,
      if (includeOptional) ...professionalColumns,
      'full_name',
      if (includeOptional) ..._birthDateColumns,
      ..._measurementColumns,
      ..._appearanceColumns,
      ..._rateColumns,
      'resume',
      'unavailable_days',
      'is_available',
      ..._moderationColumns,
      if (includeOptional) 'is_verified',
      if (includeOptional) 'verification_status',
      ..._mediaColumns,
      if (includeOptional) ..._pendingMediaColumns,
    ]);
  }

  static String selectCatalog({
    required bool includeBirthDate,
    required bool includeUnavailableDays,
    required bool includePro,
    required bool includeVerification,
  }) {
    return _join([
      ..._publicIdentityColumns,
      if (includeBirthDate) ..._birthDateColumns,
      ..._measurementColumns,
      ..._appearanceColumns,
      'status',
      ..._rateColumns,
      if (includeUnavailableDays) 'unavailable_days',
      if (includePro) 'is_pro',
      if (includePro) 'pro_until',
      if (includeVerification) 'is_verified',
      'photo_urls',
    ]);
  }

  static String selectPublic({
    required bool includeBirthDate,
    required bool includeProfessional,
    required bool includePro,
    required bool includeVerification,
  }) {
    return _join([
      ..._publicIdentityColumns,
      'status',
      if (includeBirthDate) ..._birthDateColumns,
      ..._measurementColumns,
      ..._appearanceColumns,
      'resume',
      ..._mediaColumns,
      'unavailable_days',
      ..._rateColumns,
      if (includeProfessional) ...professionalColumns,
      if (includePro) 'is_pro',
      if (includePro) 'pro_until',
      if (includeVerification) 'is_verified',
    ]);
  }

  static String selectModeration({
    required bool includeBirthDate,
    required bool includeVerification,
    required bool includePendingMedia,
  }) {
    return _join([
      'id',
      'full_name',
      if (includeBirthDate) ..._birthDateColumns,
      ..._measurementColumns,
      ..._appearanceColumns,
      'country',
      'resume',
      'unavailable_days',
      'is_available',
      ..._moderationColumns,
      if (includeVerification) 'is_verified',
      if (includeVerification) 'verification_status',
      ..._mediaColumns,
      if (includePendingMedia) ..._pendingMediaColumns,
    ]);
  }

  static bool isMissingProfessionalColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, professionalColumns);
  }

  static bool isMissingVerificationColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, verificationColumns);
  }

  static bool isMissingCatalogOptionalColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, catalogOptionalColumns);
  }

  static bool isMissingProColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, proColumns);
  }

  static bool isMissingPendingMediaColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, _pendingMediaColumns);
  }

  static bool isMissingBirthDateColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, _birthDateColumns);
  }

  static bool isMissingOwnOptionalColumn(PostgrestException error) {
    return isMissingProfessionalColumn(error) ||
        isMissingVerificationColumn(error) ||
        isMissingBirthDateColumn(error) ||
        isMissingPendingMediaColumn(error);
  }

  static Map<String, dynamic> withoutProfessionalPayload(
    Map<String, dynamic> payload,
  ) {
    final next = Map<String, dynamic>.from(payload);
    for (final column in [
      ...professionalColumns,
      ...verificationColumns,
      ..._pendingMediaColumns,
      ..._birthDateColumns,
    ]) {
      next.remove(column);
    }
    return next;
  }

  static String _join(Iterable<String> columns) {
    return columns.toSet().join(', ');
  }
}
