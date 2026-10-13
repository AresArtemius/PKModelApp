import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_providers.dart';
import '../../core/content_safety_filter.dart';
import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/storage_image_variant.dart';
import '../../ui/brand/ui_constants.dart';
import 'edit_text_dialog.dart';
import 'feed_models.dart';
import 'feed_page.dart' show feedRelativeTime;
import 'feed_service.dart';

/// Step 47: comments under a post — the list and a one-line composer.
/// Shown inline when the comment icon is tapped.
class PostCommentsSection extends ConsumerStatefulWidget {
  const PostCommentsSection({super.key, required this.post});

  final FeedPost post;

  @override
  ConsumerState<PostCommentsSection> createState() =>
      _PostCommentsSectionState();
}

class _PostCommentsSectionState extends ConsumerState<PostCommentsSection> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final body = _text.text.trim();
    if (body.isEmpty || _busy) return;
    if (body.length > 1000) {
      setState(
        () => _error = ru
            ? 'Слишком длинно (до 1000 символов)'
            : 'Too long (up to 1000 characters)',
      );
      return;
    }
    if (ContentSafetyFilter.hasBlockedText(body)) {
      setState(
        () => _error = ContentSafetyFilter.message(
          isRussian: ru,
          fieldLabel: ru ? 'Комментарий' : 'Comment',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(feedActionsProvider).addComment(widget.post.id, body);
      if (!mounted) return;
      _text.clear();
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ru ? 'Не удалось отправить' : 'Could not send';
      });
    }
  }

  Future<void> _edit(FeedComment c) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final text = await showEditTextDialog(
      context,
      title: ru ? 'Редактировать комментарий' : 'Edit comment',
      initial: c.body,
      maxLength: 1000,
      minLines: 2,
    );
    if (text == null || !mounted) return;
    try {
      await ref
          .read(feedActionsProvider)
          .editComment(widget.post.id, c.id, text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = ru ? 'Не удалось сохранить' : 'Could not save');
    }
  }

  Future<void> _delete(FeedComment c) async {
    try {
      await ref.read(feedActionsProvider).deleteComment(widget.post.id, c.id);
    } catch (_) {
      if (!mounted) return;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      setState(() => _error = ru ? 'Не удалось удалить' : 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final me = ref.watch(currentUserIdProvider);
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    final comments = ref.watch(postCommentsProvider(widget.post.id));
    final canWrite = me != null && widget.post.commentsEnabled;

    return Padding(
      padding: const EdgeInsets.only(top: Tokens.s12, left: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          comments.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.s8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => Text(
              ru ? 'Не удалось загрузить комментарии' : 'Could not load comments',
              style: AppText.small.copyWith(color: Tokens.textSecondary),
            ),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.s4),
                    child: Text(
                      widget.post.commentsEnabled
                          ? (ru ? 'Комментариев пока нет' : 'No comments yet')
                          : (ru
                                ? 'Комментарии к этому посту выключены'
                                : 'Comments are off for this post'),
                      style: AppText.small.copyWith(color: Tokens.textTertiary),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in items)
                        _CommentRow(
                          comment: c,
                          ru: ru,
                          canEdit: me != null && c.authorId == me,
                          canDelete:
                              me != null &&
                              (c.authorId == me ||
                                  widget.post.authorId == me ||
                                  isAdmin),
                          canReport: me != null && c.authorId != me,
                          onEdit: () => _edit(c),
                          onDelete: () => _delete(c),
                          onReport: () => _report(c),
                        ),
                    ],
                  ),
          ),
          if (canWrite) ...[
            const SizedBox(height: Tokens.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _text,
                    focusNode: _focus,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: AppText.small,
                    decoration: InputDecoration(
                      hintText: ru ? 'Написать комментарий…' : 'Write a comment…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Tokens.s12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.s8),
                IconButton(
                  tooltip: ru ? 'Отправить' : 'Send',
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send_rounded, size: 20),
                  color: Tokens.text,
                ),
              ],
            ),
          ] else if (me == null) ...[
            const SizedBox(height: Tokens.s8),
            TextButton(
              onPressed: () => context.go(Routes.authRequired),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                ru ? 'Войдите, чтобы комментировать' : 'Sign in to comment',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Tokens.s4),
            Text(_error!, style: AppText.caption.copyWith(color: Tokens.danger)),
          ],
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.ru,
    required this.canEdit,
    required this.canDelete,
    required this.canReport,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  final FeedComment comment;
  final bool ru;
  final bool canEdit;
  final bool canDelete;
  final bool canReport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 28,
              height: 28,
              child: comment.authorAvatarUrl.isEmpty
                  ? const ColoredBox(
                      color: Tokens.surfaceAlt,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: Tokens.textTertiary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: storageImageVariant(
                        comment.authorAvatarUrl,
                        width: 56,
                      ),
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => CachedNetworkImage(
                        imageUrl: comment.authorAvatarUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () => context.push(
                          Routes.accountLocation(
                            tag: comment.authorTag,
                            userId: comment.authorId,
                          ),
                        ),
                        child: Text(
                          comment.displayAuthor(ru),
                          style: AppText.smallStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.s8),
                    Text(
                      feedRelativeTime(comment.createdAt, ru),
                      style: AppText.caption.copyWith(color: Tokens.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body.trim(), style: AppText.small),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              tooltip: ru ? 'Редактировать' : 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: Tokens.textTertiary,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          if (canReport)
            IconButton(
              tooltip: ru ? 'Пожаловаться' : 'Report',
              onPressed: onReport,
              icon: const Icon(Icons.flag_outlined, size: 16),
              color: Tokens.textTertiary,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          if (canDelete)
            IconButton(
              tooltip: ru ? 'Удалить' : 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 16),
              color: Tokens.textTertiary,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

/// Step 47: «Пожаловаться» in one click — a reason, an optional note.
Future<bool> showReportPostDialog(BuildContext context, FeedPost post) =>
    _showReportDialog(context, post: post);

/// A report on a single comment goes to the same moderation queue as a
/// post report; the comment text travels in the note so the moderator sees
/// what was reported.
Future<bool> showReportCommentDialog(
  BuildContext context, {
  required FeedPost post,
  required FeedComment comment,
}) => _showReportDialog(context, post: post, comment: comment);

Future<bool> _showReportDialog(
  BuildContext context, {
  required FeedPost post,
  FeedComment? comment,
}) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return showReportReasonsDialog(
    context,
    title: comment == null
        ? (ru ? 'Пожаловаться на пост' : 'Report post')
        : (ru ? 'Пожаловаться на комментарий' : 'Report comment'),
    onSubmit: (ref, reason, note) {
      final text = comment == null
          ? note
          : '${ru ? 'Комментарий' : 'Comment'} '
                '${comment.authorTag.isNotEmpty ? '@${comment.authorTag}' : comment.authorName} '
                '(${comment.id}): «${comment.body.trim()}»'
                '${note.trim().isEmpty ? '' : '\n$note'}';
      return ref
          .read(feedServiceProvider)
          .reportPost(postId: post.id, reason: reason, comment: text);
    },
  );
}

/// The shared «reason + note» report dialog (posts, comments, accounts).
/// Returns true when the report was sent.
Future<bool> showReportReasonsDialog(
  BuildContext context, {
  required String title,
  required Future<void> Function(WidgetRef ref, String reason, String note)
  onSubmit,
}) async {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final reasons = <(String, String)>[
    ('spam', ru ? 'Спам или реклама' : 'Spam or ads'),
    ('abuse', ru ? 'Оскорбление, травля' : 'Harassment'),
    ('nudity', ru ? 'Откровенный контент' : 'Explicit content'),
    ('minor', ru ? 'Ребёнок в опасности' : 'Child at risk'),
    ('fake', ru ? 'Обман, чужие фото' : 'Scam or stolen photos'),
    ('other', ru ? 'Другое' : 'Other'),
  ];
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => Consumer(
      builder: (context, ref, _) => _ReportDialog(
        title: title,
        reasons: reasons,
        ru: ru,
        onSubmit: (reason, note) => onSubmit(ref, reason, note),
      ),
    ),
  );
  return result ?? false;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.title,
    required this.reasons,
    required this.ru,
    required this.onSubmit,
  });

  final String title;
  final List<(String, String)> reasons;
  final bool ru;
  final Future<void> Function(String reason, String note) onSubmit;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(reason, _note.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = widget.ru ? 'Не удалось отправить' : 'Could not send';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = widget.ru;
    return AlertDialog(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      title: Text(widget.title, style: AppText.h2),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in widget.reasons)
              InkWell(
                onTap: _busy ? null : () => setState(() => _reason = r.$1),
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _reason == r.$1
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: _reason == r.$1 ? Tokens.text : Tokens.textTertiary,
                      ),
                      const SizedBox(width: Tokens.s12),
                      Expanded(child: Text(r.$2, style: AppText.body)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Tokens.s8),
            TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: _note,
              enabled: !_busy,
              minLines: 1,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: ru ? 'Комментарий (необязательно)' : 'Note (optional)',
              ),
            ),
            if (_error != null)
              Text(_error!, style: AppText.small.copyWith(color: Tokens.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(ru ? 'Отмена' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _reason == null ? null : _submit,
          child: Text(ru ? 'Отправить' : 'Send'),
        ),
      ],
    );
  }
}
