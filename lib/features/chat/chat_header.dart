part of 'chat_page.dart';

// Step 27: split out of chat_page.dart without behaviour changes.
// Chat header (v2 and native), presence line and the context card.

// Header icons: ink, round surface on hover.
final ButtonStyle _headerIconStyle = IconButton.styleFrom(
  foregroundColor: Tokens.ink,
  hoverColor: Tokens.surfaceAlt,
  highlightColor: Tokens.surfaceAlt,
  shape: const CircleBorder(),
);

/// Horizontal page gutter of the v2 conversation column.
class _V2Pad extends StatelessWidget {
  const _V2Pad({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 24),
      child: child,
    );
  }
}

class _ChatHeaderV2 extends ConsumerWidget {
  const _ChatHeaderV2({
    required this.title,
    required this.subtitle,
    required this.otherUserId,
    required this.avatarUrl,
    required this.onSearch,
    required this.searchActive,
    required this.onDeleteChat,
    this.onOpenProfile,
    this.onOpenCasting,
    this.onBack,
    this.onToggleInfo,
    this.infoActive = false,
  });

  /// Set on the standalone (phone-width) page; the two-column layout has
  /// the list beside the chat and needs no back arrow.
  final VoidCallback? onBack;
  final String title;
  final String subtitle;
  final String otherUserId;
  final String avatarUrl;
  final VoidCallback onSearch;
  final bool searchActive;
  final VoidCallback onDeleteChat;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenCasting;

  /// Step 29: shows / hides the context panel; null when it does not fit.
  final VoidCallback? onToggleInfo;
  final bool infoActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final presence = otherUserId.isEmpty
        ? null
        : ref.watch(userPresenceProvider(otherUserId)).valueOrNull;
    // Step 36: Realtime Presence decides «в сети»; the heartbeat table
    // supplies «был(а) …».
    final online =
        otherUserId.isNotEmpty && ref.watch(userIsOnlineProvider(otherUserId));
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Container(
      height: narrow ? 64 : 72,
      padding: EdgeInsets.fromLTRB(onBack == null ? 24 : 8, 0, narrow ? 4 : 12, 0),
      decoration: const BoxDecoration(
        color: Tokens.bg,
        border: Border(bottom: BorderSide(color: Tokens.border)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              tooltip: ru ? 'Назад' : 'Back',
              onPressed: onBack,
              style: _headerIconStyle,
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
            ),
            const SizedBox(width: 4),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: avatarUrl.trim().isEmpty
                      ? const ColoredBox(
                          color: Tokens.surfaceAlt,
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: Tokens.textTertiary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.6),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: Tokens.surfaceAlt,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: Tokens.textTertiary,
                            ),
                          ),
                        ),
                ),
              ),
              if (online)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Tokens.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Tokens.bg, width: 2.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h2.copyWith(height: 1.2),
                ),
                const SizedBox(height: 2),
                _PresenceLine(
                  presence: presence,
                  online: online,
                  context: subtitle
                      .replaceAll('Анкета: ', '')
                      .replaceAll('Кастинг: ', '')
                      .replaceAll(' • ', ' · '),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (onOpenProfile != null && !narrow)
            IconButton(
              tooltip: ru ? 'Открыть анкету' : 'Open profile',
              onPressed: onOpenProfile,
              style: _headerIconStyle,
              icon: const Icon(Icons.badge_outlined, size: 22),
            ),
          if (onOpenCasting != null && !narrow)
            IconButton(
              tooltip: ru ? 'Открыть кастинг' : 'Open casting',
              onPressed: onOpenCasting,
              style: _headerIconStyle,
              icon: const Icon(Icons.video_camera_front_outlined, size: 22),
            ),
          if (narrow && (onOpenProfile != null || onOpenCasting != null))
            PopupMenuButton<String>(
              tooltip: ru ? 'Ещё' : 'More',
              style: _headerIconStyle,
              icon: const Icon(Icons.more_vert_rounded, size: 22),
              onSelected: (value) {
                if (value == 'profile') onOpenProfile?.call();
                if (value == 'casting') onOpenCasting?.call();
              },
              itemBuilder: (context) => [
                if (onOpenProfile != null)
                  PopupMenuItem(
                    value: 'profile',
                    child: Text(ru ? 'Открыть анкету' : 'Open profile'),
                  ),
                if (onOpenCasting != null)
                  PopupMenuItem(
                    value: 'casting',
                    child: Text(ru ? 'Открыть кастинг' : 'Open casting'),
                  ),
              ],
            ),
          if (!narrow && (onOpenProfile != null || onOpenCasting != null))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, color: Tokens.border),
              ),
            ),
          IconButton(
            tooltip: ru ? 'Поиск по переписке' : 'Search messages',
            onPressed: onSearch,
            style: searchActive
                ? IconButton.styleFrom(
                    foregroundColor: Tokens.accent,
                    backgroundColor: Tokens.accentSoft,
                    shape: const CircleBorder(),
                  )
                : _headerIconStyle,
            icon: const Icon(Icons.search_rounded, size: 22),
          ),
          IconButton(
            tooltip: ru ? 'Удалить диалог' : 'Delete chat',
            onPressed: onDeleteChat,
            style: _headerIconStyle,
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
          ),
          if (onToggleInfo != null)
            IconButton(
              tooltip: infoActive
                  ? (ru ? 'Скрыть панель' : 'Hide panel')
                  : (ru ? 'О диалоге' : 'About'),
              onPressed: onToggleInfo,
              style: infoActive
                  ? IconButton.styleFrom(
                      foregroundColor: Tokens.ink,
                      backgroundColor: Tokens.surfaceAlt,
                      shape: const CircleBorder(),
                    )
                  : _headerIconStyle,
              icon: const Icon(Icons.info_outline_rounded, size: 22),
            ),
        ],
      ),
    );
  }
}

/// "в сети" / "был(а) в 15:40" followed by the chat context; re-renders
/// every 30 s so a stale heartbeat turns into "был(а) …" on its own.
class _PresenceLine extends StatefulWidget {
  const _PresenceLine({
    required this.presence,
    required this.online,
    required this.context,
  });

  final UserPresence? presence;
  final bool online;
  final String context;

  @override
  State<_PresenceLine> createState() => _PresenceLineState();
}

class _PresenceLineState extends State<_PresenceLine> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final presence = widget.presence;
    final online = widget.online;
    final seen = presence?.lastSeenAt;
    final status = online
        ? (ru ? 'в сети' : 'online')
        : seen == null
        ? ''
        : _lastSeenLabel(seen, ru);
    final parts = [
      if (status.isNotEmpty) status,
      if (widget.context.trim().isNotEmpty) widget.context.trim(),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          if (status.isNotEmpty)
            TextSpan(
              text: status,
              style: TextStyle(
                color: online ? Tokens.success : Tokens.textSecondary,
                fontWeight: online ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          if (parts.length > 1) const TextSpan(text: '  ·  '),
          if (widget.context.trim().isNotEmpty)
            TextSpan(text: widget.context.trim()),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.caption.copyWith(fontSize: 13),
    );
  }
}

String _lastSeenLabel(DateTime seen, bool ru) {
  final local = seen.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff < const Duration(minutes: 1)) {
    return ru ? 'был(а) только что' : 'last seen just now';
  }
  if (diff < const Duration(hours: 1)) {
    final m = diff.inMinutes;
    return ru ? 'был(а) $m мин назад' : 'last seen $m min ago';
  }
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = _timeLabelV2(seen);
  if (day == today) return ru ? 'был(а) в $time' : 'last seen at $time';
  if (today.difference(day).inDays == 1) {
    return ru ? 'был(а) вчера в $time' : 'last seen yesterday at $time';
  }
  final date = _dayLabelV2(local, ru);
  return ru ? 'был(а) $date' : 'last seen $date';
}

class _ChatHeaderData {
  const _ChatHeaderData({
    required this.title,
    this.subtitle = '',
    this.avatarUrl = '',
  });

  final String title;
  final String subtitle;
  final String avatarUrl;
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.onBack,
    required this.onSearch,
    required this.searchActive,
    required this.onDeleteChat,
  });

  final String title;
  final String subtitle;
  final String avatarUrl;
  final VoidCallback? onBack;
  final VoidCallback onSearch;
  final bool searchActive;
  final VoidCallback onDeleteChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack == null)
          const SizedBox(width: 48)
        else
          _IconPill(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack!),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChatHeaderAvatar(url: avatarUrl),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextDark,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 18,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kTextMuted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconPill(
              icon: Icons.search_rounded,
              onTap: onSearch,
              active: searchActive,
            ),
            const SizedBox(width: 8),
            _IconPill(icon: Icons.delete_outline_rounded, onTap: onDeleteChat),
          ],
        ),
      ],
    );
  }
}

class _ChatHeaderAvatar extends StatelessWidget {
  const _ChatHeaderAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 34,
        height: 34,
        color: kTextDark,
        child: url.trim().isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 21)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    const Icon(Icons.person_rounded, color: Colors.white),
              ),
      ),
    );
  }
}

class _ChatContextCard extends StatelessWidget {
  const _ChatContextCard({
    required this.summary,
    required this.contexts,
    this.flat = false,
  });

  final ChatSummary summary;
  final List<ChatContextEntry> contexts;

  /// v2: white, hairline border, no shadow or dark icon plate.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final profileName = summary.profileName.trim();
    final selectionTitle = summary.selectionTitle.trim();
    final hasProfile = summary.profileId.trim().isNotEmpty;
    final hasSelection = summary.selectionId.trim().isNotEmpty;
    final history = contexts
        .where(
          (entry) =>
              entry.profileId != summary.profileId ||
              entry.selectionId != summary.selectionId,
        )
        .take(4)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: flat
          ? BoxDecoration(
              color: Tokens.bg,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              border: Border.all(color: Tokens.border),
            )
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: flat
                    ? BoxDecoration(
                        color: Tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      )
                    : pillDecoration(isDark: true, radius: 15),
                child: Icon(
                  Icons.account_tree_rounded,
                  color: flat ? Tokens.ink : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRussian ? 'КОНТЕКСТ ДИАЛОГА' : 'CHAT CONTEXT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: flat
                          ? AppText.label
                          : const TextStyle(
                              color: kTextMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                    ),
                    const SizedBox(height: 5),
                    if (profileName.isNotEmpty)
                      _ContextLine(
                        label: isRussian ? 'Анкета' : 'Profile',
                        value: profileName,
                      ),
                    if (selectionTitle.isNotEmpty)
                      _ContextLine(
                        label: isRussian ? 'Кастинг' : 'Casting',
                        value: selectionTitle,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasProfile)
                    _ContextIconButton(
                      icon: Icons.badge_rounded,
                      tooltip: isRussian ? 'Открыть анкету' : 'Open profile',
                      onTap: () => context.push(
                        '${Routes.modelPrefix}${summary.profileId}',
                      ),
                    ),
                  if (hasProfile && hasSelection) const SizedBox(width: 6),
                  if (hasSelection)
                    _ContextIconButton(
                      icon: Icons.video_camera_front_rounded,
                      tooltip: isRussian ? 'Открыть кастинг' : 'Open casting',
                      onTap: () => context.push(
                        '${Routes.publicSelectionPrefix}${summary.selectionId}',
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: kBorderColor),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.history_rounded, size: 15, color: kTextMuted),
                SizedBox(width: 6),
                Text(
                  isRussian ? 'ИСТОРИЯ КОНТЕКСТОВ' : 'CONTEXT HISTORY',
                  style: TextStyle(
                    color: kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in history) ...[
              _ContextHistoryRow(entry: entry),
              if (entry != history.last) const SizedBox(height: 7),
            ],
          ],
        ],
      ),
    );
  }
}

class _ContextHistoryRow extends StatelessWidget {
  const _ContextHistoryRow({required this.entry});

  final ChatContextEntry entry;

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final profileName = entry.profileName.trim();
    final selectionTitle = entry.selectionTitle.trim();
    final date = _shortDate(entry.createdAt);
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: BrandTheme.redTop,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                [
                  if (profileName.isNotEmpty) profileName,
                  if (selectionTitle.isNotEmpty) selectionTitle,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              if (date.isNotEmpty)
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.profileId.trim().isNotEmpty)
              _ContextMiniButton(
                icon: Icons.badge_rounded,
                tooltip: isRussian ? 'Открыть анкету' : 'Open profile',
                onTap: () =>
                    context.push('${Routes.modelPrefix}${entry.profileId}'),
              ),
            if (entry.profileId.trim().isNotEmpty &&
                entry.selectionId.trim().isNotEmpty)
              const SizedBox(width: 5),
            if (entry.selectionId.trim().isNotEmpty)
              _ContextMiniButton(
                icon: Icons.video_camera_front_rounded,
                tooltip: isRussian ? 'Открыть кастинг' : 'Open casting',
                onTap: () => context.push(
                  '${Routes.publicSelectionPrefix}${entry.selectionId}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _shortDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }
}

class _ContextMiniButton extends StatelessWidget {
  const _ContextMiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: catalogSearchDecoration(radius: 11),
            child: Icon(icon, color: kTextDark, size: 16),
          ),
        ),
      ),
    );
  }
}

class _ContextLine extends StatelessWidget {
  const _ContextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: kTextMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, letterSpacing: 0),
      ),
    );
  }
}

class _ContextIconButton extends StatelessWidget {
  const _ContextIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: catalogSearchDecoration(radius: 15),
            child: Icon(icon, color: kTextDark, size: 20),
          ),
        ),
      ),
    );
  }
}
