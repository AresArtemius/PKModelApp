import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/entitlements_provider.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'chat_models.dart';
import 'chat_page.dart';
import 'chat_providers.dart';

const double _invitationsDesktopBreakpoint = 900;
const double _invitationsDesktopMaxWidth = 1480;
const double _invitationsDesktopListWidth = 430;
const EdgeInsets _invitationsDesktopPadding = EdgeInsets.fromLTRB(
  32,
  24,
  32,
  28,
);

TextStyle _invitationCommandStyle({
  Color color = kTextDark,
  double size = 16,
  double spacing = 1.6,
  FontWeight weight = FontWeight.w600,
}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

TextStyle _invitationBodyStyle({
  Color color = kTextMuted,
  double size = 15,
  double spacing = 0.2,
  FontWeight weight = FontWeight.w500,
  double height = 1.18,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
    height: height,
  );
}

class InvitationsPage extends ConsumerStatefulWidget {
  const InvitationsPage({super.key});

  @override
  ConsumerState<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends ConsumerState<InvitationsPage> {
  String? _selectedKey;
  String? _selectedChatId;

  String _key(CastingInvitation item) =>
      '${item.selectionId}_${item.profileId}';

  Future<String?> _ensureChat(
    BuildContext context,
    CastingInvitation item,
  ) async {
    final entitlements = await ref.read(accountEntitlementsProvider.future);
    if (!context.mounted) return null;
    if (!entitlements.canUseSelectionChat) {
      await _showModelProRequiredDialog(context);
      return null;
    }
    final chatId = await ref
        .read(chatServiceProvider)
        .ensureSelectionChat(
          selectionId: item.selectionId,
          profileId: item.profileId,
          modelUserId: item.modelUserId,
        );
    if (!context.mounted || chatId.isEmpty) return null;
    return chatId;
  }

  Future<void> _openChatMobile(
    BuildContext context,
    CastingInvitation item,
  ) async {
    final chatId = await _ensureChat(context, item);
    if (!context.mounted || chatId == null) return;
    context.push('${Routes.chatPrefix}$chatId');
  }

  Future<void> _openChatDesktop(
    BuildContext context,
    CastingInvitation item,
  ) async {
    final chatId = await _ensureChat(context, item);
    if (!context.mounted || chatId == null) return;
    setState(() {
      _selectedKey = _key(item);
      _selectedChatId = chatId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final invitations = ref.watch(myInvitationsProvider);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _invitationsDesktopBreakpoint;
    final pagePadding = isDesktop
        ? _invitationsDesktopPadding
        : const EdgeInsets.fromLTRB(16, 18, 16, 24);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: pagePadding,
              child: Column(
                children: [
                  Text(
                    t.invitationsUpper,
                    style: _invitationCommandStyle(
                      size: 22,
                      spacing: 3.8,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: invitations.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _CenteredMessage(
                        title: t.errorUpper,
                        message: AppErrorMapper.message(e, t),
                      ),
                      data: (items) => RefreshIndicator(
                        color: Colors.black,
                        backgroundColor: Colors.white,
                        onRefresh: () async =>
                            ref.invalidate(myInvitationsProvider),
                        child: items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 120),
                                  _CenteredMessage(
                                    title: t.noInvitationsUpper,
                                    message: t.noInvitationsMessage,
                                  ),
                                ],
                              )
                            : isDesktop
                            ? _InvitationsDesktopLayout(
                                items: items,
                                selectedKey: _selectedKey,
                                selectedChatId: _selectedChatId,
                                message: t.consideredForCastingMessage,
                                onSelect: (item) {
                                  setState(() {
                                    _selectedKey = _key(item);
                                    _selectedChatId = null;
                                  });
                                },
                                onDelete: (item) async {
                                  await _deleteInvitationWithConfirmation(
                                    context: context,
                                    ref: ref,
                                    item: item,
                                  );
                                  if (_selectedKey == _key(item)) {
                                    setState(() {
                                      _selectedKey = null;
                                      _selectedChatId = null;
                                    });
                                  }
                                },
                                onOpenChat: (item) =>
                                    _openChatDesktop(context, item),
                                onCloseChat: () =>
                                    setState(() => _selectedChatId = null),
                              )
                            : _InvitationsMobileList(
                                items: items,
                                message: t.consideredForCastingMessage,
                                onDelete: (item) =>
                                    _deleteInvitationWithConfirmation(
                                      context: context,
                                      ref: ref,
                                      item: item,
                                    ),
                                onDismiss: (item) async {
                                  await _hideInvitation(ref: ref, item: item);
                                },
                                onOpenChat: (item) =>
                                    _openChatMobile(context, item),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showModelProRequiredDialog(BuildContext context) async {
  final t = AppLocalizations.of(context)!;
  final goToBilling = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        decoration: catalogDialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.billingUpgradeRequiredTitle,
              textAlign: TextAlign.center,
              style: _invitationCommandStyle(
                size: 21,
                spacing: 1.8,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t.billingUpgradeRequiredMessage,
              textAlign: TextAlign.center,
              style: _invitationBodyStyle(
                color: kTextMuted,
                size: 15,
                spacing: 0.1,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: BrandPillButton(
                    label: MaterialLocalizations.of(context).cancelButtonLabel,
                    style: BrandPillStyle.light,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrandPillButton(
                    label: t.billingUpgradeActionUpper,
                    style: BrandPillStyle.dark,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (goToBilling == true && context.mounted) {
    context.go(Routes.billing);
  }
}

Future<bool> _confirmDeleteInvitation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        decoration: catalogDialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'УДАЛИТЬ ПРИГЛАШЕНИЕ?',
              textAlign: TextAlign.center,
              style: _invitationCommandStyle(
                size: 20,
                spacing: 2,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Карточка исчезнет из списка приглашений. Чат и анкета останутся доступны, если они уже были открыты.',
              textAlign: TextAlign.center,
              style: _invitationBodyStyle(
                color: kTextMuted,
                size: 15,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: BrandPillButton(
                    label: MaterialLocalizations.of(context).cancelButtonLabel,
                    style: BrandPillStyle.light,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrandPillButton(
                    label: 'УДАЛИТЬ',
                    style: BrandPillStyle.dark,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

Future<void> _hideInvitation({
  required WidgetRef ref,
  required CastingInvitation item,
}) async {
  await ref
      .read(chatServiceProvider)
      .hideInvitationForMe(
        selectionId: item.selectionId,
        profileId: item.profileId,
      );
  ref.invalidate(myInvitationsProvider);
}

Future<void> _deleteInvitationWithConfirmation({
  required BuildContext context,
  required WidgetRef ref,
  required CastingInvitation item,
}) async {
  final confirmed = await _confirmDeleteInvitation(context);
  if (!confirmed) return;
  await _hideInvitation(ref: ref, item: item);
}

class _InvitationsMobileList extends StatelessWidget {
  const _InvitationsMobileList({
    required this.items,
    required this.message,
    required this.onDelete,
    required this.onDismiss,
    required this.onOpenChat,
  });

  final List<CastingInvitation> items;
  final String message;
  final Future<void> Function(CastingInvitation item) onDelete;
  final Future<void> Function(CastingInvitation item) onDismiss;
  final Future<void> Function(CastingInvitation item) onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey('${item.selectionId}_${item.profileId}'),
          direction: DismissDirection.endToStart,
          background: const _DeleteBackground(),
          confirmDismiss: (_) async {
            await onDismiss(item);
            return true;
          },
          child: _InvitationCard(
            item: item,
            message: message,
            onDelete: () => onDelete(item),
            onOpenChat: () => onOpenChat(item),
          ),
        );
      },
    );
  }
}

class _InvitationsDesktopLayout extends StatelessWidget {
  const _InvitationsDesktopLayout({
    required this.items,
    required this.selectedKey,
    required this.selectedChatId,
    required this.message,
    required this.onSelect,
    required this.onDelete,
    required this.onOpenChat,
    required this.onCloseChat,
  });

  final List<CastingInvitation> items;
  final String? selectedKey;
  final String? selectedChatId;
  final String message;
  final ValueChanged<CastingInvitation> onSelect;
  final Future<void> Function(CastingInvitation item) onDelete;
  final Future<void> Function(CastingInvitation item) onOpenChat;
  final VoidCallback onCloseChat;

  String _key(CastingInvitation item) =>
      '${item.selectionId}_${item.profileId}';

  @override
  Widget build(BuildContext context) {
    final active = items.firstWhere(
      (item) => _key(item) == selectedKey,
      orElse: () => items.first,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _invitationsDesktopMaxWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _invitationsDesktopListWidth,
              child: _InvitationsDesktopQueuePanel(
                items: items,
                active: active,
                activeChatId: selectedChatId,
                message: message,
                itemKey: _key,
                onSelect: onSelect,
                onDelete: onDelete,
                onOpenChat: onOpenChat,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: selectedChatId == null
                  ? _InvitationDesktopDetails(
                      item: active,
                      message: message,
                      onDelete: () => onDelete(active),
                      onOpenChat: () => onOpenChat(active),
                    )
                  : Container(
                      decoration: catalogCardDecoration(),
                      clipBehavior: Clip.antiAlias,
                      child: ChatPage(
                        key: ValueKey(selectedChatId),
                        chatId: selectedChatId!,
                        embedded: true,
                        onClose: onCloseChat,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationsDesktopQueuePanel extends StatelessWidget {
  const _InvitationsDesktopQueuePanel({
    required this.items,
    required this.active,
    required this.activeChatId,
    required this.message,
    required this.itemKey,
    required this.onSelect,
    required this.onDelete,
    required this.onOpenChat,
  });

  final List<CastingInvitation> items;
  final CastingInvitation active;
  final String? activeChatId;
  final String message;
  final String Function(CastingInvitation item) itemKey;
  final ValueChanged<CastingInvitation> onSelect;
  final Future<void> Function(CastingInvitation item) onDelete;
  final Future<void> Function(CastingInvitation item) onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: catalogCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ДИАЛОГИ И ПРИГЛАШЕНИЯ',
                    style: _invitationCommandStyle(
                      size: 17,
                      spacing: 1.8,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: pillDecoration(isDark: true, radius: 999),
                  child: Text(
                    '${items.length}',
                    style: _invitationCommandStyle(
                      color: Colors.white,
                      size: 12,
                      spacing: 0.8,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Выберите приглашение слева, чтобы открыть карточку или продолжить чат справа.',
              style: _invitationBodyStyle(
                color: kTextMuted,
                size: 14,
                weight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = itemKey(item) == itemKey(active);
                return _InvitationListTile(
                  item: item,
                  message: message,
                  selected: selected,
                  chatOpen: selected && activeChatId != null,
                  onTap: () => onSelect(item),
                  onDelete: () => onDelete(item),
                  onOpenChat: () => onOpenChat(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationListTile extends StatelessWidget {
  const _InvitationListTile({
    required this.item,
    required this.message,
    required this.selected,
    required this.chatOpen,
    required this.onTap,
    required this.onDelete,
    required this.onOpenChat,
  });

  final CastingInvitation item;
  final String message;
  final bool selected;
  final bool chatOpen;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final Future<void> Function() onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: catalogCardDecoration().copyWith(
            border: Border.all(
              color: selected
                  ? BrandTheme.redTop.withValues(alpha: 0.58)
                  : Colors.white.withValues(alpha: 0.78),
              width: selected ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              _InvitationThumb(url: item.accountAvatarUrl, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.accountName.isEmpty ? message : item.accountName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _invitationCommandStyle(
                        color: kTextDark,
                        size: 16,
                        spacing: 0.4,
                        weight: FontWeight.w700,
                      ),
                    ),
                    if (item.contextLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.contextLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _invitationBodyStyle(
                          color: kTextMuted,
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (chatOpen) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_rounded,
                            size: 14,
                            color: BrandTheme.redTop,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'ЧАТ ОТКРЫТ',
                            style: _invitationCommandStyle(
                              color: BrandTheme.redTop,
                              size: 10,
                              spacing: 1.2,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _SmallIconButton(
                    icon: Icons.chat_bubble_rounded,
                    onTap: onOpenChat,
                  ),
                  const SizedBox(height: 8),
                  _SmallIconButton(
                    icon: Icons.delete_outline_rounded,
                    color: BrandTheme.redTop,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationDesktopDetails extends StatelessWidget {
  const _InvitationDesktopDetails({
    required this.item,
    required this.message,
    required this.onDelete,
    required this.onOpenChat,
  });

  final CastingInvitation item;
  final String message;
  final Future<void> Function() onDelete;
  final Future<void> Function() onOpenChat;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      decoration: catalogCardDecoration(),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'КАРТОЧКА ПРИГЛАШЕНИЯ',
            style: _invitationCommandStyle(
              color: kTextMuted,
              size: 13,
              spacing: 2,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InvitationThumb(
                url: item.accountAvatarUrl,
                size: 112,
                radius: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: _invitationCommandStyle(
                        color: BrandTheme.redTop,
                        size: 13,
                        spacing: 1.2,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.accountName.isEmpty ? '—' : item.accountName,
                      style: _invitationCommandStyle(
                        color: kTextDark,
                        size: 28,
                        spacing: 0.4,
                        weight: FontWeight.w800,
                      ),
                    ),
                    if (item.contextLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.contextLabel,
                        style: _invitationBodyStyle(
                          color: kTextMuted,
                          size: 17,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.requestVideoIntro) ...[
            const SizedBox(height: 22),
            _VideoIntroNotice(
              title: t.videoIntroRequiredMessage,
              requirements: item.videoIntroRequirements,
            ),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: kTextMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Здесь отображается выбранное приглашение. Откройте чат, чтобы обсудить детали кастинга без перехода на отдельный экран.',
                    style: _invitationBodyStyle(
                      color: kTextMuted,
                      size: 14,
                      weight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              SizedBox(
                width: 190,
                height: BrandTheme.pillHeight,
                child: BrandPillButton(
                  label: t.deleteUpper,
                  style: BrandPillStyle.light,
                  onTap: onDelete,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: BrandTheme.pillHeight,
                  child: BrandPillButton(
                    label: t.openChatUpper,
                    style: BrandPillStyle.dark,
                    onTap: onOpenChat,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatefulWidget {
  const _SmallIconButton({
    required this.icon,
    required this.onTap,
    this.color = kTextDark,
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final Color color;

  @override
  State<_SmallIconButton> createState() => _SmallIconButtonState();
}

class _SmallIconButtonState extends State<_SmallIconButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _busy ? null : _tap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: catalogSearchDecoration(radius: 15),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(widget.icon, color: widget.color, size: 20),
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.item,
    required this.message,
    required this.onDelete,
    required this.onOpenChat,
  });

  final CastingInvitation item;
  final String message;
  final Future<void> Function() onDelete;
  final Future<void> Function() onOpenChat;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final title = item.accountName.isEmpty ? '—' : item.accountName;
    final subtitle = item.contextLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: catalogCardDecoration(),
      child: Stack(
        children: [
          Positioned(
            top: -6,
            right: -6,
            child: _DeleteInvitationButton(onTap: onDelete),
          ),
          Row(
            children: [
              _InvitationThumb(url: item.accountAvatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 34),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _invitationCommandStyle(
                          color: BrandTheme.redTop,
                          size: 12,
                          spacing: 1.3,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _invitationCommandStyle(
                          color: kTextDark,
                          size: 18,
                          spacing: 0.4,
                          weight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _invitationBodyStyle(
                            color: kTextMuted,
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (item.requestVideoIntro) ...[
                        const SizedBox(height: 8),
                        _VideoIntroNotice(
                          title: t.videoIntroRequiredMessage,
                          requirements: item.videoIntroRequirements,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _OpenChatButton(
                          label: t.openChatUpper,
                          onTap: onOpenChat,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteInvitationButton extends StatefulWidget {
  const _DeleteInvitationButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_DeleteInvitationButton> createState() =>
      _DeleteInvitationButtonState();
}

class _DeleteInvitationButtonState extends State<_DeleteInvitationButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy ? null : _tap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: catalogSearchDecoration(radius: 16),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      BrandTheme.redTop,
                    ),
                  ),
                )
              : const Icon(
                  Icons.delete_outline_rounded,
                  color: BrandTheme.redTop,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardRadius),
        gradient: BrandTheme.redPillGradient,
        boxShadow: BrandTheme.redGlow(strong: true),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }
}

class _OpenChatButton extends StatefulWidget {
  const _OpenChatButton({required this.label, required this.onTap});

  final String label;
  final Future<void> Function() onTap;

  @override
  State<_OpenChatButton> createState() => _OpenChatButtonState();
}

class _OpenChatButtonState extends State<_OpenChatButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _busy ? null : _tap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: pillDecoration(isDark: true, radius: 999),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.label,
                  style: _invitationCommandStyle(
                    color: Colors.white,
                    size: 12,
                    spacing: 1.4,
                    weight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _VideoIntroNotice extends StatelessWidget {
  const _VideoIntroNotice({required this.title, required this.requirements});

  final String title;
  final String requirements;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BrandTheme.redTop.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandTheme.redTop.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.videocam_rounded,
                color: BrandTheme.redTop,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: _invitationCommandStyle(
                    color: BrandTheme.redTop,
                    size: 12,
                    spacing: 1,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (requirements.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              requirements.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _invitationBodyStyle(
                color: kTextDark,
                size: 13,
                weight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvitationThumb extends StatelessWidget {
  const _InvitationThumb({required this.url, this.size = 64, this.radius = 14});

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.trim().isEmpty
            ? Container(
                decoration: catalogPhotoPlaceholderDecoration(),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                maxWidthDiskCache: 320,
                placeholder: (_, _) =>
                    Container(decoration: catalogPhotoPlaceholderDecoration()),
                errorWidget: (_, _, _) => Container(
                  decoration: catalogPhotoPlaceholderDecoration(),
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: _invitationCommandStyle(
                color: kTextDark,
                size: 16,
                spacing: 1.8,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _invitationBodyStyle(
                color: kTextMuted,
                size: 15,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
