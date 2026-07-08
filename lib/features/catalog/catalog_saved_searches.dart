import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_logger.dart';
import '../auth/auth_controller.dart';
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
  CatalogSavedSearchesController({
    required String userKey,
    required SupabaseClient supabase,
    required String? userId,
  }) : _storageKey = '$_savedSearchesKeyPrefix:$userKey',
       _supabase = supabase,
       _userId = userId?.trim();

  final String _storageKey;
  final SupabaseClient _supabase;
  final String? _userId;
  bool _remoteUnavailable = false;

  bool get isRemoteEnabled =>
      !_remoteUnavailable && (_userId?.isNotEmpty ?? false);

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
      final next = isRemoteEnabled ? await _loadMerged() : await _loadLocal();

      _items
        ..clear()
        ..addAll(next);

      if (isRemoteEnabled) {
        await _migrateLocalSearches();
      }
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
      if (isRemoteEnabled && _isMissingRemoteTable(e)) {
        _remoteUnavailable = true;
        final next = await _loadLocal();
        _items
          ..clear()
          ..addAll(next);
      }
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

    final search = isRemoteEnabled
        ? await _insertRemote(title: trimmedTitle, filters: filters)
        : CatalogSavedSearch(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: trimmedTitle,
            filters: filters,
          );

    _items.add(search);
    notifyListeners();
    await _persistLocal();
    if (isRemoteEnabled) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    if (!isRemoteEnabled) {
      await load();
      return;
    }

    final next = await _loadMerged();
    _items
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<void> rename({required String id, required String title}) async {
    await _ensureLoaded();

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final index = _items.indexWhere((item) => item.id == id && !item.isBuiltin);
    if (index < 0) return;

    final current = _items[index];
    if (current.title == trimmedTitle) return;

    if (isRemoteEnabled) {
      await _supabase
          .from('catalog_saved_searches')
          .update({'title': trimmedTitle})
          .eq('id', id);
    }

    _items[index] = CatalogSavedSearch(
      id: current.id,
      title: trimmedTitle,
      filters: current.filters,
    );
    notifyListeners();
    await _persistLocal();
    if (isRemoteEnabled) {
      await refresh();
    }
  }

  Future<void> delete(String id) async {
    await _ensureLoaded();

    final before = _items.length;
    if (isRemoteEnabled) {
      await _supabase.from('catalog_saved_searches').delete().eq('id', id);
    }
    _items.removeWhere((item) => item.id == id && !item.isBuiltin);
    if (_items.length == before) return;
    notifyListeners();
    await _persistLocal();
    if (isRemoteEnabled) {
      await refresh();
    }
  }

  Future<List<CatalogSavedSearch>> _loadRemote() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    final rows = await _supabase
        .from('catalog_saved_searches')
        .select('id,title,filters')
        .eq('user_id', userId)
        .order('position', ascending: true)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _fromRemoteRow(Map<String, dynamic>.from(row as Map)))
        .where(
          (search) =>
              search.id.trim().isNotEmpty && search.title.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<CatalogSavedSearch> _insertRemote({
    required String title,
    required CatalogFilterSnapshot filters,
  }) async {
    final row = await _supabase
        .from('catalog_saved_searches')
        .insert({
          'user_id': _userId,
          'title': title,
          'filters': filters.toJson(),
          'position': _items.length,
        })
        .select('id,title,filters')
        .single();
    return _fromRemoteRow(Map<String, dynamic>.from(row));
  }

  CatalogSavedSearch _fromRemoteRow(Map<String, dynamic> row) {
    final filtersJson = row['filters'];
    return CatalogSavedSearch(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      filters: filtersJson is Map
          ? CatalogFilterSnapshot.fromJson(
              Map<String, dynamic>.from(filtersJson),
            )
          : const CatalogFilterSnapshot(),
    );
  }

  Future<List<CatalogSavedSearch>> _loadLocal() async {
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

    return next;
  }

  Future<List<CatalogSavedSearch>> _loadMerged() async {
    final remote = await _loadRemote();
    final local = await _loadLocal();
    return _mergeSearches(remote, local);
  }

  List<CatalogSavedSearch> _mergeSearches(
    Iterable<CatalogSavedSearch> primary,
    Iterable<CatalogSavedSearch> secondary,
  ) {
    final seen = <String>{};
    final merged = <CatalogSavedSearch>[];

    void add(CatalogSavedSearch item) {
      if (item.id.trim().isEmpty || item.title.trim().isEmpty) return;
      final key = _dedupeKey(item);
      if (!seen.add(key)) return;
      merged.add(item);
    }

    for (final item in primary) {
      add(item);
    }
    for (final item in secondary) {
      add(item);
    }
    return merged;
  }

  Future<void> _migrateLocalSearches() async {
    final localItems = await _loadLocal();
    if (localItems.isEmpty) return;
    final existingKeys = _items.map(_dedupeKey).toSet();
    final migrated = <CatalogSavedSearch>[];

    for (final item in localItems) {
      if (item.isBuiltin || existingKeys.contains(_dedupeKey(item))) continue;
      final saved = await _insertRemote(
        title: item.title,
        filters: item.filters,
      );
      migrated.add(saved);
      existingKeys.add(_dedupeKey(saved));
    }

    if (migrated.isEmpty) return;
    _items.addAll(migrated);
    await _persistLocal();
  }

  String _dedupeKey(CatalogSavedSearch item) {
    return '${item.title.trim().toLowerCase()}::${jsonEncode(item.filters.toJson())}';
  }

  bool _isMissingRemoteTable(Object error) {
    if (error is! PostgrestException) return false;
    final msg = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();
    return msg.contains('catalog_saved_searches') ||
        msg.contains('schema cache') ||
        msg.contains('does not exist');
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.map((item) => item.toJson()).toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}

final catalogSavedSearchesProvider =
    ChangeNotifierProvider<CatalogSavedSearchesController>((ref) {
      ref.watch(authStateProvider);

      final sb = Supabase.instance.client;
      final userId = sb.auth.currentUser?.id;
      final controller = CatalogSavedSearchesController(
        userKey: userId ?? 'guest',
        supabase: sb,
        userId: userId,
      );

      controller.load();

      final sub = sb.auth.onAuthStateChange.listen((_) {
        ref.invalidateSelf();
      });
      ref.onDispose(sub.cancel);

      return controller;
    });
