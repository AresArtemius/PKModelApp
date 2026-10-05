import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_shell_v2.dart';
import 'admin_style.dart';

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
    return AdminPageScaffold(
      title: ru ? 'ДОПОЛНИТЕЛЬНЫЕ АНКЕТЫ' : 'EXTRA PROFILES',
      subtitle: ru
          ? 'Запросы на увеличение лимита анкет'
          : 'Profile limit requests',
      onBack: () => context.go(Routes.admin),
      brandBackground: true,
      scrollable: true,
      headerGap: kGap14,
      children: [
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
                      ? (adminV2
                            ? AdminEmptyV2(
                                text: ru
                                    ? 'Новых запросов нет'
                                    : 'No new requests',
                              )
                            : Text(
                                ru ? 'НОВЫХ ЗАПРОСОВ НЕТ' : 'NO NEW REQUESTS',
                                textAlign: TextAlign.center,
                              ))
                      : adminV2
                      ? Column(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              AdminQueueRowV2(
                                title: items[i].owner,
                                subtitle: ru
                                    ? 'Запрос ещё на 1 анкету'
                                    : 'Request for 1 more profile',
                                date: adminDateV2(items[i].createdAt),
                                last: i == items.length - 1,
                                actions: [
                                  AdminRowButton(
                                    label: ru ? 'Отклонить' : 'Reject',
                                    onPressed: () =>
                                        _decide(context, ref, items[i], false),
                                  ),
                                  AdminRowButton(
                                    label: ru ? 'Разрешить' : 'Approve',
                                    primary: true,
                                    onPressed: () =>
                                        _decide(context, ref, items[i], true),
                                  ),
                                ],
                              ),
                          ],
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
    );
  }
}
