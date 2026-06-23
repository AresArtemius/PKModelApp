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
import 'chat_providers.dart';

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

class InvitationsPage extends ConsumerWidget {
  const InvitationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final invitations = ref.watch(myInvitationsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
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
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return Dismissible(
                                    key: ValueKey(
                                      '${item.selectionId}_${item.profileId}',
                                    ),
                                    direction: DismissDirection.endToStart,
                                    background: const _DeleteBackground(),
                                    confirmDismiss: (_) async {
                                      await _hideInvitation(
                                        ref: ref,
                                        item: item,
                                      );
                                      return true;
                                    },
                                    child: _InvitationCard(
                                      item: item,
                                      message: t.consideredForCastingMessage,
                                      onDelete: () async {
                                        await _deleteInvitationWithConfirmation(
                                          context: context,
                                          ref: ref,
                                          item: item,
                                        );
                                      },
                                      onOpenChat: () async {
                                        final entitlements = await ref.read(
                                          accountEntitlementsProvider.future,
                                        );
                                        if (!context.mounted) return;
                                        if (!entitlements.canUseSelectionChat) {
                                          await _showModelProRequiredDialog(
                                            context,
                                          );
                                          return;
                                        }
                                        final chatId = await ref
                                            .read(chatServiceProvider)
                                            .ensureSelectionChat(
                                              selectionId: item.selectionId,
                                              profileId: item.profileId,
                                              modelUserId: item.modelUserId,
                                            );
                                        if (!context.mounted ||
                                            chatId.isEmpty) {
                                          return;
                                        }
                                        context.push(
                                          '${Routes.chatPrefix}$chatId',
                                        );
                                      },
                                    ),
                                  );
                                },
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
    final title = item.selectionTitle.isEmpty ? '—' : item.selectionTitle;
    final subtitle = item.profileName.isEmpty ? '' : item.profileName;

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
              _InvitationThumb(url: item.photoUrl),
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
  const _InvitationThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
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
