import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modelapp/core/supabase_provider.dart';
import 'package:modelapp/features/profile/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_providers.dart';
import '../../core/entitlements_provider.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_compat.dart';
import 'profile_supabase_schema.dart';

final myProfileProvider =
    StateNotifierProvider<
      MyProfileController,
      AsyncValue<List<MyProfileState>>
    >((ref) {
      ref.watch(currentUserIdProvider);
      return MyProfileController(ref);
    });

enum MyProfileError {
  noUser,
  fullNameRequired,
  ageRequired,
  ageOutOfRange,
  heightRequired,
  heightOutOfRange,
  bustRequired,
  bustOutOfRange,
  waistRequired,
  waistOutOfRange,
  hipsRequired,
  hipsOutOfRange,
  profileLimitReached,
}

class MyProfileException implements Exception {
  MyProfileException(this.code);
  final MyProfileError code;
}

class MyProfileController
    extends StateNotifier<AsyncValue<List<MyProfileState>>> {
  MyProfileController(this.ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref ref;

  static const int _ageMin = 0;
  static const int _ageMax = 99;
  static const int _heightMin = 30;
  static const int _heightMax = 220;
  static const int _measureMin = 10;
  static const int _measureMax = 200;

  SupabaseClient get _sb => ref.read(supabaseProvider);

  String? get _currentUserId => ref.read(currentUserIdProvider);

  List<String> _normalizedVideoPreviewUrls(
    List<String> previewUrls,
    int videoCount,
  ) => [
    for (var i = 0; i < videoCount; i++)
      i < previewUrls.length ? previewUrls[i].trim() : '',
  ];

  List<MyProfileState> get _currentList => [
    ...(state.value ?? const <MyProfileState>[]),
  ];

  String _requireUid() {
    final uid = _currentUserId;
    if (uid == null) throw MyProfileException(MyProfileError.noUser);
    return uid;
  }

  Map<String, dynamic> _basePayloadFor(MyProfileState s, String uid) => {
    'user_id': uid,
    'profile_type': s.profileType.storageValue,
    'profile_roles': s.effectiveProfileRoles
        .map((role) => role.storageValue)
        .toList(growable: false),
    'full_name': s.fullName,
    'birth_date': s.birthDate.trim().isEmpty ? null : s.birthDate.trim(),
    'age': s.age,
    'height': s.height,
    'bust': s.bust,
    'waist': s.waist,
    'hips': s.hips,
    'shoe_size': s.shoeSize,
    'min_hourly_rate': s.minHourlyRate,
    'min_daily_fee': s.minDailyFee,
    'eye_color': s.eyeColor,
    'hair_color': s.hairColor,
    'country': s.country,
    'resume': s.resume,
    'experience': s.experience,
    'skills': s.skills,
    'services': s.services,
    'genres': s.genres,
    'equipment': s.equipment,
    'unavailable_days': s.unavailableDays,
    'city': s.city,
    'is_available': s.isAvailable,
    'status': statusToString(s.status),
    'moderation_comment': s.moderationComment,
  };

  String _normalizedCoverPhotoUrl(String cover, List<String> photos) {
    final cleanCover = cover.trim();
    final cleanPhotos = photos.map((e) => e.trim()).where((e) => e.isNotEmpty);
    if (cleanCover.isNotEmpty && cleanPhotos.contains(cleanCover)) {
      return cleanCover;
    }
    return cleanPhotos.isEmpty ? '' : cleanPhotos.first;
  }

  String _normalizedShowreelUrl(String showreel, List<String> videos) {
    final cleanShowreel = showreel.trim();
    final cleanVideos = videos.map((e) => e.trim()).where((e) => e.isNotEmpty);
    if (cleanShowreel.isNotEmpty && cleanVideos.contains(cleanShowreel)) {
      return cleanShowreel;
    }
    return '';
  }

  List<String> _normalizedCategoryLabels(
    List<String> labels,
    int targetLength, {
    required String fallback,
  }) {
    return [
      for (var i = 0; i < targetLength; i++)
        if (i < labels.length && labels[i].trim().isNotEmpty)
          labels[i].trim()
        else
          fallback,
    ];
  }

  bool _isMissingOptionalProfileColumn(PostgrestException e) {
    return ProfileSupabaseSchema.isMissingOwnOptionalColumn(e);
  }

  Map<String, dynamic> _withoutMissingOwnOptionalPayload(
    PostgrestException error,
    Map<String, dynamic> payload,
  ) {
    return ProfileSupabaseSchema.withoutMissingOwnOptionalPayload(
      error,
      payload,
    );
  }

  Future<List<dynamic>> _selectOwnProfiles(String uid) async {
    try {
      return await _sb
          .from(ProfileSupabaseSchema.table)
          .select(ProfileSupabaseSchema.selectOwn(includeOptional: true))
          .eq('user_id', uid)
          .order('id', ascending: false);
    } on PostgrestException catch (e) {
      if (!_isMissingOptionalProfileColumn(e)) rethrow;
      return await _sb
          .from(ProfileSupabaseSchema.table)
          .select(ProfileSupabaseSchema.selectOwn(includeOptional: false))
          .eq('user_id', uid)
          .order('id', ascending: false);
    }
  }

  Future<void> _ensureCanCreateProfile(String uid) async {
    final isAdmin = await ref.read(isAdminProvider.future);
    if (isAdmin) return;

    final entitlements = await ref.read(accountEntitlementsProvider.future);
    final limit = entitlements.maxPublishedProfiles;
    if (limit == null) return;

    final count = await _sb
        .from(ProfileSupabaseSchema.table)
        .count(CountOption.exact)
        .eq('user_id', uid);
    if (count >= limit) {
      throw MyProfileException(MyProfileError.profileLimitReached);
    }
  }

  Future<Map<String, dynamic>> _insertProfileAndSelect(
    Map<String, dynamic> payload,
  ) async {
    try {
      final data = await _sb
          .from(ProfileSupabaseSchema.table)
          .insert(payload)
          .select(ProfileSupabaseSchema.selectOwn(includeOptional: true))
          .single();
      return Map<String, dynamic>.from(data as Map);
    } on PostgrestException catch (e) {
      if (!_isMissingOptionalProfileColumn(e)) rethrow;
      final data = await _sb
          .from(ProfileSupabaseSchema.table)
          .insert(_withoutMissingOwnOptionalPayload(e, payload))
          .select(ProfileSupabaseSchema.selectOwn(includeOptional: false))
          .single();
      return Map<String, dynamic>.from(data as Map);
    }
  }

  Future<Map<String, dynamic>> _updateProfileAndSelect(
    String profileId,
    String uid,
    Map<String, dynamic> payload,
  ) async {
    try {
      final data = await _sb
          .from(ProfileSupabaseSchema.table)
          .update(payload)
          .eq('id', profileId)
          .eq('user_id', uid)
          .select(ProfileSupabaseSchema.selectOwn(includeOptional: true))
          .single();
      return Map<String, dynamic>.from(data as Map);
    } on PostgrestException catch (e) {
      if (!_isMissingOptionalProfileColumn(e)) rethrow;
      final data = await _sb
          .from(ProfileSupabaseSchema.table)
          .update(_withoutMissingOwnOptionalPayload(e, payload))
          .eq('id', profileId)
          .eq('user_id', uid)
          .select(ProfileSupabaseSchema.selectOwn(includeOptional: false))
          .single();
      return Map<String, dynamic>.from(data as Map);
    }
  }

  Map<String, dynamic> _payloadFor(MyProfileState s, String uid) => {
    ..._basePayloadFor(s, uid),
    'photo_urls': s.photoUrls,
    'photo_category_labels': _normalizedCategoryLabels(
      s.photoCategoryLabels,
      s.photoUrls.length,
      fallback: 'Портфолио',
    ),
    'cover_photo_url': _normalizedCoverPhotoUrl(s.coverPhotoUrl, s.photoUrls),
    'cover_photo_focal_x': s.coverPhotoFocalX.clamp(-1.0, 1.0),
    'cover_photo_focal_y': s.coverPhotoFocalY.clamp(-1.0, 1.0),
    'video_urls': s.videoUrls,
    'video_preview_urls': _normalizedVideoPreviewUrls(
      s.videoPreviewUrls,
      s.videoUrls.length,
    ),
    'video_category_labels': _normalizedCategoryLabels(
      s.videoCategoryLabels,
      s.videoUrls.length,
      fallback: 'Видео',
    ),
    'showreel_url': _normalizedShowreelUrl(s.showreelUrl, s.videoUrls),
    'showreel_preview_url':
        _normalizedShowreelUrl(s.showreelUrl, s.videoUrls).isEmpty
        ? ''
        : s.showreelPreviewUrl,
    'pending_photo_urls': s.pendingPhotoUrls,
    'pending_photo_category_labels': _normalizedCategoryLabels(
      s.pendingPhotoCategoryLabels,
      s.pendingPhotoUrls.length,
      fallback: 'Портфолио',
    ),
    'pending_cover_photo_url': _normalizedCoverPhotoUrl(
      s.pendingCoverPhotoUrl,
      s.pendingPhotoUrls,
    ),
    'pending_cover_photo_focal_x': s.pendingCoverPhotoFocalX.clamp(-1.0, 1.0),
    'pending_cover_photo_focal_y': s.pendingCoverPhotoFocalY.clamp(-1.0, 1.0),
    'pending_video_urls': s.pendingVideoUrls,
    'pending_video_preview_urls': _normalizedVideoPreviewUrls(
      s.pendingVideoPreviewUrls,
      s.pendingVideoUrls.length,
    ),
    'pending_video_category_labels': _normalizedCategoryLabels(
      s.pendingVideoCategoryLabels,
      s.pendingVideoUrls.length,
      fallback: 'Видео',
    ),
    'pending_showreel_url': _normalizedShowreelUrl(
      s.pendingShowreelUrl,
      s.pendingVideoUrls,
    ),
    'pending_showreel_preview_url':
        _normalizedShowreelUrl(s.pendingShowreelUrl, s.pendingVideoUrls).isEmpty
        ? ''
        : s.pendingShowreelPreviewUrl,
    'has_pending_media': s.hasPendingMedia,
  };

  MyProfileState? _findById(List<MyProfileState> list, String id) {
    for (final p in list) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<MyProfileState> _upsertProfile(
    List<MyProfileState> list,
    MyProfileState item,
  ) {
    final next = [...list];
    final idx = next.indexWhere((p) => p.id == item.id);
    if (idx >= 0) {
      next[idx] = item;
    } else {
      next.insert(0, item);
    }
    return next;
  }

  List<MyProfileState> _replaceProfile(
    List<MyProfileState> list,
    MyProfileState item,
  ) {
    final next = [...list];
    final idx = next.indexWhere((p) => p.id == item.id);
    if (idx >= 0) {
      next[idx] = item;
    }
    return next;
  }

  void _validateForReview(MyProfileState p) {
    final name = p.fullName.trim();
    if (name.isEmpty) {
      throw MyProfileException(MyProfileError.fullNameRequired);
    }

    final birthDate = p.birthDate.trim();
    final hasBirthDate =
        birthDate.isNotEmpty && DateTime.tryParse(birthDate) != null;
    if (p.usesPhysicalBasics && !hasBirthDate) {
      throw MyProfileException(MyProfileError.ageRequired);
    }
    final displayAge = p.displayAge;
    if (p.usesPhysicalBasics &&
        (displayAge < _ageMin || displayAge > _ageMax)) {
      throw MyProfileException(MyProfileError.ageOutOfRange);
    }
    if (p.usesPhysicalBasics && p.height <= 0) {
      throw MyProfileException(MyProfileError.heightRequired);
    }
    if (p.usesPhysicalBasics &&
        (p.height < _heightMin || p.height > _heightMax)) {
      throw MyProfileException(MyProfileError.heightOutOfRange);
    }
    if (!p.usesModelMeasurements) return;

    if (p.bust <= 0) {
      throw MyProfileException(MyProfileError.bustRequired);
    }
    if (p.bust < _measureMin || p.bust > _measureMax) {
      throw MyProfileException(MyProfileError.bustOutOfRange);
    }
    if (p.waist <= 0) {
      throw MyProfileException(MyProfileError.waistRequired);
    }
    if (p.waist < _measureMin || p.waist > _measureMax) {
      throw MyProfileException(MyProfileError.waistOutOfRange);
    }
    if (p.hips <= 0) {
      throw MyProfileException(MyProfileError.hipsRequired);
    }
    if (p.hips < _measureMin || p.hips > _measureMax) {
      throw MyProfileException(MyProfileError.hipsOutOfRange);
    }
  }

  Future<void> load() async {
    final uid = _currentUserId;
    if (uid == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final rows = await _selectOwnProfiles(uid);

      if (!mounted) return;

      final items = rows
          .map(
            (e) => MyProfileState.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false);

      state = AsyncValue.data(items);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<MyProfileState> saveProfile(MyProfileState s) async {
    final uid = _requireUid();
    final profileId = s.id.trim();
    final payload = _payloadFor(s, uid);

    if (profileId.isEmpty) {
      await _ensureCanCreateProfile(uid);
      final data = await _insertProfileAndSelect(payload);
      final created = MyProfileState.fromMap(data);
      state = AsyncValue.data(_upsertProfile(_currentList, created));
      return created;
    }

    final data = await _updateProfileAndSelect(profileId, uid, payload);
    final updated = MyProfileState.fromMap(data);

    state = AsyncValue.data(_upsertProfile(_currentList, updated));
    return updated;
  }

  Future<MyProfileState> saveProfileWithPendingMedia({
    required MyProfileState profile,
    required List<String> newPhotoUrls,
    required List<String> newVideoUrls,
    required List<String> newVideoPreviewUrls,
    List<String> newPhotoCategoryLabels = const [],
    List<String> newVideoCategoryLabels = const [],
    String newShowreelUrl = '',
    String newShowreelPreviewUrl = '',
  }) async {
    final uid = _requireUid();
    final profileId = profile.id.trim();
    final basePayload = _basePayloadFor(profile, uid);
    final publishImmediately = profile.status == ProfileStatus.approved;

    if (profileId.isEmpty) {
      await _ensureCanCreateProfile(uid);
      final photoUrls = [...profile.photoUrls, ...newPhotoUrls];
      final videoUrls = [...profile.videoUrls, ...newVideoUrls];
      final payload = {
        ...basePayload,
        'photo_urls': photoUrls,
        'photo_category_labels': [
          ..._normalizedCategoryLabels(
            profile.photoCategoryLabels,
            profile.photoUrls.length,
            fallback: 'Портфолио',
          ),
          ..._normalizedCategoryLabels(
            newPhotoCategoryLabels,
            newPhotoUrls.length,
            fallback: 'Портфолио',
          ),
        ],
        'cover_photo_url': _normalizedCoverPhotoUrl(
          profile.coverPhotoUrl,
          photoUrls,
        ),
        'video_urls': videoUrls,
        'video_preview_urls': _normalizedVideoPreviewUrls([
          ...profile.videoPreviewUrls,
          ...newVideoPreviewUrls,
        ], videoUrls.length),
        'video_category_labels': [
          ..._normalizedCategoryLabels(
            profile.videoCategoryLabels,
            profile.videoUrls.length,
            fallback: 'Видео',
          ),
          ..._normalizedCategoryLabels(
            newVideoCategoryLabels,
            newVideoUrls.length,
            fallback: 'Видео',
          ),
        ],
        'showreel_url': _normalizedShowreelUrl(
          newShowreelUrl.trim().isNotEmpty
              ? newShowreelUrl
              : profile.showreelUrl,
          videoUrls,
        ),
        'showreel_preview_url': newShowreelUrl.trim().isNotEmpty
            ? newShowreelPreviewUrl
            : profile.showreelPreviewUrl,
        'pending_photo_urls': const <String>[],
        'pending_cover_photo_url': '',
        'pending_video_urls': const <String>[],
        'pending_video_preview_urls': const <String>[],
        'pending_photo_category_labels': const <String>[],
        'pending_video_category_labels': const <String>[],
        'pending_showreel_url': '',
        'pending_showreel_preview_url': '',
        'has_pending_media': false,
      };

      final data = await _insertProfileAndSelect(payload);
      final created = MyProfileState.fromMap(data);
      state = AsyncValue.data(_upsertProfile(_currentList, created));
      return created;
    }

    final publishedPhotoUrls = publishImmediately
        ? [...profile.photoUrls, ...profile.pendingPhotoUrls, ...newPhotoUrls]
        : profile.photoUrls;
    final publishedVideoUrls = publishImmediately
        ? [...profile.videoUrls, ...profile.pendingVideoUrls, ...newVideoUrls]
        : profile.videoUrls;
    final pendingPhotoUrls = publishImmediately
        ? const <String>[]
        : [...profile.pendingPhotoUrls, ...newPhotoUrls];
    final pendingVideoUrls = publishImmediately
        ? const <String>[]
        : [...profile.pendingVideoUrls, ...newVideoUrls];
    final nextCoverPhotoUrl = publishImmediately
        ? _normalizedCoverPhotoUrl(
            profile.pendingCoverPhotoUrl.trim().isNotEmpty
                ? profile.pendingCoverPhotoUrl
                : profile.coverPhotoUrl,
            publishedPhotoUrls,
          )
        : _normalizedCoverPhotoUrl(profile.coverPhotoUrl, publishedPhotoUrls);
    final nextPendingCoverPhotoUrl = publishImmediately
        ? ''
        : _normalizedCoverPhotoUrl(
            profile.pendingCoverPhotoUrl,
            pendingPhotoUrls,
          );

    final payload = {
      ...basePayload,
      'photo_urls': publishedPhotoUrls,
      'photo_category_labels': publishImmediately
          ? [
              ..._normalizedCategoryLabels(
                profile.photoCategoryLabels,
                profile.photoUrls.length,
                fallback: 'Портфолио',
              ),
              ..._normalizedCategoryLabels(
                profile.pendingPhotoCategoryLabels,
                profile.pendingPhotoUrls.length,
                fallback: 'Портфолио',
              ),
              ..._normalizedCategoryLabels(
                newPhotoCategoryLabels,
                newPhotoUrls.length,
                fallback: 'Портфолио',
              ),
            ]
          : _normalizedCategoryLabels(
              profile.photoCategoryLabels,
              profile.photoUrls.length,
              fallback: 'Портфолио',
            ),
      'cover_photo_url': nextCoverPhotoUrl,
      'video_urls': publishedVideoUrls,
      'video_preview_urls': publishImmediately
          ? _normalizedVideoPreviewUrls([
              ...profile.videoPreviewUrls,
              ...profile.pendingVideoPreviewUrls,
              ...newVideoPreviewUrls,
            ], publishedVideoUrls.length)
          : _normalizedVideoPreviewUrls(
              profile.videoPreviewUrls,
              publishedVideoUrls.length,
            ),
      'video_category_labels': publishImmediately
          ? [
              ..._normalizedCategoryLabels(
                profile.videoCategoryLabels,
                profile.videoUrls.length,
                fallback: 'Видео',
              ),
              ..._normalizedCategoryLabels(
                profile.pendingVideoCategoryLabels,
                profile.pendingVideoUrls.length,
                fallback: 'Видео',
              ),
              ..._normalizedCategoryLabels(
                newVideoCategoryLabels,
                newVideoUrls.length,
                fallback: 'Видео',
              ),
            ]
          : _normalizedCategoryLabels(
              profile.videoCategoryLabels,
              profile.videoUrls.length,
              fallback: 'Видео',
            ),
      'showreel_url': publishImmediately
          ? _normalizedShowreelUrl(
              newShowreelUrl.trim().isNotEmpty
                  ? newShowreelUrl
                  : (profile.pendingShowreelUrl.trim().isNotEmpty
                        ? profile.pendingShowreelUrl
                        : profile.showreelUrl),
              publishedVideoUrls,
            )
          : _normalizedShowreelUrl(profile.showreelUrl, publishedVideoUrls),
      'showreel_preview_url': publishImmediately
          ? (newShowreelPreviewUrl.trim().isNotEmpty
                ? newShowreelPreviewUrl
                : (profile.pendingShowreelPreviewUrl.trim().isNotEmpty
                      ? profile.pendingShowreelPreviewUrl
                      : profile.showreelPreviewUrl))
          : profile.showreelPreviewUrl,
      'pending_photo_urls': pendingPhotoUrls,
      'pending_photo_category_labels': publishImmediately
          ? const <String>[]
          : [
              ..._normalizedCategoryLabels(
                profile.pendingPhotoCategoryLabels,
                profile.pendingPhotoUrls.length,
                fallback: 'Портфолио',
              ),
              ..._normalizedCategoryLabels(
                newPhotoCategoryLabels,
                newPhotoUrls.length,
                fallback: 'Портфолио',
              ),
            ],
      'pending_cover_photo_url': nextPendingCoverPhotoUrl,
      'pending_video_urls': pendingVideoUrls,
      'pending_video_preview_urls': publishImmediately
          ? const <String>[]
          : _normalizedVideoPreviewUrls([
              ...profile.pendingVideoPreviewUrls,
              ...newVideoPreviewUrls,
            ], pendingVideoUrls.length),
      'pending_video_category_labels': publishImmediately
          ? const <String>[]
          : [
              ..._normalizedCategoryLabels(
                profile.pendingVideoCategoryLabels,
                profile.pendingVideoUrls.length,
                fallback: 'Видео',
              ),
              ..._normalizedCategoryLabels(
                newVideoCategoryLabels,
                newVideoUrls.length,
                fallback: 'Видео',
              ),
            ],
      'pending_showreel_url': publishImmediately
          ? ''
          : _normalizedShowreelUrl(
              newShowreelUrl.trim().isNotEmpty
                  ? newShowreelUrl
                  : profile.pendingShowreelUrl,
              pendingVideoUrls,
            ),
      'pending_showreel_preview_url': publishImmediately
          ? ''
          : (newShowreelPreviewUrl.trim().isNotEmpty
                ? newShowreelPreviewUrl
                : profile.pendingShowreelPreviewUrl),
      'has_pending_media': publishImmediately
          ? false
          : (profile.pendingPhotoUrls.isNotEmpty ||
                profile.pendingVideoUrls.isNotEmpty ||
                profile.pendingVideoPreviewUrls.isNotEmpty ||
                profile.pendingShowreelUrl.trim().isNotEmpty ||
                newPhotoUrls.isNotEmpty ||
                newVideoUrls.isNotEmpty ||
                newVideoPreviewUrls.isNotEmpty),
    };

    final data = await _updateProfileAndSelect(profileId, uid, payload);
    final updated = MyProfileState.fromMap(data);

    state = AsyncValue.data(_upsertProfile(_currentList, updated));
    return updated;
  }

  Future<MyProfileState> publishAdminProfile(String profileId) async {
    final id = profileId.trim();
    if (id.isEmpty) throw MyProfileException(MyProfileError.noUser);

    final uid = _requireUid();
    try {
      final data = await _sb.rpc(
        'admin_publish_profile',
        params: {'p_profile_id': id},
      );
      final rows = data is List ? data : const [];
      if (rows.isNotEmpty) {
        final published = MyProfileState.fromMap(
          Map<String, dynamic>.from(rows.first as Map),
        );
        state = AsyncValue.data(_upsertProfile(_currentList, published));
        return published;
      }
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'admin_publish_profile')) {
        rethrow;
      }
    }

    final current = _findById(_currentList, id);
    final photoUrls = [...?current?.photoUrls, ...?current?.pendingPhotoUrls];
    final videoUrls = [...?current?.videoUrls, ...?current?.pendingVideoUrls];
    final videoPreviewUrls = [
      ...?current?.videoPreviewUrls,
      ...?current?.pendingVideoPreviewUrls,
    ];
    final photoCategoryLabels = [
      ..._normalizedCategoryLabels(
        current?.photoCategoryLabels ?? const <String>[],
        current?.photoUrls.length ?? 0,
        fallback: 'Портфолио',
      ),
      ..._normalizedCategoryLabels(
        current?.pendingPhotoCategoryLabels ?? const <String>[],
        current?.pendingPhotoUrls.length ?? 0,
        fallback: 'Портфолио',
      ),
    ];
    final videoCategoryLabels = [
      ..._normalizedCategoryLabels(
        current?.videoCategoryLabels ?? const <String>[],
        current?.videoUrls.length ?? 0,
        fallback: 'Видео',
      ),
      ..._normalizedCategoryLabels(
        current?.pendingVideoCategoryLabels ?? const <String>[],
        current?.pendingVideoUrls.length ?? 0,
        fallback: 'Видео',
      ),
    ];
    final preferredCover =
        current?.pendingCoverPhotoUrl.trim().isNotEmpty == true
        ? current!.pendingCoverPhotoUrl
        : current?.coverPhotoUrl ?? '';
    final preferredShowreel =
        current?.pendingShowreelUrl.trim().isNotEmpty == true
        ? current!.pendingShowreelUrl
        : current?.showreelUrl ?? '';

    final data = await _updateProfileAndSelect(id, uid, {
      'status': 'approved',
      'moderation_comment': null,
      'photo_urls': photoUrls,
      'photo_category_labels': photoCategoryLabels,
      'cover_photo_url': _normalizedCoverPhotoUrl(preferredCover, photoUrls),
      'video_urls': videoUrls,
      'video_preview_urls': _normalizedVideoPreviewUrls(
        videoPreviewUrls,
        videoUrls.length,
      ),
      'video_category_labels': videoCategoryLabels,
      'showreel_url': _normalizedShowreelUrl(preferredShowreel, videoUrls),
      'showreel_preview_url':
          current?.pendingShowreelPreviewUrl.trim().isNotEmpty == true
          ? current!.pendingShowreelPreviewUrl
          : current?.showreelPreviewUrl ?? '',
      'pending_photo_urls': const <String>[],
      'pending_cover_photo_url': '',
      'pending_video_urls': const <String>[],
      'pending_video_preview_urls': const <String>[],
      'pending_photo_category_labels': const <String>[],
      'pending_video_category_labels': const <String>[],
      'pending_showreel_url': '',
      'pending_showreel_preview_url': '',
      'has_pending_media': false,
    });
    final published = MyProfileState.fromMap(data);
    state = AsyncValue.data(_upsertProfile(_currentList, published));
    return published;
  }

  Future<void> submitForReview(String profileId) async {
    final id = profileId.trim();
    if (id.isEmpty) return;

    final list = state.value ?? const <MyProfileState>[];
    final current = _findById(list, id);

    if (current == null) return;

    _validateForReview(current);

    final uid = _requireUid();

    await _submitForReview(id, uid);

    final next = current.copyWith(
      status: ProfileStatus.pending,
      moderationComment: null,
    );
    state = AsyncValue.data(_replaceProfile(list, next));
  }

  Future<void> _submitForReview(String profileId, String uid) async {
    try {
      await _sb.rpc(
        'submit_profile_for_review',
        params: {'p_profile_id': profileId},
      );
      return;
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'submit_profile_for_review')) {
        rethrow;
      }
    }

    await _updateProfileAndSelect(profileId, uid, {
      'status': 'pending',
      'moderation_comment': null,
    });
  }

  Future<void> requestVerification(String profileId) async {
    final id = profileId.trim();
    if (id.isEmpty) return;

    final list = state.value ?? const <MyProfileState>[];
    final current = _findById(list, id);
    if (current == null || current.isVerified) return;

    final uid = _requireUid();

    await _sb
        .from(ProfileSupabaseSchema.table)
        .update({
          'verification_status': 'pending',
          'verification_requested_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', uid);

    final next = current.copyWith(
      verificationStatus: ProfileVerificationStatus.pending,
    );
    state = AsyncValue.data(_replaceProfile(list, next));
  }

  Future<void> deleteProfile(String profileId) async {
    final uid = _requireUid();
    final id = profileId.trim();
    if (id.isEmpty) return;

    await _sb
        .from(ProfileSupabaseSchema.table)
        .delete()
        .eq('id', id)
        .eq('user_id', uid);

    final list = _currentList;
    list.removeWhere((p) => p.id == id);
    state = AsyncValue.data(list);
  }
}
