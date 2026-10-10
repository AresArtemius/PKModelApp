import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/storage_image_variant.dart';
import '../../ui/brand/ui_constants.dart';
import 'follow_button.dart';
import 'follow_service.dart';

/// Step 49: «Кого читать» — accounts from the same city first, then the
/// most followed and the most active. Hidden when there is nobody to show.
class WhoToFollowAside extends ConsumerWidget {
  const WhoToFollowAside({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final suggestions = ref.watch(followSuggestionsProvider);

    return suggestions.when(
      loading: () => const Skeleton(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 140, height: 20),
            SizedBox(height: Tokens.s12),
            SkeletonBox(height: 44),
            SizedBox(height: Tokens.s8),
            SkeletonBox(height: 44),
            SizedBox(height: Tokens.s8),
            SkeletonBox(height: 44),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ru ? 'Кого читать' : 'Who to follow', style: AppText.h2),
            const SizedBox(height: Tokens.s8),
            for (var i = 0; i < items.length && i < 6; i++)
              _SuggestionRow(item: items[i], ru: ru),
            const SizedBox(height: Tokens.s8),
            TextButton(
              onPressed: () => context.go(Routes.search),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(ru ? 'Каталог →' : 'Catalogue →'),
            ),
          ],
        );
      },
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.item, required this.ru});

  final FollowSuggestion item;
  final bool ru;

  @override
  Widget build(BuildContext context) {
    final title = item.name.isNotEmpty
        ? item.name
        : (item.accountTag.isNotEmpty ? '@${item.accountTag}' : (ru ? 'Аккаунт' : 'Account'));
    final hint = switch (item.reason) {
      'city' => item.city.isNotEmpty ? item.city : (ru ? 'Ваш город' : 'Your city'),
      'popular' => ru
          ? '${item.followers} ${_pluralRu(item.followers, 'подписчик', 'подписчика', 'подписчиков')}'
          : '${item.followers} followers',
      'active' => ru ? 'Недавно публиковал(а)' : 'Recently posted',
      _ => _typeLabel(item.accountType, ru),
    };
    final canOpen = item.accountTag.isNotEmpty;

    return InkWell(
      onTap: canOpen
          ? () => context.push('${Routes.publicAccountPrefix}${item.accountTag}')
          : null,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 36,
                height: 36,
                child: item.avatarUrl.isEmpty
                    ? const ColoredBox(
                        color: Tokens.surfaceAlt,
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: Tokens.textTertiary,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: storageImageVariant(item.avatarUrl, width: 72),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => CachedNetworkImage(
                          imageUrl: item.avatarUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: Tokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.smallStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hint.isNotEmpty)
                    Text(
                      hint,
                      style: AppText.caption.copyWith(color: Tokens.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: Tokens.s8),
            FollowButton(userId: item.userId, showCount: false, compact: true),
          ],
        ),
      ),
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

  static String _pluralRu(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }
}
