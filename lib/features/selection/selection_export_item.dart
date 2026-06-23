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
  });

  factory SelectionExportItem.fromProfileMap(Map<String, dynamic> profile) {
    final photoUrlsRaw = profile['photo_urls'];
    final photoUrls = photoUrlsRaw is List
        ? photoUrlsRaw
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return SelectionExportItem(
      id: (profile['id'] ?? '').toString(),
      fullName: (profile['full_name'] ?? '').toString(),
      age: _toInt(profile['age']),
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
      photoUrl: photoUrls.isNotEmpty ? photoUrls.first : '',
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
