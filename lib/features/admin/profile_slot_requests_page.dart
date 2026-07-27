import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class ProfileSlotRequest {
  const ProfileSlotRequest({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.owner,
  });
  final String id;
  final String userId;
  final DateTime? createdAt;
  final String owner;
}

final profileSlotRequestsProvider =
    FutureProvider.autoDispose<List<ProfileSlotRequest>>((ref) async {
      final sb = ref.read(supabaseProvider);
      final raw = await sb
          .from('profile_slot_requests')
          .select('id,user_id,created_at')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final rows = (raw as List).cast<Map>();
      final ids = rows.map((e) => e['user_id'].toString()).toSet().toList();
      final owners = <String, String>{};
      if (ids.isNotEmpty) {
        final ownerRows = await sb
            .from('user_profiles')
            .select('user_id,full_name,email,phone')
            .inFilter('user_id', ids);
        for (final value in ownerRows as List) {
          final row = Map<String, dynamic>.from(value as Map);
          final label = ['full_name', 'email', 'phone']
              .map((key) => (row[key] ?? '').toString().trim())
              .firstWhere((value) => value.isNotEmpty, orElse: () => '');
          owners[(row['user_id'] ?? '').toString()] = label;
        }
      }
      return rows
          .map((value) {
            final row = Map<String, dynamic>.from(value);
            final userId = row['user_id'].toString();
            return ProfileSlotRequest(
              id: row['id'].toString(),
              userId: userId,
              createdAt: DateTime.tryParse(
                (row['created_at'] ?? '').toString(),
              ),
              owner: owners[userId] ?? userId,
            );
          })
          .toList(growable: false);
    });

class ProfileSlotRequestsPage extends ConsumerWidget {
  const ProfileSlotRequestsPage({super.key});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    ProfileSlotRequest request,
    bool approved,
  ) async {
    try {
      await ref
          .read(supabaseProvider)
          .rpc(
            'admin_decide_profile_slot_request',
            params: {
              'p_request_id': request.id,
              'p_approved': approved,
              'p_slots': 1,
              'p_comment': '',
            },
          );
      ref.invalidate(profileSlotRequestsProvider);
      ref.invalidate(adminDashboardCountsProvider);
    } catch (_) {
      if (!context.mounted) return;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ru ? 'Не удалось обработать запрос.' : 'Could not process request.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final requests = ref.watch(profileSlotRequestsProvider);
    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BrandAdminHeader(
                  title: ru ? 'ДОПОЛНИТЕЛЬНЫЕ АНКЕТЫ' : 'EXTRA PROFILES',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: kGap14),
                requests.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(
                    ru
                        ? 'Не удалось загрузить запросы.'
                        : 'Could not load requests.',
                    textAlign: TextAlign.center,
                  ),
                  data: (items) => items.isEmpty
                      ? Text(
                          ru ? 'НОВЫХ ЗАПРОСОВ НЕТ' : 'NO NEW REQUESTS',
                          textAlign: TextAlign.center,
                        )
                      : Column(
                          children: [
                            for (final item in items)
                              Card(
                                child: ListTile(
                                  title: Text(item.owner),
                                  subtitle: Text(
                                    ru
                                        ? 'Запрос ещё на 1 анкету'
                                        : 'Request for 1 more profile',
                                  ),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _decide(context, ref, item, false),
                                        child: Text(
                                          ru ? 'ОТКЛОНИТЬ' : 'REJECT',
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            _decide(context, ref, item, true),
                                        child: Text(
                                          ru ? 'РАЗРЕШИТЬ' : 'APPROVE',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
