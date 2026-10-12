import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../ui/brand/public_page_frame.dart';
import '../../ui/brand/ui_constants.dart';
import 'feed_page.dart';
import 'feed_service.dart';

/// One post on its own page (/post/:id): what a shared link opens.
/// From here the author's name leads to the account page with «Подписаться».
class PostPage extends ConsumerWidget {
  const PostPage({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final scope = 'post:$postId';
    final feed = ref.watch(feedControllerProvider(scope));
    final post = feed.posts.isEmpty ? null : feed.posts.first;

    Widget body;
    if (feed.loading && post == null) {
      body = const Padding(
        padding: EdgeInsets.all(Tokens.s16),
        child: Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 160, height: 20),
              SizedBox(height: Tokens.s12),
              SkeletonBox(height: 80),
              SizedBox(height: Tokens.s12),
              SkeletonBox(height: 240),
            ],
          ),
        ),
      );
    } else if (post == null) {
      body = Padding(
        padding: const EdgeInsets.all(Tokens.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ru ? 'Пост не найден' : 'Post not found',
              style: AppText.h2,
            ),
            const SizedBox(height: Tokens.s8),
            Text(
              ru
                  ? 'Он удалён или доступен только подписчикам автора.'
                  : 'It was deleted or is visible to the author’s followers only.',
              style: AppText.small.copyWith(color: Tokens.textSecondary),
            ),
            const SizedBox(height: Tokens.s16),
            OutlinedButton(
              onPressed: () => context.go(Routes.feed),
              child: Text(ru ? 'В ленту' : 'Open feed'),
            ),
          ],
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(bottom: Tokens.s48),
        children: [
          FeedPostCard(post: post, last: true, openComments: true),
        ],
      );
    }

    return PublicPageFrame(
      currentIndex: 5,
      onBack: () => context.go(Routes.feed),
      backLabel: ru ? 'Лента' : 'Feed',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: body,
        ),
      ),
    );
  }
}
