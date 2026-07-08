import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_provider.dart';

final adminSelectionListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final sb = ref.read(supabaseProvider);
      const limit = 80;

      final castingsRows = await sb
          .from('castings')
          .select('id,title,created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      Future<List<dynamic>> loadSelections({
        required bool includeStatus,
      }) async {
        return await sb
            .from('selections')
            .select(
              includeStatus
                  ? 'id,title,created_at,status'
                  : 'id,title,created_at',
            )
            .order('created_at', ascending: false)
            .limit(limit);
      }

      List<dynamic> selectionsRows;
      try {
        selectionsRows = await loadSelections(includeStatus: true);
      } catch (_) {
        selectionsRows = await loadSelections(includeStatus: false);
      }

      final castings = (castingsRows as List)
          .map(
            (e) => {...Map<String, dynamic>.from(e as Map), '_kind': 'casting'},
          )
          .toList(growable: false);

      final selections = selectionsRows
          .map(
            (e) => {
              ...Map<String, dynamic>.from(e as Map),
              '_kind': 'selection',
            },
          )
          .toList(growable: false);

      final all = <Map<String, dynamic>>[...castings, ...selections];

      DateTime parseCreatedAt(Map<String, dynamic> row) {
        final raw = row['created_at'];
        if (raw is String) {
          return DateTime.tryParse(raw) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      all.sort((a, b) => parseCreatedAt(b).compareTo(parseCreatedAt(a)));
      return all.take(limit).toList(growable: false);
    });

final adminSelectionCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final items = await ref.watch(adminSelectionListProvider.future);
  return items.length;
});
