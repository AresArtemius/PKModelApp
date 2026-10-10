import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_providers.dart';
import '../../core/public_links.dart';
import '../../core/router.dart';
import '../../core/storage_image_variant.dart';
import '../../ui/brand/ui_constants.dart';
import '../castings/casting_model.dart';
import '../castings/casting_project_stage.dart';
import '../castings/castings_provider.dart';
import 'feed_models.dart';
import 'feed_service.dart';
import 'post_composer.dart';
import 'repost_dialog.dart';

/// Step 44: the home feed (`/feed`). Read-only for now: a 600 px column of
/// posts with infinite scroll, on wide screens a second column with open
/// castings. Likes, saves and composing come in steps 45–46.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key, this.scope = 'home'});

  final String scope;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  static const double _columnWidth = 600;
  static const double _asideWidth = 320;
  static const double _twoColumnBreakpoint = 1100;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 800) {
      ref.read(feedControllerProvider(widget.scope).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final feed = ref.watch(feedControllerProvider(widget.scope));
    final controller = ref.read(feedControllerProvider(widget.scope).notifier);
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= _twoColumnBreakpoint;
    // Step 46: the composer sits at the top of the home feed.
    final showComposer =
        ref.watch(isAuthenticatedProvider) && widget.scope == 'home';
    final offset = showComposer ? 1 : 0;

    final column = RefreshIndicator(
      onRefresh: controller.refresh,
      color: Tokens.text,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: twoColumns ? Tokens.s24 : Tokens.s8,
          bottom: Tokens.s48,
        ),
        itemCount: _itemCount(feed) + offset,
        itemBuilder: (context, rawIndex) {
          if (showComposer && rawIndex == 0) return const PostComposer();
          final index = rawIndex - offset;
          if (feed.loading) return const _PostSkeleton();
          if (feed.error != null && feed.posts.isEmpty) {
            return _FeedMessage(
              icon: Icons.cloud_off_rounded,
              title: ru ? 'Не удалось загрузить ленту' : 'Could not load the feed',
              action: TextButton(
                onPressed: controller.refresh,
                child: Text(ru ? 'Повторить' : 'Retry'),
              ),
            );
          }
          if (feed.posts.isEmpty) return _EmptyFeed(ru: ru);
          if (index < feed.posts.length) {
            return _PostCard(
              post: feed.posts[index],
              last: index == feed.posts.length - 1 && !feed.hasMore,
            );
          }
          // Tail: spinner while the next page loads, or a quiet end mark.
          if (feed.loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.s24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (feed.error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.s16),
              child: Center(
                child: TextButton(
                  onPressed: controller.loadMore,
                  child: Text(
                    ru ? 'Ошибка загрузки — повторить' : 'Load failed — retry',
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.s24),
            child: Center(
              child: Text(
                ru ? 'Это всё' : 'That is all',
                style: AppText.caption.copyWith(color: Tokens.textTertiary),
              ),
            ),
          );
        },
      ),
    );

    if (!twoColumns) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _columnWidth),
          child: column,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _columnWidth + Tokens.s48 + _asideWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: _columnWidth, child: column),
            const SizedBox(width: Tokens.s48),
            const SizedBox(
              width: _asideWidth,
              child: Padding(
                padding: EdgeInsets.only(top: Tokens.s24),
                child: _OpenCastingsAside(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _itemCount(FeedState feed) {
    if (feed.loading) return 4;
    if (feed.posts.isEmpty) return 1;
    return feed.posts.length + 1;
  }
}

// ---------------------------------------------------------------------------
// Post card
// ---------------------------------------------------------------------------

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.last});

  final FeedPost post;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.s16,
        vertical: Tokens.s16,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: Tokens.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(post: post, ru: ru),
          if (post.body.trim().isNotEmpty) ...[
            const SizedBox(height: Tokens.s12),
            Text(post.body.trim(), style: AppText.body),
          ],
          ..._kindContent(context, ru),
          const SizedBox(height: Tokens.s12),
          _PostFooter(post: post, ru: ru),
        ],
      ),
    );
  }

  List<Widget> _kindContent(BuildContext context, bool ru) {
    switch (post.kind) {
      case FeedPostKind.media:
        if (post.media.isEmpty) return const [];
        return [
          const SizedBox(height: Tokens.s12),
          _MediaGrid(
            media: post.media,
            onTap: () => _openProfile(context),
          ),
        ];
      case FeedPostKind.casting:
        return [
          const SizedBox(height: Tokens.s12),
          _CastingBlock(post: post, ru: ru),
        ];
      case FeedPostKind.booked:
        return [
          const SizedBox(height: Tokens.s12),
          _BookedBlock(post: post, ru: ru, onOpenProfile: () => _openProfile(context)),
        ];
      case FeedPostKind.repost:
        // A repost points at a post, a profile or a casting.
        if (post.repostOf != null) {
          if (post.repostBody.trim().isEmpty && post.repostAuthorName.isEmpty) {
            return const [];
          }
          return [
            const SizedBox(height: Tokens.s12),
            _QuoteBlock(author: post.repostAuthorName, body: post.repostBody),
          ];
        }
        if (post.castingId != null) {
          return [
            const SizedBox(height: Tokens.s12),
            _CastingBlock(post: post, ru: ru),
          ];
        }
        if (post.profileId != null) {
          return [
            const SizedBox(height: Tokens.s12),
            _ProfileBlock(post: post, ru: ru, onOpen: () => _openProfile(context)),
          ];
        }
        return const [];
      case FeedPostKind.text:
        if (post.media.isEmpty) return const [];
        return [
          const SizedBox(height: Tokens.s12),
          _MediaGrid(media: post.media, onTap: null),
        ];
    }
  }

  void _openProfile(BuildContext context) {
    final id = post.profileId;
    if (id == null) return;
    context.push('${Routes.modelPrefix}$id');
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post, required this.ru});

  final FeedPost post;
  final bool ru;

  @override
  Widget build(BuildContext context) {
    final canOpen = post.authorTag.isNotEmpty;
    final meta = <String>[
      if (post.authorTag.isNotEmpty) '@${post.authorTag}',
      feedRelativeTime(post.createdAt, ru),
      if (post.auto) (ru ? 'авто' : 'auto'),
    ].join(' · ');

    return InkWell(
      onTap: canOpen
          ? () => context.push('${Routes.publicAccountPrefix}${post.authorTag}')
          : null,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Row(
        children: [
          _Avatar(url: post.authorAvatarUrl, size: 40),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.displayAuthor(ru),
                  style: AppText.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _KindLabel(kind: post.kind, ru: ru),
        ],
      ),
    );
  }
}

/// Small text marker on the right of the header: what kind of event this is.
class _KindLabel extends StatelessWidget {
  const _KindLabel({required this.kind, required this.ru});

  final FeedPostKind kind;
  final bool ru;

  @override
  Widget build(BuildContext context) {
    final (IconData, String)? spec = switch (kind) {
      FeedPostKind.media => (
        Icons.photo_outlined,
        ru ? 'Новые фото' : 'New photos',
      ),
      FeedPostKind.casting => (
        Icons.videocam_outlined,
        ru ? 'Кастинг' : 'Casting',
      ),
      FeedPostKind.booked => (
        Icons.check_circle_outline_rounded,
        ru ? 'Утверждение' : 'Booked',
      ),
      FeedPostKind.repost => (
        Icons.repeat_rounded,
        ru ? 'Поделился' : 'Shared',
      ),
      FeedPostKind.text => null,
    };
    if (spec == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.$1, size: 16, color: Tokens.textTertiary),
        const SizedBox(width: 6),
        Text(
          spec.$2,
          style: AppText.caption.copyWith(color: Tokens.textTertiary),
        ),
      ],
    );
  }
}

class _PostFooter extends ConsumerWidget {
  const _PostFooter({required this.post, required this.ru});

  final FeedPost post;
  final bool ru;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isAuthenticatedProvider);
    final actions = ref.read(feedActionsProvider);

    void requireSignIn() => context.go(Routes.authRequired);

    Future<void> onLike() async {
      if (!signedIn) {
        requireSignIn();
        return;
      }
      final ok = await actions.toggleLike(post);
      if (!ok && context.mounted) _toast(context, ru ? 'Не получилось' : 'Failed');
    }

    Future<void> onSave() async {
      if (!signedIn) {
        requireSignIn();
        return;
      }
      final ok = await actions.toggleSave(post);
      if (!context.mounted) return;
      if (!ok) {
        _toast(context, ru ? 'Не получилось' : 'Failed');
      } else if (!post.saved) {
        _toast(context, ru ? 'Сохранено' : 'Saved');
      }
    }

    Future<void> onRepost() async {
      if (!signedIn) {
        requireSignIn();
        return;
      }
      // Reposting a repost shares the original.
      final target = post.kind == FeedPostKind.repost && post.repostOf != null
          ? post.repostOf!
          : post.id;
      final title = post.body.trim().isNotEmpty
          ? post.body.trim()
          : post.castingTitle.isNotEmpty
          ? post.castingTitle
          : post.profileName.isNotEmpty
          ? post.profileName
          : post.displayAuthor(ru);
      final done = await showRepostDialog(context, title: title, repostOf: target);
      if (done && context.mounted) showRepostDone(context);
    }

    Future<void> onShare() async {
      final link = _shareLink(post);
      if (link == null) return;
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        _toast(context, ru ? 'Ссылка скопирована' : 'Link copied');
      }
    }

    return Row(
      children: [
        _FooterAction(
          icon: post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          value: post.likeCount,
          active: post.liked,
          activeColor: Tokens.accent,
          tooltip: ru ? 'Нравится' : 'Like',
          onTap: onLike,
        ),
        const SizedBox(width: Tokens.s16),
        _FooterAction(
          icon: Icons.mode_comment_outlined,
          value: post.commentCount,
          active: false,
          tooltip: ru ? 'Комментарии' : 'Comments',
          onTap: null,
        ),
        const SizedBox(width: Tokens.s16),
        _FooterAction(
          icon: Icons.repeat_rounded,
          value: post.repostCount,
          active: false,
          tooltip: ru ? 'Поделиться в ленту' : 'Repost',
          onTap: onRepost,
        ),
        const Spacer(),
        if (_shareLink(post) != null)
          _FooterAction(
            icon: Icons.link_rounded,
            value: 0,
            active: false,
            tooltip: ru ? 'Скопировать ссылку' : 'Copy link',
            onTap: onShare,
          ),
        const SizedBox(width: Tokens.s8),
        _FooterAction(
          icon: post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          value: 0,
          active: post.saved,
          activeColor: Tokens.text,
          tooltip: ru ? 'Сохранить' : 'Save',
          onTap: onSave,
        ),
      ],
    );
  }

  /// Public page the post is about: the profile, the casting, or the author.
  static String? _shareLink(FeedPost post) {
    if (post.profileId != null) return publicProfileLink(post.profileId!);
    if (post.castingId != null) return publicCastingLink(post.castingId!);
    if (post.authorTag.isNotEmpty) return publicAccountLink(post.authorTag);
    return null;
  }

  static void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.value,
    required this.active,
    required this.tooltip,
    required this.onTap,
    this.activeColor = Tokens.accent,
  });

  final IconData icon;
  final int value;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? activeColor
        : (onTap == null ? Tokens.textTertiary : Tokens.textSecondary);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              if (value > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$value',
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kind-specific blocks
// ---------------------------------------------------------------------------

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.media, required this.onTap});

  final List<FeedMedia> media;
  final VoidCallback? onTap;

  static const _maxTiles = 4;

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      final m = media.first;
      return _MediaTile(
        media: m,
        aspectRatio: m.aspectRatio.clamp(0.6, 1.6).toDouble(),
        onTap: onTap,
        width: 600,
      );
    }
    final shown = media.take(_maxTiles).toList();
    final overflow = media.length - shown.length;
    const columns = 2;
    const gap = 4.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final tileHeight = shown.length <= 2 ? tileWidth * 1.25 : tileWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < shown.length; i++)
              SizedBox(
                width: tileWidth,
                height: tileHeight,
                child: _MediaTile(
                  media: shown[i],
                  onTap: onTap,
                  width: tileWidth.round(),
                  overlayCount: i == shown.length - 1 ? overflow : 0,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.onTap,
    required this.width,
    this.aspectRatio,
    this.overlayCount = 0,
  });

  final FeedMedia media;
  final VoidCallback? onTap;
  final int width;
  final double? aspectRatio;
  final int overlayCount;

  @override
  Widget build(BuildContext context) {
    final src = media.thumbnailUrl.isNotEmpty ? media.thumbnailUrl : media.url;
    Widget image = CachedNetworkImage(
      imageUrl: storageImageVariant(src, width: width * 2),
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: Tokens.surfaceAlt),
      errorWidget: (_, _, _) => CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const ColoredBox(
          color: Tokens.surfaceAlt,
          child: Icon(Icons.broken_image_outlined, color: Tokens.textTertiary),
        ),
      ),
    );
    if (media.isVideo || overlayCount > 0) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (media.isVideo)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          if (overlayCount > 0)
            ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Text(
                  '+$overlayCount',
                  style: AppText.h2.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      );
    }
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: aspectRatio != null
          ? AspectRatio(aspectRatio: aspectRatio!, child: image)
          : image,
    );
    if (onTap == null) return clipped;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: clipped),
    );
  }
}

class _CastingBlock extends StatelessWidget {
  const _CastingBlock({required this.post, required this.ru});

  final FeedPost post;
  final bool ru;

  @override
  Widget build(BuildContext context) {
    final id = post.castingId;
    final title = post.castingTitle.isNotEmpty
        ? post.castingTitle
        : (ru ? 'Кастинг' : 'Casting');
    return _Framed(
      onTap: id == null ? null : () => context.go('${Routes.castings}?casting=$id'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Tokens.accentSoft,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
            child: const Icon(Icons.videocam_outlined, color: Tokens.accent),
          ),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.bodyStrong,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (post.city.isNotEmpty) post.city,
                    ru ? 'Идёт приём заявок' : 'Accepting applications',
                  ].join(' · '),
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
              ],
            ),
          ),
          if (id != null)
            const Icon(Icons.chevron_right_rounded, color: Tokens.textTertiary),
        ],
      ),
    );
  }
}

class _BookedBlock extends StatelessWidget {
  const _BookedBlock({
    required this.post,
    required this.ru,
    required this.onOpenProfile,
  });

  final FeedPost post;
  final bool ru;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final name = post.profileName.isNotEmpty
        ? post.profileName
        : (ru ? 'Анкета' : 'Profile');
    final casting = post.castingTitle.isNotEmpty
        ? '«${post.castingTitle}»'
        : (ru ? 'кастинг' : 'the casting');
    return _Framed(
      onTap: post.profileId == null ? null : onOpenProfile,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            child: SizedBox(
              width: 56,
              height: 70,
              child: post.profilePhotoUrl.isEmpty
                  ? const ColoredBox(
                      color: Tokens.surfaceAlt,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: Tokens.textTertiary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: storageImageVariant(
                        post.profilePhotoUrl,
                        width: 160,
                      ),
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => CachedNetworkImage(
                        imageUrl: post.profilePhotoUrl,
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
                Text(name, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  ru ? 'утверждена на $casting' : 'booked for $casting',
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Tokens.success),
        ],
      ),
    );
  }
}

/// A profile from the catalogue shared to the feed.
class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({
    required this.post,
    required this.ru,
    required this.onOpen,
  });

  final FeedPost post;
  final bool ru;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = post.profileName.isNotEmpty
        ? post.profileName
        : (ru ? 'Анкета' : 'Profile');
    return _Framed(
      onTap: onOpen,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            child: SizedBox(
              width: 56,
              height: 70,
              child: post.profilePhotoUrl.isEmpty
                  ? const ColoredBox(
                      color: Tokens.surfaceAlt,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: Tokens.textTertiary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: storageImageVariant(
                        post.profilePhotoUrl,
                        width: 160,
                      ),
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => CachedNetworkImage(
                        imageUrl: post.profilePhotoUrl,
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
                Text(name, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  ru ? 'Анкета в каталоге' : 'Catalogue profile',
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Tokens.textTertiary),
        ],
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.author, required this.body});

  final String author;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Tokens.s12, Tokens.s8, Tokens.s12, Tokens.s8),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Tokens.borderStrong, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (author.isNotEmpty) Text(author, style: AppText.smallStrong),
          if (body.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              body.trim(),
              style: AppText.small.copyWith(color: Tokens.textSecondary),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin-bordered inset block (no grey plates — v2 standard).
class _Framed extends StatelessWidget {
  const _Framed({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(Tokens.s12),
        decoration: BoxDecoration(
          border: Border.all(color: Tokens.border),
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
        ),
        child: child,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? ColoredBox(
                color: Tokens.surfaceAlt,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: size * 0.5,
                  color: Tokens.textTertiary,
                ),
              )
            : CachedNetworkImage(
                imageUrl: storageImageVariant(url, width: (size * 2).round()),
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: Tokens.surfaceAlt,
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.ru});

  final bool ru;

  @override
  Widget build(BuildContext context) {
    return _FeedMessage(
      icon: Icons.dynamic_feed_outlined,
      title: ru ? 'Лента пока пуста' : 'Your feed is empty',
      subtitle: ru
          ? 'Подпишитесь на модели, агентства и кастинг-директоров — их новые фото, кастинги и утверждения появятся здесь.'
          : 'Follow talent, agencies and casting directors — their new photos, castings and bookings will show up here.',
      action: Wrap(
        spacing: Tokens.s8,
        children: [
          FilledButton(
            onPressed: () => context.go(Routes.search),
            child: Text(ru ? 'Найти людей' : 'Find people'),
          ),
          OutlinedButton(
            onPressed: () => context.go(Routes.castings),
            child: Text(ru ? 'Кастинги' : 'Castings'),
          ),
        ],
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.s24, Tokens.s48, Tokens.s24, Tokens.s24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Tokens.textTertiary),
          const SizedBox(height: Tokens.s16),
          Text(title, style: AppText.h2, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: Tokens.s8),
            Text(
              subtitle!,
              style: AppText.body.copyWith(color: Tokens.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: Tokens.s20),
            action!,
          ],
        ],
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Container(
        padding: const EdgeInsets.all(Tokens.s16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Tokens.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                SkeletonBox(width: 40, height: 40, radius: 20),
                SizedBox(width: Tokens.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 12),
                  ],
                ),
              ],
            ),
            SizedBox(height: Tokens.s12),
            SkeletonBox(height: 14, width: 420),
            SizedBox(height: 6),
            SkeletonBox(height: 14, width: 300),
            SizedBox(height: Tokens.s12),
            SkeletonBox(aspectRatio: 1.4, radius: Tokens.radiusMd),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right column: open castings
// ---------------------------------------------------------------------------

class _OpenCastingsAside extends ConsumerWidget {
  const _OpenCastingsAside();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final castings = ref.watch(castingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ru ? 'Открытые кастинги' : 'Open castings', style: AppText.h2),
        const SizedBox(height: Tokens.s12),
        castings.when(
          loading: () => const Skeleton(
            child: Column(
              children: [
                SkeletonBox(height: 56),
                SizedBox(height: Tokens.s8),
                SkeletonBox(height: 56),
                SizedBox(height: Tokens.s8),
                SkeletonBox(height: 56),
              ],
            ),
          ),
          error: (_, _) => Text(
            ru ? 'Не удалось загрузить' : 'Could not load',
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
          data: (items) {
            final open = items
                .where(
                  (c) =>
                      c.projectStage == CastingProjectStage.acceptingApplications,
                )
                .take(5)
                .toList();
            if (open.isEmpty) {
              return Text(
                ru ? 'Сейчас открытых кастингов нет' : 'No open castings right now',
                style: AppText.small.copyWith(color: Tokens.textSecondary),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < open.length; i++)
                  _AsideCastingRow(casting: open[i], last: i == open.length - 1),
              ],
            );
          },
        ),
        const SizedBox(height: Tokens.s12),
        TextButton(
          onPressed: () => context.go(Routes.castings),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(ru ? 'Все кастинги →' : 'All castings →'),
        ),
      ],
    );
  }
}

class _AsideCastingRow extends StatelessWidget {
  const _AsideCastingRow({required this.casting, required this.last});

  final CastingModel casting;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (casting.datesText.trim().isNotEmpty) casting.datesText.trim(),
      if (casting.fee.trim().isNotEmpty) casting.fee.trim(),
    ].join(' · ');
    return InkWell(
      onTap: () => context.go('${Routes.castings}?casting=${casting.id}'),
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Tokens.s12),
        decoration: BoxDecoration(
          border: Border(
            bottom: last
                ? BorderSide.none
                : const BorderSide(color: Tokens.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              casting.title,
              style: AppText.bodyStrong,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                meta,
                style: AppText.small.copyWith(color: Tokens.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// «только что», «5 мин», «3 ч», «вчера», «12 окт», «12 окт 2025».
String feedRelativeTime(DateTime at, bool ru) {
  final now = DateTime.now();
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return ru ? 'только что' : 'just now';
  if (diff.inHours < 1) {
    return ru ? '${diff.inMinutes} мин' : '${diff.inMinutes}m';
  }
  if (diff.inHours < 24 && at.day == now.day) {
    return ru ? '${diff.inHours} ч' : '${diff.inHours}h';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (at.year == yesterday.year &&
      at.month == yesterday.month &&
      at.day == yesterday.day) {
    return ru ? 'вчера' : 'yesterday';
  }
  const ruMonths = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
  const enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = (ru ? ruMonths : enMonths)[at.month - 1];
  final base = ru ? '${at.day} $month' : '$month ${at.day}';
  return at.year == now.year ? base : '$base ${at.year}';
}
