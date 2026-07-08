class SelectionPdfOptions {
  final bool includePhoto;
  final bool includeFullName;
  final bool includeAge;
  final bool includeHeight;
  final bool includeCity;
  final bool includeCountry;
  final bool includeEyeColor;
  final bool includeHairColor;
  final bool includeMeasurements;
  final bool includeShoeSize;
  final bool includeHourlyRate;
  final bool includeDailyFee;
  final bool includeModelLink;

  const SelectionPdfOptions({
    required this.includePhoto,
    required this.includeFullName,
    required this.includeAge,
    required this.includeHeight,
    required this.includeCity,
    required this.includeCountry,
    required this.includeEyeColor,
    required this.includeHairColor,
    required this.includeMeasurements,
    required this.includeShoeSize,
    required this.includeHourlyRate,
    required this.includeDailyFee,
    required this.includeModelLink,
  });

  const SelectionPdfOptions.basic()
    : includePhoto = true,
      includeFullName = true,
      includeAge = true,
      includeHeight = true,
      includeCity = false,
      includeCountry = false,
      includeEyeColor = false,
      includeHairColor = false,
      includeMeasurements = false,
      includeShoeSize = false,
      includeHourlyRate = false,
      includeDailyFee = false,
      includeModelLink = true;
}
