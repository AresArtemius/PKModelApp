import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../ui/brand/ui_constants.dart';
import 'follow_button.dart';
import 'follow_service.dart';

/// Step 42: «Подписки» in the account — who I follow and who follows me.
class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  String _direction = 'following';

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final list = ref.watch(followListProvider(_direction));

    return SettingsPageV2(
      title: ru ? 'Подписки' : 'Follows',
      subtitle: ru
          ? 'Посты людей, на которых вы подписаны, попадают в вашу ленту'
          : 'Posts from people you follow appear in your feed',
      backLabel: ru ? 'Аккаунт' : 'Account',
      onBack: () => context.go(Routes.me),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'following',
                label: Text(ru ? 'Я подписан' : 'Following'),
              ),
              ButtonSegment(
                value: 'followers',
                label: Text(ru ? 'Подписчики' : 'Followers'),
              ),
            ],
            selected: {_direction},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _direction = value.first),
          ),
        ),
        SettingsSection(
          title: _direction == 'following'
              ? (ru ? 'Вы подписаны' : 'You follow')
              : (ru ? 'На вас подписаны' : 'Your followers'),
          child: list.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SettingsNote(
              text: ru ? 'Не удалось загрузить список' : 'Could not load the list',
              tone: SettingsNoteTone.warning,
            ),
            data: (items) => items.isEmpty
                ? SettingsNote(
                    text: _direction == 'following'
                        ? (ru
                              ? 'Пока никого. Кнопка «Подписаться» есть на странице аккаунта (/@tag) и в анкете.'
                              : 'Nobody yet. The «Follow» button is on account pages (/@tag) and profiles.')
                        : (ru ? 'Подписчиков пока нет.' : 'No followers yet.'),
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
                          subtitle: [
                            if (items[i].accountTag.isNotEmpty)
                              '@${items[i].accountTag}',
                            _typeLabel(items[i].accountType, ru),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          onTap: items[i].accountTag.isEmpty
                              ? null
                              : () => context.push(
                                  '${Routes.publicAccountPrefix}${items[i].accountTag}',
                                ),
                          trailing: FollowButton(
                            userId: items[i].userId,
                            showCount: false,
                            compact: true,
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

  static String _typeLabel(String type, bool ru) {
    return switch (type) {
      'user' => ru ? 'Участник' : 'Talent',
      'casting_director' => ru ? 'Кастинг-директор' : 'Casting director',
      'casting_agent' => ru ? 'Кастинг-агент' : 'Casting agent',
      'director_producer' => ru ? 'Режиссёр / продюсер' : 'Director / producer',
      'brand_client' => ru ? 'Бренд / клиент' : 'Brand / client',
      'agency' => ru ? 'Агентство' : 'Agency',
      'production_agency' => ru ? 'Продакшн' : 'Production',
      'photo_video' => ru ? 'Фото / видео' : 'Photo / video',
      'scout_booker' => ru ? 'Скаут / букер' : 'Scout / booker',
      _ => '',
    };
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
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: Tokens.textTertiary,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Tokens.surfaceAlt,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: Tokens.textTertiary,
                  ),
                ),
              ),
      ),
    );
  }
}
