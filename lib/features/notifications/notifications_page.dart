import 'package:flutter/foundation.dart' show kIsWeb;
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

/// v2 (web): full-width page — the feed grouped by day on the left, push
/// status and preferences on the right; no cards, pills or caps.
const bool _notificationsV2 = kIsWeb;
const double _notificationsV2SideWidth = 380;
const double _notificationsV2Breakpoint = 960;

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(appNotificationsProvider);
    final compact = MediaQuery.sizeOf(context).width < 560;
    if (_notificationsV2) {
      ref.watch(appNotificationsRealtimeProvider);
      return _NotificationsPageV2(async: async);
    }

    Future<void> markAllRead() async {
      await ref.read(appNotificationsServiceProvider).markAllRead();
      ref.invalidate(appNotificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
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
      ref.invalidate(unreadNotificationsCountProvider);
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
                  SizedBox(height: compact ? 8 : kGap12),
                  const _NotificationSettingsCard(),
                  SizedBox(height: compact ? 10 : kGap16),
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
                                SizedBox(height: compact ? 8 : kGap12),
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
                                  ref.invalidate(
                                    unreadNotificationsCountProvider,
                                  );
                                  return true;
                                },
                                child: _NotificationCard(
                                  item: item,
                                  onDelete: () async {
                                    await ref
                                        .read(appNotificationsServiceProvider)
                                        .deleteOne(item.id);
                                    ref.invalidate(appNotificationsProvider);
                                    ref.invalidate(
                                      unreadNotificationsCountProvider,
                                    );
                                  },
                                  onTap: () async {
                                    await ref
                                        .read(appNotificationsServiceProvider)
                                        .markRead(item.id);
                                    ref.invalidate(appNotificationsProvider);
                                    ref.invalidate(
                                      unreadNotificationsCountProvider,
                                    );

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

class _NotificationsPageV2 extends ConsumerWidget {
  const _NotificationsPageV2({required this.async});

  final AsyncValue<List<AppNotification>> async;

  Future<void> _markAllRead(WidgetRef ref) async {
    await ref.read(appNotificationsServiceProvider).markAllRead();
    ref.invalidate(appNotificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'Очистить уведомления?' : 'Clear notifications?'),
        content: Text(
          ru
              ? 'Все уведомления будут скрыты из списка.'
              : 'All notifications will be hidden from the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ru ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
            child: Text(ru ? 'Очистить' : 'Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appNotificationsServiceProvider).deleteAll();
    ref.invalidate(appNotificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }

  Future<void> _deleteOne(WidgetRef ref, AppNotification item) async {
    await ref.read(appNotificationsServiceProvider).deleteOne(item.id);
    ref.invalidate(appNotificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    if (!item.isRead) {
      await ref.read(appNotificationsServiceProvider).markRead(item.id);
      ref.invalidate(appNotificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    }
    if (!context.mounted) return;
    final route = item.route.trim();
    if (route.isNotEmpty) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final t = AppLocalizations.of(context)!;
    final wide = MediaQuery.sizeOf(context).width >= _notificationsV2Breakpoint;
    final items = async.valueOrNull ?? const <AppNotification>[];
    final unread = items.where((e) => !e.isRead).length;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 32 : 16, wide ? 28 : 20, wide ? 32 : 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ru ? 'Уведомления' : 'Notifications',
                  style: AppText.h1.copyWith(fontSize: wide ? 32 : 28),
                ),
                const SizedBox(height: 4),
                Text(
                  unread == 0
                      ? (ru ? 'Всё прочитано' : 'All caught up')
                      : (ru
                            ? _pluralRuNotifications(
                                unread,
                                '$unread непрочитанное',
                                '$unread непрочитанных',
                                '$unread непрочитанных',
                              )
                            : '$unread unread'),
                  style: AppText.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            TextButton.icon(
              onPressed: unread == 0 ? null : () => _markAllRead(ref),
              style: TextButton.styleFrom(foregroundColor: Tokens.ink),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(ru ? 'Прочитать все' : 'Mark all read'),
            ),
            TextButton.icon(
              onPressed: () => _deleteAll(context, ref),
              style: TextButton.styleFrom(foregroundColor: Tokens.danger),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(ru ? 'Очистить' : 'Clear'),
            ),
          ],
        ],
      ),
    );

    final feed = async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: SkeletonList(rows: 6),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          AppErrorMapper.message(e, t),
          style: AppText.small.copyWith(color: Tokens.danger),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
            child: Column(
              children: [
                Text(
                  ru ? 'Уведомлений нет' : 'No notifications',
                  style: AppText.h2.copyWith(color: Tokens.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  ru
                      ? 'Здесь появятся сообщения, приглашения и решения по анкетам.'
                      : 'Messages, invitations and profile decisions will appear here.',
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: Tokens.textTertiary),
                ),
              ],
            ),
          );
        }
        final groups = _groupByDay(items, ru);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 20, wide ? 32 : 16, 6),
                child: Text(
                  group.label.toUpperCase(),
                  style: AppText.label.copyWith(color: Tokens.textTertiary),
                ),
              ),
              for (final item in group.items)
                _NotificationRowV2(
                  item: item,
                  gutter: wide ? 32 : 16,
                  onTap: () => _open(context, ref, item),
                  onDelete: () => _deleteOne(ref, item),
                ),
            ],
          ],
        );
      },
    );

    final settings = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, wide ? 28 : 8, wide ? 32 : 16, 32),
      child: const _NotificationSettingsV2(),
    );

    if (!wide) {
      return Scaffold(
        backgroundColor: Tokens.bg,
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            header,
            feed,
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Tokens.border),
            settings,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [header, feed],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Tokens.border),
          SizedBox(
            width: _notificationsV2SideWidth,
            child: SingleChildScrollView(child: settings),
          ),
        ],
      ),
    );
  }
}

class _NotificationGroup {
  const _NotificationGroup(this.label, this.items);
  final String label;
  final List<AppNotification> items;
}

List<_NotificationGroup> _groupByDay(List<AppNotification> items, bool ru) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const monthsRu = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  const monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  String labelFor(DateTime? at) {
    if (at == null) return ru ? 'Ранее' : 'Earlier';
    final local = at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return ru ? 'Сегодня' : 'Today';
    if (diff == 1) return ru ? 'Вчера' : 'Yesterday';
    final month = ru ? monthsRu[local.month - 1] : monthsEn[local.month - 1];
    final sameYear = local.year == now.year;
    if (ru) return sameYear ? '${local.day} $month' : '${local.day} $month ${local.year}';
    return sameYear ? '$month ${local.day}' : '$month ${local.day}, ${local.year}';
  }

  final groups = <_NotificationGroup>[];
  for (final item in items) {
    final label = labelFor(item.createdAt);
    if (groups.isNotEmpty && groups.last.label == label) {
      groups.last.items.add(item);
    } else {
      groups.add(_NotificationGroup(label, [item]));
    }
  }
  return groups;
}

String _pluralRuNotifications(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// Type of a notification inferred from where it leads.
IconData _notificationIcon(AppNotification item) {
  final route = item.route.trim();
  final title = item.title.toLowerCase();
  if (route.startsWith('/chat') || title.contains('сообщен')) {
    return Icons.chat_bubble_outline_rounded;
  }
  if (route.startsWith('/casting') ||
      route.startsWith('/s/') ||
      route.startsWith('/invitations') ||
      title.contains('кастинг') ||
      title.contains('приглаш')) {
    return Icons.movie_outlined;
  }
  if (route.startsWith('/model') ||
      route.startsWith('/me') ||
      title.contains('анкет')) {
    return Icons.badge_outlined;
  }
  if (route.startsWith('/billing') || title.contains('тариф')) {
    return Icons.workspace_premium_outlined;
  }
  return Icons.notifications_none_rounded;
}

String _timeOnly(DateTime? at) {
  if (at == null) return '';
  final local = at.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class _NotificationRowV2 extends StatefulWidget {
  const _NotificationRowV2({
    required this.item,
    required this.gutter,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification item;
  final double gutter;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_NotificationRowV2> createState() => _NotificationRowV2State();
}

class _NotificationRowV2State extends State<_NotificationRowV2> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final unread = !item.isRead;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered ? Tokens.surface : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Tokens.border)),
            ),
            padding: EdgeInsets.fromLTRB(widget.gutter, 14, widget.gutter - 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 10,
                  child: unread
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Tokens.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: unread ? Tokens.ink : Tokens.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _notificationIcon(item),
                    size: 20,
                    color: unread ? Colors.white : Tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isEmpty ? 'PK Management' : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small.copyWith(
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                          color: unread ? Tokens.ink : Tokens.text,
                        ),
                      ),
                      if (item.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.copyWith(
                            color: Tokens.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
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
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _timeOnly(item.createdAt),
                            style: AppText.caption.copyWith(
                              color: Tokens.textTertiary,
                            ),
                          ),
                        ),
                    ],
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

/// Push status for this device + what to receive, as flat settings rows.
class _NotificationSettingsV2 extends ConsumerWidget {
  const _NotificationSettingsV2();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final push = ref.watch(pushDeviceStatusProvider);
    final prefs = ref.watch(notificationPreferencesProvider);

    Future<void> enable() async {
      await ref.read(pushNotificationsServiceProvider).enableForCurrentUser();
      ref.invalidate(pushDeviceStatusProvider);
    }

    Future<void> disable() async {
      await ref.read(pushNotificationsServiceProvider).disableForCurrentDevice();
      ref.invalidate(pushDeviceStatusProvider);
    }

    Future<void> save(NotificationPreferences next) async {
      await ref.read(notificationPreferencesServiceProvider).save(next);
      ref.invalidate(notificationPreferencesProvider);
    }

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: AppText.label.copyWith(color: Tokens.textTertiary),
      ),
    );

    final pushBlock = push.when(
      loading: () => Text(
        ru ? 'Проверяем статус устройства…' : 'Checking device status…',
        style: AppText.small.copyWith(color: Tokens.textSecondary),
      ),
      error: (e, _) => Text(
        AppErrorMapper.message(e, AppLocalizations.of(context)!),
        style: AppText.small.copyWith(color: Tokens.danger),
      ),
      data: (status) {
        final (text, color) = switch (status.state) {
          PushPermissionState.enabled => (
            ru ? 'Включены на этом устройстве' : 'Enabled on this device',
            Tokens.success,
          ),
          PushPermissionState.denied => (
            ru
                ? 'Запрещены — разрешите уведомления в настройках браузера'
                : 'Blocked — allow notifications in the browser settings',
            Tokens.danger,
          ),
          PushPermissionState.notDetermined => (
            ru ? 'Не включены' : 'Not enabled',
            Tokens.textSecondary,
          ),
          PushPermissionState.unsupported => (
            ru
                ? 'Этот браузер не поддерживает push'
                : 'This browser does not support push',
            Tokens.textSecondary,
          ),
          PushPermissionState.notConfigured => (
            ru ? 'Ещё настраиваются' : 'Being set up',
            Tokens.textSecondary,
          ),
        };
        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: AppText.small.copyWith(color: Tokens.text),
              ),
            ),
            if (status.canRequestPermission)
              TextButton(
                onPressed: enable,
                style: TextButton.styleFrom(foregroundColor: Tokens.ink),
                child: Text(ru ? 'Включить' : 'Enable'),
              )
            else if (status.canDisable)
              TextButton(
                onPressed: disable,
                style: TextButton.styleFrom(foregroundColor: Tokens.textSecondary),
                child: Text(ru ? 'Выключить' : 'Disable'),
              ),
          ],
        );
      },
    );

    Widget toggle(
      String label,
      String hint,
      bool value,
      ValueChanged<bool>? onChanged,
    ) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.small.copyWith(fontSize: 15)),
                  if (hint.isNotEmpty)
                    Text(hint, style: AppText.caption),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: Tokens.ink,
              inactiveTrackColor: Tokens.border,
              thumbColor: const WidgetStatePropertyAll(Colors.white),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel(ru ? 'Push на этом устройстве' : 'Push on this device'),
        pushBlock,
        const SizedBox(height: 24),
        const Divider(height: 1, thickness: 1, color: Tokens.border),
        const SizedBox(height: 20),
        sectionLabel(ru ? 'Что получать' : 'What to receive'),
        prefs.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
          error: (e, _) => Text(
            AppErrorMapper.message(e, AppLocalizations.of(context)!),
            style: AppText.small.copyWith(color: Tokens.danger),
          ),
          data: (p) => Column(
            children: [
              toggle(
                'Push',
                ru ? 'Всплывающие на устройстве' : 'On this device',
                p.pushEnabled,
                (v) => save(p.copyWith(pushEnabled: v)),
              ),
              toggle(
                'Email',
                ru ? 'Письма на почту' : 'By email',
                p.emailEnabled,
                (v) => save(p.copyWith(emailEnabled: v)),
              ),
              const Divider(height: 20, thickness: 1, color: Tokens.border),
              toggle(
                ru ? 'Чаты' : 'Chats',
                ru ? 'Новые сообщения' : 'New messages',
                p.chatEnabled,
                (v) => save(p.copyWith(chatEnabled: v)),
              ),
              toggle(
                ru ? 'Кастинги' : 'Castings',
                ru ? 'Приглашения и отклики' : 'Invitations and responses',
                p.castingEnabled,
                (v) => save(p.copyWith(castingEnabled: v)),
              ),
              toggle(
                ru ? 'Анкеты' : 'Profiles',
                ru ? 'Решения модерации' : 'Moderation decisions',
                p.profileEnabled,
                (v) => save(p.copyWith(profileEnabled: v)),
              ),
              toggle(
                ru ? 'Системные' : 'System',
                ru ? 'Безопасность и аккаунт' : 'Security and account',
                p.systemEnabled,
                (v) => save(p.copyWith(systemEnabled: v)),
              ),
            ],
          ),
        ),
      ],
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
    final compact = MediaQuery.sizeOf(context).width < 560;
    final iconColor = enabled
        ? Colors.white
        : danger
        ? Colors.white
        : kTextMuted;
    final cleanBody = body.replaceAll('\n', ' · ');
    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: catalogCardDecoration().copyWith(
          border: Border.all(
            color: danger
                ? BrandTheme.redTop
                : enabled
                ? kTextDark
                : kBorderColor,
            width: danger || enabled ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: enabled || danger
                    ? BrandTheme.darkPillGradient
                    : BrandTheme.lightPillGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _notificationCommandStyle(
                      size: 15,
                      spacing: 1,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cleanBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _notificationBodyStyle(size: 12, height: 1.1),
                  ),
                ],
              ),
            ),
            if (actionLabel != null || secondaryLabel != null) ...[
              const SizedBox(width: 8),
              _CompactStatusAction(
                label: actionLabel ?? secondaryLabel!,
                onTap: actionLabel != null ? onAction : onSecondary,
                dark: actionLabel != null,
              ),
            ],
          ],
        ),
      );
    }

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

class _CompactStatusAction extends StatelessWidget {
  const _CompactStatusAction({
    required this.label,
    required this.onTap,
    required this.dark,
  });

  final String label;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 34, minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pillDecoration(isDark: dark, radius: 18).copyWith(
            border: Border.all(color: dark ? kTextDark : kBorderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _notificationCommandStyle(
              color: dark ? Colors.white : kTextDark,
              size: 11,
              spacing: 1,
              weight: FontWeight.w800,
            ),
          ),
        ),
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
    final compact = MediaQuery.sizeOf(context).width < 560;
    final toggles = [
      _SettingsPill(
        icon: Icons.notifications_active_rounded,
        label: ru ? 'Push' : 'Push',
        value: preferences.pushEnabled,
        onTap: busy || isError
            ? null
            : () => onChanged(
                preferences.copyWith(pushEnabled: !preferences.pushEnabled),
              ),
      ),
      _SettingsPill(
        icon: Icons.alternate_email_rounded,
        label: ru ? 'Email' : 'Email',
        value: preferences.emailEnabled,
        onTap: busy || isError
            ? null
            : () => onChanged(
                preferences.copyWith(emailEnabled: !preferences.emailEnabled),
              ),
      ),
      _SettingsPill(
        icon: Icons.chat_bubble_rounded,
        label: ru ? 'Чаты' : 'Chats',
        value: preferences.chatEnabled,
        onTap: busy || isError
            ? null
            : () => onChanged(
                preferences.copyWith(chatEnabled: !preferences.chatEnabled),
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
                preferences.copyWith(systemEnabled: !preferences.systemEnabled),
              ),
      ),
    ];
    final enabledCount = [
      preferences.pushEnabled,
      preferences.emailEnabled,
      preferences.chatEnabled,
      preferences.castingEnabled,
      preferences.profileEnabled,
      preferences.systemEnabled,
    ].where((enabled) => enabled).length;

    if (compact) {
      return Container(
        width: double.infinity,
        decoration: catalogCardDecoration().copyWith(
          border: Border.all(
            color: isError ? BrandTheme.redTop : kBorderColor,
            width: isError ? 1.4 : 1,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            initiallyExpanded: false,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: BrandTheme.darkPillGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            title: Text(
              ru ? 'ЦЕНТР СОБЫТИЙ' : 'EVENT CENTER',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _notificationCommandStyle(
                size: 15,
                spacing: 1,
                weight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              isError
                  ? error!
                  : busy
                  ? (ru ? 'Загружаем настройки' : 'Loading preferences')
                  : (ru
                        ? 'Включено: $enabledCount/6'
                        : 'Enabled: $enabledCount/6'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _notificationBodyStyle(
                color: isError ? kTextDanger : kTextMuted,
                size: 12,
                weight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            trailing: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kTextDark,
                  ),
            children: [
              if (isError)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error!,
                    style: _notificationBodyStyle(
                      color: kTextDanger,
                      weight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Wrap(spacing: kGap8, runSpacing: kGap8, children: toggles),
            ],
          ),
        ),
      );
    }

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
          Wrap(spacing: kGap12, runSpacing: kGap12, children: toggles),
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
    final compact = MediaQuery.sizeOf(context).width < 560;
    final iconSize = compact ? 44.0 : kProfileSummaryImageSize;
    final radius = compact ? 14.0 : kProfileImageRadius;
    final titleSize = compact ? 15.0 : 18.0;
    final bodySize = compact ? 13.0 : 15.0;
    final contentPad = compact
        ? const EdgeInsets.fromLTRB(12, 10, 8, 10)
        : kLoginCardPad;
    final gap = compact ? 10.0 : kProfileSummaryGap;
    final deleteSize = compact ? 34.0 : 48.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: Container(
          padding: contentPad,
          decoration: catalogCardDecoration().copyWith(
            border: Border.all(
              color: unread ? BrandTheme.redTop : kBorderColor,
              width: unread ? (compact ? 1.2 : 1.4) : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  gradient: unread
                      ? BrandTheme.darkPillGradient
                      : BrandTheme.lightPillGradient,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Icon(
                  unread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: unread ? Colors.white : kTextMuted,
                  size: compact ? 21 : 24,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title.isEmpty ? 'ModelApp' : item.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: _notificationCommandStyle(
                        size: titleSize,
                        spacing: compact ? 1.0 : 1.4,
                        weight: FontWeight.w800,
                      ),
                    ),
                    if (item.body.isNotEmpty) ...[
                      SizedBox(height: compact ? 3 : 6),
                      Text(
                        item.body,
                        maxLines: compact ? 1 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: _notificationBodyStyle(
                          size: bodySize,
                          height: compact ? 1.1 : 1.22,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: deleteSize,
                height: deleteSize,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: deleteSize,
                    height: deleteSize,
                  ),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: BrandTheme.redTop,
                    size: compact ? 22 : 24,
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
