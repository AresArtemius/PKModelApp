import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/admin_action_log_service.dart';
import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_shell_v2.dart';
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

/// Step 47: reports on feed posts (list_post_reports in feed_comments.sql).
final postReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final sb = ref.read(supabaseProvider);
      try {
        final rows = await sb.rpc('list_post_reports', params: {'p_limit': 100});
        return (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingRpc(e, 'list_post_reports')) {
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
      ref.invalidate(adminDashboardCountsProvider);
      if (!context.mounted) return;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ru ? 'Статус жалобы обновлен' : 'Report status updated',
            ),
          ),
        );
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

  Future<void> _setPostReportStatus({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, dynamic> row,
    required String status,
    bool hidePost = false,
  }) async {
    final t = AppLocalizations.of(context)!;
    final sb = ref.read(supabaseProvider);
    final reportId = (row['id'] ?? '').toString().trim();
    final postId = (row['post_id'] ?? '').toString().trim();
    if (reportId.isEmpty) return;
    try {
      if (hidePost && postId.isNotEmpty) {
        await sb
            .from('posts')
            .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', postId);
      }
      await sb.from('post_reports').update({'status': status}).eq('id', reportId);
      await AdminActionLogService(sb).log(
        actionType: hidePost ? 'post_hidden_by_report' : 'post_report_status_changed',
        title: hidePost
            ? 'Пост скрыт по жалобе'
            : (status == 'closed' ? 'Жалоба на пост закрыта' : 'Жалоба на пост в работе'),
        description: (row['reason'] ?? '').toString(),
        targetTable: 'post_reports',
        targetId: reportId,
        targetText: postId,
        status: status,
        metadata: {
          'post_id': postId,
          'reason': (row['reason'] ?? '').toString(),
          'comment': (row['comment'] ?? '').toString(),
        },
      );
      ref.invalidate(postReportsProvider);
      ref.invalidate(adminDashboardCountsProvider);
      if (!context.mounted) return;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              hidePost
                  ? (ru ? 'Пост скрыт' : 'Post hidden')
                  : (ru ? 'Статус жалобы обновлен' : 'Report status updated'),
            ),
          ),
        );
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
    final postReports = ref
        .watch(postReportsProvider)
        .maybeWhen(data: (v) => v, orElse: () => const <Map<String, dynamic>>[]);
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    return AdminPageScaffold(
      title: t.safetyAdminUpper,
      subtitle: Localizations.localeOf(context).languageCode == 'ru' ? 'Жалобы и проверки' : 'Reports and safety',
      onBack: () => context.go(Routes.admin),
      brandBackground: true,
      padding: const EdgeInsets.all(kPagePadH),
      headerGap: kGap16,
      children: [
                  Expanded(
                    child: async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _MessageCard(
                        text: AppErrorMapper.message(e, t),
                        isError: true,
                      ),
                      data: (items) {
                        if (items.isEmpty && postReports.isEmpty) {
                          return _MessageCard(text: t.safetyReportsEmpty);
                        }
                        return ListView(
                          children: [
                            if (items.isNotEmpty && postReports.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: kGap12),
                                child: Text(
                                  ru ? 'Жалобы на анкеты' : 'Profile reports',
                                  style: AppText.h2,
                                ),
                              ),
                            for (var i = 0; i < items.length; i++) ...[
                              _ReportCard(
                                row: items[i],
                                last: i == items.length - 1,
                                onStatusChanged: (status) => _setReportStatus(
                                  context: context,
                                  ref: ref,
                                  row: items[i],
                                  status: status,
                                ),
                              ),
                              if (!adminV2) const SizedBox(height: kGap12),
                            ],
                            if (postReports.isNotEmpty) ...[
                              Padding(
                                padding: EdgeInsets.only(
                                  top: items.isEmpty ? 0 : kGap16 * 2,
                                  bottom: kGap12,
                                ),
                                child: Text(
                                  ru ? 'Жалобы на посты' : 'Post reports',
                                  style: AppText.h2,
                                ),
                              ),
                              for (var i = 0; i < postReports.length; i++)
                                _PostReportRow(
                                  row: postReports[i],
                                  last: i == postReports.length - 1,
                                  onStatus: (status, {hidePost = false}) =>
                                      _setPostReportStatus(
                                        context: context,
                                        ref: ref,
                                        row: postReports[i],
                                        status: status,
                                        hidePost: hidePost,
                                      ),
                                ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.row,
    required this.onStatusChanged,
    this.last = false,
  });

  final Map<String, dynamic> row;
  final ValueChanged<String> onStatusChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    String text(String key) => (row[key] ?? '').toString().trim();
    final profileId = text('profile_id');
    final comment = text('comment');
    final status = text('status').isEmpty ? 'open' : text('status');
    final isClosed = status == 'closed' || status == 'resolved';

    if (adminV2) {
      return AdminQueueRowV2(
        title: text('reason').isEmpty ? (ru ? 'Жалоба' : 'Report') : text('reason'),
        note: comment,
        details: profileId.isEmpty ? null : 'ID: $profileId',
        date: adminDateV2(DateTime.tryParse(text('created_at'))),
        last: last,
        status: AdminStatusV2(
          text: switch (status) {
            'closed' => ru ? 'Закрыта' : 'Closed',
            'resolved' => ru ? 'Решена' : 'Resolved',
            'in_review' => ru ? 'В работе' : 'In review',
            _ => ru ? 'Открыта' : 'Open',
          },
          color: isClosed ? Tokens.textTertiary : Tokens.danger,
        ),
        actions: [
          if (profileId.isNotEmpty)
            AdminRowButton(
              label: ru ? 'Открыть анкету' : 'Open profile',
              onPressed: () =>
                  context.go('${Routes.modelPrefix}$profileId'),
            ),
          AdminRowButton(
            label: isClosed
                ? (ru ? 'В работу' : 'Reopen')
                : (ru ? 'Закрыть' : 'Close'),
            primary: !isClosed,
            onPressed: () =>
                onStatusChanged(isClosed ? 'in_review' : 'closed'),
          ),
        ],
      );
    }

    return Container(
      padding: kLoginCardPad,
      decoration: adminCardDecoration(),
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
                child: Text(
                  isClosed
                      ? (ru ? 'В РАБОТУ' : 'REOPEN')
                      : (ru ? 'ЗАКРЫТЬ' : 'CLOSE'),
                ),
              ),
              const SizedBox(width: 8),
              if (profileId.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      context.go('${Routes.modelPrefix}$profileId'),
                  child: Text(ru ? 'ОТКРЫТЬ' : 'OPEN'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostReportRow extends StatelessWidget {
  const _PostReportRow({
    required this.row,
    required this.onStatus,
    this.last = false,
  });

  final Map<String, dynamic> row;
  final void Function(String status, {bool hidePost}) onStatus;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    String text(String key) => (row[key] ?? '').toString().trim();
    final status = text('status').isEmpty ? 'open' : text('status');
    final isClosed =
        status == 'closed' || status == 'resolved' || status == 'dismissed';
    final hidden = row['post_deleted'] == true;
    final reason = switch (text('reason')) {
      'spam' => ru ? 'Спам или реклама' : 'Spam or ads',
      'abuse' => ru ? 'Оскорбление, травля' : 'Harassment',
      'nudity' => ru ? 'Откровенный контент' : 'Explicit content',
      'minor' => ru ? 'Ребёнок в опасности' : 'Child at risk',
      'fake' => ru ? 'Обман, чужие фото' : 'Scam or stolen photos',
      'other' => ru ? 'Другое' : 'Other',
      final r => r.isEmpty ? (ru ? 'Жалоба на пост' : 'Post report') : r,
    };
    final body = text('post_body');
    final author = text('post_author_name');
    final details = [
      if (author.isNotEmpty) (ru ? 'Автор: $author' : 'Author: $author'),
      if (text('post_kind').isNotEmpty) text('post_kind'),
      if (hidden) (ru ? 'пост скрыт' : 'post hidden'),
    ].join(' · ');

    return AdminQueueRowV2(
      title: reason,
      subtitle: body.isEmpty
          ? null
          : (body.length > 160 ? '${body.substring(0, 160)}…' : body),
      note: text('comment'),
      details: details.isEmpty ? null : details,
      date: adminDateV2(DateTime.tryParse(text('created_at'))),
      last: last,
      status: AdminStatusV2(
        text: switch (status) {
          'closed' => ru ? 'Закрыта' : 'Closed',
          'resolved' => ru ? 'Решена' : 'Resolved',
          'dismissed' => ru ? 'Отклонена' : 'Dismissed',
          'in_review' => ru ? 'В работе' : 'In review',
          _ => ru ? 'Открыта' : 'Open',
        },
        color: isClosed ? Tokens.textTertiary : Tokens.danger,
      ),
      actions: [
        if (!hidden && !isClosed)
          AdminRowButton(
            label: ru ? 'Скрыть пост' : 'Hide post',
            primary: true,
            onPressed: () => onStatus('resolved', hidePost: true),
          ),
        AdminRowButton(
          label: isClosed
              ? (ru ? 'В работу' : 'Reopen')
              : (ru ? 'Закрыть' : 'Close'),
          onPressed: () => onStatus(isClosed ? 'in_review' : 'closed'),
        ),
      ],
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
