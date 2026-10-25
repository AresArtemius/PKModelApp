import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../ui/brand/ui_constants.dart';
import '../feed/feed_service.dart' show feedControllerProvider, postCommentsProvider;
import 'safety_service.dart';

/// My account → Blocked users: the list with «Unblock» on every row.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final list = ref.watch(blockedUsersProvider);

    Future<void> unblock(BlockedAccount a) async {
      await ref.read(safetyServiceProvider).unblockUser(a.userId);
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(blockedByMeProvider(a.userId));
      ref.invalidate(feedControllerProvider);
      ref.invalidate(postCommentsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ru ? 'Разблокировано' : 'Unblocked')),
        );
    }

    return SettingsPageV2(
      title: ru ? 'Заблокированные' : 'Blocked users',
      subtitle: ru
          ? 'Их публикации и сообщения вам не показываются. Разблокировать можно в любой момент.'
          : 'Their posts and messages are hidden from you. You can unblock at any time.',
      backLabel: ru ? 'Аккаунт' : 'Account',
      onBack: () => context.go(Routes.me),
      children: [
        SettingsSection(
          title: ru ? 'Вы заблокировали' : 'You blocked',
          child: list.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SettingsNote(
              text: ru ? 'Не удалось загрузить список' : 'Could not load the list',
              tone: SettingsNoteTone.danger,
            ),
            data: (items) => items.isEmpty
                ? SettingsNote(
                    text: ru
                        ? 'Никого. Заблокировать можно из меню «⋯» поста или на странице аккаунта.'
                        : 'Nobody. You can block from a post\'s «⋯» menu or on an account page.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        SettingsListRow(
                          leading: _Avatar(url: items[i].avatarUrl),
                          title: items[i].name.isEmpty
                              ? (items[i].accountTag.isEmpty
                                    ? (ru ? 'Аккаунт' : 'Account')
                                    : '@${items[i].accountTag}')
                              : items[i].name,
                          subtitle: items[i].accountTag.isEmpty
                              ? ''
                              : '@${items[i].accountTag}',
                          onTap: () => context.push(
                            Routes.accountLocation(
                              tag: items[i].accountTag,
                              userId: items[i].userId,
                            ),
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => unblock(items[i]),
                            child: Text(ru ? 'Разблокировать' : 'Unblock'),
                          ),
                          last: i == items.length - 1,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: SizedBox(
        width: 36,
        height: 36,
        child: url.trim().isEmpty
            ? const ColoredBox(
                color: Tokens.surfaceAlt,
                child: Icon(Icons.person_outline_rounded, size: 18),
              )
            : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
      ),
    );
  }
}
