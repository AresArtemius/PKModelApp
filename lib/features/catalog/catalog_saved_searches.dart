import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_logger.dart';
import 'catalog_controller.dart';

const String _savedSearchesKeyPrefix = 'catalog_saved_searches_v1';

class CatalogSavedSearch {
  const CatalogSavedSearch({
    required this.id,
    required this.title,
    required this.filters,
    this.isBuiltin = false,
  });

  factory CatalogSavedSearch.fromJson(Map<String, dynamic> json) {
    final filtersJson = json['filters'];
    return CatalogSavedSearch(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      filters: filtersJson is Map
          ? CatalogFilterSnapshot.fromJson(
              Map<String, dynamic>.from(filtersJson),
            )
          : const CatalogFilterSnapshot(),
    );
  }

  final String id;
  final String title;
  final CatalogFilterSnapshot filters;
  final bool isBuiltin;

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'filters': filters.toJson()};
  }
}

class CatalogSavedSearchesController extends ChangeNotifier {
  CatalogSavedSearchesController({required String userKey})
    : _storageKey = '$_savedSearchesKeyPrefix:$userKey';

  final String _storageKey;

  bool isLoading = true;
  Object? lastError;
  Future<void>? _loadFuture;

  final List<CatalogSavedSearch> _items = [];
  List<CatalogSavedSearch> get items => List.unmodifiable(_items);

  Future<void> load() {
    final future = _load();
    _loadFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    });
  }

  Future<void> _load() async {
    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final decoded = raw == null ? const [] : jsonDecode(raw);
      final next = <CatalogSavedSearch>[];

      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final search = CatalogSavedSearch.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (search.id.trim().isEmpty || search.title.trim().isEmpty) {
            continue;
          }
          next.add(search);
        }
      }

      _items
        ..clear()
        ..addAll(next);
    } catch (e, st) {
      lastError = e;
      assert(() {
        AppLogger.error(
          'Catalog saved searches load failed',
          error: e,
          stackTrace: st,
        );
        return true;
      }());
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureLoaded() async {
    if (!isLoading) return;
    await (_loadFuture ?? load());
  }

  Future<void> save({
    required String title,
    required CatalogFilterSnapshot filters,
  }) async {
    await _ensureLoaded();

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final search = CatalogSavedSearch(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: trimmedTitle,
      filters: filters,
    );

    _items.add(search);
    notifyListeners();
    await _persist();
  }

  Future<void> rename({required String id, required String title}) async {
    await _ensureLoaded();

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final index = _items.indexWhere((item) => item.id == id && !item.isBuiltin);
    if (index < 0) return;

    final current = _items[index];
    if (current.title == trimmedTitle) return;

    _items[index] = CatalogSavedSearch(
      id: current.id,
      title: trimmedTitle,
      filters: current.filters,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    await _ensureLoaded();

    final before = _items.length;
    _items.removeWhere((item) => item.id == id && !item.isBuiltin);
    if (_items.length == before) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.map((item) => item.toJson()).toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}

final catalogSavedSearchesProvider =
    ChangeNotifierProvider<CatalogSavedSearchesController>((ref) {
      final sb = Supabase.instance.client;
      final userKey = sb.auth.currentUser?.id ?? 'guest';
      final controller = CatalogSavedSearchesController(userKey: userKey);

      controller.load();

      final sub = sb.auth.onAuthStateChange.listen((_) {
        ref.invalidateSelf();
      });
      ref.onDispose(sub.cancel);

      return controller;
    });
