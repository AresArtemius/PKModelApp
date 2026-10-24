import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/brand/ui_constants.dart';
import '../feed/feed_service.dart' show feedActionsProvider;
import 'safety_service.dart';

/// Confirm + block. Returns true when the user is now blocked. The author's
/// posts and comments disappear from the loaded feeds immediately and the
/// moderation team is notified (database trigger).
Future<bool> blockUserWithConfirm(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final name = displayName.trim().isEmpty
      ? (ru ? 'этого пользователя' : 'this user')
      : displayName.trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      title: Text(
        ru ? 'Заблокировать $name?' : 'Block $name?',
        style: AppText.h2,
      ),
      content: Text(
        ru
            ? 'Его публикации и комментарии сразу исчезнут из вашей ленты, он не сможет писать вам и подписываться на вас. Модераторы получат уведомление и проверят аккаунт.'
            : 'Their posts and comments will disappear from your feed right away, and they will no longer be able to message or follow you. Our moderators will be notified and will review the account.',
        style: AppText.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(ru ? 'Отмена' : 'Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(ru ? 'Заблокировать' : 'Block'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  final ok = await ref
      .read(safetyServiceProvider)
      .blockUser(blockedUserId: userId, profileId: '');
  if (!ok) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ru ? 'Не удалось заблокировать' : 'Could not block'),
          ),
        );
    }
    return false;
  }
  ref.read(feedActionsProvider).hideAuthor(userId);
  ref.invalidate(blockedByMeProvider(userId));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            ru
                ? 'Пользователь заблокирован. Его публикации скрыты, модераторы уведомлены.'
                : 'User blocked. Their posts are hidden and our moderators have been notified.',
          ),
        ),
      );
  }
  return true;
}
