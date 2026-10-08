import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/router.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../support/support_unread_provider.dart';
import 'selection_providers.dart';

/// Web admin layout: a 240 px section menu on the left, the page header and
/// the page body on the right. Every admin page uses it, so the sections
/// look the same and switching between them is one click.
const double kAdminShellNavWidth = 240;

/// Width below which the side menu collapses into a horizontal strip.
const double kAdminShellWideBreakpoint = 1100;

class _AdminShellSection {
  const _AdminShellSection({
    required this.route,
    required this.label,
    required this.icon,
    this.badge = 0,
  });

  final String route;
  final String label;
  final IconData icon;
  final int badge;
}

class _AdminShellGroup {
  const _AdminShellGroup({required this.title, required this.items});

  final String title;
  final List<_AdminShellSection> items;
}

/// Converts an admin label written in capitals («ВСЕ АНКЕТЫ») to sentence
/// case for the v2 headings.
String adminSentenceCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final cyrillic = RegExp(r'[А-ЯЁ]');
  final words = trimmed.split(' ').map((word) {
    if (word != word.toUpperCase() || word == word.toLowerCase()) return word;
    // Cyrillic capitals are never acronyms here («ВСЕ», «НЕТ»); Latin
    // ones up to three letters usually are (PDF, CSV, SLA, 2FA).
    final isAcronym = !cyrillic.hasMatch(word) && word.length <= 3;
    return isAcronym ? word : word.toLowerCase();
  }).toList();
  final joined = words.join(' ');
  return joined[0].toUpperCase() + joined.substring(1);
}

/// Page frame for admin sections. On the web it is the [AdminShellV2]
/// (side menu + header); on native it is the old card header inside a
/// Scaffold, exactly as before.
class AdminPageScaffold extends StatelessWidget {
  const AdminPageScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.children,
    this.subtitle,
    this.trailing,
    this.actions = const [],
    this.headerSideWidth = kTopBarIconBoxW,
    this.backgroundColor,
    this.brandBackground = false,
    this.padding = const EdgeInsets.all(16),
    this.headerGap = 12,
    this.scrollable = false,
    this.webPadding,
  });

  /// Header title (may be in capitals: the web shell lowercases it).
  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  /// Native: widget on the right of the card header. Web: placed in the
  /// header actions unless [actions] is given.
  final Widget? trailing;

  /// Web header actions (buttons on the right of the title).
  final List<Widget> actions;
  final double headerSideWidth;

  /// Native look.
  final Color? backgroundColor;
  final bool brandBackground;
  final EdgeInsets padding;
  final double headerGap;

  /// Content that goes after the header. With [scrollable] the children
  /// are put in a ListView, otherwise in a Column (use Expanded inside).
  final List<Widget> children;
  final bool scrollable;

  /// Web: padding around the body (defaults to the shell gutter).
  final EdgeInsets? webPadding;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return AdminShellV2(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        actions: actions.isNotEmpty
            ? actions
            : [if (trailing != null) trailing!],
        bodyPadding: webPadding,
        body: scrollable
            ? ListView(padding: EdgeInsets.zero, children: children)
            : Column(children: children),
      );
    }

    final header = BrandAdminHeader(
      title: title,
      onBack: onBack,
      trailing: trailing,
      sideWidth: headerSideWidth,
    );
    final content = scrollable
        ? ListView(
            padding: padding,
            children: [header, SizedBox(height: headerGap), ...children],
          )
        : Padding(
            padding: padding,
            child: Column(
              children: [header, SizedBox(height: headerGap), ...children],
            ),
          );
    if (brandBackground) {
      return Scaffold(
        body: Stack(
          children: [
            const BrandBackground(),
            SafeArea(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: backgroundColor ?? BrandTheme.greyMid,
      body: SafeArea(child: content),
    );
  }
}

/// The web admin frame itself.
class AdminShellV2 extends ConsumerWidget {
  const AdminShellV2({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.bodyPadding,
    this.headerBottom,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget body;
  final EdgeInsets? bodyPadding;

  /// Optional strip under the header (stats, tabs).
  final Widget? headerBottom;

  List<_AdminShellGroup> _groups(
    BuildContext context, {
    required AdminDashboardCounts counts,
    required int selections,
    required int support,
  }) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return [
      _AdminShellGroup(
        title: ru ? 'Обзор' : 'Overview',
        items: [
          _AdminShellSection(
            route: Routes.admin,
            label: ru ? 'Рабочий стол' : 'Dashboard',
            icon: Icons.space_dashboard_outlined,
          ),
        ],
      ),
      _AdminShellGroup(
        title: ru ? 'Очередь' : 'Queue',
        items: [
          _AdminShellSection(
            route: Routes.moderationAdmin,
            label: ru ? 'Модерация' : 'Moderation',
            icon: Icons.verified_user_outlined,
            badge: counts.moderation,
          ),
          _AdminShellSection(
            route: Routes.adminSupport,
            label: ru ? 'Поддержка' : 'Support',
            icon: Icons.support_agent_outlined,
            badge: support,
          ),
          _AdminShellSection(
            route: Routes.castingAgentApplicationsAdmin,
            label: ru ? 'Заявки на статус' : 'Role requests',
            icon: Icons.badge_outlined,
            badge: counts.agentApplications,
          ),
          _AdminShellSection(
            route: Routes.accountMergeRequestsAdmin,
            label: ru ? 'Объединения' : 'Account merges',
            icon: Icons.merge_type_rounded,
            badge: counts.accountMerges,
          ),
          _AdminShellSection(
            route: Routes.profileSlotRequestsAdmin,
            label: ru ? 'Дополнительные анкеты' : 'Extra profiles',
            icon: Icons.library_add_outlined,
            badge: counts.profileSlotRequests,
          ),
          _AdminShellSection(
            route: Routes.safetyAdmin,
            label: ru ? 'Безопасность' : 'Safety',
            icon: Icons.health_and_safety_outlined,
            badge: counts.safety,
          ),
        ],
      ),
      _AdminShellGroup(
        title: ru ? 'Данные' : 'Data',
        items: [
          _AdminShellSection(
            route: Routes.adminUsers,
            label: ru ? 'Пользователи' : 'Users',
            icon: Icons.groups_outlined,
          ),
          _AdminShellSection(
            route: Routes.adminProfiles,
            label: ru ? 'Анкеты' : 'Profiles',
            icon: Icons.view_list_outlined,
          ),
          _AdminShellSection(
            route: Routes.adminCastings,
            label: ru ? 'Кастинги' : 'Castings',
            icon: Icons.videocam_outlined,
          ),
          _AdminShellSection(
            route: Routes.adminSelectionsTable,
            label: ru ? 'Подборки' : 'Selections',
            icon: Icons.folder_copy_outlined,
          ),
          _AdminShellSection(
            route: Routes.adminSelection,
            label: ru ? 'Отбор' : 'Selection desk',
            icon: Icons.dashboard_customize_outlined,
            badge: selections,
          ),
        ],
      ),
      _AdminShellGroup(
        title: ru ? 'Контроль' : 'Control',
        items: [
          _AdminShellSection(
            route: Routes.profileActionAuditAdmin,
            label: ru ? 'Журнал действий' : 'Action log',
            icon: Icons.history_rounded,
          ),
        ],
      ),
    ];
  }

  String _activeRoute(BuildContext context, List<_AdminShellGroup> groups) {
    final location = GoRouterState.of(context).uri.path;
    String best = '';
    for (final group in groups) {
      for (final item in group.items) {
        final match =
            location == item.route || location.startsWith('${item.route}/');
        if (match && item.route.length > best.length) best = item.route;
      }
    }
    if (best.isEmpty) {
      // Pages without a menu entry (selection project, casting responses,
      // create casting) highlight the section they belong to.
      if (location.startsWith(Routes.adminSelectionProject)) {
        return Routes.adminSelection;
      }
      if (location.startsWith(Routes.createCastingAdmin)) {
        return Routes.adminCastings;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kAdminShellWideBreakpoint;
    final counts = ref
        .watch(adminDashboardCountsProvider)
        .maybeWhen(data: (v) => v, orElse: () => const AdminDashboardCounts());
    final selections = ref
        .watch(adminSelectionCountProvider)
        .maybeWhen(data: (v) => v, orElse: () => 0);
    final support = ref.watch(supportUnreadTotalProvider);
    final groups = _groups(
      context,
      counts: counts,
      selections: selections,
      support: support,
    );
    final active = _activeRoute(context, groups);
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    final gutter = wide ? 32.0 : 16.0;
    // With the side menu on screen a «Назад» link is noise; it stays for
    // the narrow layout where the menu is a strip.
    final onBack = wide ? null : this.onBack;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(gutter, onBack == null ? 28 : 16, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(ru ? 'Назад' : 'Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: Tokens.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    textStyle: AppText.smallStrong,
                  ),
                ),
              ),
            ),
          if (onBack != null) const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminSentenceCase(title),
                      maxLines: wide ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h1.copyWith(fontSize: wide ? 28 : 24),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: AppText.caption.copyWith(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ],
          ),
          if (headerBottom != null) ...[
            const SizedBox(height: 16),
            headerBottom!,
          ],
          const SizedBox(height: 20),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!wide)
          _AdminShellStrip(groups: groups, active: active),
        header,
        Expanded(
          child: Padding(
            padding:
                bodyPadding ?? EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
            child: body,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminShellNav(groups: groups, active: active),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
    );
  }
}

class _AdminShellNav extends StatelessWidget {
  const _AdminShellNav({required this.groups, required this.active});

  final List<_AdminShellGroup> groups;
  final String active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kAdminShellNavWidth,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Tokens.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
              child: Text(
                group.title.toUpperCase(),
                style: AppText.label.copyWith(color: Tokens.textTertiary),
              ),
            ),
            for (final item in group.items)
              _AdminShellNavItem(item: item, active: item.route == active),
          ],
        ],
      ),
    );
  }
}

class _AdminShellNavItem extends StatelessWidget {
  const _AdminShellNavItem({required this.item, required this.active});

  final _AdminShellSection item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? Tokens.surfaceAlt : Colors.transparent,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          onTap: active ? null : () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: active ? Tokens.text : Tokens.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small.copyWith(
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: Tokens.text,
                    ),
                  ),
                ),
                if (item.badge > 0) ...[
                  const SizedBox(width: 8),
                  AdminCountBadge(count: item.badge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Narrow screens: the sections as a horizontal strip under the top bar.
class _AdminShellStrip extends StatefulWidget {
  const _AdminShellStrip({required this.groups, required this.active});

  final List<_AdminShellGroup> groups;
  final String active;

  @override
  State<_AdminShellStrip> createState() => _AdminShellStripState();
}

class _AdminShellStripState extends State<_AdminShellStrip> {
  final _activeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
  }

  @override
  void didUpdateWidget(covariant _AdminShellStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
    }
  }

  // Scrolls the strip so the current section is on screen.
  void _revealActive() {
    final context = _activeKey.currentContext;
    if (context == null || !mounted) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.3,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [for (final g in widget.groups) ...g.items];
    final active = widget.active;
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final item = items[index];
          final isActive = item.route == active;
          return Material(
            key: isActive ? _activeKey : null,
            color: isActive ? Tokens.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            child: InkWell(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              onTap: isActive ? null : () => context.go(item.route),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      item.label,
                      style: AppText.smallStrong.copyWith(
                        color: isActive ? Colors.white : Tokens.text,
                      ),
                    ),
                    if (item.badge > 0) ...[
                      const SizedBox(width: 6),
                      AdminCountBadge(count: item.badge, onInk: isActive),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small count badge for the menu and headers: accent when non-zero.
class AdminCountBadge extends StatelessWidget {
  const AdminCountBadge({
    super.key,
    required this.count,
    this.onInk = false,
  });

  final int count;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: onInk ? Colors.white.withValues(alpha: 0.18) : Tokens.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// A row of counters under the page title: label on top, number below.
class AdminStatsRow extends StatelessWidget {
  const AdminStatsRow({super.key, required this.items});

  final List<({String label, int value, bool alert})> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 36,
      runSpacing: 14,
      children: [
        for (final item in items)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: AppText.caption.copyWith(color: Tokens.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.value}',
                style: AppText.h2.copyWith(
                  fontSize: 22,
                  color: item.alert && item.value > 0
                      ? Tokens.accent
                      : Tokens.text,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Status with a coloured dot («Одобрено», «На модерации»).
class AdminStatusV2 extends StatelessWidget {
  const AdminStatusV2({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(color: Tokens.text),
          ),
        ),
      ],
    );
  }
}

/// Flat filter chip for the admin toolbars.
class AdminChipV2 extends StatelessWidget {
  const AdminChipV2({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Tokens.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Tokens.ink : Tokens.bg,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(color: selected ? Tokens.ink : Tokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                adminSentenceCase(label),
                style: AppText.smallStrong.copyWith(
                  color: selected ? Colors.white : Tokens.text,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: AppText.small.copyWith(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.7)
                        : Tokens.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Header row of a flat table: small grey labels, hairline below.
class AdminTableHeaderV2 extends StatelessWidget {
  const AdminTableHeaderV2({
    super.key,
    required this.cells,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  /// Each cell is (label, flex or fixed width). Use `width` for a fixed
  /// column and `flex` otherwise.
  final List<AdminTableCellSpec> cells;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: padding,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.border)),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            cell.wrap(
              Text(
                adminSentenceCase(cell.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  color: Tokens.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminTableCellSpec {
  const AdminTableCellSpec(this.label, {this.flex, this.width});

  final String label;
  final int? flex;
  final double? width;

  Widget wrap(Widget child) {
    if (width != null) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: child,
        ),
      );
    }
    return Expanded(
      flex: flex ?? 1,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: child,
      ),
    );
  }
}

/// Table row: hairline below, hover tint, optional selection tint.
class AdminTableRowV2 extends StatelessWidget {
  const AdminTableRowV2({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.last = false,
    this.minHeight = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool last;
  final double minHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Tokens.surfaceAlt : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Tokens.surfaceAlt.withValues(alpha: 0.6),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Tokens.border)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Empty / loading / error text in place of a table.
class AdminEmptyV2 extends StatelessWidget {
  const AdminEmptyV2({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Text(
        adminSentenceCase(text),
        textAlign: TextAlign.center,
        style: AppText.small.copyWith(
          color: error ? Tokens.danger : Tokens.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

/// Queue row (web): title, a line of details, a note, the date on the
/// right and the decision buttons. Replaces the per-page cards.
class AdminQueueRowV2 extends StatelessWidget {
  const AdminQueueRowV2({
    super.key,
    required this.title,
    this.subtitle,
    this.details,
    this.note,
    this.date,
    this.status,
    this.actions = const [],
    this.last = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? details;
  final String? note;
  final String? date;
  final Widget? status;
  final List<Widget> actions;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong,
              ),
            ),
            if (status != null) ...[const SizedBox(width: 12), status!],
          ],
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(color: Tokens.text),
          ),
        ],
        if (details != null && details!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            details!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
        ],
        if (note != null && note!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            note!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(
              color: Tokens.textSecondary,
              height: 1.45,
            ),
          ),
        ],
        if (narrow && date != null && date!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(date!, style: AppText.caption),
        ],
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions[i],
        ],
      ],
    );

    return AdminTableRowV2(
      last: last,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  buttons,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                if (date != null && date!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Text(date!, style: AppText.caption),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 20),
                  buttons,
                ],
              ],
            ),
    );
  }
}

/// Small decision buttons for queue rows.
class AdminRowButton extends StatelessWidget {
  const AdminRowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final text = Text(adminSentenceCase(label));
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: AppText.smallStrong,
          backgroundColor: destructive ? Tokens.danger : null,
        ),
        child: text,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: AppText.smallStrong,
        foregroundColor: destructive ? Tokens.danger : null,
      ),
      child: text,
    );
  }
}

String adminDateV2(DateTime? date) {
  if (date == null) return '';
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
