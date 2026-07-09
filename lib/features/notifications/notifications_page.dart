import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/push_notifications_service.dart';
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
                  const _PushStatusCard(),
                  const SizedBox(height: kGap12),
                  const _NotificationSettingsCard(),
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

class _PushStatusCard extends ConsumerWidget {
  const _PushStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final async = ref.watch(pushDeviceStatusProvider);

    Future<void> enable() async {
      await ref.read(pushNotificationsServiceProvider).enableForCurrentUser();
      ref.invalidate(pushDeviceStatusProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ru
                ? 'Статус уведомлений обновлен.'
                : 'Notification status updated.',
          ),
        ),
      );
    }

    Future<void> disable() async {
      await ref
          .read(pushNotificationsServiceProvider)
          .disableForCurrentDevice();
      ref.invalidate(pushDeviceStatusProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ru
                ? 'Push-уведомления выключены для этого устройства.'
                : 'Push notifications are disabled for this device.',
          ),
        ),
      );
    }

    return async.when(
      loading: () => _PushStatusShell(
        icon: Icons.notifications_rounded,
        title: ru ? 'PUSH-УВЕДОМЛЕНИЯ' : 'PUSH NOTIFICATIONS',
        body: ru
            ? 'Проверяем статус устройства...'
            : 'Checking device status...',
        actionLabel: null,
        secondaryLabel: null,
        onAction: null,
        onSecondary: null,
      ),
      error: (e, _) => _PushStatusShell(
        icon: Icons.notifications_off_rounded,
        title: ru ? 'PUSH-УВЕДОМЛЕНИЯ' : 'PUSH NOTIFICATIONS',
        body: AppErrorMapper.message(e, AppLocalizations.of(context)!),
        actionLabel: ru ? 'ПОВТОРИТЬ' : 'RETRY',
        secondaryLabel: null,
        onAction: () => ref.invalidate(pushDeviceStatusProvider),
        onSecondary: null,
        danger: true,
      ),
      data: (status) {
        final copy = _pushStatusCopy(status.state, ru: ru);
        return _PushStatusShell(
          icon: copy.icon,
          title: copy.title,
          body:
              '${copy.body}\n${ru ? 'Устройство' : 'Device'}: ${status.platform}',
          actionLabel: status.canRequestPermission
              ? (ru ? 'ВКЛЮЧИТЬ' : 'ENABLE')
              : null,
          secondaryLabel: status.canDisable
              ? (ru ? 'ВЫКЛЮЧИТЬ' : 'DISABLE')
              : null,
          onAction: status.canRequestPermission ? enable : null,
          onSecondary: status.canDisable ? disable : null,
          enabled: status.isEnabled,
          danger: status.state == PushPermissionState.denied,
        );
      },
    );
  }

  ({IconData icon, String title, String body}) _pushStatusCopy(
    PushPermissionState state, {
    required bool ru,
  }) {
    return switch (state) {
      PushPermissionState.enabled => (
        icon: Icons.notifications_active_rounded,
        title: ru ? 'PUSH ВКЛЮЧЕНЫ' : 'PUSH ENABLED',
        body: ru
            ? 'Уведомления для этого устройства разрешены.'
            : 'Notifications are enabled for this device.',
      ),
      PushPermissionState.denied => (
        icon: Icons.notifications_off_rounded,
        title: ru ? 'PUSH ЗАПРЕЩЕНЫ' : 'PUSH BLOCKED',
        body: ru
            ? 'Разрешите уведомления в настройках браузера или устройства.'
            : 'Allow notifications in browser or device settings.',
      ),
      PushPermissionState.notDetermined => (
        icon: Icons.notifications_none_rounded,
        title: ru ? 'PUSH НЕ ВКЛЮЧЕНЫ' : 'PUSH NOT ENABLED',
        body: ru
            ? 'Можно включить уведомления для новых сообщений и приглашений.'
            : 'You can enable notifications for new messages and invitations.',
      ),
      PushPermissionState.unsupported => (
        icon: Icons.notifications_off_rounded,
        title: ru ? 'PUSH НЕДОСТУПНЫ' : 'PUSH UNSUPPORTED',
        body: ru
            ? 'Этот браузер или платформа не поддерживает push-уведомления.'
            : 'This browser or platform does not support push notifications.',
      ),
      PushPermissionState.notConfigured => (
        icon: Icons.notifications_paused_rounded,
        title: ru ? 'PUSH ГОТОВЯТСЯ' : 'PUSH PENDING',
        body: ru
            ? 'Клиентская часть готова, но Firebase/Web Push еще не настроены полностью.'
            : 'The client is ready, but Firebase/Web Push is not fully configured yet.',
      ),
    };
  }
}

class _PushStatusShell extends StatelessWidget {
  const _PushStatusShell({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.secondaryLabel,
    required this.onAction,
    required this.onSecondary,
    this.enabled = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final String? secondaryLabel;
  final VoidCallback? onAction;
  final VoidCallback? onSecondary;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled
        ? Colors.white
        : danger
        ? Colors.white
        : kTextMuted;
    return Container(
      width: double.infinity,
      padding: kLoginCardPad,
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(
          color: danger
              ? BrandTheme.redTop
              : enabled
              ? kTextDark
              : kBorderColor,
          width: danger || enabled ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: kProfileSummaryImageSize,
            height: kProfileSummaryImageSize,
            decoration: BoxDecoration(
              gradient: enabled || danger
                  ? BrandTheme.darkPillGradient
                  : BrandTheme.lightPillGradient,
              borderRadius: BorderRadius.circular(kProfileImageRadius),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: kProfileSummaryGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _notificationCommandStyle(
                    size: 18,
                    spacing: 1.4,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: _notificationBodyStyle()),
                if (actionLabel != null || secondaryLabel != null) ...[
                  const SizedBox(height: kGap12),
                  Wrap(
                    spacing: kGap12,
                    runSpacing: kGap8,
                    children: [
                      if (actionLabel != null)
                        SizedBox(
                          width: 180,
                          child: BrandPillButton(
                            label: actionLabel!,
                            style: BrandPillStyle.dark,
                            onTap: onAction,
                          ),
                        ),
                      if (secondaryLabel != null)
                        SizedBox(
                          width: 180,
                          child: BrandPillButton(
                            label: secondaryLabel!,
                            style: BrandPillStyle.light,
                            onTap: onSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsCard extends ConsumerWidget {
  const _NotificationSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final async = ref.watch(notificationPreferencesProvider);

    Future<void> save(NotificationPreferences next) async {
      await ref.read(notificationPreferencesServiceProvider).save(next);
      ref.invalidate(notificationPreferencesProvider);
    }

    return async.when(
      loading: () => _SettingsShell(
        ru: ru,
        busy: true,
        preferences: NotificationPreferences.defaults,
        onChanged: (_) {},
      ),
      error: (e, _) => _SettingsShell(
        ru: ru,
        preferences: NotificationPreferences.defaults,
        error: AppErrorMapper.message(e, AppLocalizations.of(context)!),
        onChanged: (_) => ref.invalidate(notificationPreferencesProvider),
      ),
      data: (preferences) =>
          _SettingsShell(ru: ru, preferences: preferences, onChanged: save),
    );
  }
}

class _SettingsShell extends StatelessWidget {
  const _SettingsShell({
    required this.ru,
    required this.preferences,
    required this.onChanged,
    this.busy = false,
    this.error,
  });

  final bool ru;
  final NotificationPreferences preferences;
  final ValueChanged<NotificationPreferences> onChanged;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final isError = error != null;
    return Container(
      width: double.infinity,
      padding: kLoginCardPad,
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(
          color: isError ? BrandTheme.redTop : kBorderColor,
          width: isError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: BrandTheme.darkPillGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: kGap12),
              Expanded(
                child: Text(
                  ru ? 'ЦЕНТР СОБЫТИЙ' : 'EVENT CENTER',
                  style: _notificationCommandStyle(
                    size: 18,
                    spacing: 1.4,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (isError) ...[
            const SizedBox(height: kGap12),
            Text(
              error!,
              style: _notificationBodyStyle(
                color: kTextDanger,
                weight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: kGap12),
          Wrap(
            spacing: kGap12,
            runSpacing: kGap12,
            children: [
              _SettingsPill(
                icon: Icons.notifications_active_rounded,
                label: ru ? 'Push' : 'Push',
                value: preferences.pushEnabled,
                onTap: busy || isError
                    ? null
                    : () => onChanged(
                        preferences.copyWith(
                          pushEnabled: !preferences.pushEnabled,
                        ),
                      ),
              ),
              _SettingsPill(
                icon: Icons.alternate_email_rounded,
                label: ru ? 'Email' : 'Email',
                value: preferences.emailEnabled,
                onTap: busy || isError
                    ? null
                    : () => onChanged(
                        preferences.copyWith(
                          emailEnabled: !preferences.emailEnabled,
                        ),
                      ),
              ),
              _SettingsPill(
                icon: Icons.chat_bubble_rounded,
                label: ru ? 'Чаты' : 'Chats',
                value: preferences.chatEnabled,
                onTap: busy || isError
                    ? null
                    : () => onChanged(
                        preferences.copyWith(
                          chatEnabled: !preferences.chatEnabled,
                        ),
                      ),
              ),
              _SettingsPill(
                icon: Icons.movie_filter_rounded,
                label: ru ? 'Кастинги' : 'Castings',
                value: preferences.castingEnabled,
                onTap: busy || isError
                    ? null
                    : () => onChanged(
                        preferences.copyWith(
                          castingEnabled: !preferences.castingEnabled,
                        ),
                      ),
              ),
              _SettingsPill(
                icon: Icons.badge_rounded,
                label: ru ? 'Анкеты' : 'Profiles',
                value: preferences.profileEnabled,
                onTap: busy || isError
                    ? null
                    : () => onChanged(
                        preferences.copyWith(
                          profileEnabled: !preferences.profileEnabled,
                        ),
                      ),
              ),
              _SettingsPill(
                icon: Icons.shield_rounded,
                label: ru ? 'Системные' : 'System',
                value: preferences.systemEnabled,
                onTap: busy || isError
                    ? null
                    : () => onChanged(
                        preferences.copyWith(
                          systemEnabled: !preferences.systemEnabled,
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

class _SettingsPill extends StatelessWidget {
  const _SettingsPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: disabled ? 0.64 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pillDecoration(isDark: value, radius: 22).copyWith(
              border: Border.all(color: value ? kTextDark : kBorderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value ? Icons.check_rounded : icon,
                  color: value ? Colors.white : kTextMuted,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: _notificationCommandStyle(
                    color: value ? Colors.white : kTextDark,
                    size: 14,
                    spacing: 0.4,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
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
