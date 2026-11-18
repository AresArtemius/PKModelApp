import 'package:cached_network_image/cached_network_image.dart';
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
import '../../ui/brand/ui_constants.dart';
import 'admin_shell_v2.dart';
import 'admin_style.dart';

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

/// Profile reports (the admin desk counts them; used by admin_page.dart).
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

/// Post reports (step 47, list_post_reports in feed_comments.sql).
final postReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final sb = ref.read(supabaseProvider);
      try {
        final rows = await sb.rpc(
          'list_post_reports',
          params: {'p_limit': 100},
        );
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

/// One report from admin_list_reports (moderation_v2.sql).
class ModerationReport {
  const ModerationReport({
    required this.reportId,
    required this.reportTable,
    required this.kind,
    required this.targetId,
    required this.postId,
    required this.reason,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.reporterName,
    required this.contentText,
    required this.contentImage,
    required this.authorId,
    required this.authorName,
    required this.authorTag,
    required this.contentRemoved,
    required this.authorSuspended,
  });

  final String reportId;
  final String reportTable;

  /// post | comment | profile
  final String kind;

  /// post id | comment id | profile id
  final String targetId;
  final String postId;
  final String reason;
  final String note;
  final String status;
  final DateTime? createdAt;
  final String reporterName;
  final String contentText;
  final String contentImage;
  final String authorId;
  final String authorName;
  final String authorTag;
  final bool contentRemoved;
  final bool authorSuspended;

  bool get isOpen =>
      status == 'open' || status == 'in_review' || status == 'reviewing';

  factory ModerationReport.fromMap(Map<String, dynamic> m) {
    String s(String key) => (m[key] ?? '').toString().trim();
    return ModerationReport(
      reportId: s('report_id'),
      reportTable: s('report_table'),
      kind: s('kind'),
      targetId: s('target_id'),
      postId: s('post_id'),
      reason: s('reason'),
      note: s('note'),
      status: s('status').isEmpty ? 'open' : s('status'),
      createdAt: DateTime.tryParse(s('created_at'))?.toLocal(),
      reporterName: s('reporter_name'),
      contentText: s('content_text'),
      contentImage: s('content_image'),
      authorId: s('author_id'),
      authorName: s('author_name'),
      authorTag: s('author_tag'),
      contentRemoved: m['content_removed'] == true,
      authorSuspended: m['author_suspended'] == true,
    );
  }
}

/// Every report on one post / comment / profile: one card, one decision.
class ModerationCase {
  ModerationCase(this.reports);

  final List<ModerationReport> reports;

  ModerationReport get first => reports.first;
  String get kind => first.kind;
  String get targetId => first.targetId;
  String get postId => reports
      .map((r) => r.postId)
      .firstWhere((v) => v.isNotEmpty, orElse: () => '');
  bool get isOpen => reports.any((r) => r.isOpen);
  bool get allDismissed => reports.every((r) => r.status == 'dismissed');

  /// The oldest still-open report: the 24-hour clock runs from it.
  DateTime? get oldestOpen {
    DateTime? out;
    for (final r in reports.where((r) => r.isOpen)) {
      final at = r.createdAt;
      if (at != null && (out == null || at.isBefore(out))) out = at;
    }
    return out;
  }

  DateTime? get latest {
    DateTime? out;
    for (final r in reports) {
      final at = r.createdAt;
      if (at != null && (out == null || at.isAfter(out))) out = at;
    }
    return out;
  }

  /// reason → count, the most frequent first.
  List<MapEntry<String, int>> get reasons {
    final counts = <String, int>{};
    for (final r in reports) {
      counts[r.reason] = (counts[r.reason] ?? 0) + 1;
    }
    return counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }
}

/// null = moderation_v2.sql is not applied yet.
final moderationReportsProvider =
    FutureProvider.autoDispose<List<ModerationReport>?>((ref) async {
      final sb = ref.read(supabaseProvider);
      try {
        final rows = await sb.rpc(
          'admin_list_reports',
          params: {'p_limit': 500},
        );
        return (rows as List)
            .map(
              (e) => ModerationReport.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(growable: false);
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingRpc(e, 'admin_list_reports')) return null;
        rethrow;
      }
    });

final moderationBlocksProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final sb = ref.read(supabaseProvider);
      try {
        final rows = await sb.rpc(
          'admin_list_user_blocks',
          params: {'p_limit': 300},
        );
        return (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingRpc(e, 'admin_list_user_blocks')) {
          return const [];
        }
        rethrow;
      }
    });

final moderationSuspensionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final sb = ref.read(supabaseProvider);
      try {
        final rows = await sb.rpc('admin_list_suspensions');
        return (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingRpc(e, 'admin_list_suspensions')) {
          return const [];
        }
        rethrow;
      }
    });

List<ModerationCase> _groupCases(List<ModerationReport> reports) {
  final byKey = <String, List<ModerationReport>>{};
  for (final r in reports) {
    byKey.putIfAbsent('${r.kind}:${r.targetId}', () => []).add(r);
  }
  final cases = byKey.values.map(ModerationCase.new).toList();
  // Open cases: the most urgent (the oldest open report) first.
  // Closed cases: the most recent first.
  cases.sort((a, b) {
    if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
    if (a.isOpen) {
      final x = a.oldestOpen, y = b.oldestOpen;
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    }
    final x = a.latest, y = b.latest;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  });
  return cases;
}

// ---------------------------------------------------------------------------
// Wording
// ---------------------------------------------------------------------------

String _reasonLabel(String code, bool ru) => switch (code) {
  'spam' => ru ? 'Спам или реклама' : 'Spam or ads',
  'abuse' => ru ? 'Оскорбление, травля' : 'Harassment',
  'nudity' => ru ? 'Откровенный контент' : 'Explicit content',
  'minor' => ru ? 'Ребёнок в опасности' : 'Child at risk',
  'fake' => ru ? 'Обман, чужие фото' : 'Scam or stolen photos',
  'other' => ru ? 'Другое' : 'Other',
  '' => ru ? 'Без причины' : 'No reason',
  final r => r,
};

String _kindLabel(String kind, bool ru) => switch (kind) {
  'comment' => ru ? 'Комментарий' : 'Comment',
  'profile' => ru ? 'Анкета' : 'Profile',
  _ => ru ? 'Пост' : 'Post',
};

String _removeLabel(String kind, bool ru) => switch (kind) {
  'comment' => ru ? 'Удалить комментарий' : 'Delete comment',
  'profile' => ru ? 'Снять анкету' : 'Unpublish profile',
  _ => ru ? 'Удалить пост' : 'Delete post',
};

String _removedState(String kind, bool ru) => switch (kind) {
  'comment' => ru ? 'комментарий удалён' : 'comment deleted',
  'profile' => ru ? 'анкета не опубликована' : 'profile not published',
  _ => ru ? 'пост удалён' : 'post deleted',
};

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10, mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

String _reportsCount(int n, bool ru) => ru
    ? '$n ${_plural(n, 'жалоба', 'жалобы', 'жалоб')}'
    : '$n ${n == 1 ? 'report' : 'reports'}';

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

const List<String> _tabs = ['open', 'done', 'blocks', 'suspended'];

class SafetyAdminPage extends ConsumerStatefulWidget {
  const SafetyAdminPage({super.key});

  @override
  ConsumerState<SafetyAdminPage> createState() => _SafetyAdminPageState();
}

class _SafetyAdminPageState extends ConsumerState<SafetyAdminPage> {
  String _tab = 'open';
  bool _busy = false;

  bool get _ru => Localizations.localeOf(context).languageCode == 'ru';

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _refresh() {
    ref.invalidate(moderationReportsProvider);
    ref.invalidate(moderationBlocksProvider);
    ref.invalidate(moderationSuspensionsProvider);
    ref.invalidate(safetyReportsProvider);
    ref.invalidate(postReportsProvider);
    ref.invalidate(adminDashboardCountsProvider);
  }

  /// Runs one admin action with a busy flag, a refresh and a toast.
  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    final t = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      _toast(done);
    } catch (e) {
      final message = e is StateError
          ? e.message
          : AppErrorMapper.message(e, t);
      _toast('${t.errorUpper}: $message');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- decisions ------------------------------------------------------------

  Future<void> _decide(ModerationCase c, String decision) async {
    final ru = _ru;
    final what = _kindLabel(c.kind, ru).toLowerCase();
    final author = c.first.authorName.isEmpty
        ? (ru ? 'автора' : 'the author')
        : '«${c.first.authorName}»';
    final (title, message, confirm) = switch (decision) {
      'dismiss' => (
        ru ? 'Нарушения нет?' : 'No violation?',
        ru
            ? 'Жалобы закроются, $what останется. Пожаловавшимся придёт уведомление, что нарушений не нашли.'
            : 'The reports are closed and the $what stays. The reporters are told no violation was found.',
        ru ? 'Нарушения нет' : 'No violation',
      ),
      'remove' => (
        '${_removeLabel(c.kind, ru)}?',
        ru
            ? (c.kind == 'profile'
                  ? 'Анкета пропадёт из каталога. Автор получит уведомление, пожаловавшиеся — что жалоба рассмотрена.'
                  : 'Этот $what пропадёт у всех. Автор получит уведомление, пожаловавшиеся — что жалоба рассмотрена.')
            : 'It disappears for everyone. The author and the reporters are notified.',
        ru ? 'Удалить' : 'Delete',
      ),
      _ => (
        ru
            ? 'Удалить и заблокировать автора?'
            : 'Delete and suspend the author?',
        ru
            ? '${_kindLabel(c.kind, ru)} пропадёт у всех, а аккаунт $author будет заблокирован: войти он не сможет, его посты и комментарии скроются у всех. Снять блокировку можно на вкладке «Заблокированные».'
            : 'The $what disappears and $author is suspended: they cannot sign in, and their posts and comments are hidden. You can lift it on the «Suspended» tab.',
        ru ? 'Удалить и заблокировать' : 'Delete and suspend',
      ),
    };
    final ok = await showAdminConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirm,
      destructive: decision != 'dismiss',
    );
    if (!ok || !mounted) return;
    final sb = ref.read(supabaseProvider);
    await _run(
      () async {
        await sb.rpc(
          'admin_resolve_reports',
          params: {
            'p_kind': c.kind,
            'p_target_id': c.targetId,
            'p_decision': decision,
            'p_note': '',
          },
        );
        await AdminActionLogService(sb).log(
          actionType: 'moderation_$decision',
          title: switch (decision) {
            'dismiss' => 'Жалобы отклонены: нарушения нет',
            'remove' => 'Контент удалён по жалобе',
            _ => 'Контент удалён, автор заблокирован',
          },
          description: c.reasons.map((e) => e.key).join(', '),
          targetTable: switch (c.kind) {
            'profile' => 'profiles',
            'comment' => 'post_comments',
            _ => 'posts',
          },
          targetId: c.targetId,
          targetText: c.first.contentText,
          status: decision,
          metadata: {
            'kind': c.kind,
            'author_id': c.first.authorId,
            'reports': c.reports.length,
          },
        );
      },
      switch (decision) {
        'dismiss' => ru ? 'Жалобы закрыты: нарушения нет' : 'Closed: no violation',
        'remove' => ru ? 'Удалено, уведомления отправлены' : 'Removed, people notified',
        _ => ru ? 'Удалено, автор заблокирован' : 'Removed, author suspended',
      },
    );
  }

  Future<void> _deleteReports(ModerationCase c) async {
    final ru = _ru;
    final n = c.reports.length;
    final ok = await showAdminConfirmDialog(
      context: context,
      title: ru ? 'Удалить жалобы?' : 'Delete reports?',
      message: ru
          ? '${_reportsCount(n, ru)} — удалятся из списка навсегда, без уведомлений. ${_kindLabel(c.kind, ru)} не изменится. Для тестовых и ошибочных жалоб.'
          : '${_reportsCount(n, ru)} will be removed for good, without notifications. The content is not changed. For test or mistaken reports.',
      confirmLabel: ru ? 'Удалить' : 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final sb = ref.read(supabaseProvider);
    await _run(() async {
      for (final r in c.reports) {
        final deleted = await sb
            .from(r.reportTable)
            .delete()
            .eq('id', r.reportId)
            .select('id');
        if ((deleted as List).isEmpty) {
          throw StateError(
            ru
                ? 'Нет прав на удаление жалоб — выполните moderation_v2.sql'
                : 'No permission to delete reports — run moderation_v2.sql',
          );
        }
      }
      await AdminActionLogService(sb).log(
        actionType: 'report_deleted',
        title: 'Жалобы удалены',
        targetTable: c.first.reportTable,
        targetId: c.targetId,
        targetText: c.first.contentText,
        status: 'deleted',
        metadata: {'kind': c.kind, 'reports': n},
      );
    }, ru ? 'Жалобы удалены' : 'Reports deleted');
  }

  Future<void> _suspend({
    required String userId,
    required String name,
    required String reason,
  }) async {
    final ru = _ru;
    final ok = await showAdminConfirmDialog(
      context: context,
      title: ru ? 'Заблокировать аккаунт?' : 'Suspend the account?',
      message: ru
          ? 'Аккаунт «$name» не сможет войти, его посты и комментарии скроются у всех. Снять блокировку можно на вкладке «Заблокированные».'
          : '«$name» will not be able to sign in, and their posts and comments are hidden. You can lift it on the «Suspended» tab.',
      confirmLabel: ru ? 'Заблокировать' : 'Suspend',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final sb = ref.read(supabaseProvider);
    await _run(() async {
      await sb.rpc(
        'admin_suspend_user',
        params: {'p_user_id': userId, 'p_reason': reason},
      );
      await AdminActionLogService(sb).log(
        actionType: 'user_suspended',
        title: 'Аккаунт заблокирован',
        description: reason,
        targetTable: 'auth.users',
        targetId: userId,
        targetText: name,
        status: 'suspended',
      );
    }, ru ? 'Аккаунт заблокирован' : 'Account suspended');
  }

  Future<void> _unsuspend({
    required String userId,
    required String name,
  }) async {
    final ru = _ru;
    final ok = await showAdminConfirmDialog(
      context: context,
      title: ru ? 'Разблокировать аккаунт?' : 'Lift the suspension?',
      message: ru
          ? '«$name» снова сможет войти, его посты и комментарии станут видны. Удалённые по жалобам публикации не вернутся.'
          : '«$name» can sign in again and their posts and comments become visible. Content removed after reports does not come back.',
      confirmLabel: ru ? 'Разблокировать' : 'Lift',
    );
    if (!ok || !mounted) return;
    final sb = ref.read(supabaseProvider);
    await _run(() async {
      await sb.rpc('admin_unsuspend_user', params: {'p_user_id': userId});
      await AdminActionLogService(sb).log(
        actionType: 'user_unsuspended',
        title: 'Аккаунт разблокирован',
        targetTable: 'auth.users',
        targetId: userId,
        targetText: name,
        status: 'active',
      );
    }, ru ? 'Аккаунт разблокирован' : 'Suspension lifted');
  }

  // --- navigation -----------------------------------------------------------

  void _openContent(ModerationCase c) {
    if (c.kind == 'profile') {
      context.push('${Routes.modelPrefix}${c.targetId}');
      return;
    }
    final postId = c.kind == 'post' ? c.targetId : c.postId;
    if (postId.isNotEmpty) context.push('${Routes.postPrefix}$postId');
  }

  void _openAccount(String userId, String tag) {
    if (userId.isEmpty) return;
    context.push(Routes.accountLocation(tag: tag, userId: userId));
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = _ru;
    final reportsAsync = ref.watch(moderationReportsProvider);
    final blocks =
        ref.watch(moderationBlocksProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final suspensions =
        ref.watch(moderationSuspensionsProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final cases = _groupCases(
      reportsAsync.valueOrNull ?? const <ModerationReport>[],
    );
    final openCases = cases.where((c) => c.isOpen).toList(growable: false);
    final doneCases = cases.where((c) => !c.isOpen).toList(growable: false);
    final counts = <String, int>{
      'open': openCases.length,
      'done': doneCases.length,
      'blocks': blocks.length,
      'suspended': suspensions.length,
    };

    Widget body;
    switch (_tab) {
      case 'blocks':
        body = _buildBlocks(ru, blocks);
      case 'suspended':
        body = _buildSuspensions(ru, suspensions);
      default:
        body = reportsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AdminMessageCard(
            text: AppErrorMapper.message(e, t),
            isError: true,
          ),
          data: (list) {
            if (list == null) {
              return AdminMessageCard(
                text: ru
                    ? 'Обновите базу: выполните moderation_v2.sql в Supabase → SQL Editor.'
                    : 'Update the database: run moderation_v2.sql in Supabase → SQL Editor.',
                isError: true,
              );
            }
            final shown = _tab == 'open' ? openCases : doneCases;
            if (shown.isEmpty) {
              return AdminMessageCard(
                text: _tab == 'open'
                    ? (ru ? 'Новых жалоб нет.' : 'No new reports.')
                    : (ru
                          ? 'Решённых жалоб пока нет.'
                          : 'Nothing resolved yet.'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final c = shown[i];
                return _CaseCard(
                  data: c,
                  busy: _busy,
                  onOpen: () => _openContent(c),
                  onOpenAuthor: () =>
                      _openAccount(c.first.authorId, c.first.authorTag),
                  onDecide: (decision) => _decide(c, decision),
                  onDeleteReports: () => _deleteReports(c),
                  onUnsuspend: () => _unsuspend(
                    userId: c.first.authorId,
                    name: c.first.authorName,
                  ),
                );
              },
            );
          },
        );
    }

    return AdminPageScaffold(
      title: t.safetyAdminUpper,
      subtitle: ru
          ? 'Жалобы, блокировки и заблокированные аккаунты. Решение по каждой жалобе — в течение 24 часов.'
          : 'Reports, blocks and suspended accounts. Every report needs a decision within 24 hours.',
      onBack: () => context.go(Routes.admin),
      brandBackground: true,
      padding: const EdgeInsets.all(kPagePadH),
      headerGap: kGap16,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  AdminChipV2(
                    label: switch (_tabs[i]) {
                      'open' => ru ? 'Нужно решение' : 'Needs a decision',
                      'done' => ru ? 'Решённые' : 'Resolved',
                      'blocks' =>
                        ru ? 'Блокировки пользователей' : 'User blocks',
                      _ => ru ? 'Заблокированные' : 'Suspended',
                    },
                    selected: _tab == _tabs[i],
                    count: counts[_tabs[i]],
                    onTap: () => setState(() => _tab = _tabs[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildBlocks(bool ru, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return AdminMessageCard(
        text: ru
            ? 'Пользователи пока никого не блокировали. Каждая блокировка появится здесь и придёт админам уведомлением.'
            : 'Nobody has blocked anyone yet. Every block shows up here and is sent to admins as a notification.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (var i = 0; i < rows.length; i++)
          _blockRow(ru, rows[i], last: i == rows.length - 1),
      ],
    );
  }

  Widget _blockRow(bool ru, Map<String, dynamic> row, {required bool last}) {
    String s(String k) => (row[k] ?? '').toString().trim();
    final blocker = s('blocker_name').isEmpty
        ? (ru ? 'Пользователь' : 'A user')
        : s('blocker_name');
    final blocked = s('blocked_name').isEmpty
        ? (ru ? 'аккаунт' : 'an account')
        : s('blocked_name');
    final suspended = row['blocked_suspended'] == true;
    return AdminQueueRowV2(
      title: ru
          ? '$blocker заблокировал(а) $blocked'
          : '$blocker blocked $blocked',
      details: [
        if (s('blocked_tag').isNotEmpty) '@${s('blocked_tag')}',
        if (suspended)
          (ru
              ? 'аккаунт заблокирован администрацией'
              : 'suspended by admins'),
      ].join(' · '),
      date: adminDateV2(DateTime.tryParse(s('created_at'))),
      last: last,
      actions: [
        AdminRowButton(
          label: ru ? 'Открыть аккаунт' : 'Open account',
          onPressed: () => _openAccount(s('blocked_id'), s('blocked_tag')),
        ),
        if (!suspended)
          AdminRowButton(
            label: ru ? 'Заблокировать' : 'Suspend',
            destructive: true,
            onPressed: _busy
                ? null
                : () => _suspend(
                    userId: s('blocked_id'),
                    name: blocked,
                    reason: ru
                        ? 'Проверка после блокировки пользователем'
                        : 'Review after a user block',
                  ),
          ),
      ],
    );
  }

  Widget _buildSuspensions(bool ru, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return AdminMessageCard(
        text: ru
            ? 'Заблокированных аккаунтов нет. Заблокировать можно кнопкой «Удалить и заблокировать автора» у жалобы или на вкладке «Блокировки пользователей».'
            : 'No suspended accounts. Use «Delete and suspend author» on a report or the «User blocks» tab.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (var i = 0; i < rows.length; i++)
          _suspensionRow(ru, rows[i], last: i == rows.length - 1),
      ],
    );
  }

  Widget _suspensionRow(
    bool ru,
    Map<String, dynamic> row, {
    required bool last,
  }) {
    String s(String k) => (row[k] ?? '').toString().trim();
    final name = s('full_name').isNotEmpty
        ? s('full_name')
        : (s('email').isNotEmpty ? s('email') : (ru ? 'Аккаунт' : 'Account'));
    return AdminQueueRowV2(
      title: name,
      subtitle: s('reason').isEmpty ? null : s('reason'),
      details: [
        if (s('account_tag').isNotEmpty) '@${s('account_tag')}',
        if (s('email').isNotEmpty && s('email') != name) s('email'),
      ].join(' · '),
      date: adminDateV2(DateTime.tryParse(s('created_at'))),
      last: last,
      actions: [
        AdminRowButton(
          label: ru ? 'Открыть аккаунт' : 'Open account',
          onPressed: () => _openAccount(s('user_id'), s('account_tag')),
        ),
        AdminRowButton(
          label: ru ? 'Разблокировать' : 'Lift',
          primary: true,
          onPressed: _busy
              ? null
              : () => _unsuspend(userId: s('user_id'), name: name),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One case card
// ---------------------------------------------------------------------------

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.data,
    required this.busy,
    required this.onOpen,
    required this.onOpenAuthor,
    required this.onDecide,
    required this.onDeleteReports,
    required this.onUnsuspend,
  });

  final ModerationCase data;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onOpenAuthor;
  final ValueChanged<String> onDecide;
  final VoidCallback onDeleteReports;
  final VoidCallback onUnsuspend;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final c = data;
    final f = c.first;

    // 24-hour clock for open cases, the outcome for closed ones.
    final AdminStatusV2 status;
    if (c.isOpen) {
      final since = c.oldestOpen;
      final hours = since == null
          ? 0
          : DateTime.now().difference(since).inHours;
      final left = 24 - hours;
      status = AdminStatusV2(
        text: left > 0
            ? (ru ? 'Осталось $left ч' : '$left h left')
            : (ru ? 'Просрочено на ${-left} ч' : '${-left} h overdue'),
        color: left > 6 ? Tokens.textSecondary : Tokens.danger,
      );
    } else {
      status = AdminStatusV2(
        text: c.allDismissed
            ? (ru ? 'Нарушения нет' : 'No violation')
            : (f.authorSuspended
                  ? (ru
                        ? 'Удалено, автор заблокирован'
                        : 'Removed, author suspended')
                  : (ru ? 'Удалено' : 'Removed')),
        color: Tokens.textTertiary,
      );
    }

    final authorLine = [
      if (f.authorName.isNotEmpty)
        f.authorName
      else
        (ru ? 'автор неизвестен' : 'unknown author'),
      if (f.authorTag.isNotEmpty) '@${f.authorTag}',
    ].join(' · ');
    final flags = [
      if (f.contentRemoved) _removedState(c.kind, ru),
      if (f.authorSuspended) (ru ? 'автор заблокирован' : 'author suspended'),
    ];
    final reasons = c.reasons
        .map(
          (e) => e.value > 1
              ? '${_reasonLabel(e.key, ru)} ×${e.value}'
              : _reasonLabel(e.key, ru),
        )
        .join(', ');
    final shownReports = c.reports.take(3).toList(growable: false);

    final canRemove = !f.contentRemoved;
    final canSuspend = f.authorId.isNotEmpty && !f.authorSuspended;
    final canOpen = switch (c.kind) {
      'comment' => c.postId.isNotEmpty,
      _ => !f.contentRemoved,
    };
    final openLabel = c.kind == 'profile'
        ? (ru ? 'Открыть анкету' : 'Open profile')
        : (ru ? 'Открыть пост' : 'Open post');

    void onMore(String value) {
      switch (value) {
        case 'open':
          onOpen();
        case 'author':
          onOpenAuthor();
        default:
          onDeleteReports();
      }
    }

    final actions = <Widget>[
      if (c.isOpen) ...[
        if (canRemove)
          AdminRowButton(
            label: _removeLabel(c.kind, ru),
            primary: true,
            destructive: true,
            onPressed: busy ? null : () => onDecide('remove'),
          ),
        if (canSuspend)
          AdminRowButton(
            label: ru
                ? 'Удалить и заблокировать автора'
                : 'Delete and suspend author',
            destructive: true,
            onPressed: busy ? null : () => onDecide('remove_and_suspend'),
          ),
        // Content already gone (the author deleted it): just close the
        // reports as resolved.
        AdminRowButton(
          label: canRemove
              ? (ru ? 'Нарушения нет' : 'No violation')
              : (ru ? 'Закрыть жалобы' : 'Close reports'),
          onPressed: busy
              ? null
              : () => onDecide(canRemove ? 'dismiss' : 'remove'),
        ),
      ] else ...[
        if (canOpen) AdminRowButton(label: openLabel, onPressed: onOpen),
        if (f.authorSuspended)
          AdminRowButton(
            label: ru ? 'Разблокировать автора' : 'Lift suspension',
            onPressed: busy ? null : onUnsuspend,
          ),
      ],
      _MoreButton(
        options: [
          if (c.isOpen && canOpen)
            AdminMenuOption(
              value: 'open',
              label: openLabel,
              icon: Icons.open_in_new_rounded,
            ),
          if (f.authorId.isNotEmpty)
            AdminMenuOption(
              value: 'author',
              label: ru ? 'Открыть аккаунт автора' : 'Open author',
              icon: Icons.person_outline_rounded,
            ),
          AdminMenuOption(
            value: 'delete',
            label: ru
                ? 'Удалить жалобы (тест или ошибка)'
                : 'Delete reports (test or mistake)',
            icon: Icons.delete_outline_rounded,
            destructive: true,
          ),
        ],
        onSelected: onMore,
      ),
    ];

    final content = f.contentText.isEmpty
        ? (ru ? '(без текста)' : '(no text)')
        : (f.contentText.length > 280
              ? '${f.contentText.substring(0, 280)}…'
              : f.contentText);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.bg,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(
          color: c.isOpen ? Tokens.borderStrong : Tokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // What was reported, how many times, how much time is left.
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_kindLabel(c.kind, ru), style: AppText.bodyStrong),
              Text(
                _reportsCount(c.reports.length, ru),
                style: AppText.small.copyWith(color: Tokens.textSecondary),
              ),
              status,
            ],
          ),
          const SizedBox(height: 4),
          Text(reasons, style: AppText.small.copyWith(color: Tokens.text)),
          const SizedBox(height: 12),
          // The reported content itself.
          InkWell(
            onTap: canOpen ? onOpen : null,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Tokens.surface,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f.contentImage.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: CachedNetworkImage(
                          imageUrl: f.contentImage,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: Tokens.surfaceAlt),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                            decoration: f.contentRemoved
                                ? TextDecoration.lineThrough
                                : null,
                            color: f.contentRemoved
                                ? Tokens.textSecondary
                                : Tokens.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: f.authorId.isEmpty ? null : onOpenAuthor,
                          child: Text(
                            '${ru ? 'Автор' : 'Author'}: $authorLine',
                            style: AppText.small.copyWith(
                              color: Tokens.textSecondary,
                              decoration: f.authorId.isEmpty
                                  ? null
                                  : TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (flags.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            flags.join(' · '),
                            style: AppText.small.copyWith(
                              color: Tokens.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Who complained and what they wrote.
          for (final r in shownReports)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                [
                  r.reporterName.isEmpty
                      ? (ru ? 'Пользователь' : 'A user')
                      : r.reporterName,
                  _reasonLabel(r.reason, ru).toLowerCase(),
                  if (r.note.isNotEmpty) '«${r.note}»',
                  adminDateV2(r.createdAt),
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(color: Tokens.textSecondary),
              ),
            ),
          if (c.reports.length > shownReports.length)
            Text(
              ru
                  ? 'и ещё ${_reportsCount(c.reports.length - shownReports.length, ru)}'
                  : 'and ${c.reports.length - shownReports.length} more',
              style: AppText.small.copyWith(color: Tokens.textSecondary),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ),
    );
  }
}

/// «⋯» with the secondary actions.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.options, required this.onSelected});

  final List<AdminMenuOption<String>> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return AdminPopupMenuButton<String>(
      tooltip: ru ? 'Ещё' : 'More',
      options: options,
      onSelected: onSelected,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: Tokens.border),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: Tokens.textSecondary,
        ),
      ),
    );
  }
}
