part of 'chat_page.dart';

// Step 27: split out of chat_page.dart without behaviour changes.
// Message bubbles of a conversation: the v2 (web) bubble, the native
// bubble, media, quotes, reactions and the body parser.

const List<String> _quickReactionsV2 = ['👍', '❤️', '🔥', '👏', '😂', '😮'];

/// Telegram-style bubble: mine on the right (ink), theirs on the left
/// (light), time and ✓/✓✓ inside the bubble, reactions beneath, a hover
/// toolbar with reply / react, and a right-click context menu.
class _BubbleV2 extends StatefulWidget {
  const _BubbleV2({
    super.key,
    required this.message,
    required this.mine,
    this.avatarUrl = '',
    required this.firstInGroup,
    required this.lastInGroup,
    required this.maxWidth,
    required this.reactions,
    required this.currentUserId,
    required this.selected,
    required this.selectionMode,
    required this.searchQuery,
    required this.activeSearchResult,
    required this.onMediaTap,
    required this.onVoiceListened,
    required this.onTap,
    required this.onLongPress,
    required this.onContextMenu,
    required this.onReact,
    required this.onReply,
    this.quoteAuthor = '',
    this.onQuoteTap,
  });

  final ChatMessage message;
  final bool mine;
  final String avatarUrl;
  final bool firstInGroup;
  final bool lastInGroup;
  final double maxWidth;
  final List<ChatReaction> reactions;
  final String currentUserId;
  final bool selected;
  final bool selectionMode;
  final String searchQuery;
  final bool activeSearchResult;
  final VoidCallback onMediaTap;
  final VoidCallback onVoiceListened;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onContextMenu;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;

  /// Step 31: who wrote the quoted message («Вы» / the other party) and
  /// the jump to it.
  final String quoteAuthor;
  final VoidCallback? onQuoteTap;

  @override
  State<_BubbleV2> createState() => _BubbleV2State();
}

class _BubbleV2State extends State<_BubbleV2> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final mine = widget.mine;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final parsedBody = _ParsedMessageBody.from(message.body);
    final visibleBody =
        message.hasMedia &&
            ((message.isImage && parsedBody.body.trim() == 'Фото') ||
                (message.isVideo && parsedBody.body.trim() == 'Видео') ||
                (message.isAudio &&
                    parsedBody.body.trim() == 'Голосовое сообщение'))
        ? ''
        : parsedBody.body.trim();
    final textColor = mine ? Colors.white : Tokens.text;
    final metaColor = mine
        ? Colors.white.withValues(alpha: 0.55)
        : Tokens.textTertiary;
    final highlight = widget.activeSearchResult || widget.selected;

    const big = Radius.circular(16);
    const small = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: !mine && widget.lastInGroup ? small : big,
      bottomRight: mine && widget.lastInGroup ? small : big,
    );

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isPinned) ...[
          Icon(Icons.push_pin_rounded, size: 12, color: metaColor),
          const SizedBox(width: 4),
        ],
        if (message.editedAt != null) ...[
          Text(
            ru ? 'изменено' : 'edited',
            style: TextStyle(fontSize: 11, color: metaColor, height: 1),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _timeLabelV2(message.createdAt),
          style: TextStyle(fontSize: 11, color: metaColor, height: 1),
        ),
        if (mine) ...[
          const SizedBox(width: 4),
          Icon(
            message.metadata['pending'] == true
                ? Icons.schedule_rounded
                : message.isDelivered
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14,
            color: message.isRead ? const Color(0xFFFF6B6B) : metaColor,
          ),
        ],
      ],
    );

    final forwarded = message.metadata['forwarded'] == true;
    final hasQuote = parsedBody.replyQuote.isNotEmpty;
    final isPicture = message.hasMedia && (message.isImage || message.isVideo);
    // A message that is only a few emoji is shown big, without a bubble.
    final emojiOnly =
        !message.hasMedia &&
        !hasQuote &&
        !forwarded &&
        _isEmojiOnly(visibleBody);
    // A picture without text is the bubble itself: no padding, time on top.
    final pictureOnly =
        isPicture && visibleBody.isEmpty && !hasQuote && !forwarded;

    final mediaWidget = message.hasMedia
        ? _MessageMedia(
            message: message,
            onTap: widget.onMediaTap,
            showReadStatus: false,
            onVoiceListened: widget.onVoiceListened,
            flat: true,
            mine: mine,
          )
        : null;

    Widget bubble;
    if (emojiOnly) {
      bubble = Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        decoration: highlight
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Tokens.accent, width: 2),
              )
            : null,
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(visibleBody, style: const TextStyle(fontSize: 44, height: 1.2)),
            const SizedBox(height: 2),
            _BubbleMeta(message: message, mine: mine, color: Tokens.textTertiary),
          ],
        ),
      );
    } else if (pictureOnly) {
      bubble = Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: highlight
              ? Border.all(color: Tokens.accent, width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            mediaWidget!,
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: _BubbleMeta(
                  message: message,
                  mine: mine,
                  color: Colors.white.withValues(alpha: 0.9),
                  readColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      bubble = Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        padding: isPicture
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(14, 9, 12, 8),
        decoration: BoxDecoration(
          color: mine ? Tokens.ink : Tokens.bg,
          borderRadius: radius,
          border: highlight
              ? Border.all(color: Tokens.accent, width: 2)
              : mine
              ? null
              : Border.all(color: Tokens.border),
        ),
        clipBehavior: isPicture ? Clip.antiAlias : Clip.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPicture) ...[
              if (forwarded || hasQuote)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (forwarded) _ForwardedLabel(mine: mine),
                      if (forwarded && hasQuote) const SizedBox(height: 6),
                      if (hasQuote)
                        _ReplyPreview(
                          text: parsedBody.replyQuote,
                          mine: mine,
                          flat: true,
                          author: widget.quoteAuthor,
                          onTap: widget.onQuoteTap,
                        ),
                    ],
                  ),
                ),
              mediaWidget!,
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (visibleBody.isNotEmpty)
                      _HighlightedMessageText(
                        text: visibleBody,
                        query: widget.searchQuery,
                        selectable: false,
                        style: AppText.body.copyWith(
                          color: textColor,
                          height: 1.45,
                          fontSize: 15.5,
                        ),
                        highlightColor: mine
                            ? Colors.white.withValues(alpha: 0.26)
                            : Tokens.accent.withValues(alpha: 0.18),
                      ),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight, child: meta),
                  ],
                ),
              ),
            ] else ...[
              if (forwarded) ...[
                _ForwardedLabel(mine: mine),
                const SizedBox(height: 6),
              ],
              if (hasQuote) ...[
                _ReplyPreview(
                  text: parsedBody.replyQuote,
                  mine: mine,
                  flat: true,
                  author: widget.quoteAuthor,
                  onTap: widget.onQuoteTap,
                ),
                const SizedBox(height: 6),
              ],
              if (mediaWidget != null) ...[
                mediaWidget,
                if (visibleBody.isNotEmpty) const SizedBox(height: 8),
              ],
              if (visibleBody.isNotEmpty)
                _HighlightedMessageText(
                  text: visibleBody,
                  query: widget.searchQuery,
                  selectable: false,
                  style: AppText.body.copyWith(
                    color: textColor,
                    height: 1.45,
                    fontSize: 15.5,
                  ),
                  highlightColor: mine
                      ? Colors.white.withValues(alpha: 0.26)
                      : Tokens.accent.withValues(alpha: 0.18),
                ),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: meta),
            ],
          ],
        ),
      );
    }

    final myReaction = widget.reactions
        .where((r) => r.userId == widget.currentUserId)
        .map((r) => r.emoji)
        .firstOrNull;
    final reactionCounts = <String, int>{};
    for (final r in widget.reactions) {
      reactionCounts[r.emoji] = (reactionCounts[r.emoji] ?? 0) + 1;
    }

    final pending = message.metadata['pending'] == true;
    final narrowScreen = MediaQuery.sizeOf(context).width < 600;
    final hoverBar = narrowScreen
        ? const SizedBox.shrink()
        : AnimatedOpacity(
      duration: Tokens.fast,
      opacity: _hovered && !widget.selectionMode && !pending ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_hovered || widget.selectionMode || pending,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BubbleHoverButton(
              icon: Icons.reply_rounded,
              tooltip: ru ? 'Ответить' : 'Reply',
              onTap: widget.onReply,
            ),
            const SizedBox(width: 4),
            _ReactionPickerButton(
              tooltip: ru ? 'Реакция' : 'React',
              current: myReaction,
              onPick: widget.onReact,
            ),
            const SizedBox(width: 4),
            _BubbleHoverButton(
              icon: Icons.more_horiz_rounded,
              tooltip: ru ? 'Ещё' : 'More',
              onTapDown: widget.onContextMenu,
            ),
          ],
        ),
      ),
    );

    final column = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onSecondaryTapDown: (details) =>
              widget.onContextMenu(details.globalPosition),
          child: bubble,
        ),
        if (reactionCounts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final entry in reactionCounts.entries)
                _ReactionChipV2(
                  emoji: entry.key,
                  count: entry.value,
                  mine: myReaction == entry.key,
                  onTap: () => widget.onReact(entry.key),
                ),
            ],
          ),
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: EdgeInsets.only(
          top: widget.firstInGroup ? 8 : 2,
          bottom: widget.lastInGroup ? 6 : 0,
        ),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: mine
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.end,
          children: mine
              ? [
                  hoverBar,
                  const SizedBox(width: 8),
                  if (widget.selected) ...[
                    const _SelectedMarkV2(),
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: column),
                ]
              : [
                  if (widget.selected) ...[
                    const _SelectedMarkV2(),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: widget.lastInGroup
                        ? _V2SmallAvatar(url: widget.avatarUrl)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: column),
                  const SizedBox(width: 8),
                  hoverBar,
                ],
        ),
      ),
    );
  }
}

/// True for a message made of one to three emoji (and nothing else).
/// Checked by code point ranges rather than a regular expression so the
/// analyzer's regexp lint and older engines are not involved.
bool _isEmojiOnly(String text) {
  final clean = text.trim();
  if (clean.isEmpty || clean.length > 32) return false;
  for (final rune in clean.runes) {
    if (!_isEmojiRune(rune)) return false;
  }
  final graphemes = clean.replaceAll(RegExp(r'\s'), '').characters.length;
  return graphemes >= 1 && graphemes <= 3;
}

bool _isEmojiRune(int c) {
  // Whitespace between emoji.
  if (c == 0x20 || c == 0x0A || c == 0x09) return true;
  // Pieces that build emoji: variation selector, joiner, keycap, skin
  // tones, regional indicators (flags), tag letters.
  if (c == 0xFE0F || c == 0x200D || c == 0x20E3) return true;
  if (c >= 0x1F3FB && c <= 0x1F3FF) return true;
  if (c >= 0x1F1E6 && c <= 0x1F1FF) return true;
  if (c >= 0xE0020 && c <= 0xE007F) return true;
  // Pictographic blocks.
  if (c >= 0x1F000 && c <= 0x1FAFF) return true;
  if (c >= 0x2600 && c <= 0x27BF) return true;
  if (c >= 0x2B00 && c <= 0x2BFF) return true;
  if (c >= 0x2300 && c <= 0x23FF) return true;
  if (c >= 0x2190 && c <= 0x21FF) return true;
  if (c >= 0x25AA && c <= 0x25FE) return true;
  const singles = {
    0x00A9, 0x00AE, 0x203C, 0x2049, 0x2122, 0x2139, 0x24C2, 0x2934, 0x2935,
    0x3030, 0x303D, 0x3297, 0x3299,
  };
  return singles.contains(c);
}

/// Time + edited mark + ✓ / ✓✓ used inside and under bubbles.
class _BubbleMeta extends StatelessWidget {
  const _BubbleMeta({
    required this.message,
    required this.mine,
    required this.color,
    this.readColor,
  });

  final ChatMessage message;
  final bool mine;
  final Color color;
  final Color? readColor;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isPinned) ...[
          Icon(Icons.push_pin_rounded, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        if (message.editedAt != null) ...[
          Text(
            ru ? 'изменено' : 'edited',
            style: TextStyle(fontSize: 11, color: color, height: 1),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _timeLabelV2(message.createdAt),
          style: TextStyle(fontSize: 11, color: color, height: 1),
        ),
        if (mine) ...[
          const SizedBox(width: 4),
          Icon(
            message.metadata['pending'] == true
                ? Icons.schedule_rounded
                : message.isDelivered
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14,
            color: message.isRead ? (readColor ?? Tokens.ink) : color,
          ),
        ],
      ],
    );
  }
}

class _V2SmallAvatar extends StatelessWidget {
  const _V2SmallAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final clean = url.trim();
    return ClipOval(
      child: clean.isEmpty
          ? const ColoredBox(
              color: Tokens.surfaceAlt,
              child: Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Tokens.textTertiary,
              ),
            )
          : CachedNetworkImage(
              imageUrl: clean,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.6),
              memCacheWidth: 128,
              placeholder: (_, _) =>
                  const ColoredBox(color: Tokens.surfaceAlt),
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: Tokens.surfaceAlt),
            ),
    );
  }
}

class _SelectedMarkV2 extends StatelessWidget {
  const _SelectedMarkV2();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Tokens.accent,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
    );
  }
}

class _BubbleHoverButton extends StatelessWidget {
  const _BubbleHoverButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onTapDown,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onTapDown;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Tokens.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Tokens.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap ?? () {},
          onTapDown: onTapDown == null
              ? null
              : (details) => onTapDown!(details.globalPosition),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 16, color: Tokens.ink),
          ),
        ),
      ),
    );
  }
}

class _ReactionPickerButton extends StatelessWidget {
  const _ReactionPickerButton({
    required this.tooltip,
    required this.current,
    required this.onPick,
  });

  final String tooltip;
  final String? current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onPick,
      color: Tokens.bg,
      elevation: 6,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: Tokens.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final emoji in _quickReactionsV2)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).pop(emoji),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: current == emoji
                          ? Tokens.surfaceAlt
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
        ),
      ],
      child: Material(
        color: Tokens.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Tokens.border),
        ),
        child: const SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            Icons.add_reaction_outlined,
            size: 16,
            color: Tokens.ink,
          ),
        ),
      ),
    );
  }
}

class _ReactionChipV2 extends StatelessWidget {
  const _ReactionChipV2({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: mine ? Tokens.ink : Tokens.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: mine ? Tokens.ink : Tokens.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14, height: 1.2)),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: mine ? Colors.white : Tokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.avatarUrl,
    required this.showReadStatus,
    required this.onMediaTap,
    required this.onVoiceListened,
    required this.selected,
    required this.searchQuery,
    required this.activeSearchResult,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTap,
  });

  final ChatMessage message;
  final bool mine;
  final String avatarUrl;
  final bool showReadStatus;
  final bool selected;
  final String searchQuery;
  final bool activeSearchResult;
  final VoidCallback onMediaTap;
  final VoidCallback onVoiceListened;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = viewportWidth >= 800
        ? math.min(640.0, viewportWidth * 0.56)
        : math.min(420.0, viewportWidth * 0.78);
    final parsedBody = _ParsedMessageBody.from(message.body);
    final visibleBody =
        message.hasMedia &&
            ((message.isImage && parsedBody.body.trim() == 'Фото') ||
                (message.isVideo && parsedBody.body.trim() == 'Видео') ||
                (message.isAudio &&
                    parsedBody.body.trim() == 'Голосовое сообщение'))
        ? ''
        : parsedBody.body.trim();
    final bubble = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: activeSearchResult
              ? BrandTheme.redTop.withValues(alpha: mine ? 0.92 : 0.08)
              : mine
              ? kTextDark
              : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected || activeSearchResult
                ? BrandTheme.redTop
                : kBorderColor,
            width: selected || activeSearchResult ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.metadata['forwarded'] == true) ...[
              _ForwardedLabel(mine: mine),
              const SizedBox(height: 6),
            ],
            if (parsedBody.replyQuote.isNotEmpty) ...[
              _ReplyPreview(text: parsedBody.replyQuote, mine: mine),
              const SizedBox(height: 8),
            ],
            if (message.hasMedia) ...[
              _MessageMedia(
                message: message,
                onTap: onMediaTap,
                showReadStatus: showReadStatus,
                onVoiceListened: onVoiceListened,
              ),
              if (visibleBody.isNotEmpty) const SizedBox(height: 8),
            ],
            if (visibleBody.isNotEmpty)
              _HighlightedMessageText(
                text: visibleBody,
                query: searchQuery,
                style: TextStyle(
                  color: mine ? Colors.white : kTextDark,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                highlightColor: mine
                    ? Colors.white.withValues(alpha: 0.22)
                    : BrandTheme.redTop.withValues(alpha: 0.18),
              ),
            if (message.editedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                        'ru'
                    ? 'изменено'
                    : 'edited',
                style: TextStyle(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.62)
                      : kTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final bubbleContent = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            if (selected)
              Positioned(
                top: -7,
                right: mine ? -7 : null,
                left: mine ? null : -7,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: BrandTheme.redTop,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            if (message.isPinned)
              Positioned(
                top: -7,
                right: mine ? null : -7,
                left: mine ? -7 : null,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandTheme.redTop, width: 2),
                  ),
                  child: const Icon(
                    Icons.push_pin_rounded,
                    size: 13,
                    color: BrandTheme.redTop,
                  ),
                ),
              ),
          ],
        ),
        if (showReadStatus && !message.isAudio)
          _MessageReadStatus(readAt: message.readAt),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: mine
            ? [
                bubbleContent,
                const SizedBox(width: 8),
                _ChatAvatar(avatarUrl: avatarUrl),
              ]
            : [
                _ChatAvatar(avatarUrl: avatarUrl),
                const SizedBox(width: 8),
                bubbleContent,
              ],
      ),
    );
  }
}

class _ForwardedLabel extends StatelessWidget {
  const _ForwardedLabel({required this.mine});

  final bool mine;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final color = mine
        ? Colors.white.withValues(alpha: 0.6)
        : Tokens.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.reply_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          isRussian ? 'Пересланное сообщение' : 'Forwarded message',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _ParsedMessageBody {
  const _ParsedMessageBody({required this.replyQuote, required this.body});

  final String replyQuote;
  final String body;

  factory _ParsedMessageBody.from(String raw) {
    final text = raw.trim();
    if (!text.startsWith(_replyPrefix)) {
      return _ParsedMessageBody(replyQuote: '', body: text);
    }
    final withoutPrefix = text.substring(_replyPrefix.length);
    final separatorIndex = withoutPrefix.indexOf(_replySeparator);
    if (separatorIndex <= 0) {
      return _ParsedMessageBody(replyQuote: '', body: text);
    }
    return _ParsedMessageBody(
      replyQuote: withoutPrefix.substring(0, separatorIndex).trim(),
      body: withoutPrefix
          .substring(separatorIndex + _replySeparator.length)
          .trim(),
    );
  }
}

class _HighlightedMessageText extends StatelessWidget {
  const _HighlightedMessageText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
    this.selectable = true,
  });

  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;

  /// False when an ancestor already provides a [SelectionArea] (the v2
  /// feed wraps the whole list in one instead of one per bubble).
  final bool selectable;

  Widget _wrap(Widget child) =>
      selectable ? SelectionArea(child: child) : child;

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || text.isEmpty) {
      return _wrap(Text(text, style: style));
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = cleanQuery.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;

    while (cursor < text.length) {
      final index = lowerText.indexOf(lowerQuery, cursor);
      if (index < 0) break;
      if (index > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: style.copyWith(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      cursor = index + lowerQuery.length;
    }

    if (spans.isEmpty) {
      return _wrap(Text(text, style: style));
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return _wrap(Text.rich(TextSpan(style: style, children: spans)));
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.text,
    required this.mine,
    this.flat = false,
    this.author = '',
    this.onTap,
  });

  final String text;
  final bool mine;

  /// v2: a compact quote that hugs its text instead of stretching the
  /// bubble to its maximum width.
  final bool flat;

  /// Step 31: the quoted message's author, shown above the text, and the
  /// click that scrolls to the original.
  final String author;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      final quote = Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withValues(alpha: 0.12)
              : Tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: mine ? Colors.white.withValues(alpha: 0.8) : Tokens.accent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (author.isNotEmpty)
              Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mine ? Colors.white : Tokens.accent,
                ),
              ),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 13,
                color: mine
                    ? Colors.white.withValues(alpha: 0.8)
                    : Tokens.textSecondary,
              ),
            ),
          ],
        ),
      );
      if (onTap == null) return quote;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: quote,
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.14)
            : kTextDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: mine ? Colors.white : BrandTheme.redTop,
            width: 3,
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: mine ? Colors.white.withValues(alpha: 0.78) : kTextMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

class _MessageReadStatus extends StatelessWidget {
  const _MessageReadStatus({required this.readAt});

  final DateTime? readAt;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final read = readAt != null;
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            read ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15,
            color: read ? BrandTheme.redTop : kTextMuted,
          ),
          const SizedBox(width: 4),
          Text(
            read
                ? (isRussian ? 'прочитано' : 'read')
                : (isRussian ? 'доставлено' : 'delivered'),
            style: TextStyle(
              color: read ? BrandTheme.redTop : kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMedia extends StatelessWidget {
  const _MessageMedia({
    required this.message,
    required this.onTap,
    required this.showReadStatus,
    required this.onVoiceListened,
    this.flat = false,
    this.mine = false,
  });

  final ChatMessage message;
  final VoidCallback onTap;
  final bool showReadStatus;
  final VoidCallback onVoiceListened;
  final bool flat;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (message.isFile) {
      return _MessageFileCard(message: message, onTap: onTap);
    }
    if (message.isAudio) {
      return _AudioMessagePlayer(
        message: message,
        showReadStatus: showReadStatus,
        onListened: onVoiceListened,
        flat: flat,
        mine: mine,
      );
    }
    final imageUrl = message.mediaThumbnailUrl.isNotEmpty
        ? message.mediaThumbnailUrl
        : message.mediaUrl;
    if (flat) {
      // v2: the picture keeps its own proportions, up to 420×480.
      return GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 160,
            maxWidth: 420,
            maxHeight: 480,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ProtectedCachedNetworkImage(
                source: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 900,
                maxWidthDiskCache: 1200,
                placeholder: const SizedBox(
                  width: 240,
                  height: 180,
                  child: ColoredBox(color: Color(0x14000000)),
                ),
                errorWidget: const SizedBox(
                  width: 240,
                  height: 180,
                  child: ColoredBox(
                    color: Color(0x14000000),
                    child: Icon(Icons.broken_image_rounded),
                  ),
                ),
              ),
              if (message.isVideo)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 220,
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ProtectedCachedNetworkImage(
                source: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 520,
                maxWidthDiskCache: 900,
                placeholder: Container(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                errorWidget: Container(
                  color: Colors.white.withValues(alpha: 0.18),
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
              if (message.isVideo)
                Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageFileCard extends StatelessWidget {
  const _MessageFileCard({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = _formatFileSize(message.fileSize);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kTextDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insert_drive_file_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileDisplayName.isEmpty
                          ? 'Файл'
                          : message.fileDisplayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    if (size.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        size,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: kTextDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: avatarUrl.trim().isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 19)
          : ClipOval(
              child: SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  memCacheWidth: 160,
                  maxWidthDiskCache: 220,
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: kTextDark,
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
