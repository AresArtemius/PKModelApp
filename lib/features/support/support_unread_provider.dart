import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_provider.dart';

final supportUnreadByTicketProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
      final data = await ref
          .read(supabaseProvider)
          .rpc('support_unread_counts');
      final rows = data is List ? data : const [];
      final result = <String, int>{};
      for (final raw in rows.whereType<Map>()) {
        final ticketId = (raw['ticket_id'] ?? '').toString();
        if (ticketId.isEmpty) continue;
        result[ticketId] =
            int.tryParse((raw['unread_count'] ?? 0).toString()) ?? 0;
      }
      return result;
    });

final supportUnreadTotalProvider = Provider.autoDispose<int>((ref) {
  return ref
      .watch(supportUnreadByTicketProvider)
      .maybeWhen(
        data: (items) => items.values.fold(0, (sum, value) => sum + value),
        orElse: () => 0,
      );
});

Future<void> markSupportTicketRead(WidgetRef ref, String ticketId) async {
  try {
    await ref
        .read(supabaseProvider)
        .rpc('mark_support_ticket_read', params: {'p_ticket_id': ticketId});
    ref.invalidate(supportUnreadByTicketProvider);
  } catch (_) {
    // Совместимость на время между выкладкой клиента и применением SQL.
  }
}
