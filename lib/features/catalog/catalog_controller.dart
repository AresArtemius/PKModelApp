import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/app_logger.dart';
import 'model_data.dart';
import 'catalog_repository.dart';
import 'catalog_filter_bounds.dart';
import '../profile/profile_model.dart';

class CatalogFilterSnapshot {
  const CatalogFilterSnapshot({
    this.query = '',
    this.ageFrom,
    this.ageTo,
    this.heightFrom,
    this.heightTo,
    this.shoeFrom,
    this.shoeTo,
    this.bustFrom,
    this.bustTo,
    this.waistFrom,
    this.waistTo,
    this.hipsFrom,
    this.hipsTo,
    this.minHourlyRateFrom,
    this.minHourlyRateTo,
    this.minDailyFeeFrom,
    this.minDailyFeeTo,
    this.eyeColor = '',
    this.hairColor = '',
    this.country = '',
    this.city = '',
    this.needDate,
    this.profileRole,
  });

  factory CatalogFilterSnapshot.fromJson(Map<String, dynamic> json) {
    int? intValue(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    String stringValue(String key) => (json[key] ?? '').toString();

    DateTime? dateValue(String key) {
      final value = json[key];
      if (value == null) return null;
      final parsed = DateTime.tryParse(value.toString());
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return CatalogFilterSnapshot(
      query: stringValue('query'),
      ageFrom: intValue('ageFrom'),
      ageTo: intValue('ageTo'),
      heightFrom: intValue('heightFrom'),
      heightTo: intValue('heightTo'),
      shoeFrom: intValue('shoeFrom'),
      shoeTo: intValue('shoeTo'),
      bustFrom: intValue('bustFrom'),
      bustTo: intValue('bustTo'),
      waistFrom: intValue('waistFrom'),
      waistTo: intValue('waistTo'),
      hipsFrom: intValue('hipsFrom'),
      hipsTo: intValue('hipsTo'),
      minHourlyRateFrom: intValue('minHourlyRateFrom'),
      minHourlyRateTo: intValue('minHourlyRateTo'),
      minDailyFeeFrom: intValue('minDailyFeeFrom'),
      minDailyFeeTo: intValue('minDailyFeeTo'),
      eyeColor: stringValue('eyeColor'),
      hairColor: stringValue('hairColor'),
      country: stringValue('country'),
      city: stringValue('city'),
      needDate: dateValue('needDate'),
      profileRole: _profileRoleValue(json['profileRole']),
    );
  }

  final String query;
  final int? ageFrom;
  final int? ageTo;
  final int? heightFrom;
  final int? heightTo;
  final int? shoeFrom;
  final int? shoeTo;
  final int? bustFrom;
  final int? bustTo;
  final int? waistFrom;
  final int? waistTo;
  final int? hipsFrom;
  final int? hipsTo;
  final int? minHourlyRateFrom;
  final int? minHourlyRateTo;
  final int? minDailyFeeFrom;
  final int? minDailyFeeTo;
  final String eyeColor;
  final String hairColor;
  final String country;
  final String city;
  final DateTime? needDate;
  final ProfessionalProfileType? profileRole;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'ageFrom': ageFrom,
      'ageTo': ageTo,
      'heightFrom': heightFrom,
      'heightTo': heightTo,
      'shoeFrom': shoeFrom,
      'shoeTo': shoeTo,
      'bustFrom': bustFrom,
      'bustTo': bustTo,
      'waistFrom': waistFrom,
      'waistTo': waistTo,
      'hipsFrom': hipsFrom,
      'hipsTo': hipsTo,
      'minHourlyRateFrom': minHourlyRateFrom,
      'minHourlyRateTo': minHourlyRateTo,
      'minDailyFeeFrom': minDailyFeeFrom,
      'minDailyFeeTo': minDailyFeeTo,
      'eyeColor': eyeColor,
      'hairColor': hairColor,
      'country': country,
      'city': city,
      'needDate': needDate?.toIso8601String().split('T').first,
      'profileRole': profileRole?.storageValue,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CatalogFilterSnapshot &&
        query == other.query &&
        ageFrom == other.ageFrom &&
        ageTo == other.ageTo &&
        heightFrom == other.heightFrom &&
        heightTo == other.heightTo &&
        shoeFrom == other.shoeFrom &&
        shoeTo == other.shoeTo &&
        bustFrom == other.bustFrom &&
        bustTo == other.bustTo &&
        waistFrom == other.waistFrom &&
        waistTo == other.waistTo &&
        hipsFrom == other.hipsFrom &&
        hipsTo == other.hipsTo &&
        minHourlyRateFrom == other.minHourlyRateFrom &&
        minHourlyRateTo == other.minHourlyRateTo &&
        minDailyFeeFrom == other.minDailyFeeFrom &&
        minDailyFeeTo == other.minDailyFeeTo &&
        eyeColor == other.eyeColor &&
        hairColor == other.hairColor &&
        country == other.country &&
        city == other.city &&
        _dateKey(needDate) == _dateKey(other.needDate) &&
        profileRole == other.profileRole;
  }

  @override
  int get hashCode => Object.hashAll([
    query,
    ageFrom,
    ageTo,
    heightFrom,
    heightTo,
    shoeFrom,
    shoeTo,
    bustFrom,
    bustTo,
    waistFrom,
    waistTo,
    hipsFrom,
    hipsTo,
    minHourlyRateFrom,
    minHourlyRateTo,
    minDailyFeeFrom,
    minDailyFeeTo,
    eyeColor,
    hairColor,
    country,
    city,
    _dateKey(needDate),
    profileRole,
  ]);

  static String? _dateKey(DateTime? value) {
    if (value == null) return null;
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).toIso8601String().split('T').first;
  }

  static ProfessionalProfileType? _profileRoleValue(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return profileTypeFromString(text);
  }
}

class CatalogController extends ChangeNotifier {
  CatalogController({
    required CatalogRepository repo,
    int pageSize = 24,
    int autoFillMaxLoads = 3,
  }) : _repo = repo,
       _pageSize = pageSize,
       _autoFillMaxLoads = autoFillMaxLoads;

  final CatalogRepository _repo;
  final int _pageSize;
  final int _autoFillMaxLoads;

  final List<ModelVm> _loaded = [];
  List<ModelVm> get loaded => List.unmodifiable(_loaded);

  bool isInitialLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int offset = 0;
  Object? lastError;
  CatalogFilterBounds? bounds;

  int _loadToken = 0;
  int _autoFillLoads = 0;
  Timer? _loadMoreThrottle;

  String query = '';
  int? ageFrom;
  int? ageTo;
  int? heightFrom;
  int? heightTo;
  int? shoeFrom;
  int? shoeTo;
  int? bustFrom;
  int? bustTo;
  int? waistFrom;
  int? waistTo;
  int? hipsFrom;
  int? hipsTo;
  int? minHourlyRateFrom;
  int? minHourlyRateTo;
  int? minDailyFeeFrom;
  int? minDailyFeeTo;
  String eyeColor = '';
  String hairColor = '';
  String country = '';
  String city = '';
  DateTime? needDate;
  ProfessionalProfileType? profileRole;

  CatalogFilterSnapshot get filterSnapshot {
    return CatalogFilterSnapshot(
      query: query,
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
      needDate: needDate,
      profileRole: profileRole,
    );
  }

  void _resetAdvancedFiltersOnly() {
    ageFrom = null;
    ageTo = null;
    heightFrom = null;
    heightTo = null;
    shoeFrom = null;
    shoeTo = null;
    bustFrom = null;
    bustTo = null;
    waistFrom = null;
    waistTo = null;
    hipsFrom = null;
    hipsTo = null;
    minHourlyRateFrom = null;
    minHourlyRateTo = null;
    minDailyFeeFrom = null;
    minDailyFeeTo = null;
    eyeColor = '';
    hairColor = '';
    country = '';
    city = '';
    needDate = null;
  }

  @override
  void dispose() {
    _loadMoreThrottle?.cancel();
    super.dispose();
  }

  void setQuery(String value) {
    query = value.trim();
    notifyListeners();
  }

  void setProfileRole(ProfessionalProfileType? value) {
    if (profileRole == value) return;
    profileRole = value;
    notifyListeners();
  }

  void applyAdvancedFilters({
    required bool reset,
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
    DateTime? needDate,
  }) {
    if (reset) {
      _resetAdvancedFiltersOnly();
    } else {
      this.ageFrom = ageFrom;
      this.ageTo = ageTo;
      this.heightFrom = heightFrom;
      this.heightTo = heightTo;
      this.shoeFrom = shoeFrom;
      this.shoeTo = shoeTo;
      this.bustFrom = bustFrom;
      this.bustTo = bustTo;
      this.waistFrom = waistFrom;
      this.waistTo = waistTo;
      this.hipsFrom = hipsFrom;
      this.hipsTo = hipsTo;
      this.minHourlyRateFrom = minHourlyRateFrom;
      this.minHourlyRateTo = minHourlyRateTo;
      this.minDailyFeeFrom = minDailyFeeFrom;
      this.minDailyFeeTo = minDailyFeeTo;
      this.eyeColor = eyeColor.trim();
      this.hairColor = hairColor.trim();
      this.country = country.trim();
      this.city = city.trim();
      this.needDate = needDate;
    }
    notifyListeners();
  }

  void clearAllFilters() {
    query = '';
    profileRole = null;
    _resetAdvancedFiltersOnly();
    notifyListeners();
  }

  void applyFilterSnapshot(CatalogFilterSnapshot snapshot) {
    query = snapshot.query.trim();
    ageFrom = snapshot.ageFrom;
    ageTo = snapshot.ageTo;
    heightFrom = snapshot.heightFrom;
    heightTo = snapshot.heightTo;
    shoeFrom = snapshot.shoeFrom;
    shoeTo = snapshot.shoeTo;
    bustFrom = snapshot.bustFrom;
    bustTo = snapshot.bustTo;
    waistFrom = snapshot.waistFrom;
    waistTo = snapshot.waistTo;
    hipsFrom = snapshot.hipsFrom;
    hipsTo = snapshot.hipsTo;
    minHourlyRateFrom = snapshot.minHourlyRateFrom;
    minHourlyRateTo = snapshot.minHourlyRateTo;
    minDailyFeeFrom = snapshot.minDailyFeeFrom;
    minDailyFeeTo = snapshot.minDailyFeeTo;
    eyeColor = snapshot.eyeColor.trim();
    hairColor = snapshot.hairColor.trim();
    country = snapshot.country.trim();
    city = snapshot.city.trim();
    needDate = snapshot.needDate;
    profileRole = snapshot.profileRole;
    notifyListeners();
  }

  Future<void> loadBounds() async {
    try {
      bounds = await _repo.loadFilterBounds();
    } catch (e, st) {
      lastError = e;
      assert(() {
        AppLogger.error(
          'Catalog filter bounds load failed',
          error: e,
          stackTrace: st,
        );
        return true;
      }());
    } finally {
      notifyListeners();
    }
  }

  Future<void> reload() async {
    final token = ++_loadToken;
    isInitialLoading = true;
    isLoadingMore = false;
    hasMore = true;
    offset = 0;
    _loaded.clear();
    _autoFillLoads = 0;
    lastError = null;
    notifyListeners();

    try {
      final first = await _loadPage(offset: 0, limit: _pageSize);
      if (token != _loadToken) return;
      _loaded.addAll(first);
      offset = _loaded.length;
      hasMore = first.length == _pageSize;
    } catch (e, st) {
      lastError = e;
      assert(() {
        AppLogger.error('Catalog reload failed', error: e, stackTrace: st);
        return true;
      }());
    } finally {
      if (token == _loadToken) {
        isInitialLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => reload();

  void scheduleLoadMoreThrottle() {
    _loadMoreThrottle?.cancel();
    _loadMoreThrottle = Timer(const Duration(milliseconds: 160), () {
      loadMore();
    });
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore || isInitialLoading) return;
    final token = _loadToken;
    isLoadingMore = true;
    notifyListeners();

    try {
      final next = await _loadPage(offset: offset, limit: _pageSize);
      if (token != _loadToken) return;
      _loaded.addAll(next);
      offset = _loaded.length;
      hasMore = next.length == _pageSize;
    } catch (e, st) {
      lastError = e;
      assert(() {
        AppLogger.error('Catalog load more failed', error: e, stackTrace: st);
        return true;
      }());
    } finally {
      if (token == _loadToken) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void maybeAutoFillMore({required bool itemsEmpty}) {
    if (!itemsEmpty) {
      if (_autoFillLoads != 0) _autoFillLoads = 0;
      return;
    }
    if (!hasMore || isLoadingMore || isInitialLoading) return;
    if (_autoFillLoads >= _autoFillMaxLoads) return;
    _autoFillLoads += 1;
    scheduleLoadMoreThrottle();
  }

  bool get shouldAutoFillNow {
    if (!hasMore || isLoadingMore || isInitialLoading) return false;
    if (_autoFillLoads == 0) return false;
    return _autoFillLoads <= _autoFillMaxLoads;
  }

  List<ModelVm> applyLocalFilters(List<ModelVm> items) {
    final cityQ = city.trim().toLowerCase();
    final eyeQ = eyeColor.trim().toLowerCase();
    final hairQ = hairColor.trim().toLowerCase();
    final countryQ = country.trim().toLowerCase();
    final role = profileRole;

    final need = needDate == null
        ? null
        : DateTime(needDate!.year, needDate!.month, needDate!.day);

    bool matches(ModelVm m) {
      if (role != null && !m.hasProfileRole(role)) return false;

      if (ageFrom != null && m.age < ageFrom!) return false;
      if (ageTo != null && m.age > ageTo!) return false;

      if (heightFrom != null && m.height < heightFrom!) return false;
      if (heightTo != null && m.height > heightTo!) return false;

      final s = m.shoeSize;
      if (shoeFrom != null && (s == null || s < shoeFrom!)) return false;
      if (shoeTo != null && (s == null || s > shoeTo!)) return false;

      final b = m.bust;
      if (bustFrom != null && b < bustFrom!) return false;
      if (bustTo != null && b > bustTo!) return false;

      final w = m.waist;
      if (waistFrom != null && w < waistFrom!) return false;
      if (waistTo != null && w > waistTo!) return false;

      final h = m.hips;
      if (hipsFrom != null && h < hipsFrom!) return false;
      if (hipsTo != null && h > hipsTo!) return false;

      final hourly = m.minHourlyRate;
      if (minHourlyRateFrom != null &&
          (hourly == null || hourly < minHourlyRateFrom!)) {
        return false;
      }
      if (minHourlyRateTo != null &&
          (hourly == null || hourly > minHourlyRateTo!)) {
        return false;
      }

      final daily = m.minDailyFee;
      if (minDailyFeeFrom != null &&
          (daily == null || daily < minDailyFeeFrom!)) {
        return false;
      }
      if (minDailyFeeTo != null && (daily == null || daily > minDailyFeeTo!)) {
        return false;
      }

      final cityL = m.city.toLowerCase();
      if (cityQ.isNotEmpty && !cityL.contains(cityQ)) return false;

      final eyeL = m.eyeColor.toLowerCase();
      final hairL = m.hairColor.toLowerCase();
      final countryL = m.country.toLowerCase();

      if (eyeQ.isNotEmpty && !eyeL.contains(eyeQ)) return false;
      if (hairQ.isNotEmpty && !hairL.contains(hairQ)) return false;
      if (countryQ.isNotEmpty && !countryL.contains(countryQ)) return false;

      if (need != null) {
        for (final d in m.unavailableDays) {
          final dd = DateTime(d.year, d.month, d.day);
          if (dd == need) return false;
        }
      }

      return true;
    }

    return items.where(matches).toList();
  }

  Future<List<ModelVm>> _loadPage({required int offset, required int limit}) {
    return _repo.loadApprovedProfilesPage(
      offset: offset,
      limit: limit,
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
    );
  }
}
