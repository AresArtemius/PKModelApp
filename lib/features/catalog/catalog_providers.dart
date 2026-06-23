import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_provider.dart';
import 'catalog_controller.dart';
import 'catalog_repository.dart';

const int kCatalogPageSize = 24;
const int kCatalogAutoFillMaxLoads = 3;

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final sb = ref.read(supabaseProvider);
  return CatalogRepository(sb);
});

final catalogControllerProvider = ChangeNotifierProvider<CatalogController>((
  ref,
) {
  final repo = ref.watch(catalogRepositoryProvider);

  return CatalogController(
    repo: repo,
    pageSize: kCatalogPageSize,
    autoFillMaxLoads: kCatalogAutoFillMaxLoads,
  );
});

final selectedCatalogModelIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

final catalogSelectionAuthSyncProvider = Provider<void>((ref) {
  final sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
    ref.read(selectedCatalogModelIdsProvider.notifier).state = <String>{};
  });

  ref.onDispose(sub.cancel);
});
