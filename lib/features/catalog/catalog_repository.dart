import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import '../../ui/brand/ui_constants.dart';
import '../profile/profile_supabase_schema.dart';
import 'catalog_filter_bounds.dart';
import 'model_data.dart';

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  static const int _hourlyRateFallbackMin = 0;
  static const int _hourlyRateFallbackMax = 10000;
  static const int _dailyFeeFallbackMin = 0;
  static const int _dailyFeeFallbackMax = 100000;
  static const Duration _filterBoundsCacheTtl = Duration(minutes: 15);

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
          .from(ProfileSupabaseSchema.table)
          .select(
            ProfileSupabaseSchema.selectCatalog(
              includeBirthDate: includeBirthDate,
              includeUnavailableDays: includeUnavailableDays,
              includePro: includePro,
              includeVerification: includeVerification,
              includeCoverPhoto: includeCoverPhoto,
            ),
          );

      q = q.eq('status', 'approved');

      q = _applyIntRangeFilter(q, 'age', ageFrom, ageTo);
      q = _applyIntRangeFilter(q, 'height', heightFrom, heightTo);
      q = _applyIntRangeFilter(q, 'shoe_size', shoeFrom, shoeTo);
      q = _applyIntRangeFilter(q, 'bust', bustFrom, bustTo);
      q = _applyIntRangeFilter(q, 'waist', waistFrom, waistTo);
      q = _applyIntRangeFilter(q, 'hips', hipsFrom, hipsTo);
      q = _applyIntRangeFilter(
        q,
        'min_hourly_rate',
        minHourlyRateFrom,
        minHourlyRateTo,
      );
      q = _applyIntRangeFilter(
        q,
        'min_daily_fee',
        minDailyFeeFrom,
        minDailyFeeTo,
      );

      final search = _clean(query);
      final eye = _clean(eyeColor);
      final hair = _clean(hairColor);
      final ctry = _clean(country);
      final cty = _clean(city);

      if (needDate != null && includeUnavailableDays) {
        final dateOnly = DateTime(needDate.year, needDate.month, needDate.day);
        final dateStr = dateOnly.toIso8601String().split('T').first;
        q = q.not('unavailable_days', 'cs', '{${_escapeArrayValue(dateStr)}}');
      }

      if (search.isNotEmpty) {
        q = q.ilike('full_name', '%${_escapeForIlike(search)}%');
      }

      q = _applyTextFilter(q, 'eye_color', eye);
      q = _applyTextFilter(q, 'hair_color', hair);
      q = _applyTextFilter(q, 'country', ctry);
      q = _applyTextFilter(q, 'city', cty);

      var ordered = q.range(offset, offset + limit - 1);
      if (includePro) {
        ordered = ordered.order('is_pro', ascending: false);
      }
      if (includeVerification) {
        ordered = ordered.order('is_verified', ascending: false);
      }
      final rows = await ordered.order('full_name').order('id');

      return (rows as List)
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
      final missingCoverPhoto = SupabaseCompat.isMissingColumn(
        e,
        'cover_photo_url',
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

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyIntRangeFilter(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> q,
    String column,
    int? from,
    int? to,
  ) {
    if (from != null) q = q.gte(column, from);
    if (to != null) q = q.lte(column, to);
    return q;
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyTextFilter(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> q,
    String column,
    String value,
  ) {
    if (value.isEmpty) return q;
    return q.ilike(column, '%${_escapeForIlike(value)}%');
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
    final min = minValue ?? fallbackMin;
    final max = maxValue ?? fallbackMax;

    if (min > max) {
      return (min: fallbackMin, max: fallbackMax);
    }

    return (min: min, max: max);
  }

  Future<int?> _edgeOf(String column, {required bool ascending}) async {
    final rows = await _client
        .from(ProfileSupabaseSchema.table)
        .select(column)
        .eq('status', 'approved')
        .not(column, 'is', null)
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
      _edgeOf('age', ascending: true),
      _edgeOf('age', ascending: false),
      _edgeOf('height', ascending: true),
      _edgeOf('height', ascending: false),
      _edgeOf('shoe_size', ascending: true),
      _edgeOf('shoe_size', ascending: false),
      _edgeOf('bust', ascending: true),
      _edgeOf('bust', ascending: false),
      _edgeOf('waist', ascending: true),
      _edgeOf('waist', ascending: false),
      _edgeOf('hips', ascending: true),
      _edgeOf('hips', ascending: false),
      _edgeOf('min_hourly_rate', ascending: true),
      _edgeOf('min_hourly_rate', ascending: false),
      _edgeOf('min_daily_fee', ascending: true),
      _edgeOf('min_daily_fee', ascending: false),
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
