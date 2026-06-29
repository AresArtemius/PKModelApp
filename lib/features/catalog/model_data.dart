import '../profile/profile_model.dart';

class ModelVm {
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
  final String city;
  final List<String> photoUrls;
  final String coverPhotoUrl;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
  final String resume;
  final String experience;
  final String skills;
  final String services;
  final String genres;
  final String equipment;
  final int? shoeSize;
  final int? minHourlyRate;
  final int? minDailyFee;
  final String eyeColor;
  final String hairColor;
  final String country;
  final List<DateTime> unavailableDays;
  final bool isPro;
  final DateTime? proUntil;
  final bool isVerified;

  const ModelVm({
    required this.id,
    this.userId = '',
    this.profileType = ProfessionalProfileType.model,
    required this.fullName,
    this.birthDate = '',
    required this.age,
    required this.height,
    required this.bust,
    required this.waist,
    required this.hips,
    required this.city,
    required this.photoUrls,
    this.coverPhotoUrl = '',
    this.videoUrls = const [],
    this.videoPreviewUrls = const [],
    this.resume = '',
    this.experience = '',
    this.skills = '',
    this.services = '',
    this.genres = '',
    this.equipment = '',
    this.shoeSize,
    this.minHourlyRate,
    this.minDailyFee,
    this.eyeColor = '',
    this.hairColor = '',
    this.country = '',
    this.unavailableDays = const [],
    this.isPro = false,
    this.proUntil,
    this.isVerified = false,
  });

  bool get hasPhotos => photoUrls.isNotEmpty;
  bool get hasVideos => videoUrls.isNotEmpty;
  bool get hasVideoPreviews => videoPreviewUrls.isNotEmpty;
  String? get primaryPhotoUrl {
    final cover = coverPhotoUrl.trim();
    if (cover.isNotEmpty) return cover;
    return hasPhotos ? photoUrls.first : null;
  }

  List<String> get displayPhotoUrls {
    final primary = primaryPhotoUrl?.trim() ?? '';
    if (primary.isEmpty) return photoUrls;
    final rest = photoUrls.where((url) => url.trim() != primary);
    return [primary, ...rest];
  }

  bool get isProActive {
    if (!isPro) return false;
    final until = proUntil;
    if (until == null) return true;
    return until.isAfter(DateTime.now());
  }

  static int _intOrZero(dynamic v) => _intOrNull(v) ?? 0;

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();

    final s = v.toString().trim();
    if (s.isEmpty) return null;

    return int.tryParse(s);
  }

  static String _string(dynamic v) => (v ?? '').toString().trim();

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static DateTime? _dateTime(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static int _ageFromBirthDate(DateTime birthDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var age = today.year - birthDate.year;
    final hadBirthdayThisYear =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthdayThisYear) age -= 1;
    return age.clamp(0, 120);
  }

  static int displayAgeFromMap(Map<String, dynamic> map) {
    final birthDate = _dateTime(map['birth_date']);
    if (birthDate != null) return _ageFromBirthDate(birthDate);
    return _intOrZero(map['age']);
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];

    return v
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static List<DateTime> _dateList(dynamic v) {
    if (v == null) return const [];

    final raw = v is List ? v : [v];
    final out = <DateTime>[];

    for (final e in raw) {
      if (e == null) continue;
      final dt = DateTime.tryParse(e.toString());
      if (dt == null) continue;

      out.add(DateTime(dt.year, dt.month, dt.day));
    }

    out.sort();
    return out
        .map((d) => d.toIso8601String())
        .toSet()
        .map(DateTime.parse)
        .toList(growable: false);
  }

  factory ModelVm.fromMap(Map<String, dynamic> m) {
    return ModelVm(
      id: _string(m['id']),
      userId: _string(m['user_id']),
      profileType: profileTypeFromString(_string(m['profile_type'])),
      fullName: _string(m['full_name']),
      birthDate: _string(m['birth_date']),
      age: displayAgeFromMap(m),
      height: _intOrZero(m['height']),
      bust: _intOrZero(m['bust']),
      waist: _intOrZero(m['waist']),
      hips: _intOrZero(m['hips']),
      city: _string(m['city']),
      photoUrls: _stringList(m['photo_urls']),
      coverPhotoUrl: _string(m['cover_photo_url']),
      videoUrls: _stringList(m['video_urls']),
      videoPreviewUrls: _stringList(m['video_preview_urls']),
      resume: _string(m['resume']),
      experience: _string(m['experience']),
      skills: _string(m['skills']),
      services: _string(m['services']),
      genres: _string(m['genres']),
      equipment: _string(m['equipment']),
      shoeSize: _intOrNull(m['shoe_size']),
      minHourlyRate: _intOrNull(m['min_hourly_rate']),
      minDailyFee: _intOrNull(m['min_daily_fee']),
      eyeColor: _string(m['eye_color']),
      hairColor: _string(m['hair_color']),
      country: _string(m['country']),
      unavailableDays: _dateList(m['unavailable_days']),
      isPro: _bool(m['is_pro']),
      proUntil: _dateTime(m['pro_until']),
      isVerified: _bool(m['is_verified']),
    );
  }
}
