class SelectionExportItem {
  final String id;
  final String fullName;
  final int age;
  final int height;
  final String city;
  final String country;
  final String eyeColor;
  final String hairColor;
  final int bust;
  final int waist;
  final int hips;
  final int shoeSize;
  final int minHourlyRate;
  final int minDailyFee;
  final String photoUrl;
  final List<String> photoUrls;

  const SelectionExportItem({
    required this.id,
    required this.fullName,
    required this.age,
    required this.height,
    required this.city,
    required this.country,
    required this.eyeColor,
    required this.hairColor,
    required this.bust,
    required this.waist,
    required this.hips,
    required this.shoeSize,
    required this.minHourlyRate,
    required this.minDailyFee,
    required this.photoUrl,
    this.photoUrls = const <String>[],
  });

  factory SelectionExportItem.fromProfileMap(Map<String, dynamic> profile) {
    final photoUrlsRaw = profile['photo_urls'];
    final photoUrls = photoUrlsRaw is List
        ? photoUrlsRaw
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final coverPhotoUrl = (profile['cover_photo_url'] ?? '').toString().trim();
    final orderedPhotoUrls = [
      if (coverPhotoUrl.isNotEmpty) coverPhotoUrl,
      ...photoUrls.where((url) => url.trim() != coverPhotoUrl),
    ].take(3).toList(growable: false);

    return SelectionExportItem(
      id: (profile['id'] ?? '').toString(),
      fullName: (profile['full_name'] ?? '').toString(),
      age: _displayAge(profile),
      height: _toInt(profile['height']),
      city: (profile['city'] ?? '').toString(),
      country: (profile['country'] ?? '').toString(),
      eyeColor: (profile['eye_color'] ?? '').toString(),
      hairColor: (profile['hair_color'] ?? '').toString(),
      bust: _toInt(profile['bust']),
      waist: _toInt(profile['waist']),
      hips: _toInt(profile['hips']),
      shoeSize: _toInt(profile['shoe_size']),
      minHourlyRate: _toInt(profile['min_hourly_rate']),
      minDailyFee: _toInt(profile['min_daily_fee']),
      photoUrl: orderedPhotoUrls.isNotEmpty ? orderedPhotoUrls.first : '',
      photoUrls: orderedPhotoUrls,
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int _displayAge(Map<String, dynamic> profile) {
    final rawBirthDate = (profile['birth_date'] ?? '').toString().trim();
    final birthDate = DateTime.tryParse(rawBirthDate);
    if (birthDate == null) return _toInt(profile['age']);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    var age = today.year - birth.year;
    final hadBirthdayThisYear =
        today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthdayThisYear) age -= 1;
    return age.clamp(0, 120);
  }
}
