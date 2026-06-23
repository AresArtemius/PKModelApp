import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_providers.dart';
import '../../core/supabase_provider.dart';

import 'casting_response_status.dart';
import 'casting_model.dart';
import 'castings_service.dart';

final castingsServiceProvider = Provider<CastingsService>((ref) {
  final sb = ref.watch(supabaseProvider);
  return CastingsService(sb);
});

final castingsProvider = FutureProvider.autoDispose<List<CastingModel>>((
  ref,
) async {
  final service = ref.watch(castingsServiceProvider);
  return service.fetchCastings();
});

final respondingCastingsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

final myCastingResponseStatusesProvider =
    FutureProvider.autoDispose<Map<String, CastingResponseStatus>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return const <String, CastingResponseStatus>{};

      final service = ref.watch(castingsServiceProvider);
      return service.fetchMyCastingStatuses(userId: userId);
    });
