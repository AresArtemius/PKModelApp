import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_providers.dart';
import '../../ui/brand/ui_constants.dart';
import '../feed/feed_service.dart' show feedControllerProvider, postCommentsProvider;
import '../feed/post_comments.dart' show showReportReasonsDialog;
import '../safety/block_user_dialog.dart';
import '../safety/safety_service.dart';

/// «⋯» on a public account page: report the account, block / unblock.
/// Shown only to signed-in visitors looking at someone else's account.
class AccountActionsMenu extends ConsumerWidget {
  const AccountActionsMenu({
    super.key,
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    if (me == null || me == userId) return const SizedBox.shrink();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final blocked = ref
        .watch(blockedByMeProvider(userId))
        .maybeWhen(data: (v) => v, orElse: () => false);

    void toast(String text) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }

    Future<void> report() async {
      final safety = ref.read(safetyServiceProvider);
      final profileId = await safety.firstProfileIdOf(userId);
      if (!context.mounted) return;
      if (profileId == null) {
        toast(
          ru
              ? 'У этого аккаунта нет анкеты. Пожаловаться можно на конкретный пост или комментарий через «⋯».'
              : 'This account has no profile. Report a specific post or comment from its "…" menu.',
        );
        return;
      }
      final sent = await showReportReasonsDialog(
        context,
        title: ru ? 'Пожаловаться на аккаунт' : 'Report account',
        onSubmit: (r, reason, note) async {
          final ok = await r
              .read(safetyServiceProvider)
              .reportProfile(
                profileId: profileId,
                reason: reason,
                comment: note,
              );
          if (!ok) throw StateError('report failed');
        },
      );
      if (sent && context.mounted) {
        toast(ru ? 'Жалоба отправлена' : 'Report sent');
      }
    }

    Future<void> toggleBlock() async {
      final safety = ref.read(safetyServiceProvider);
      if (blocked) {
        await safety.unblockUser(userId);
        ref.invalidate(blockedByMeProvider(userId));
        ref.invalidate(feedControllerProvider);
        ref.invalidate(postCommentsProvider);
        if (context.mounted) toast(ru ? 'Разблокировано' : 'Unblocked');
        return;
      }
      await blockUserWithConfirm(
        context,
        ref,
        userId: userId,
        displayName: displayName,
      );
    }

    return PopupMenuButton<String>(
      tooltip: ru ? 'Ещё' : 'More',
      icon: const Icon(Icons.more_horiz_rounded),
      color: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.border),
      ),
      onSelected: (v) {
        switch (v) {
          case 'report':
            report();
          case 'block':
            toggleBlock();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'report',
          child: Text(ru ? 'Пожаловаться' : 'Report', style: AppText.body),
        ),
        PopupMenuItem(
          value: 'block',
          child: Text(
            blocked
                ? (ru ? 'Разблокировать' : 'Unblock')
                : (ru ? 'Заблокировать' : 'Block'),
            style: AppText.body.copyWith(
              color: blocked ? Tokens.text : Tokens.danger,
            ),
          ),
        ),
      ],
    );
  }
}
