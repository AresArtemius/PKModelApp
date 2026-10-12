import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/router.dart';
import '../../ui/brand/ui_constants.dart';
import '../support/support_unread_provider.dart';
import 'admin_shell_v2.dart';
import 'selection_providers.dart';

/// Phone: the «Админ» tab is a list of sections (grouped, with counters).
/// Each opens its page with a back arrow; the dashboard is one of them.
class AdminMenuPage extends ConsumerWidget {
  const AdminMenuPage({
    super.key,
    required this.onCreateCasting,
    required this.onExit,
  });

  final VoidCallback onCreateCasting;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final counts = ref
        .watch(adminDashboardCountsProvider)
        .maybeWhen(data: (v) => v, orElse: () => const AdminDashboardCounts());
    final selections = ref
        .watch(adminSelectionCountProvider)
        .maybeWhen(data: (v) => v, orElse: () => 0);
    final support = ref.watch(supportUnreadTotalProvider);
    final groups = adminShellGroups(
      context,
      counts: counts,
      selections: selections,
      support: support,
    );

    return AdminShellV2(
      title: ru ? 'Админ-панель' : 'Back office',
      menu: true,
      actions: [
        IconButton(
          tooltip: ru ? 'Создать кастинг' : 'Create casting',
          onPressed: onCreateCasting,
          icon: const Icon(Icons.add_rounded),
          color: Tokens.text,
        ),
        IconButton(
          tooltip: ru ? 'Выйти' : 'Sign out',
          onPressed: onExit,
          icon: const Icon(Icons.logout_rounded),
          color: Tokens.textSecondary,
        ),
      ],
      bodyPadding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
              child: Text(
                group.title.toUpperCase(),
                style: AppText.label.copyWith(color: Tokens.textTertiary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Tokens.border),
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < group.items.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, thickness: 1, color: Tokens.border),
                    _MenuRow(
                      item: group.items[i],
                      onTap: () => context.push(
                        group.items[i].route == Routes.admin
                            ? '${Routes.admin}?view=desk'
                            : group.items[i].route,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});

  final AdminShellSection item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: Tokens.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label, style: AppText.body)),
            if (item.badge > 0) ...[
              AdminCountBadge(count: item.badge),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: Tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}
