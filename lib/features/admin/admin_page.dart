import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';

const _kAdminBg = BrandTheme.greyMid;

const double _kAdminPad = 14;
const double _kAdminPagePad = 16;
const double _kAdminSectionGap = 12;
const double _kAdminMessagePadV = 18;
const double _kAdminMaxCardWidth = 460;

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isAdminAsync = ref.watch(isAdminProvider);

    Future<void> signOutAndGoLogin() async {
      context.go(Routes.login);
      try {
        await ref.read(supabaseProvider).auth.signOut();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Sign out failed')));
        }
      }
    }

    return Scaffold(
      backgroundColor: _kAdminBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_kAdminPagePad),
          child: isAdminAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _ForbiddenView(
              message: t.adminOnlyUpper,
              exitLabel: t.adminExitUpper,
              onExit: signOutAndGoLogin,
            ),
            data: (isAdmin) {
              if (!isAdmin) {
                return _ForbiddenView(
                  message: t.adminOnlyUpper,
                  exitLabel: t.adminExitUpper,
                  onExit: signOutAndGoLogin,
                );
              }

              final countsAsync = ref.watch(adminDashboardCountsProvider);
              return _AdminHome(
                exitLabel: t.adminExitUpper,
                counts: countsAsync.maybeWhen(
                  data: (value) => value,
                  orElse: () => const AdminDashboardCounts(),
                ),
                actions: [
                  _AdminAction(
                    label: t.adminCreateCastingUpper,
                    description: ru ? 'Новый проект' : 'New project',
                    icon: Icons.videocam_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.createCastingAdmin),
                  ),
                  _AdminAction(
                    label: t.selectionUpper,
                    description: ru
                        ? 'Подборки и кастинги'
                        : 'Selections and castings',
                    icon: Icons.dashboard_customize_rounded,
                    group: _AdminActionGroup.operations,
                    onTap: () => context.go(Routes.adminSelection),
                  ),
                  _AdminAction(
                    label: t.adminModerationUpper,
                    description: ru ? 'Анкеты на проверке' : 'Pending profiles',
                    icon: Icons.verified_user_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.moderation,
                      orElse: () => 0,
                    ),
                    onTap: () => context.go(Routes.moderationAdmin),
                  ),
                  _AdminAction(
                    label: t.adminAgentApplicationsUpper,
                    description: ru
                        ? 'Статусы заказчиков'
                        : 'Client role requests',
                    icon: Icons.badge_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.agentApplications,
                      orElse: () => 0,
                    ),
                    onTap: () =>
                        context.go(Routes.castingAgentApplicationsAdmin),
                  ),
                  _AdminAction(
                    label: Localizations.localeOf(context).languageCode == 'ru'
                        ? 'ОБЪЕДИНЕНИЕ АККАУНТОВ'
                        : 'ACCOUNT MERGES',
                    description: ru
                        ? 'Заявки на перенос телефона'
                        : 'Phone merge requests',
                    icon: Icons.merge_type_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.accountMerges,
                      orElse: () => 0,
                    ),
                    onTap: () => context.go(Routes.accountMergeRequestsAdmin),
                  ),
                  _AdminAction(
                    label: t.safetyAdminUpper,
                    description: ru
                        ? 'Жалобы и проверки'
                        : 'Reports and safety',
                    icon: Icons.health_and_safety_rounded,
                    group: _AdminActionGroup.queue,
                    badge: countsAsync.maybeWhen(
                      data: (value) => value.safety,
                      orElse: () => 0,
                    ),
                    onTap: () => context.go(Routes.safetyAdmin),
                  ),
                  _AdminAction(
                    label: Localizations.localeOf(context).languageCode == 'ru'
                        ? 'ЖУРНАЛ ДЕЙСТВИЙ'
                        : 'ACTION LOG',
                    description: ru ? 'Audit и история' : 'Audit and history',
                    icon: Icons.history_rounded,
                    group: _AdminActionGroup.audit,
                    onTap: () => context.go(Routes.profileActionAuditAdmin),
                  ),
                ],
                onExit: signOutAndGoLogin,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ForbiddenView extends StatelessWidget {
  const _ForbiddenView({
    required this.message,
    required this.exitLabel,
    required this.onExit,
  });

  final String message;
  final String exitLabel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminTopBar(exitLabel: exitLabel, onExit: onExit),
        const SizedBox(height: _kAdminSectionGap),
        Expanded(
          child: Center(
            child: _AdminSurface(
              maxWidth: _kAdminMaxCardWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _kAdminMessagePadV,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: adminCommandStyle(size: 14, letterSpacing: 1.1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({
    required this.exitLabel,
    required this.counts,
    required this.actions,
    required this.onExit,
  });

  final String exitLabel;
  final AdminDashboardCounts counts;
  final List<_AdminAction> actions;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final queue = actions
        .where((item) => item.group == _AdminActionGroup.queue)
        .toList(growable: false);
    final operations = actions
        .where((item) => item.group == _AdminActionGroup.operations)
        .toList(growable: false);
    final audit = actions
        .where((item) => item.group == _AdminActionGroup.audit)
        .toList(growable: false);

    return Column(
      children: [
        _AdminTopBar(exitLabel: exitLabel, onExit: onExit),
        const SizedBox(height: _kAdminSectionGap),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              _AdminDashboardHeader(
                title: ru ? 'BACK-OFFICE' : 'BACK OFFICE',
                subtitle: ru
                    ? 'Заявки, безопасность, подборки, кастинги и журнал действий'
                    : 'Requests, safety, selections, castings and audit log',
                total: counts.total,
              ),
              const SizedBox(height: 14),
              _AdminStatGrid(counts: counts),
              const SizedBox(height: 18),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _AdminActionSection(
                        title: ru ? 'ОЧЕРЕДЬ' : 'QUEUE',
                        items: queue,
                        dense: false,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _AdminActionSection(
                            title: ru ? 'ОПЕРАЦИИ' : 'OPERATIONS',
                            items: operations,
                            dense: true,
                          ),
                          const SizedBox(height: 14),
                          _AdminActionSection(
                            title: ru ? 'КОНТРОЛЬ' : 'CONTROL',
                            items: audit,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _AdminActionSection(
                  title: ru ? 'ОЧЕРЕДЬ' : 'QUEUE',
                  items: queue,
                  dense: false,
                ),
                const SizedBox(height: 14),
                _AdminActionSection(
                  title: ru ? 'ОПЕРАЦИИ' : 'OPERATIONS',
                  items: operations,
                  dense: false,
                ),
                const SizedBox(height: 14),
                _AdminActionSection(
                  title: ru ? 'КОНТРОЛЬ' : 'CONTROL',
                  items: audit,
                  dense: false,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _AdminActionGroup { queue, operations, audit }

class _AdminAction {
  const _AdminAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.group,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final String description;
  final IconData icon;
  final _AdminActionGroup group;
  final VoidCallback onTap;
  final int badge;
}

class _AdminDashboardHeader extends StatelessWidget {
  const _AdminDashboardHeader({
    required this.title,
    required this.subtitle,
    required this.total,
  });

  final String title;
  final String subtitle;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _AdminPanelSurface(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: adminCommandStyle(size: 24, letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: adminBodyStyle(
                    size: 14,
                    color: kTextMuted,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _AdminBadge(count: total, large: true),
        ],
      ),
    );
  }
}

class _AdminStatGrid extends StatelessWidget {
  const _AdminStatGrid({required this.counts});

  final AdminDashboardCounts counts;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final stats = [
      (label: ru ? 'МОДЕРАЦИЯ' : 'MODERATION', value: counts.moderation),
      (label: ru ? 'ЗАЯВКИ' : 'REQUESTS', value: counts.agentApplications),
      (label: ru ? 'MERGE' : 'MERGE', value: counts.accountMerges),
      (label: ru ? 'SAFETY' : 'SAFETY', value: counts.safety),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 4 : 2;
        final gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in stats)
              SizedBox(
                width: itemWidth,
                child: _AdminPanelSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: adminCommandStyle(
                            size: 12,
                            letterSpacing: 1.0,
                            color: kTextMuted,
                          ),
                        ),
                      ),
                      Text(
                        '${item.value}',
                        style: adminCommandStyle(
                          size: 24,
                          letterSpacing: 0,
                          color: item.value > 0 ? BrandTheme.redTop : kTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminActionSection extends StatelessWidget {
  const _AdminActionSection({
    required this.title,
    required this.items,
    required this.dense,
  });

  final String title;
  final List<_AdminAction> items;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _AdminPanelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: adminCommandStyle(size: 15, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++) ...[
            _AdminActionTile(action: items[i], dense: dense),
            if (i != items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({required this.action, required this.dense});

  final _AdminAction action;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: action.onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 14,
            vertical: dense ? 12 : 14,
          ),
          decoration: catalogSearchDecoration(
            radius: 22,
            borderColor: action.badge > 0
                ? BrandTheme.redTop.withValues(alpha: 0.48)
                : kBorderColor,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: BrandTheme.darkPillGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: adminCommandStyle(
                        size: dense ? 13 : 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: adminBodyStyle(
                        size: 12,
                        color: kTextMuted,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (action.badge > 0) _AdminBadge(count: action.badge),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge({required this.count, this.large = false});

  final int count;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: large ? 42 : 26),
      height: large ? 42 : 26,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8),
      decoration: BoxDecoration(
        color: count > 0
            ? BrandTheme.redTop
            : kTextMuted.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: adminCommandStyle(
          size: large ? 16 : 11,
          letterSpacing: 0,
          color: count > 0 ? Colors.white : kTextMuted,
        ),
      ),
    );
  }
}

class _AdminPanelSurface extends StatelessWidget {
  const _AdminPanelSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: catalogCardDecoration(),
      child: child,
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.exitLabel, required this.onExit});

  final String exitLabel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _AdminSurface(
      child: Align(
        alignment: Alignment.centerLeft,
        child: BrandPillButton(
          label: exitLabel,
          style: BrandPillStyle.dark,
          onTap: onExit,
        ),
      ),
    );
  }
}

class _AdminSurface extends StatelessWidget {
  const _AdminSurface({required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      constraints: maxWidth == null
          ? null
          : const BoxConstraints(maxWidth: _kAdminMaxCardWidth),
      padding: const EdgeInsets.all(_kAdminPad),
      decoration: catalogCardDecoration(),
      child: child,
    );

    if (maxWidth == null) return content;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: content,
    );
  }
}
