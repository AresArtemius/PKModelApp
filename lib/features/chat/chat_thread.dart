part of 'chat_page.dart';

// Step 27: split out of chat_page.dart without behaviour changes.
// Feed pieces: day separators, scroll-to-bottom, selection bar, forward
// picker, action sheets.

class _FeedEntryV2 {
  const _FeedEntryV2._({
    this.message,
    this.dayLabel,
    this.firstInGroup = false,
    this.lastInGroup = false,
  });

  factory _FeedEntryV2.day(String label) => _FeedEntryV2._(dayLabel: label);

  factory _FeedEntryV2.message(
    ChatMessage message, {
    required bool firstInGroup,
    required bool lastInGroup,
  }) => _FeedEntryV2._(
    message: message,
    firstInGroup: firstInGroup,
    lastInGroup: lastInGroup,
  );

  final ChatMessage? message;
  final String? dayLabel;
  final bool firstInGroup;
  final bool lastInGroup;
}

const List<String> _monthsGenitiveRu = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

const List<String> _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _dayLabelV2(DateTime day, bool ru) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(day.year, day.month, day.day);
  final diff = today.difference(date).inDays;
  if (diff == 0) return ru ? 'Сегодня' : 'Today';
  if (diff == 1) return ru ? 'Вчера' : 'Yesterday';
  final month = ru
      ? _monthsGenitiveRu[day.month - 1]
      : _monthsEn[day.month - 1];
  final sameYear = day.year == now.year;
  if (ru) return sameYear ? '${day.day} $month' : '${day.day} $month ${day.year}';
  return sameYear ? '$month ${day.day}' : '$month ${day.day}, ${day.year}';
}

String _timeLabelV2(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class _DaySeparatorV2 extends StatelessWidget {
  const _DaySeparatorV2({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          label.toUpperCase(),
          style: AppText.label.copyWith(color: Tokens.textTertiary),
        ),
      ),
    );
  }
}

class _EmptyConversationV2 extends StatelessWidget {
  const _EmptyConversationV2({required this.title, required this.ru});

  final String title;
  final bool ru;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ru ? 'Здесь пока пусто' : 'Nothing here yet',
            style: AppText.h2.copyWith(color: Tokens.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            ru ? 'Напишите первое сообщение.' : 'Send the first message.',
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(color: Tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Fade + slide for a message that arrived while the feed was open.
class _AppearV2 extends StatelessWidget {
  const _AppearV2({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _ScrollDownButtonV2 extends StatelessWidget {
  const _ScrollDownButtonV2({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.bg,
      shape: const CircleBorder(side: BorderSide(color: Tokens.border)),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: Tokens.ink,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Tokens.accent,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
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

class _LoadOlderMessagesButton extends StatelessWidget {
  const _LoadOlderMessagesButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: GestureDetector(
          onTap: loading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: pillDecoration(isDark: false, radius: 18),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isRussian ? 'ЗАГРУЗИТЬ СТАРЫЕ' : 'LOAD OLDER',
                    style: const TextStyle(
                      color: kTextDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ForwardChatPickerSheet extends StatelessWidget {
  const _ForwardChatPickerSheet({required this.chats, required this.count});

  final List<ChatListItem> chats;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: height,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: kTextDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRussian ? 'Переслать в чат' : 'Forward to chat',
                      style: _chatSheetTitleStyle(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRussian
                          ? 'Сообщений: $count'
                          : 'Messages selected: $count',
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final chat = chats[index];
                final preview = chat.lastMessage.trim().isEmpty
                    ? (isRussian ? 'Диалог создан' : 'Chat created')
                    : chat.lastMessage.trim();
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(chat),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: catalogCardDecoration().copyWith(
                        boxShadow: const [],
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Row(
                        children: [
                          _ChatAvatar(avatarUrl: chat.photoUrl),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chat.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kTextDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (chat.contextLabel.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    chat.contextLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: kTextMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kTextMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: kTextMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _chatSheetTitleStyle() {
  return const TextStyle(
    color: kTextDark,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
}

class _MessageSelectionBar extends StatelessWidget {
  const _MessageSelectionBar({
    required this.count,
    required this.singleMessage,
    required this.onCancel,
    required this.onReply,
    required this.onForward,
    required this.onTogglePin,
    required this.onDelete,
    this.flat = false,
  });

  final int count;
  final ChatMessage? singleMessage;
  final VoidCallback onCancel;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;

  /// v2: white bar with a hairline, sentence-case label, text actions.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final pinTooltip = singleMessage?.isPinned == true
        ? (isRussian ? 'Открепить' : 'Unpin')
        : (isRussian ? 'Закрепить' : 'Pin');
    if (flat) {
      Widget action(IconData icon, String label, VoidCallback? onTap,
          {bool danger = false}) {
        return TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: danger ? Tokens.danger : Tokens.ink,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label, style: AppText.button),
        );
      }

      final selectedLabel = isRussian
          ? _pluralRu(count, 'Выбрано $count сообщение',
              'Выбрано $count сообщения', 'Выбрано $count сообщений')
          : '$count selected';
      return Container(
        height: 48,
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
        decoration: BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: Tokens.border),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: isRussian ? 'Снять выделение' : 'Clear selection',
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 20),
              style: IconButton.styleFrom(foregroundColor: Tokens.ink),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(selectedLabel, style: AppText.smallStrong),
            ),
            if (onReply != null)
              action(Icons.reply_rounded,
                  isRussian ? 'Ответить' : 'Reply', onReply),
            if (onForward != null)
              action(Icons.forward_rounded,
                  isRussian ? 'Переслать' : 'Forward', onForward),
            if (onTogglePin != null)
              action(
                singleMessage?.isPinned == true
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                pinTooltip,
                onTogglePin,
              ),
            action(Icons.delete_outline_rounded,
                isRussian ? 'Удалить' : 'Delete', onDelete,
                danger: true),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: kTextDark,
        borderRadius: BorderRadius.circular(22),
        boxShadow: BrandTheme.basePillShadow(isDark: true),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              isRussian
                  ? 'ВЫБРАНО СООБЩЕНИЙ: $count'
                  : 'MESSAGES SELECTED: $count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (onReply != null)
            Tooltip(
              message: isRussian ? 'Ответить' : 'Reply',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, color: Colors.white),
              ),
            ),
          if (onForward != null)
            Tooltip(
              message: isRussian ? 'Переслать' : 'Forward',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onForward,
                icon: const Icon(Icons.forward_rounded, color: Colors.white),
              ),
            ),
          if (onTogglePin != null)
            Tooltip(
              message: pinTooltip,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onTogglePin,
                icon: Icon(
                  singleMessage?.isPinned == true
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_rounded,
              color: onDelete == null
                  ? Colors.white.withValues(alpha: 0.28)
                  : BrandTheme.redTop,
            ),
          ),
        ],
      ),
    );
  }
}

String _pluralRu(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: profileCardDecoration(),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _ActionSheetTile extends StatelessWidget {
  const _ActionSheetTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BrandTheme.redTop : kTextDark;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
      onTap: onTap,
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active ? kTextDark : Colors.white.withValues(alpha: 0.76),
          border: Border.all(
            color: active ? BrandTheme.redTop : kBorderColor,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Icon(icon, color: active ? Colors.white : kTextDark, size: 22),
      ),
    );
  }
}
