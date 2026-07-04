enum ProfileStatus { draft, pending, approved, rejected }

enum ProfileVerificationStatus { none, pending, verified, rejected }

enum ProfessionalProfileType {
  model('model'),
  actor('actor'),
  photographer('photographer'),
  videographer('videographer'),
  stylist('stylist'),
  makeupArtist('makeup_artist'),
  hairStylist('hair_stylist');

  const ProfessionalProfileType(this.storageValue);

  final String storageValue;

  bool get isModel => this == ProfessionalProfileType.model;

  bool get isActor => this == ProfessionalProfileType.actor;

  bool get usesModelMeasurements => isModel || isActor;

  bool get usesPhysicalBasics => isModel || isActor;
}

ProfessionalProfileType profileTypeFromString(String? s) {
  final v = (s ?? '').toLowerCase().trim();
  switch (v) {
    case 'actor':
      return ProfessionalProfileType.actor;
    case 'photographer':
      return ProfessionalProfileType.photographer;
    case 'videographer':
      return ProfessionalProfileType.videographer;
    case 'stylist':
      return ProfessionalProfileType.stylist;
    case 'makeup_artist':
      return ProfessionalProfileType.makeupArtist;
    case 'hair_stylist':
      return ProfessionalProfileType.hairStylist;
    case 'model':
    default:
      return ProfessionalProfileType.model;
  }
}

ProfileVerificationStatus verificationStatusFromString(String? s) {
  final v = (s ?? '').toLowerCase().trim();
  switch (v) {
    case 'pending':
      return ProfileVerificationStatus.pending;
    case 'verified':
      return ProfileVerificationStatus.verified;
    case 'rejected':
      return ProfileVerificationStatus.rejected;
    case 'none':
    default:
      return ProfileVerificationStatus.none;
  }
}

String verificationStatusToString(ProfileVerificationStatus s) {
  switch (s) {
    case ProfileVerificationStatus.pending:
      return 'pending';
    case ProfileVerificationStatus.verified:
      return 'verified';
    case ProfileVerificationStatus.rejected:
      return 'rejected';
    case ProfileVerificationStatus.none:
      return 'none';
  }
}

ProfileStatus statusFromString(String? s) {
  final v = (s ?? '').toLowerCase().trim();
  switch (v) {
    case 'pending':
      return ProfileStatus.pending;
    case 'approved':
      return ProfileStatus.approved;
    case 'rejected':
      return ProfileStatus.rejected;
    case 'draft':
    default:
      return ProfileStatus.draft;
  }
}

String statusToString(ProfileStatus s) {
  switch (s) {
    case ProfileStatus.pending:
      return 'pending';
    case ProfileStatus.approved:
      return 'approved';
    case ProfileStatus.rejected:
      return 'rejected';
    case ProfileStatus.draft:
      return 'draft';
  }
}

int _intFromMap(Map<String, dynamic> m, String key, {int fallback = 0}) {
  final v = m[key];
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

bool _boolFromMap(Map<String, dynamic> m, String key, {bool fallback = false}) {
  final v = m[key];
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase().trim();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

double _doubleFromMap(
  Map<String, dynamic> m,
  String key, {
  double fallback = 0,
}) {
  final v = m[key];
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _stringFromMap(
  Map<String, dynamic> m,
  String key, {
  String fallback = '',
}) {
  final v = m[key];
  if (v == null) return fallback;
  return v.toString();
}

List<String> _stringListFromMap(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v == null) return const [];
  if (v is List) {
    return v
        .map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
  final s = v.toString().trim();
  if (s.isEmpty) return const [];
  return [s];
}

class MyProfileState {
  final String id;
  final String userId;
  final ProfessionalProfileType profileType;
  final String fullName;
  final String birthDate;
  final int age;
  final int height;
  final int bust;
  final int waist;
  final int hips;
  final int shoeSize;
  final int minHourlyRate;
  final int minDailyFee;
  final String eyeColor;
  final String hairColor;
  final String country;
  final String resume;
  final String experience;
  final String skills;
  final String services;
  final String genres;
  final String equipment;
  final List<String> unavailableDays;
  final String city;
  final bool isAvailable;
  final ProfileStatus status;
  final String? moderationComment;
  final bool isVerified;
  final ProfileVerificationStatus verificationStatus;

  final List<String> photoUrls;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
  final List<String> photoCategoryLabels;
  final List<String> videoCategoryLabels;
  final String coverPhotoUrl;
  final double coverPhotoFocalX;
  final double coverPhotoFocalY;
  final String showreelUrl;
  final String showreelPreviewUrl;
  final List<String> pendingPhotoUrls;
  final List<String> pendingVideoUrls;
  final List<String> pendingVideoPreviewUrls;
  final List<String> pendingPhotoCategoryLabels;
  final List<String> pendingVideoCategoryLabels;
  final String pendingCoverPhotoUrl;
  final double pendingCoverPhotoFocalX;
  final double pendingCoverPhotoFocalY;
  final String pendingShowreelUrl;
  final String pendingShowreelPreviewUrl;
  final bool hasPendingMedia;

  const MyProfileState({
    required this.id,
    required this.userId,
    this.profileType = ProfessionalProfileType.model,
    required this.fullName,
    this.birthDate = '',
    required this.age,
    required this.height,
    required this.bust,
    required this.waist,
    required this.hips,
    required this.shoeSize,
    required this.minHourlyRate,
    required this.minDailyFee,
    required this.eyeColor,
    required this.hairColor,
    required this.country,
    required this.resume,
    this.experience = '',
    this.skills = '',
    this.services = '',
    this.genres = '',
    this.equipment = '',
    this.unavailableDays = const [],
    required this.city,
    required this.isAvailable,
    required this.status,
    this.moderationComment,
    this.isVerified = false,
    this.verificationStatus = ProfileVerificationStatus.none,
    this.photoUrls = const [],
    this.videoUrls = const [],
    this.videoPreviewUrls = const [],
    this.photoCategoryLabels = const [],
    this.videoCategoryLabels = const [],
    this.coverPhotoUrl = '',
    this.coverPhotoFocalX = 0,
    this.coverPhotoFocalY = -0.72,
    this.showreelUrl = '',
    this.showreelPreviewUrl = '',
    this.pendingPhotoUrls = const [],
    this.pendingVideoUrls = const [],
    this.pendingVideoPreviewUrls = const [],
    this.pendingPhotoCategoryLabels = const [],
    this.pendingVideoCategoryLabels = const [],
    this.pendingCoverPhotoUrl = '',
    this.pendingCoverPhotoFocalX = 0,
    this.pendingCoverPhotoFocalY = -0.72,
    this.pendingShowreelUrl = '',
    this.pendingShowreelPreviewUrl = '',
    this.hasPendingMedia = false,
  });

  int get displayAge {
    final parsedBirthDate = DateTime.tryParse(birthDate.trim());
    if (parsedBirthDate == null) return age;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(
      parsedBirthDate.year,
      parsedBirthDate.month,
      parsedBirthDate.day,
    );
    var calculated = today.year - birth.year;
    final hadBirthdayThisYear =
        today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthdayThisYear) calculated -= 1;
    return calculated.clamp(0, 120);
  }

  factory MyProfileState.blank({required String userId}) {
    return MyProfileState(
      id: '',
      userId: userId,
      profileType: ProfessionalProfileType.model,
      fullName: '',
      birthDate: '',
      age: 0,
      height: 0,
      bust: 0,
      waist: 0,
      hips: 0,
      shoeSize: 0,
      minHourlyRate: 0,
      minDailyFee: 0,
      eyeColor: '',
      hairColor: '',
      country: '',
      resume: '',
      experience: '',
      skills: '',
      services: '',
      genres: '',
      equipment: '',
      unavailableDays: const [],
      city: '',
      isAvailable: true,
      status: ProfileStatus.draft,
      moderationComment: null,
      isVerified: false,
      verificationStatus: ProfileVerificationStatus.none,
      photoUrls: const [],
      videoUrls: const [],
      videoPreviewUrls: const [],
      photoCategoryLabels: const [],
      videoCategoryLabels: const [],
      coverPhotoUrl: '',
      showreelUrl: '',
      showreelPreviewUrl: '',
      pendingPhotoUrls: const [],
      pendingVideoUrls: const [],
      pendingVideoPreviewUrls: const [],
      pendingPhotoCategoryLabels: const [],
      pendingVideoCategoryLabels: const [],
      pendingCoverPhotoUrl: '',
      pendingShowreelUrl: '',
      pendingShowreelPreviewUrl: '',
      hasPendingMedia: false,
    );
  }

  static const Object _noValue = Object();

  MyProfileState copyWith({
    String? id,
    String? userId,
    ProfessionalProfileType? profileType,
    String? fullName,
    String? birthDate,
    int? age,
    int? height,
    int? bust,
    int? waist,
    int? hips,
    int? shoeSize,
    int? minHourlyRate,
    int? minDailyFee,
    String? eyeColor,
    String? hairColor,
    String? country,
    String? resume,
    String? experience,
    String? skills,
    String? services,
    String? genres,
    String? equipment,
    List<String>? unavailableDays,
    String? city,
    bool? isAvailable,
    ProfileStatus? status,
    Object? moderationComment = _noValue,
    bool? isVerified,
    ProfileVerificationStatus? verificationStatus,
    List<String>? photoUrls,
    List<String>? videoUrls,
    List<String>? videoPreviewUrls,
    List<String>? photoCategoryLabels,
    List<String>? videoCategoryLabels,
    String? coverPhotoUrl,
    double? coverPhotoFocalX,
    double? coverPhotoFocalY,
    String? showreelUrl,
    String? showreelPreviewUrl,
    List<String>? pendingPhotoUrls,
    List<String>? pendingVideoUrls,
    List<String>? pendingVideoPreviewUrls,
    List<String>? pendingPhotoCategoryLabels,
    List<String>? pendingVideoCategoryLabels,
    String? pendingCoverPhotoUrl,
    double? pendingCoverPhotoFocalX,
    double? pendingCoverPhotoFocalY,
    String? pendingShowreelUrl,
    String? pendingShowreelPreviewUrl,
    bool? hasPendingMedia,
  }) {
    return MyProfileState(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileType: profileType ?? this.profileType,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      height: height ?? this.height,
      bust: bust ?? this.bust,
      waist: waist ?? this.waist,
      hips: hips ?? this.hips,
      shoeSize: shoeSize ?? this.shoeSize,
      minHourlyRate: minHourlyRate ?? this.minHourlyRate,
      minDailyFee: minDailyFee ?? this.minDailyFee,
      eyeColor: eyeColor ?? this.eyeColor,
      hairColor: hairColor ?? this.hairColor,
      country: country ?? this.country,
      resume: resume ?? this.resume,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
      services: services ?? this.services,
      genres: genres ?? this.genres,
      equipment: equipment ?? this.equipment,
      unavailableDays: unavailableDays ?? this.unavailableDays,
      city: city ?? this.city,
      isAvailable: isAvailable ?? this.isAvailable,
      status: status ?? this.status,
      moderationComment: identical(moderationComment, _noValue)
          ? this.moderationComment
          : moderationComment as String?,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      videoPreviewUrls: videoPreviewUrls ?? this.videoPreviewUrls,
      photoCategoryLabels: photoCategoryLabels ?? this.photoCategoryLabels,
      videoCategoryLabels: videoCategoryLabels ?? this.videoCategoryLabels,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      coverPhotoFocalX: coverPhotoFocalX ?? this.coverPhotoFocalX,
      coverPhotoFocalY: coverPhotoFocalY ?? this.coverPhotoFocalY,
      showreelUrl: showreelUrl ?? this.showreelUrl,
      showreelPreviewUrl: showreelPreviewUrl ?? this.showreelPreviewUrl,
      pendingPhotoUrls: pendingPhotoUrls ?? this.pendingPhotoUrls,
      pendingVideoUrls: pendingVideoUrls ?? this.pendingVideoUrls,
      pendingVideoPreviewUrls:
          pendingVideoPreviewUrls ?? this.pendingVideoPreviewUrls,
      pendingPhotoCategoryLabels:
          pendingPhotoCategoryLabels ?? this.pendingPhotoCategoryLabels,
      pendingVideoCategoryLabels:
          pendingVideoCategoryLabels ?? this.pendingVideoCategoryLabels,
      pendingCoverPhotoUrl: pendingCoverPhotoUrl ?? this.pendingCoverPhotoUrl,
      pendingCoverPhotoFocalX:
          pendingCoverPhotoFocalX ?? this.pendingCoverPhotoFocalX,
      pendingCoverPhotoFocalY:
          pendingCoverPhotoFocalY ?? this.pendingCoverPhotoFocalY,
      pendingShowreelUrl: pendingShowreelUrl ?? this.pendingShowreelUrl,
      pendingShowreelPreviewUrl:
          pendingShowreelPreviewUrl ?? this.pendingShowreelPreviewUrl,
      hasPendingMedia: hasPendingMedia ?? this.hasPendingMedia,
    );
  }

  static MyProfileState fromMap(Map<String, dynamic> m) {
    return MyProfileState(
      id: _stringFromMap(m, 'id'),
      userId: _stringFromMap(m, 'user_id'),
      profileType: profileTypeFromString(_stringFromMap(m, 'profile_type')),
      fullName: _stringFromMap(m, 'full_name').trim(),
      birthDate: _stringFromMap(m, 'birth_date').trim(),
      age: _intFromMap(m, 'age'),
      height: _intFromMap(m, 'height'),
      bust: _intFromMap(m, 'bust'),
      waist: _intFromMap(m, 'waist'),
      hips: _intFromMap(m, 'hips'),
      shoeSize: _intFromMap(m, 'shoe_size'),
      minHourlyRate: _intFromMap(m, 'min_hourly_rate'),
      minDailyFee: _intFromMap(m, 'min_daily_fee'),
      eyeColor: _stringFromMap(m, 'eye_color'),
      hairColor: _stringFromMap(m, 'hair_color'),
      country: _stringFromMap(m, 'country'),
      resume: _stringFromMap(m, 'resume'),
      experience: _stringFromMap(m, 'experience'),
      skills: _stringFromMap(m, 'skills'),
      services: _stringFromMap(m, 'services'),
      genres: _stringFromMap(m, 'genres'),
      equipment: _stringFromMap(m, 'equipment'),
      unavailableDays: _stringListFromMap(m, 'unavailable_days'),
      city: _stringFromMap(m, 'city'),
      isAvailable: _boolFromMap(m, 'is_available'),
      status: statusFromString(m['status']?.toString()),
      moderationComment: (m['moderation_comment'] as String?)?.trim(),
      isVerified: _boolFromMap(m, 'is_verified'),
      verificationStatus: verificationStatusFromString(
        m['verification_status']?.toString(),
      ),
      photoUrls: _stringListFromMap(m, 'photo_urls'),
      videoUrls: _stringListFromMap(m, 'video_urls'),
      videoPreviewUrls: _stringListFromMap(m, 'video_preview_urls'),
      photoCategoryLabels: _stringListFromMap(m, 'photo_category_labels'),
      videoCategoryLabels: _stringListFromMap(m, 'video_category_labels'),
      coverPhotoUrl: _stringFromMap(m, 'cover_photo_url').trim(),
      coverPhotoFocalX: _doubleFromMap(m, 'cover_photo_focal_x'),
      coverPhotoFocalY: _doubleFromMap(
        m,
        'cover_photo_focal_y',
        fallback: -0.72,
      ),
      showreelUrl: _stringFromMap(m, 'showreel_url').trim(),
      showreelPreviewUrl: _stringFromMap(m, 'showreel_preview_url').trim(),
      pendingPhotoUrls: _stringListFromMap(m, 'pending_photo_urls'),
      pendingVideoUrls: _stringListFromMap(m, 'pending_video_urls'),
      pendingVideoPreviewUrls: _stringListFromMap(
        m,
        'pending_video_preview_urls',
      ),
      pendingPhotoCategoryLabels: _stringListFromMap(
        m,
        'pending_photo_category_labels',
      ),
      pendingVideoCategoryLabels: _stringListFromMap(
        m,
        'pending_video_category_labels',
      ),
      pendingCoverPhotoUrl: _stringFromMap(m, 'pending_cover_photo_url').trim(),
      pendingCoverPhotoFocalX: _doubleFromMap(m, 'pending_cover_photo_focal_x'),
      pendingCoverPhotoFocalY: _doubleFromMap(
        m,
        'pending_cover_photo_focal_y',
        fallback: -0.72,
      ),
      pendingShowreelUrl: _stringFromMap(m, 'pending_showreel_url').trim(),
      pendingShowreelPreviewUrl: _stringFromMap(
        m,
        'pending_showreel_preview_url',
      ).trim(),
      hasPendingMedia: _boolFromMap(m, 'has_pending_media'),
    );
  }

  String get effectiveCoverPhotoUrl {
    final cover = coverPhotoUrl.trim();
    if (cover.isNotEmpty) return cover;
    return photoUrls.isNotEmpty ? photoUrls.first : '';
  }
}
