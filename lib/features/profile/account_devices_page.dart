import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_providers.dart';
import '../../core/router.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class AccountDeviceEntry {
  const AccountDeviceEntry({
    required this.id,
    required this.platform,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  final String id;
  final String platform;
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeenAt;

  factory AccountDeviceEntry.fromMap(Map<String, dynamic> map) {
    String text(String key) => (map[key] ?? '').toString().trim();
    DateTime? date(String key) {
      final raw = text(key);
      return raw.isEmpty ? null : DateTime.tryParse(raw);
    }

    return AccountDeviceEntry(
      id: text('id'),
      platform: text('platform').isEmpty ? 'unknown' : text('platform'),
      enabled: map['enabled'] != false,
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      lastSeenAt: date('last_seen_at'),
    );
  }
}

class AccountDevicesService {
  const AccountDevicesService(this._sb);

  final SupabaseClient _sb;

  Future<List<AccountDeviceEntry>> loadForCurrentUser() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    try {
      final rows = await _sb
          .from('push_device_tokens')
          .select('id,platform,enabled,created_at,updated_at,last_seen_at')
          .eq('user_id', userId)
          .order('last_seen_at', ascending: false)
          .limit(30);

      return rows
          .map(
            (row) => AccountDeviceEntry.fromMap(Map<String, dynamic>.from(row)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, const ['push_device_tokens'])) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> disableDevice(String id) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || id.trim().isEmpty) return;

    await _sb
        .from('push_device_tokens')
        .update({
          'enabled': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('id', id.trim());
  }
}

final accountDevicesServiceProvider = Provider<AccountDevicesService>((ref) {
  return AccountDevicesService(ref.read(supabaseProvider));
});

final accountDevicesProvider =
    FutureProvider.autoDispose<List<AccountDeviceEntry>>((ref) async {
      ref.watch(currentUserIdProvider);
      return ref.read(accountDevicesServiceProvider).loadForCurrentUser();
    });

class AccountDevicesPage extends ConsumerWidget {
  const AccountDevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final user = ref.watch(currentUserProvider);
    final asyncDevices = ref.watch(accountDevicesProvider);

    if (kIsWeb) {
      final email = user?.email?.trim() ?? '';
      Future<void> signOutHere() async {
        await ref.read(supabaseProvider).auth.signOut();
        if (context.mounted) context.go(Routes.login);
      }

      return SettingsPageV2(
        title: isRussian ? 'Устройства и входы' : 'Devices & logins',
        subtitle: isRussian
            ? 'Текущая сессия и устройства с включёнными push-уведомлениями'
            : 'The current session and devices with push notifications enabled',
        backLabel: isRussian ? 'Аккаунт' : 'Account',
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(Routes.me);
          }
        },
        children: [
          SettingsSection(
            title: isRussian ? 'Текущая сессия' : 'Current session',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsListRow(
                  icon: Icons.desktop_windows_outlined,
                  active: true,
                  title: isRussian ? 'Это устройство' : 'This device',
                  subtitle: [
                    if (email.isNotEmpty) email,
                    isRussian ? 'Сейчас авторизовано' : 'Signed in now',
                  ].join(' · '),
                  trailing: OutlinedButton(
                    onPressed: signOutHere,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(isRussian ? 'Выйти' : 'Sign out'),
                  ),
                  last: true,
                ),
              ],
            ),
          ),
          SettingsSection(
            title: isRussian ? 'Push-устройства' : 'Push devices',
            hint: isRussian
                ? 'Устройства, на которых включены push-уведомления. Полный список входов и выход со всех устройств появятся позже.'
                : 'Devices where push notifications are enabled. A full sign-in list and «sign out everywhere» come later.',
            child: asyncDevices.when(
              loading: () => const SkeletonList(rows: 3),
              error: (e, _) => SettingsNote(
                text: e.toString(),
                tone: SettingsNoteTone.danger,
              ),
              data: (devices) {
                if (devices.isEmpty) {
                  return SettingsNote(
                    text: isRussian
                        ? 'Пока ни одного. Когда вы включите push-уведомления на устройстве, оно появится здесь.'
                        : 'None yet. When push notifications are enabled on a device, it will show up here.',
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < devices.length; i++)
                      SettingsListRow(
                        icon: _platformIcon(devices[i].platform),
                        active: devices[i].enabled,
                        title: _platformTitle(devices[i].platform, isRussian),
                        subtitle:
                            '${devices[i].enabled ? (isRussian ? 'Push включены' : 'Push enabled') : (isRussian ? 'Push отключены' : 'Push disabled')} · '
                            '${isRussian ? 'активность' : 'last seen'} ${_formatDate(devices[i].lastSeenAt, isRussian)}',
                        trailing: devices[i].enabled
                            ? TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(accountDevicesServiceProvider)
                                      .disableDevice(devices[i].id);
                                  ref.invalidate(accountDevicesProvider);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Tokens.textSecondary,
                                ),
                                child: Text(
                                  isRussian ? 'Отключить push' : 'Disable push',
                                ),
                              )
                            : const SizedBox.shrink(),
                        last: i == devices.length - 1,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(
              padding: kMyProfilePagePad,
              children: [
                BrandAdminHeader(
                  title: isRussian ? 'УСТРОЙСТВА И ВХОДЫ' : 'DEVICES & LOGINS',
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(Routes.accountProfile);
                    }
                  },
                ),
                const SizedBox(height: kGap14),
                _SessionCard(userEmail: user?.email, isRussian: isRussian),
                const SizedBox(height: kGap12),
                _InfoCard(
                  icon: Icons.info_outline_rounded,
                  title: isRussian ? 'Что здесь видно' : 'What is shown here',
                  body: isRussian
                      ? 'На первом этапе показываем текущую сессию и устройства, где включены push-уведомления. Полный список Auth-сессий и выход со всех устройств потребуют server-side слоя Supabase Auth.'
                      : 'For the first launch, this page shows the current session and devices with push enabled. A full Auth session list and sign out everywhere require a Supabase Auth server-side layer.',
                ),
                const SizedBox(height: kGap12),
                asyncDevices.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _InfoCard(
                    icon: Icons.warning_amber_rounded,
                    title: isRussian ? 'Не удалось загрузить' : 'Load failed',
                    body: e.toString(),
                    danger: true,
                  ),
                  data: (devices) => _DevicesSection(
                    devices: devices,
                    isRussian: isRussian,
                    onDisable: (id) async {
                      await ref
                          .read(accountDevicesServiceProvider)
                          .disableDevice(id);
                      ref.invalidate(accountDevicesProvider);
                    },
                  ),
                ),
                const SizedBox(height: kGap12),
                SizedBox(
                  height: kRegisterButtonH,
                  child: BrandPillButton(
                    label: isRussian
                        ? 'ВЫЙТИ НА ЭТОМ УСТРОЙСТВЕ'
                        : 'SIGN OUT ON THIS DEVICE',
                    style: BrandPillStyle.light,
                    onTap: () async {
                      await ref.read(supabaseProvider).auth.signOut();
                      if (context.mounted) context.go(Routes.login);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.userEmail, required this.isRussian});

  final String? userEmail;
  final bool isRussian;

  @override
  Widget build(BuildContext context) {
    final email = userEmail?.trim() ?? '';
    return _InfoCard(
      icon: Icons.verified_user_rounded,
      title: isRussian ? 'Текущая сессия' : 'Current session',
      body: [
        if (email.isNotEmpty) email,
        isRussian
            ? 'Это устройство сейчас авторизовано.'
            : 'This device is currently signed in.',
      ].join('\n'),
    );
  }
}

class _DevicesSection extends StatelessWidget {
  const _DevicesSection({
    required this.devices,
    required this.isRussian,
    required this.onDisable,
  });

  final List<AccountDeviceEntry> devices;
  final bool isRussian;
  final ValueChanged<String> onDisable;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return _InfoCard(
        icon: Icons.notifications_off_rounded,
        title: isRussian ? 'Push-устройств нет' : 'No push devices',
        body: isRussian
            ? 'Когда пользователь включает push-уведомления, устройство появится здесь.'
            : 'When push notifications are enabled, the device will appear here.',
      );
    }

    return Column(
      children: [
        for (final device in devices) ...[
          _DeviceCard(
            device: device,
            isRussian: isRussian,
            onDisable: () => onDisable(device.id),
          ),
          const SizedBox(height: kGap10),
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.isRussian,
    required this.onDisable,
  });

  final AccountDeviceEntry device;
  final bool isRussian;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final lastSeen = _formatDate(device.lastSeenAt, isRussian);
    final status = device.enabled
        ? (isRussian ? 'Активно' : 'Enabled')
        : (isRussian ? 'Отключено' : 'Disabled');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: device.enabled
                  ? BrandTheme.darkPillGradient
                  : BrandTheme.lightPillGradient,
              boxShadow: BrandTheme.basePillShadow(isDark: device.enabled),
            ),
            child: Icon(
              _platformIcon(device.platform),
              color: device.enabled ? Colors.white : kTextDark,
            ),
          ),
          const SizedBox(width: kGap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${device.platform} • $status', style: _titleStyle()),
                const SizedBox(height: 5),
                Text(
                  isRussian
                      ? 'Последняя активность: $lastSeen'
                      : 'Last seen: $lastSeen',
                  style: _bodyStyle(),
                ),
                if (device.enabled) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: BrandPillButton(
                      label: isRussian ? 'ОТКЛЮЧИТЬ PUSH' : 'DISABLE PUSH',
                      style: BrandPillStyle.light,
                      onTap: onDisable,
                    ),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(
          color: danger
              ? BrandTheme.redTop.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.70),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: danger ? BrandTheme.redTop : kTextDark),
          const SizedBox(width: kGap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle()),
                const SizedBox(height: 6),
                Text(body, style: _bodyStyle()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _platformTitle(String platform, bool isRussian) {
  final lower = platform.toLowerCase();
  if (lower.contains('ios')) return 'iPhone / iPad';
  if (lower.contains('android')) return 'Android';
  if (lower.contains('web')) return isRussian ? 'Браузер' : 'Browser';
  return isRussian ? 'Устройство' : 'Device';
}

IconData _platformIcon(String platform) {
  final lower = platform.toLowerCase();
  if (lower.contains('ios')) return Icons.phone_iphone_rounded;
  if (lower.contains('android')) return Icons.phone_android_rounded;
  if (lower.contains('web')) return Icons.desktop_windows_rounded;
  return Icons.devices_rounded;
}

String _formatDate(DateTime? value, bool isRussian) {
  if (value == null) return isRussian ? 'нет данных' : 'unknown';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

TextStyle _titleStyle() {
  return BrandTheme.pillText.copyWith(
    color: kTextDark,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );
}

TextStyle _bodyStyle() {
  return const TextStyle(
    color: kTextMuted,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
}
