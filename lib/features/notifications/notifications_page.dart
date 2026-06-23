import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'app_notifications.dart';

TextStyle _notificationCommandStyle({
  Color color = kTextDark,
  double size = 16,
  double spacing = 1.4,
  FontWeight weight = FontWeight.w600,
}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

TextStyle _notificationBodyStyle({
  Color color = kTextMuted,
  double size = 15,
  double spacing = 0.2,
  FontWeight weight = FontWeight.w600,
  double height = 1.22,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
    height: height,
  );
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(appNotificationsProvider);

    Future<void> markAllRead() async {
      await ref.read(appNotificationsServiceProvider).markAllRead();
      ref.invalidate(appNotificationsProvider);
    }

    Future<void> deleteAll() async {
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: kDialogInsetPad,
          child: Container(
            padding: kLoginCardPad,
            decoration: catalogDialogDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ru ? 'УДАЛИТЬ УВЕДОМЛЕНИЯ?' : 'DELETE NOTIFICATIONS?',
                  textAlign: TextAlign.center,
                  style: _notificationCommandStyle(
                    size: 22,
                    spacing: 2.1,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: kGap12),
                Text(
                  ru
                      ? 'Все уведомления будут скрыты из списка.'
                      : 'All notifications will be hidden from the list.',
                  textAlign: TextAlign.center,
                  style: _notificationBodyStyle(),
                ),
                const SizedBox(height: kGap16),
                Row(
                  children: [
                    Expanded(
                      child: BrandPillButton(
                        label: ru ? 'ОТМЕНА' : 'CANCEL',
                        style: BrandPillStyle.light,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: kGap12),
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
      if (confirmed != true) return;
      await ref.read(appNotificationsServiceProvider).deleteAll();
      ref.invalidate(appNotificationsProvider);
    }

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(kPagePadH),
              child: Column(
                children: [
                  BrandAdminHeader(
                    title: t.notificationsUpper,
                    onBack: () => context.go(Routes.me),
                    sideWidth: 76,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeaderActionButton(
                          icon: Icons.done_all_rounded,
                          color: kTextDark,
                          onPressed: markAllRead,
                        ),
                        _HeaderActionButton(
                          icon: Icons.delete_sweep_rounded,
                          color: BrandTheme.redTop,
                          onPressed: deleteAll,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kGap16),
                  Expanded(
                    child: async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _MessageCard(
                        text: AppErrorMapper.message(e, t),
                        isError: true,
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return _MessageCard(text: t.notificationsEmpty);
                        }

                        return RefreshIndicator(
                          color: kTextDark,
                          onRefresh: () async =>
                              ref.refresh(appNotificationsProvider.future),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: kGap12),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.endToStart,
                                background: const _DeleteBackground(),
                                confirmDismiss: (_) async {
                                  await ref
                                      .read(appNotificationsServiceProvider)
                                      .deleteOne(item.id);
                                  ref.invalidate(appNotificationsProvider);
                                  return true;
                                },
                                child: _NotificationCard(
                                  item: item,
                                  onDelete: () async {
                                    await ref
                                        .read(appNotificationsServiceProvider)
                                        .deleteOne(item.id);
                                    ref.invalidate(appNotificationsProvider);
                                  },
                                  onTap: () async {
                                    await ref
                                        .read(appNotificationsServiceProvider)
                                        .markRead(item.id);
                                    ref.invalidate(appNotificationsProvider);

                                    if (!context.mounted) return;
                                    final route = item.route.trim();
                                    if (route.isNotEmpty) context.go(route);
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
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

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 32,
          height: 42,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: Container(
          padding: kLoginCardPad,
          decoration: catalogCardDecoration().copyWith(
            border: Border.all(
              color: unread ? BrandTheme.redTop : kBorderColor,
              width: unread ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: kProfileSummaryImageSize,
                height: kProfileSummaryImageSize,
                decoration: BoxDecoration(
                  gradient: unread
                      ? BrandTheme.darkPillGradient
                      : BrandTheme.lightPillGradient,
                  borderRadius: BorderRadius.circular(kProfileImageRadius),
                ),
                child: Icon(
                  unread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: unread ? Colors.white : kTextMuted,
                ),
              ),
              const SizedBox(width: kProfileSummaryGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? 'ModelApp' : item.title,
                      style: _notificationCommandStyle(
                        size: 18,
                        spacing: 1.4,
                        weight: FontWeight.w700,
                      ),
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.body, style: _notificationBodyStyle()),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: BrandTheme.redTop,
                ),
              ),
            ],
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
        color: BrandTheme.redTop,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: kLoginCardPad,
        decoration: catalogCardDecoration(),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _notificationBodyStyle(
            color: isError ? kTextDanger : kTextMuted,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
