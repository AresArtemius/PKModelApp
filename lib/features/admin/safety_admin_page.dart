import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/admin_action_log_service.dart';
import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';

final safetyReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final sb = ref.read(supabaseProvider);
      try {
        final rows = await sb
            .from('profile_reports')
            .select('id,profile_id,reason,comment,status,created_at')
            .order('created_at', ascending: false)
            .limit(100);
        return (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingRelation(e, const ['profile_reports'])) {
          return const [];
        }
        rethrow;
      }
    });

class SafetyAdminPage extends ConsumerWidget {
  const SafetyAdminPage({super.key});

  Future<void> _setReportStatus({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, dynamic> row,
    required String status,
  }) async {
    final t = AppLocalizations.of(context)!;
    final sb = ref.read(supabaseProvider);
    final reportId = (row['id'] ?? '').toString().trim();
    final profileId = (row['profile_id'] ?? '').toString().trim();
    final reason = (row['reason'] ?? '').toString().trim();
    if (reportId.isEmpty) return;

    try {
      await sb
          .from('profile_reports')
          .update({'status': status})
          .eq('id', reportId);
      await AdminActionLogService(sb).log(
        actionType: 'safety_report_status_changed',
        title: status == 'closed' ? 'Жалоба закрыта' : 'Жалоба взята в работу',
        description: reason,
        targetTable: 'profile_reports',
        targetId: reportId,
        targetText: profileId,
        status: status,
        metadata: {
          'profile_id': profileId,
          'reason': reason,
          'comment': (row['comment'] ?? '').toString(),
        },
      );
      ref.invalidate(safetyReportsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Статус жалобы обновлен')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${t.errorUpper}: ${AppErrorMapper.message(e, t)}'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(safetyReportsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(kPagePadH),
              child: Column(
                children: [
                  BrandAdminHeader(
                    title: t.safetyAdminUpper,
                    onBack: () => context.go(Routes.admin),
                  ),
                  const SizedBox(height: kGap16),
                  Expanded(
                    child: async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _MessageCard(
                        text: AppErrorMapper.message(e, t),
                        isError: true,
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return _MessageCard(text: t.safetyReportsEmpty);
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: kGap12),
                          itemBuilder: (context, index) {
                            final row = items[index];
                            return _ReportCard(
                              row: row,
                              onStatusChanged: (status) => _setReportStatus(
                                context: context,
                                ref: ref,
                                row: row,
                                status: status,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.row, required this.onStatusChanged});

  final Map<String, dynamic> row;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    String text(String key) => (row[key] ?? '').toString().trim();
    final profileId = text('profile_id');
    final comment = text('comment');
    final status = text('status').isEmpty ? 'open' : text('status');
    final isClosed = status == 'closed' || status == 'resolved';

    return Container(
      padding: kLoginCardPad,
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text('reason'),
            style: adminCommandStyle(size: 17, letterSpacing: 0.7),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: adminBodyStyle(weight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  text('status').isEmpty ? 'open' : text('status'),
                  style: adminCommandStyle(
                    size: 12,
                    color: BrandTheme.redTop,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () =>
                    onStatusChanged(isClosed ? 'in_review' : 'closed'),
                child: Text(isClosed ? 'В РАБОТУ' : 'ЗАКРЫТЬ'),
              ),
              const SizedBox(width: 8),
              if (profileId.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      context.go('${Routes.modelPrefix}$profileId'),
                  child: const Text('ОТКРЫТЬ'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return AdminMessageCard(text: text, isError: isError);
  }
}
