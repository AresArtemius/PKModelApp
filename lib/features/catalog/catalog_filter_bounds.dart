class CatalogFilterBounds {
  const CatalogFilterBounds({
    required this.ageMin,
    required this.ageMax,
    required this.heightMin,
    required this.heightMax,
    required this.shoeMin,
    required this.shoeMax,
    required this.bustMin,
    required this.bustMax,
    required this.waistMin,
    required this.waistMax,
    required this.hipsMin,
    required this.hipsMax,
    required this.minHourlyRateMin,
    required this.minHourlyRateMax,
    required this.minDailyFeeMin,
    required this.minDailyFeeMax,
  });

  final int ageMin;
  final int ageMax;

  final int heightMin;
  final int heightMax;

  final int shoeMin;
  final int shoeMax;

  final int bustMin;
  final int bustMax;

  final int waistMin;
  final int waistMax;

  final int hipsMin;
  final int hipsMax;

  final int minHourlyRateMin;
  final int minHourlyRateMax;

  final int minDailyFeeMin;
  final int minDailyFeeMax;
}
