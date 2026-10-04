import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

/// v2 (web): full-width page — hairline list of invitations on the left,
/// the selected invitation on the right; chat opens on the chats page.
const bool _invitationsV2 = kIsWeb;
const double _invitationsV2ListWidth = 400;
const double _invitationsV2Breakpoint = 960;

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
    context.push(Routes.chatLocation(chatId));
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

  Future<void> _openChatV2(BuildContext context, CastingInvitation item) async {
    final chatId = await _ensureChat(context, item);
    if (!context.mounted || chatId == null) return;
    context.push(Routes.chatLocation(chatId));
  }

  Future<void> _deleteV2(BuildContext context, CastingInvitation item) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'Удалить приглашение?' : 'Delete invitation?'),
        content: Text(
          ru
              ? 'Приглашение исчезнет из списка. Чат и анкета останутся доступны, если они уже были открыты.'
              : 'The invitation will disappear from the list. The chat and profile remain available if already opened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ru ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
            child: Text(ru ? 'Удалить' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _hideInvitation(ref: ref, item: item);
    if (_selectedKey == _key(item) && mounted) {
      setState(() => _selectedKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final invitations = ref.watch(myInvitationsProvider);
    if (_invitationsV2) {
      return _InvitationsPageV2(
        async: invitations,
        selectedKey: _selectedKey,
        keyOf: _key,
        onSelect: (item) => setState(
          () => _selectedKey = item == null ? null : _key(item),
        ),
        onRefresh: () => ref.invalidate(myInvitationsProvider),
        onOpenChat: (item) => _openChatV2(context, item),
        onDelete: (item) => _deleteV2(context, item),
      );
    }
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
  final ru = Localizations.localeOf(context).languageCode == 'ru';
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
              ru ? 'УДАЛИТЬ ПРИГЛАШЕНИЕ?' : 'DELETE INVITATION?',
              textAlign: TextAlign.center,
              style: _invitationCommandStyle(
                size: 20,
                spacing: 2,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ru
                  ? 'Карточка исчезнет из списка приглашений. Чат и анкета останутся доступны, если они уже были открыты.'
                  : 'The card will disappear from invitations. The chat and profile will remain available if already opened.',
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
                    label: ru ? 'УДАЛИТЬ' : 'DELETE',
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
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
                    ru ? 'ДИАЛОГИ И ПРИГЛАШЕНИЯ' : 'CHATS AND INVITATIONS',
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
              ru
                  ? 'Выберите приглашение слева, чтобы открыть карточку или продолжить чат справа.'
                  : 'Select an invitation on the left to view its card or continue the chat on the right.',
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
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
                            ru ? 'ЧАТ ОТКРЫТ' : 'CHAT OPEN',
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    return Container(
      decoration: catalogCardDecoration(),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ru ? 'КАРТОЧКА ПРИГЛАШЕНИЯ' : 'INVITATION DETAILS',
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
                    ru
                        ? 'Здесь отображается выбранное приглашение. Откройте чат, чтобы обсудить детали кастинга без перехода на отдельный экран.'
                        : 'The selected invitation is shown here. Open the chat to discuss casting details without leaving this screen.',
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


// ---------------------------------------------------------------------------
// v2 (web)
// ---------------------------------------------------------------------------

class _InvitationsPageV2 extends StatelessWidget {
  const _InvitationsPageV2({
    required this.async,
    required this.selectedKey,
    required this.keyOf,
    required this.onSelect,
    required this.onRefresh,
    required this.onOpenChat,
    required this.onDelete,
  });

  final AsyncValue<List<CastingInvitation>> async;
  final String? selectedKey;
  final String Function(CastingInvitation item) keyOf;
  final ValueChanged<CastingInvitation?> onSelect;
  final VoidCallback onRefresh;
  final Future<void> Function(CastingInvitation item) onOpenChat;
  final Future<void> Function(CastingInvitation item) onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final wide = MediaQuery.sizeOf(context).width >= _invitationsV2Breakpoint;
    final items = async.valueOrNull ?? const <CastingInvitation>[];
    CastingInvitation? selected;
    for (final item in items) {
      if (keyOf(item) == selectedKey) {
        selected = item;
        break;
      }
    }
    if (wide && selected == null && items.isNotEmpty) selected = items.first;
    final current = selected;

    final gutter = wide ? 24.0 : 16.0;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(gutter, wide ? 28 : 20, gutter, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ru ? 'Приглашения' : 'Invitations',
                  style: AppText.h1.copyWith(fontSize: wide ? 32 : 28),
                ),
                const SizedBox(height: 4),
                Text(
                  items.isEmpty
                      ? (ru ? 'Пока ничего нет' : 'Nothing yet')
                      : (ru
                            ? _pluralRuInvitations(
                                items.length,
                                '${items.length} приглашение',
                                '${items.length} приглашения',
                                '${items.length} приглашений',
                              )
                            : '${items.length} invitations'),
                  style: AppText.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: ru ? 'Обновить' : 'Refresh',
            onPressed: onRefresh,
            style: IconButton.styleFrom(foregroundColor: Tokens.textSecondary),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );

    Widget list = async.when(
      loading: () => Padding(
        padding: EdgeInsets.all(gutter),
        child: const SkeletonList(rows: 6),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(gutter),
        child: Text(
          AppErrorMapper.message(e, t),
          style: AppText.small.copyWith(color: Tokens.danger),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ru ? 'Приглашений нет' : 'No invitations',
                  style: AppText.h2.copyWith(color: Tokens.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  t.noInvitationsMessage,
                  style: AppText.small.copyWith(color: Tokens.textTertiary),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              _InvitationRowV2(
                item: item,
                gutter: gutter,
                selected: wide && current != null &&
                    keyOf(item) == keyOf(current),
                onTap: () => onSelect(item),
                onDelete: () => onDelete(item),
              ),
          ],
        );
      },
    );

    if (!wide) {
      if (current != null) {
        return Scaffold(
          backgroundColor: Tokens.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => onSelect(null),
                        style: IconButton.styleFrom(
                          foregroundColor: Tokens.textSecondary,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Text(
                        ru ? 'Приглашения' : 'Invitations',
                        style: AppText.smallStrong,
                      ),
                    ],
                  ),
                ),
                _InvitationDetailsV2(
                  item: current,
                  gutter: 16,
                  onOpenChat: () => onOpenChat(current),
                  onDelete: () => onDelete(current),
                ),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Tokens.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [header, list],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _invitationsV2ListWidth,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [header, list],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Tokens.border),
          Expanded(
            child: current == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    child: _InvitationDetailsV2(
                      item: current,
                      gutter: 40,
                      onOpenChat: () => onOpenChat(current),
                      onDelete: () => onDelete(current),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _pluralRuInvitations(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

String _invitationDateV2(DateTime? at, bool ru) {
  if (at == null) return '';
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (diff == 0) return '$hh:$mm';
  if (diff == 1) return ru ? 'вчера' : 'yesterday';
  const monthsRu = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
  const monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = ru ? monthsRu[local.month - 1] : monthsEn[local.month - 1];
  final sameYear = local.year == now.year;
  if (ru) return sameYear ? '${local.day} $month' : '${local.day} $month ${local.year}';
  return sameYear ? '$month ${local.day}' : '$month ${local.day}, ${local.year}';
}

String _invitationTitleV2(CastingInvitation item, bool ru) {
  final name = item.accountName.trim();
  if (name.isNotEmpty) return name;
  final title = item.selectionTitle.trim();
  if (title.isNotEmpty) return title;
  return ru ? 'Кастинг' : 'Casting';
}

String _invitationSubtitleV2(CastingInvitation item, bool ru) {
  final context = item.contextLabel.trim();
  if (context.isNotEmpty) return context;
  final title = item.selectionTitle.trim();
  if (title.isNotEmpty) return title;
  return ru ? 'Вас рассматривают на кастинг' : 'You are being considered';
}

class _InvitationAvatarV2 extends StatelessWidget {
  const _InvitationAvatarV2({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clean = url.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: SizedBox(
        width: size,
        height: size,
        child: clean.isEmpty
            ? ColoredBox(
                color: Tokens.surfaceAlt,
                child: Icon(
                  Icons.movie_outlined,
                  size: size * 0.45,
                  color: Tokens.textTertiary,
                ),
              )
            : CachedNetworkImage(
                imageUrl: clean,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.6),
                memCacheWidth: 240,
                maxWidthDiskCache: 480,
                placeholder: (_, _) =>
                    const ColoredBox(color: Tokens.surfaceAlt),
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: Tokens.surfaceAlt),
              ),
      ),
    );
  }
}

class _InvitationRowV2 extends StatefulWidget {
  const _InvitationRowV2({
    required this.item,
    required this.gutter,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final CastingInvitation item;
  final double gutter;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_InvitationRowV2> createState() => _InvitationRowV2State();
}

class _InvitationRowV2State extends State<_InvitationRowV2> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: selected
            ? Tokens.surfaceAlt
            : (_hovered ? Tokens.surface : Colors.transparent),
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            children: [
              if (selected)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 3,
                    child: ColoredBox(color: Tokens.accent),
                  ),
                ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Tokens.border)),
                ),
                padding: EdgeInsets.fromLTRB(
                  widget.gutter,
                  12,
                  widget.gutter - 8,
                  12,
                ),
                child: Row(
                  children: [
                    _InvitationAvatarV2(url: item.accountAvatarUrl, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _invitationTitleV2(item, ru),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _invitationSubtitleV2(item, ru),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.copyWith(
                              color: Tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_hovered)
                            IconButton(
                              tooltip: ru ? 'Удалить' : 'Delete',
                              onPressed: widget.onDelete,
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                foregroundColor: Tokens.textSecondary,
                              ),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          else ...[
                            if (item.requestVideoIntro)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.videocam_outlined,
                                  size: 16,
                                  color: Tokens.accent,
                                ),
                              ),
                            Text(
                              _invitationDateV2(item.createdAt, ru),
                              style: AppText.caption.copyWith(
                                color: Tokens.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _InvitationDetailsV2 extends StatelessWidget {
  const _InvitationDetailsV2({
    required this.item,
    required this.gutter,
    required this.onOpenChat,
    required this.onDelete,
  });

  final CastingInvitation item;
  final double gutter;
  final Future<void> Function() onOpenChat;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final date = _invitationDateV2(item.createdAt, ru);
    final profileName = item.profileName.trim();
    final selectionTitle = item.selectionTitle.trim();
    final requirements = item.videoIntroRequirements.trim();

    Widget fact(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppText.small.copyWith(color: Tokens.textTertiary),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );

    Widget textValue(String text) =>
        Text(text, style: AppText.small.copyWith(fontSize: 15));

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 36, gutter, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InvitationAvatarV2(url: item.accountAvatarUrl, size: 72),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ru
                          ? 'Вас рассматривают на кастинг'
                          : 'You are being considered for a casting',
                      style: AppText.caption.copyWith(
                        color: Tokens.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _invitationTitleV2(item, ru),
                      style: AppText.h1.copyWith(fontSize: 28),
                    ),
                    if (item.contextLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.contextLabel.trim(),
                        style: AppText.small.copyWith(
                          fontSize: 15,
                          color: Tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onOpenChat,
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(ru ? 'Открыть чат' : 'Open chat'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Tokens.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: Text(ru ? 'Удалить' : 'Delete'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          const SizedBox(height: 8),
          if (selectionTitle.isNotEmpty)
            fact(ru ? 'Кастинг' : 'Casting', textValue(selectionTitle)),
          if (profileName.isNotEmpty || item.photoUrl.trim().isNotEmpty)
            fact(
              ru ? 'Анкета' : 'Profile',
              Row(
                children: [
                  if (item.photoUrl.trim().isNotEmpty) ...[
                    _InvitationAvatarV2(url: item.photoUrl, size: 28),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: textValue(profileName.isEmpty ? '—' : profileName),
                  ),
                ],
              ),
            ),
          if (date.isNotEmpty)
            fact(
              ru ? 'Получено' : 'Received',
              textValue(
                _invitationFullDateV2(item.createdAt, ru),
              ),
            ),
          fact(
            ru ? 'Видео-визитка' : 'Video intro',
            item.requestVideoIntro
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.videocam_outlined,
                            size: 18,
                            color: Tokens.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ru ? 'Требуется' : 'Required',
                            style: AppText.small.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Tokens.accent,
                            ),
                          ),
                        ],
                      ),
                      if (requirements.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          requirements,
                          style: AppText.small.copyWith(
                            color: Tokens.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  )
                : Text(
                    ru ? 'Не требуется' : 'Not required',
                    style: AppText.small.copyWith(
                      fontSize: 15,
                      color: Tokens.textSecondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _invitationFullDateV2(DateTime? at, bool ru) {
  if (at == null) return '';
  final local = at.toLocal();
  const monthsRu = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  const monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final month = ru ? monthsRu[local.month - 1] : monthsEn[local.month - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (ru) return '${local.day} $month ${local.year}, $hh:$mm';
  return '$month ${local.day}, ${local.year}, $hh:$mm';
}
