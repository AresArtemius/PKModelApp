import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';

class ProfileSupabaseSchema {
  const ProfileSupabaseSchema._();

  static const table = 'profiles';

  static const professionalColumns = <String>[
    'profile_type',
    'profile_roles',
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
    'profile_roles',
    'birth_date',
    'unavailable_days',
    'is_pro',
    'pro_until',
    'is_verified',
    'cover_photo_url',
    'cover_photo_focal_x',
    'cover_photo_focal_y',
    'showreel_url',
    'showreel_preview_url',
    'photo_category_labels',
    'video_category_labels',
  ];

  static const proColumns = <String>['is_pro', 'pro_until'];
  static const coverPhotoColumns = <String>[
    'cover_photo_url',
    'pending_cover_photo_url',
    'cover_photo_focal_x',
    'cover_photo_focal_y',
    'pending_cover_photo_focal_x',
    'pending_cover_photo_focal_y',
  ];
  static const showreelColumns = <String>[
    'showreel_url',
    'showreel_preview_url',
    'pending_showreel_url',
    'pending_showreel_preview_url',
  ];

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
  static const _mediaCategoryColumns = <String>[
    'photo_category_labels',
    'video_category_labels',
    'pending_photo_category_labels',
    'pending_video_category_labels',
  ];
  static const _pendingMediaColumns = <String>[
    'pending_photo_urls',
    'pending_video_urls',
    'pending_video_preview_urls',
    'pending_photo_category_labels',
    'pending_video_category_labels',
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
      if (includeOptional) ..._mediaCategoryColumns,
      if (includeOptional) ...coverPhotoColumns,
      if (includeOptional) ...showreelColumns,
      if (includeOptional) ..._pendingMediaColumns,
    ]);
  }

  static String selectCatalog({
    required bool includeBirthDate,
    required bool includeUnavailableDays,
    required bool includePro,
    required bool includeVerification,
    required bool includeCoverPhoto,
  }) {
    return _join([
      ..._publicIdentityColumns,
      if (includeBirthDate) ..._birthDateColumns,
      ..._measurementColumns,
      ..._appearanceColumns,
      'status',
      ..._rateColumns,
      if (includeUnavailableDays) 'unavailable_days',
      if (includeCoverPhoto) 'profile_roles',
      if (includePro) 'is_pro',
      if (includePro) 'pro_until',
      if (includeVerification) 'is_verified',
      if (includeCoverPhoto) 'cover_photo_url',
      if (includeCoverPhoto) 'cover_photo_focal_x',
      if (includeCoverPhoto) 'cover_photo_focal_y',
      if (includeCoverPhoto) 'showreel_url',
      if (includeCoverPhoto) 'showreel_preview_url',
      if (includeCoverPhoto) 'photo_category_labels',
      if (includeCoverPhoto) 'video_category_labels',
      'photo_urls',
    ]);
  }

  static String selectPublic({
    required bool includeBirthDate,
    required bool includeProfessional,
    required bool includePro,
    required bool includeVerification,
    required bool includeCoverPhoto,
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
      if (includeCoverPhoto) 'cover_photo_url',
      if (includeCoverPhoto) 'cover_photo_focal_x',
      if (includeCoverPhoto) 'cover_photo_focal_y',
      if (includeCoverPhoto) ...showreelColumns.take(2),
      if (includeCoverPhoto) ..._mediaCategoryColumns.take(2),
    ]);
  }

  static String selectModeration({
    required bool includeBirthDate,
    required bool includeProfessional,
    required bool includeVerification,
    required bool includePendingMedia,
  }) {
    return _join([
      'id',
      if (includeProfessional) ...professionalColumns,
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
      if (includePendingMedia) ..._mediaCategoryColumns,
      if (includePendingMedia) ...coverPhotoColumns,
      if (includePendingMedia) ...showreelColumns,
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
    return SupabaseCompat.isMissingAnyColumn(error, [
      ..._pendingMediaColumns,
      ..._mediaCategoryColumns,
      ...coverPhotoColumns,
      ...showreelColumns,
    ]);
  }

  static bool isMissingMediaCategoryColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, _mediaCategoryColumns);
  }

  static bool isMissingCoverPhotoColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, [
      ...coverPhotoColumns,
      ...showreelColumns,
      ..._mediaCategoryColumns,
    ]);
  }

  static bool isMissingShowreelColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, showreelColumns);
  }

  static bool isMissingBirthDateColumn(PostgrestException error) {
    return SupabaseCompat.isMissingAnyColumn(error, _birthDateColumns);
  }

  static bool isMissingOwnOptionalColumn(PostgrestException error) {
    return isMissingProfessionalColumn(error) ||
        isMissingVerificationColumn(error) ||
        isMissingBirthDateColumn(error) ||
        isMissingCoverPhotoColumn(error) ||
        isMissingShowreelColumn(error) ||
        isMissingMediaCategoryColumn(error) ||
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
      ...coverPhotoColumns,
      ...showreelColumns,
      ..._mediaCategoryColumns,
    ]) {
      next.remove(column);
    }
    return next;
  }

  static Map<String, dynamic> withoutMissingOwnOptionalPayload(
    PostgrestException error,
    Map<String, dynamic> payload,
  ) {
    final next = Map<String, dynamic>.from(payload);

    void removeAll(Iterable<String> columns) {
      for (final column in columns) {
        next.remove(column);
      }
    }

    if (isMissingProfessionalColumn(error)) removeAll(professionalColumns);
    if (isMissingVerificationColumn(error)) removeAll(verificationColumns);
    if (isMissingBirthDateColumn(error)) removeAll(_birthDateColumns);
    if (SupabaseCompat.isMissingAnyColumn(error, _mediaCategoryColumns)) {
      removeAll(_mediaCategoryColumns);
    }
    if (SupabaseCompat.isMissingAnyColumn(error, coverPhotoColumns)) {
      removeAll(coverPhotoColumns);
    }
    if (SupabaseCompat.isMissingAnyColumn(error, showreelColumns)) {
      removeAll(showreelColumns);
    }
    if (SupabaseCompat.isMissingAnyColumn(error, _pendingMediaColumns)) {
      removeAll(_pendingMediaColumns);
    }

    return next;
  }

  static String _join(Iterable<String> columns) {
    return columns.toSet().join(', ');
  }
}
