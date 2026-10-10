import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_providers.dart';
import '../../core/router.dart';
import '../../ui/brand/ui_constants.dart';
import 'follow_service.dart';

/// Step 42: «Подписаться / Вы подписаны» for an account, with the follower
/// count next to it. Hidden for one's own account and when the id is empty.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.userId,
    this.showCount = true,
    this.compact = false,
  });

  final String userId;
  final bool showCount;

  /// Smaller control for lists and tight headers.
  final bool compact;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool? _optimistic;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final me = ref.watch(currentUserIdProvider) ?? '';
    final id = widget.userId.trim();
    if (id.isEmpty || id == me) return const SizedBox.shrink();

    final counts =
        ref.watch(followCountsProvider(id)).valueOrNull ?? FollowCounts.empty;
    final following = _optimistic ?? counts.iFollow;
    final followers =
        counts.followers +
        (_optimistic == null || _optimistic == counts.iFollow
            ? 0
            : (_optimistic! ? 1 : -1));

    Future<void> toggle() async {
      if (me.isEmpty) {
        this.context.go(Routes.authRequired);
        return;
      }
      if (_busy) return;
      setState(() {
        _busy = true;
        _optimistic = !following;
      });
      final ok = await ref
          .read(followActionsProvider)
          .toggle(id, currentlyFollowing: following);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _optimistic = null;
      });
      if (!ok && mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              ru ? 'Не удалось изменить подписку' : 'Could not update the follow',
            ),
          ),
        );
      }
    }

    final label = following
        ? (ru ? 'Вы подписаны' : 'Following')
        : (ru ? 'Подписаться' : 'Follow');
    final height = widget.compact ? 36.0 : Tokens.controlHeight;
    final padding = EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 20);
    final icon = Icon(
      following ? Icons.check_rounded : Icons.person_add_alt_1_outlined,
      size: 18,
    );
    final button = following
        ? OutlinedButton.icon(
            onPressed: toggle,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, height),
              padding: padding,
            ),
            icon: icon,
            label: Text(label),
          )
        : FilledButton.icon(
            onPressed: toggle,
            style: FilledButton.styleFrom(
              minimumSize: Size(0, height),
              padding: padding,
            ),
            icon: icon,
            label: Text(label),
          );

    if (!widget.showCount) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(width: 10),
        Text(
          _followersLabel(followers.clamp(0, 1 << 30), ru),
          style: AppText.caption.copyWith(fontSize: 13),
        ),
      ],
    );
  }

  static String _followersLabel(int n, bool ru) {
    if (!ru) return '$n ${n == 1 ? 'follower' : 'followers'}';
    final m10 = n % 10;
    final m100 = n % 100;
    final word = m10 == 1 && m100 != 11
        ? 'подписчик'
        : m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)
        ? 'подписчика'
        : 'подписчиков';
    return '$n $word';
  }
}
