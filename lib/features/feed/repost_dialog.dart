import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_goals.dart';
import '../../core/router.dart';
import '../../ui/brand/ui_constants.dart';
import 'feed_service.dart';

/// Step 45: «Поделиться в ленту» — a repost of a post, a profile or a
/// casting with an optional caption. Returns true when published.
Future<bool> showRepostDialog(
  BuildContext context, {
  required String title,
  String? repostOf,
  String? profileId,
  String? castingId,
}) async {
  assert(
    [repostOf, profileId, castingId].where((v) => v != null).length == 1,
    'exactly one target',
  );
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _RepostDialog(
      title: title,
      repostOf: repostOf,
      profileId: profileId,
      castingId: castingId,
    ),
  );
  return result ?? false;
}

class _RepostDialog extends ConsumerStatefulWidget {
  const _RepostDialog({
    required this.title,
    this.repostOf,
    this.profileId,
    this.castingId,
  });

  final String title;
  final String? repostOf;
  final String? profileId;
  final String? castingId;

  @override
  ConsumerState<_RepostDialog> createState() => _RepostDialogState();
}

class _RepostDialogState extends ConsumerState<_RepostDialog> {
  static const _maxLength = 500;

  final _caption = TextEditingController();
  String _visibility = 'public';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(feedActionsProvider).repost(
        repostOf: widget.repostOf,
        profileId: widget.profileId,
        castingId: widget.castingId,
        body: _caption.text,
        visibility: _visibility,
      );
      reachGoal(Goals.feedRepost, {
        'kind': widget.repostOf != null
            ? 'post'
            : widget.profileId != null
            ? 'profile'
            : 'casting',
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ru
            ? 'Не удалось опубликовать. Попробуйте ещё раз.'
            : 'Could not publish. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final what = widget.repostOf != null
        ? (ru ? 'пост' : 'post')
        : widget.profileId != null
        ? (ru ? 'анкету' : 'profile')
        : (ru ? 'кастинг' : 'casting');

    return AlertDialog(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      title: Text(ru ? 'Поделиться в ленту' : 'Share to feed', style: AppText.h2),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What is being shared.
            Container(
              padding: const EdgeInsets.all(Tokens.s12),
              decoration: BoxDecoration(
                border: Border.all(color: Tokens.border),
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, size: 18, color: Tokens.textTertiary),
                  const SizedBox(width: Tokens.s8),
                  Expanded(
                    child: Text(
                      widget.title.isEmpty
                          ? (ru ? 'Вы делитесь $what' : 'Sharing a $what')
                          : widget.title,
                      style: AppText.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.s16),
            TextField(
              controller: _caption,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: _maxLength,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: ru ? 'Подпись (необязательно)' : 'Caption (optional)',
              ),
            ),
            const SizedBox(height: Tokens.s8),
            Row(
              children: [
                Text(
                  ru ? 'Кто увидит' : 'Visible to',
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
                const SizedBox(width: Tokens.s12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'public',
                      label: Text(ru ? 'Все' : 'Everyone'),
                    ),
                    ButtonSegment(
                      value: 'followers',
                      label: Text(ru ? 'Подписчики' : 'Followers'),
                    ),
                  ],
                  selected: {_visibility},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: _busy
                      ? null
                      : (v) => setState(() => _visibility = v.first),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: Tokens.s12),
              Text(_error!, style: AppText.small.copyWith(color: Tokens.danger)),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(ru ? 'Отмена' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy ? (ru ? 'Публикуем…' : 'Publishing…') : (ru ? 'Поделиться' : 'Share'),
          ),
        ),
      ],
    );
  }
}

/// Shows the result of a repost in a snackbar with a way to the feed.
void showRepostDone(BuildContext context) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(ru ? 'Опубликовано в ленте' : 'Shared to your feed'),
        action: SnackBarAction(
          label: ru ? 'Открыть' : 'Open',
          onPressed: () => context.go(Routes.feed),
        ),
      ),
    );
}
