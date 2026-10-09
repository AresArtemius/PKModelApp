import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import '../../ui/brand/ui_constants.dart';
import '../profile/profile_model.dart';
import '../profile/profile_supabase_schema.dart';
import 'catalog_filter_bounds.dart';
import 'model_data.dart';

/// Result ordering offered in the catalogue header.
enum CatalogSort {
  recommended,
  newest,

  /// Views and selection adds over the last 30 days (catalog_popularity_sort.sql).
  popular,
  ageAsc,
  ageDesc,
  heightAsc,
  heightDesc,
}

/// Distinct values of the text facets among published profiles, with the
/// number of profiles per value (eye colour, hair colour, country, city).
class CatalogFacets {
  const CatalogFacets({
    this.eyeColors = const {},
    this.hairColors = const {},
    this.countries = const {},
    this.cities = const {},
  });

  final Map<String, int> eyeColors;
  final Map<String, int> hairColors;
  final Map<String, int> countries;
  final Map<String, int> cities;

  bool get isEmpty =>
      eyeColors.isEmpty &&
      hairColors.isEmpty &&
      countries.isEmpty &&
      cities.isEmpty;
}

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  static const int _hourlyRateFallbackMin = 0;
  static const int _hourlyRateFallbackMax = 10000;
  static const int _dailyFeeFallbackMin = 0;
  static const int _dailyFeeFallbackMax = 100000;
  static const Duration _filterBoundsCacheTtl = Duration(minutes: 15);
  static const String _catalogTable = 'catalog_profiles';

  CatalogFilterBounds? _filterBoundsCache;
  DateTime? _filterBoundsCachedAt;

  Future<List<ModelVm>> loadApprovedProfilesPage({
    required int offset,
    required int limit,
    String query = '',
    DateTime? needDate,
    int? ageFrom,
    int? ageTo,
    int? heightFrom,
    int? heightTo,
    int? shoeFrom,
    int? shoeTo,
    int? bustFrom,
    int? bustTo,
    int? waistFrom,
    int? waistTo,
    int? hipsFrom,
    int? hipsTo,
    int? minHourlyRateFrom,
    int? minHourlyRateTo,
    int? minDailyFeeFrom,
    int? minDailyFeeTo,
    String eyeColor = '',
    String hairColor = '',
    String country = '',
    String city = '',
    ProfessionalProfileType? profileRole,
    CatalogSort sort = CatalogSort.recommended,
  }) async {
    assert(offset >= 0 && limit > 0);

    Future<List<ModelVm>> run({
      required bool includeBirthDate,
      required bool includeUnavailableDays,
      required bool includePro,
      required bool includeVerification,
      required bool includeCoverPhoto,
    }) async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> q = _client
          .from(_catalogTable)
          .select(
            ProfileSupabaseSchema.selectCatalog(
              includeBirthDate: includeBirthDate,
              includeUnavailableDays: includeUnavailableDays,
              includePro: includePro,
              includeVerification: includeVerification,
              includeCoverPhoto: includeCoverPhoto,
            ),
          );

      q = _applyFilters(
        q,
        query: query,
        needDate: includeUnavailableDays ? needDate : null,
        ageFrom: ageFrom,
        ageTo: ageTo,
        heightFrom: heightFrom,
        heightTo: heightTo,
        shoeFrom: shoeFrom,
        shoeTo: shoeTo,
        bustFrom: bustFrom,
        bustTo: bustTo,
        waistFrom: waistFrom,
        waistTo: waistTo,
        hipsFrom: hipsFrom,
        hipsTo: hipsTo,
        minHourlyRateFrom: minHourlyRateFrom,
        minHourlyRateTo: minHourlyRateTo,
        minDailyFeeFrom: minDailyFeeFrom,
        minDailyFeeTo: minDailyFeeTo,
        eyeColor: eyeColor,
        hairColor: hairColor,
        country: country,
        city: city,
        profileRole: profileRole,
      );

      var ordered = q.range(offset, offset + limit - 1);
      switch (sort) {
        case CatalogSort.recommended:
          if (includePro) {
            ordered = ordered.order('is_pro', ascending: false);
          }
          if (includeVerification) {
            ordered = ordered.order('is_verified', ascending: false);
          }
          ordered = ordered.order('full_name');
        case CatalogSort.newest:
          ordered = ordered.order('created_at', ascending: false);
        case CatalogSort.popular:
          ordered = ordered.order('popularity', ascending: false);
          if (includePro) {
            ordered = ordered.order('is_pro', ascending: false);
          }
        case CatalogSort.ageAsc:
          ordered = ordered.order('age', ascending: true, nullsFirst: false);
        case CatalogSort.ageDesc:
          ordered = ordered.order('age', ascending: false, nullsFirst: false);
        case CatalogSort.heightAsc:
          ordered = ordered.order('height', ascending: true, nullsFirst: false);
        case CatalogSort.heightDesc:
          ordered = ordered.order('height', ascending: false, nullsFirst: false);
      }
      List<dynamic> rows;
      try {
        rows = await ordered.order('id');
      } on PostgrestException catch (e) {
        if (sort == CatalogSort.popular &&
            SupabaseCompat.isMissingColumn(e, 'popularity')) {
          // catalog_popularity_sort.sql not applied yet: newest instead.
          rows = await q
              .range(offset, offset + limit - 1)
              .order('created_at', ascending: false)
              .order('id');
        } else if (sort != CatalogSort.newest ||
            !SupabaseCompat.isMissingColumn(e, 'created_at')) {
          rethrow;
        } else {
          // Older schema without created_at: newest ≈ highest id.
          rows = await q
              .range(offset, offset + limit - 1)
              .order('id', ascending: false);
        }
      }

      return rows
          .map((e) => ModelVm.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((m) => m.fullName.trim().isNotEmpty)
          .toList(growable: false);
    }

    try {
      return await run(
        includeBirthDate: true,
        includeUnavailableDays: true,
        includePro: true,
        includeVerification: true,
        includeCoverPhoto: true,
      );
    } on PostgrestException catch (e) {
      if (!_shouldFallbackToBasicSelect(e)) rethrow;
      final missingUnavailable = SupabaseCompat.isMissingColumn(
        e,
        'unavailable_days',
      );
      final missingBirthDate = ProfileSupabaseSchema.isMissingBirthDateColumn(
        e,
      );
      final missingPro =
          SupabaseCompat.isMissingColumn(e, 'is_pro') ||
          SupabaseCompat.isMissingColumn(e, 'pro_until');
      final missingVerification = SupabaseCompat.isMissingColumn(
        e,
        'is_verified',
      );
      final missingCoverPhoto = ProfileSupabaseSchema.isMissingCoverPhotoColumn(
        e,
      );
      try {
        return await run(
          includeBirthDate: !missingBirthDate,
          includeUnavailableDays: !missingUnavailable,
          includePro: !missingPro,
          includeVerification: !missingVerification,
          includeCoverPhoto: !missingCoverPhoto,
        );
      } on PostgrestException catch (second) {
        if (!_shouldFallbackToBasicSelect(second)) rethrow;
        return run(
          includeBirthDate: false,
          includeUnavailableDays: false,
          includePro: false,
          includeVerification: false,
          includeCoverPhoto: false,
        );
      }
    }
  }

  /// Applies every catalogue filter to [q]; shared by the page query and
  /// the count used for the live «N profiles» hint.
  PostgrestFilterBuilder<T> _applyFilters<T>(
    PostgrestFilterBuilder<T> q, {
    required String query,
    required DateTime? needDate,
    required int? ageFrom,
    required int? ageTo,
    required int? heightFrom,
    required int? heightTo,
    required int? shoeFrom,
    required int? shoeTo,
    required int? bustFrom,
    required int? bustTo,
    required int? waistFrom,
    required int? waistTo,
    required int? hipsFrom,
    required int? hipsTo,
    required int? minHourlyRateFrom,
    required int? minHourlyRateTo,
    required int? minDailyFeeFrom,
    required int? minDailyFeeTo,
    required String eyeColor,
    required String hairColor,
    required String country,
    required String city,
    required ProfessionalProfileType? profileRole,
  }) {
    PostgrestFilterBuilder<T> range(
      PostgrestFilterBuilder<T> b,
      String column,
      int? from,
      int? to,
    ) {
      if (from != null) b = b.gte(column, from);
      if (to != null) b = b.lte(column, to);
      return b;
    }

    PostgrestFilterBuilder<T> text(
      PostgrestFilterBuilder<T> b,
      String column,
      String value,
    ) {
      final v = _clean(value);
      if (v.isEmpty) return b;
      return b.ilike(column, '%${_escapeForIlike(v)}%');
    }

    q = range(q, 'age', ageFrom, ageTo);
    q = range(q, 'height', heightFrom, heightTo);
    q = range(q, 'shoe_size', shoeFrom, shoeTo);
    q = range(q, 'bust', bustFrom, bustTo);
    q = range(q, 'waist', waistFrom, waistTo);
    q = range(q, 'hips', hipsFrom, hipsTo);
    q = range(q, 'min_hourly_rate', minHourlyRateFrom, minHourlyRateTo);
    q = range(q, 'min_daily_fee', minDailyFeeFrom, minDailyFeeTo);

    if (needDate != null) {
      final dateOnly = DateTime(needDate.year, needDate.month, needDate.day);
      final dateStr = dateOnly.toIso8601String().split('T').first;
      q = q.not('unavailable_days', 'cs', '{${_escapeArrayValue(dateStr)}}');
    }

    final search = _clean(query);
    if (search.isNotEmpty) {
      // Name or city, in one request.
      final safe = _escapeForIlike(search).replaceAll(RegExp(r'[,()]'), ' ');
      final pattern = '%$safe%';
      q = q.or('full_name.ilike.$pattern,city.ilike.$pattern');
    }

    q = text(q, 'eye_color', eyeColor);
    q = text(q, 'hair_color', hairColor);
    q = text(q, 'country', country);
    q = text(q, 'city', city);
    if (profileRole != null) {
      q = q.contains('profile_roles', <String>[profileRole.storageValue]);
    }
    return q;
  }

  /// Number of published profiles matching the filters (no rows fetched).
  Future<int> countApprovedProfiles({
    String query = '',
    DateTime? needDate,
    int? ageFrom,
    int? ageTo,
    int? heightFrom,
    int? heightTo,
    int? shoeFrom,
    int? shoeTo,
    int? bustFrom,
    int? bustTo,
    int? waistFrom,
    int? waistTo,
    int? hipsFrom,
    int? hipsTo,
    int? minHourlyRateFrom,
    int? minHourlyRateTo,
    int? minDailyFeeFrom,
    int? minDailyFeeTo,
    String eyeColor = '',
    String hairColor = '',
    String country = '',
    String city = '',
    ProfessionalProfileType? profileRole,
  }) async {
    final q = _applyFilters(
      _client.from(_catalogTable).select('id'),
      query: query,
      needDate: needDate,
      ageFrom: ageFrom,
      ageTo: ageTo,
      heightFrom: heightFrom,
      heightTo: heightTo,
      shoeFrom: shoeFrom,
      shoeTo: shoeTo,
      bustFrom: bustFrom,
      bustTo: bustTo,
      waistFrom: waistFrom,
      waistTo: waistTo,
      hipsFrom: hipsFrom,
      hipsTo: hipsTo,
      minHourlyRateFrom: minHourlyRateFrom,
      minHourlyRateTo: minHourlyRateTo,
      minDailyFeeFrom: minDailyFeeFrom,
      minDailyFeeTo: minDailyFeeTo,
      eyeColor: eyeColor,
      hairColor: hairColor,
      country: country,
      city: city,
      profileRole: profileRole,
    );
    return q.count(CountOption.exact).then((r) => r.count);
  }

  /// Distinct text facet values among published profiles, counted on the
  /// client (one light query; the catalogue is small).
  Future<CatalogFacets> loadFacets() async {
    final rows = await _client
        .from(_catalogTable)
        .select('eye_color,hair_color,country,city')
        .limit(5000);
    final eye = <String, int>{};
    final hair = <String, int>{};
    final countries = <String, int>{};
    final cities = <String, int>{};
    void bump(Map<String, int> into, Object? raw) {
      final value = (raw ?? '').toString().trim();
      if (value.isEmpty) return;
      into[value] = (into[value] ?? 0) + 1;
    }

    for (final row in rows) {
      bump(eye, row['eye_color']);
      bump(hair, row['hair_color']);
      bump(countries, row['country']);
      bump(cities, row['city']);
    }
    Map<String, int> sorted(Map<String, int> m) {
      final entries = m.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0 ? byCount : a.key.compareTo(b.key);
        });
      return {for (final e in entries) e.key: e.value};
    }

    return CatalogFacets(
      eyeColors: sorted(eye),
      hairColors: sorted(hair),
      countries: sorted(countries),
      cities: sorted(cities),
    );
  }

  String _clean(String value) => value.trim();

  String _escapeForIlike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  String _escapeArrayValue(String value) {
    return value.replaceAll('"', r'\"');
  }

  bool _shouldFallbackToBasicSelect(PostgrestException e) {
    return ProfileSupabaseSchema.isMissingCatalogOptionalColumn(e);
  }

  ({int min, int max}) _normalizedRange(
    int? minValue,
    int? maxValue,
    int fallbackMin,
    int fallbackMax,
  ) {
    final min = (minValue ?? fallbackMin).clamp(fallbackMin, fallbackMax);
    final max = (maxValue ?? fallbackMax).clamp(fallbackMin, fallbackMax);

    if (min > max) {
      return (min: fallbackMin, max: fallbackMax);
    }

    return (min: min, max: max);
  }

  Future<int?> _edgeOf(
    String column, {
    required bool ascending,
    required int minAllowed,
    required int maxAllowed,
  }) async {
    final rows = await _client
        .from(_catalogTable)
        .select(column)
        .not(column, 'is', null)
        .gte(column, minAllowed)
        .lte(column, maxAllowed)
        .order(column, ascending: ascending)
        .limit(1);

    if (rows.isNotEmpty) {
      final value = rows.first[column];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }
    return null;
  }

  Future<CatalogFilterBounds> loadFilterBounds() async {
    final cachedAt = _filterBoundsCachedAt;
    final cached = _filterBoundsCache;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _filterBoundsCacheTtl) {
      return cached;
    }

    try {
      final data = await _client.rpc('catalog_filter_bounds');
      if (data is List && data.isNotEmpty) {
        return _cacheFilterBounds(
          _boundsFromMap(Map<String, dynamic>.from(data.first as Map)),
        );
      }
      if (data is Map) {
        return _cacheFilterBounds(
          _boundsFromMap(Map<String, dynamic>.from(data)),
        );
      }
    } on PostgrestException catch (e) {
      if (!_shouldFallbackToEdgeQueries(e)) rethrow;
    }

    return _cacheFilterBounds(await _loadFilterBoundsFromEdgeQueries());
  }

  CatalogFilterBounds _cacheFilterBounds(CatalogFilterBounds bounds) {
    _filterBoundsCache = bounds;
    _filterBoundsCachedAt = DateTime.now();
    return bounds;
  }

  bool _shouldFallbackToEdgeQueries(PostgrestException e) {
    return SupabaseCompat.isMissingRpc(e, 'catalog_filter_bounds');
  }

  int? _intFromRpcMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  CatalogFilterBounds _boundsFromMap(Map<String, dynamic> map) {
    final age = _normalizedRange(
      _intFromRpcMap(map, 'age_min'),
      _intFromRpcMap(map, 'age_max'),
      kAgeMin,
      kAgeMax,
    );
    final height = _normalizedRange(
      _intFromRpcMap(map, 'height_min'),
      _intFromRpcMap(map, 'height_max'),
      kHeightMin,
      kHeightMax,
    );
    final shoe = _normalizedRange(
      _intFromRpcMap(map, 'shoe_min'),
      _intFromRpcMap(map, 'shoe_max'),
      kShoeMin,
      kShoeMax,
    );
    final bust = _normalizedRange(
      _intFromRpcMap(map, 'bust_min'),
      _intFromRpcMap(map, 'bust_max'),
      kBustMin,
      kBustMax,
    );
    final waist = _normalizedRange(
      _intFromRpcMap(map, 'waist_min'),
      _intFromRpcMap(map, 'waist_max'),
      kWaistMin,
      kWaistMax,
    );
    final hips = _normalizedRange(
      _intFromRpcMap(map, 'hips_min'),
      _intFromRpcMap(map, 'hips_max'),
      kHipsMin,
      kHipsMax,
    );
    final hourly = _normalizedRange(
      _intFromRpcMap(map, 'min_hourly_rate_min'),
      _intFromRpcMap(map, 'min_hourly_rate_max'),
      _hourlyRateFallbackMin,
      _hourlyRateFallbackMax,
    );
    final daily = _normalizedRange(
      _intFromRpcMap(map, 'min_daily_fee_min'),
      _intFromRpcMap(map, 'min_daily_fee_max'),
      _dailyFeeFallbackMin,
      _dailyFeeFallbackMax,
    );

    return CatalogFilterBounds(
      ageMin: age.min,
      ageMax: age.max,
      heightMin: height.min,
      heightMax: height.max,
      shoeMin: shoe.min,
      shoeMax: shoe.max,
      bustMin: bust.min,
      bustMax: bust.max,
      waistMin: waist.min,
      waistMax: waist.max,
      hipsMin: hips.min,
      hipsMax: hips.max,
      minHourlyRateMin: hourly.min,
      minHourlyRateMax: hourly.max,
      minDailyFeeMin: daily.min,
      minDailyFeeMax: daily.max,
    );
  }

  Future<CatalogFilterBounds> _loadFilterBoundsFromEdgeQueries() async {
    final results = await Future.wait<int?>([
      _edgeOf('age', ascending: true, minAllowed: kAgeMin, maxAllowed: kAgeMax),
      _edgeOf(
        'age',
        ascending: false,
        minAllowed: kAgeMin,
        maxAllowed: kAgeMax,
      ),
      _edgeOf(
        'height',
        ascending: true,
        minAllowed: kHeightMin,
        maxAllowed: kHeightMax,
      ),
      _edgeOf(
        'height',
        ascending: false,
        minAllowed: kHeightMin,
        maxAllowed: kHeightMax,
      ),
      _edgeOf(
        'shoe_size',
        ascending: true,
        minAllowed: kShoeMin,
        maxAllowed: kShoeMax,
      ),
      _edgeOf(
        'shoe_size',
        ascending: false,
        minAllowed: kShoeMin,
        maxAllowed: kShoeMax,
      ),
      _edgeOf(
        'bust',
        ascending: true,
        minAllowed: kBustMin,
        maxAllowed: kBustMax,
      ),
      _edgeOf(
        'bust',
        ascending: false,
        minAllowed: kBustMin,
        maxAllowed: kBustMax,
      ),
      _edgeOf(
        'waist',
        ascending: true,
        minAllowed: kWaistMin,
        maxAllowed: kWaistMax,
      ),
      _edgeOf(
        'waist',
        ascending: false,
        minAllowed: kWaistMin,
        maxAllowed: kWaistMax,
      ),
      _edgeOf(
        'hips',
        ascending: true,
        minAllowed: kHipsMin,
        maxAllowed: kHipsMax,
      ),
      _edgeOf(
        'hips',
        ascending: false,
        minAllowed: kHipsMin,
        maxAllowed: kHipsMax,
      ),
      _edgeOf(
        'min_hourly_rate',
        ascending: true,
        minAllowed: _hourlyRateFallbackMin,
        maxAllowed: _hourlyRateFallbackMax,
      ),
      _edgeOf(
        'min_hourly_rate',
        ascending: false,
        minAllowed: _hourlyRateFallbackMin,
        maxAllowed: _hourlyRateFallbackMax,
      ),
      _edgeOf(
        'min_daily_fee',
        ascending: true,
        minAllowed: _dailyFeeFallbackMin,
        maxAllowed: _dailyFeeFallbackMax,
      ),
      _edgeOf(
        'min_daily_fee',
        ascending: false,
        minAllowed: _dailyFeeFallbackMin,
        maxAllowed: _dailyFeeFallbackMax,
      ),
    ]);

    final ageMin = results[0];
    final ageMax = results[1];
    final heightMin = results[2];
    final heightMax = results[3];
    final shoeMin = results[4];
    final shoeMax = results[5];
    final bustMin = results[6];
    final bustMax = results[7];
    final waistMin = results[8];
    final waistMax = results[9];
    final hipsMin = results[10];
    final hipsMax = results[11];
    final minHourlyRateMin = results[12];
    final minHourlyRateMax = results[13];
    final minDailyFeeMin = results[14];
    final minDailyFeeMax = results[15];

    final age = _normalizedRange(ageMin, ageMax, kAgeMin, kAgeMax);
    final height = _normalizedRange(
      heightMin,
      heightMax,
      kHeightMin,
      kHeightMax,
    );
    final shoe = _normalizedRange(shoeMin, shoeMax, kShoeMin, kShoeMax);
    final bust = _normalizedRange(bustMin, bustMax, kBustMin, kBustMax);
    final waist = _normalizedRange(waistMin, waistMax, kWaistMin, kWaistMax);
    final hips = _normalizedRange(hipsMin, hipsMax, kHipsMin, kHipsMax);
    final hourly = _normalizedRange(
      minHourlyRateMin,
      minHourlyRateMax,
      _hourlyRateFallbackMin,
      _hourlyRateFallbackMax,
    );
    final daily = _normalizedRange(
      minDailyFeeMin,
      minDailyFeeMax,
      _dailyFeeFallbackMin,
      _dailyFeeFallbackMax,
    );

    return CatalogFilterBounds(
      ageMin: age.min,
      ageMax: age.max,
      heightMin: height.min,
      heightMax: height.max,
      shoeMin: shoe.min,
      shoeMax: shoe.max,
      bustMin: bust.min,
      bustMax: bust.max,
      waistMin: waist.min,
      waistMax: waist.max,
      hipsMin: hips.min,
      hipsMax: hips.max,
      minHourlyRateMin: hourly.min,
      minHourlyRateMax: hourly.max,
      minDailyFeeMin: daily.min,
      minDailyFeeMax: daily.max,
    );
  }
}
