part of 'catalog_page.dart';

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _CatalogSearchRow extends StatelessWidget {
  const _CatalogSearchRow({
    required this.controller,
    required this.onChanged,
    required this.hintText,
    required this.items,
    required this.selectedIds,
    required this.canSelect,
    required this.onSelectAllTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final List<ModelVm> items;
  final Set<String> selectedIds;
  final bool canSelect;
  final ValueChanged<List<ModelVm>> onSelectAllTap;

  bool _areAllVisibleSelected() {
    if (items.isEmpty) return false;
    for (final m in items) {
      if (!selectedIds.contains(m.id)) return false;
    }
    return true;
  }

  bool _areSomeVisibleSelected() {
    for (final m in items) {
      if (selectedIds.contains(m.id)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _areAllVisibleSelected();
    final someSelected = _areSomeVisibleSelected();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SearchBar(
                controller: controller,
                onChanged: onChanged,
                hintText: hintText,
              ),
            ),
            if (canSelect) ...[
              const SizedBox(width: kGap10),
              _SelectAllPill(
                value: items.isEmpty
                    ? false
                    : (allSelected ? true : (someSelected ? null : false)),
                onTap: () => onSelectAllTap(items),
              ),
            ],
          ],
        ),
        const SizedBox(height: kGap12),
      ],
    );
  }
}

class _SavedSearchRail extends StatelessWidget {
  const _SavedSearchRail({
    required this.searches,
    required this.activeFilters,
    required this.onApply,
    required this.onRename,
    required this.onSaveCurrent,
    required this.onDelete,
    required this.saveLabel,
    required this.canSaveCurrent,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    this.isVertical = false,
  });

  final List<CatalogSavedSearch> searches;
  final CatalogFilterSnapshot activeFilters;
  final ValueChanged<CatalogSavedSearch> onApply;
  final ValueChanged<CatalogSavedSearch> onRename;
  final VoidCallback? onSaveCurrent;
  final ValueChanged<CatalogSavedSearch> onDelete;
  final String saveLabel;
  final bool canSaveCurrent;
  final bool isLoading;
  final Object? error;
  final Future<void> Function()? onRefresh;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    final status = _SavedSearchStatus(
      isLoading: isLoading,
      error: error,
      onRefresh: onRefresh,
      isVertical: isVertical,
    );
    final hasStatus = isLoading || error != null;

    if (!canSaveCurrent && searches.isEmpty && !hasStatus) {
      return const SizedBox.shrink();
    }

    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canSaveCurrent) ...[
            _SavedSearchSaveChip(
              label: saveLabel,
              onTap: onSaveCurrent,
              isExpanded: true,
            ),
            const SizedBox(height: kGap8),
          ],
          if (hasStatus) ...[status, const SizedBox(height: kGap8)],
          for (final search in searches) ...[
            _SavedSearchChip(
              search: search,
              selected: search.filters == activeFilters,
              onTap: () => onApply(search),
              onRename: search.isBuiltin ? null : () => onRename(search),
              onDelete: search.isBuiltin ? null : () => onDelete(search),
              isExpanded: true,
            ),
            const SizedBox(height: kGap8),
          ],
        ],
      );
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount:
            searches.length + (canSaveCurrent ? 1 : 0) + (hasStatus ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: kGap8),
        itemBuilder: (context, index) {
          if (canSaveCurrent && index == 0) {
            return _SavedSearchSaveChip(label: saveLabel, onTap: onSaveCurrent);
          }

          final searchIndex = index - (canSaveCurrent ? 1 : 0);
          if (hasStatus && searchIndex == 0) {
            return status;
          }

          final search = searches[searchIndex - (hasStatus ? 1 : 0)];
          return _SavedSearchChip(
            search: search,
            selected: search.filters == activeFilters,
            onTap: () => onApply(search),
            onRename: search.isBuiltin ? null : () => onRename(search),
            onDelete: search.isBuiltin ? null : () => onDelete(search),
          );
        },
      ),
    );
  }
}

class _SavedSearchStatus extends StatelessWidget {
  const _SavedSearchStatus({
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.isVertical,
  });

  final bool isLoading;
  final Object? error;
  final Future<void> Function()? onRefresh;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isError = error != null;
    final label = isLoading
        ? (t.localeName.toLowerCase().startsWith('ru') ? 'ЗАГРУЗКА' : 'LOADING')
        : AppErrorMapper.message(error!, t);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: isLoading ? null : onRefresh,
        child: Container(
          height: isVertical ? 48 : 42,
          width: isVertical ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(kPillRadius),
            border: Border.all(
              color: isError ? BrandTheme.redTop : kBorderColor,
            ),
          ),
          child: Row(
            mainAxisSize: isVertical ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.refresh_rounded,
                  color: isError ? BrandTheme.redTop : kTextDark,
                  size: 18,
                ),
              const SizedBox(width: 8),
              if (isVertical)
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrandTheme.pillText.copyWith(
                      color: isError ? BrandTheme.redTop : kTextMid,
                      fontSize: 11,
                      letterSpacing: 0.55,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: isError ? BrandTheme.redTop : kTextMid,
                    fontSize: 11,
                    letterSpacing: 0.55,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedSearchSaveChip extends StatelessWidget {
  const _SavedSearchSaveChip({
    required this.label,
    required this.onTap,
    this.isExpanded = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Container(
          height: 42,
          width: isExpanded ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: pillDecoration(isDark: true, radius: kPillRadius),
          child: Row(
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              const Icon(
                Icons.bookmark_add_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 7),
              if (isExpanded)
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrandTheme.pillText.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 0.75,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 0.75,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedSearchChip extends StatelessWidget {
  const _SavedSearchChip({
    required this.search,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    this.isExpanded = false,
  });

  final CatalogSavedSearch search;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? BrandTheme.redTop
        : Colors.white.withValues(alpha: 0.92);
    final fg = selected ? Colors.white : kTextDark;
    final subtitle = _savedSearchSubtitle(context, search.filters);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Container(
          height: isExpanded ? 56 : 42,
          width: isExpanded ? double.infinity : null,
          padding: EdgeInsets.only(left: 14, right: onDelete == null ? 14 : 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(kPillRadius),
            border: Border.all(
              color: selected ? BrandTheme.redTop : kBorderColor,
            ),
          ),
          child: Row(
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(
                search.isBuiltin
                    ? Icons.auto_awesome_rounded
                    : Icons.bookmark_rounded,
                color: fg,
                size: 17,
              ),
              const SizedBox(width: 7),
              if (isExpanded)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        search.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BrandTheme.pillText.copyWith(
                          color: fg,
                          fontSize: 12,
                          letterSpacing: 0.55,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg.withValues(alpha: selected ? 0.74 : 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Text(
                  search.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: fg,
                    fontSize: 12,
                    letterSpacing: 0.55,
                  ),
                ),
              if (onRename != null || onDelete != null) ...[
                const SizedBox(width: 3),
                _SavedSearchMenuButton(
                  color: fg,
                  onRename: onRename,
                  onDelete: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedSearchMenuButton extends StatelessWidget {
  const _SavedSearchMenuButton({
    required this.color,
    required this.onRename,
    required this.onDelete,
  });

  final Color color;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<_SavedSearchAction>(
        padding: EdgeInsets.zero,
        tooltip: '',
        icon: Icon(Icons.more_horiz_rounded, size: 19, color: color),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (action) {
          switch (action) {
            case _SavedSearchAction.rename:
              onRename?.call();
              break;
            case _SavedSearchAction.delete:
              onDelete?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          if (onRename != null)
            PopupMenuItem(
              value: _SavedSearchAction.rename,
              child: _SavedSearchMenuItem(
                icon: Icons.edit_rounded,
                label: t.savedSearchRenameAction,
              ),
            ),
          if (onDelete != null)
            PopupMenuItem(
              value: _SavedSearchAction.delete,
              child: _SavedSearchMenuItem(
                icon: Icons.delete_outline_rounded,
                label: t.savedSearchDeleteAction,
                isDanger: true,
              ),
            ),
        ],
      ),
    );
  }
}

enum _SavedSearchAction { rename, delete }

class _SavedSearchMenuItem extends StatelessWidget {
  const _SavedSearchMenuItem({
    required this.icon,
    required this.label,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? kTextDanger : kTextDark;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

String _savedSearchSubtitle(
  BuildContext context,
  CatalogFilterSnapshot filters,
) {
  final t = AppLocalizations.of(context)!;
  final isRussian =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
  final parts = <String>[];

  if (filters.query.trim().isNotEmpty) {
    parts.add(filters.query.trim());
  }
  if (filters.profileRole != null) {
    parts.add(_catalogProfileTypeLabel(t, filters.profileRole!));
  }
  if (_hasAdvancedCatalogFilters(filters)) {
    parts.add(isRussian ? 'параметры' : 'filters');
  }

  return parts.take(3).join(' • ');
}

bool _hasAdvancedCatalogFilters(CatalogFilterSnapshot filters) {
  return filters.ageFrom != null ||
      filters.ageTo != null ||
      filters.heightFrom != null ||
      filters.heightTo != null ||
      filters.shoeFrom != null ||
      filters.shoeTo != null ||
      filters.bustFrom != null ||
      filters.bustTo != null ||
      filters.waistFrom != null ||
      filters.waistTo != null ||
      filters.hipsFrom != null ||
      filters.hipsTo != null ||
      filters.minHourlyRateFrom != null ||
      filters.minHourlyRateTo != null ||
      filters.minDailyFeeFrom != null ||
      filters.minDailyFeeTo != null ||
      filters.eyeColor.trim().isNotEmpty ||
      filters.hairColor.trim().isNotEmpty ||
      filters.country.trim().isNotEmpty ||
      filters.city.trim().isNotEmpty ||
      filters.needDate != null;
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState({
    required this.onRefresh,
    required this.title,
    required this.subtitle,
  });

  final Future<void> Function() onRefresh;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: onRefresh,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          const SizedBox(height: kGap120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kEmptyHorizontalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 54,
                    color: kTextMuted,
                  ),
                  const SizedBox(height: kGap12),
                  Text(
                    title,
                    style: BrandTheme.pillText.copyWith(
                      color: kTextMid,
                      fontSize: 15,
                      letterSpacing: 0.4,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: kGap8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kTextMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
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

class _CatalogDesktopLayout extends StatelessWidget {
  const _CatalogDesktopLayout({
    required this.topBar,
    required this.onAdvancedSearch,
    required this.advancedSearchEnabled,
    required this.onResetFilters,
    required this.resetFiltersLabel,
    required this.roleTabs,
    required this.search,
    required this.grid,
    required this.detail,
    this.savedSearches,
  });

  final Widget topBar;
  final VoidCallback onAdvancedSearch;
  final bool advancedSearchEnabled;
  final Future<void> Function()? onResetFilters;
  final String resetFiltersLabel;
  final Widget roleTabs;
  final Widget search;
  final Widget? savedSearches;
  final Widget grid;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        topBar,
        const SizedBox(height: 18),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _catalogDesktopSidePanelWidth,
                child: _CatalogDesktopFilterPanel(
                  search: search,
                  onAdvancedSearch: onAdvancedSearch,
                  advancedSearchEnabled: advancedSearchEnabled,
                  onResetFilters: onResetFilters,
                  resetFiltersLabel: resetFiltersLabel,
                  roleTabs: roleTabs,
                  savedSearches: savedSearches,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(child: grid),
              const SizedBox(width: 18),
              SizedBox(width: _catalogDesktopDetailWidth, child: detail),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogDesktopFilterPanel extends StatelessWidget {
  const _CatalogDesktopFilterPanel({
    required this.search,
    required this.onAdvancedSearch,
    required this.advancedSearchEnabled,
    required this.onResetFilters,
    required this.resetFiltersLabel,
    required this.roleTabs,
    this.savedSearches,
  });

  final Widget search;
  final VoidCallback onAdvancedSearch;
  final bool advancedSearchEnabled;
  final Future<void> Function()? onResetFilters;
  final String resetFiltersLabel;
  final Widget roleTabs;
  final Widget? savedSearches;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration(),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            t.catalogUpper,
            style: BrandTheme.pillText.copyWith(
              color: kTextDark,
              fontSize: 17,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 14),
          search,
          const SizedBox(height: 12),
          roleTabs,
          const SizedBox(height: 6),
          _DesktopFilterAction(
            icon: Icons.tune_rounded,
            label: t.advancedSearchUpper,
            onTap: advancedSearchEnabled ? onAdvancedSearch : null,
          ),
          if (onResetFilters != null) ...[
            const SizedBox(height: 8),
            _DesktopFilterAction(
              icon: Icons.restart_alt_rounded,
              label: resetFiltersLabel,
              onTap: onResetFilters,
            ),
          ],
          if (savedSearches != null) ...[
            const SizedBox(height: 18),
            Text(
              t.savedSearchSaveTitle,
              style: BrandTheme.pillText.copyWith(
                color: kTextMid,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            savedSearches!,
          ],
        ],
      ),
    );
  }
}

class _DesktopFilterAction extends StatelessWidget {
  const _DesktopFilterAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: pillDecoration(isDark: false, radius: kPillRadius),
          child: Row(
            children: [
              Icon(icon, color: kTextDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: kTextDark,
                    fontSize: 12,
                    letterSpacing: 0.8,
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

class _CatalogRoleTabs extends StatelessWidget {
  const _CatalogRoleTabs({required this.selectedRole, required this.onChanged});

  final ProfessionalProfileType? selectedRole;
  final ValueChanged<ProfessionalProfileType?> onChanged;

  static const _roles = <ProfessionalProfileType>[
    ProfessionalProfileType.model,
    ProfessionalProfileType.actor,
    ProfessionalProfileType.photographer,
    ProfessionalProfileType.videographer,
    ProfessionalProfileType.stylist,
    ProfessionalProfileType.makeupArtist,
    ProfessionalProfileType.hairStylist,
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final label = selectedRole == null
        ? (isRussian ? 'ВСЕ' : 'ALL')
        : _catalogProfileTypeLabel(t, selectedRole!).toUpperCase();
    final icon = selectedRole == null
        ? Icons.grid_view_rounded
        : _catalogRoleIcon(selectedRole!);

    return _CatalogRoleSelectorButton(
      label: label,
      icon: icon,
      onTap: () async {
        final choice = await showModalBottomSheet<_CatalogRoleChoice>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => _CatalogRolePickerSheet(
            roles: _roles,
            selectedRole: selectedRole,
          ),
        );
        if (!context.mounted) return;
        if (choice == null) return;
        onChanged(choice.role);
      },
    );
  }
}

class _CatalogRoleChoice {
  const _CatalogRoleChoice(this.role);

  final ProfessionalProfileType? role;
}

class _CatalogRoleSelectorButton extends StatelessWidget {
  const _CatalogRoleSelectorButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 118),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: pillDecoration(isDark: false, radius: kPillRadius),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: kTextDark),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: kTextDark,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: kTextDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogRolePickerSheet extends StatelessWidget {
  const _CatalogRolePickerSheet({
    required this.roles,
    required this.selectedRole,
  });

  final List<ProfessionalProfileType> roles;
  final ProfessionalProfileType? selectedRole;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final items =
        <({ProfessionalProfileType? role, String label, IconData icon})>[
          (
            role: null,
            label: isRussian ? 'ВСЕ' : 'ALL',
            icon: Icons.grid_view_rounded,
          ),
          for (final role in roles)
            (
              role: role,
              label: _catalogProfileTypeLabel(t, role).toUpperCase(),
              icon: _catalogRoleIcon(role),
            ),
        ];

    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kBorderColor),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isRussian ? 'РОЛЬ В КАТАЛОГЕ' : 'CATALOG ROLE',
                    style: BrandTheme.pillText.copyWith(
                      color: kTextDark,
                      fontSize: 16,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _CatalogRoleSheetTile(
                    label: item.label,
                    icon: item.icon,
                    selected: selectedRole == item.role,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_CatalogRoleChoice(item.role)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogRoleSheetTile extends StatelessWidget {
  const _CatalogRoleSheetTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : kTextDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: selected
              ? pillDecoration(isDark: true, radius: 20)
              : pillDecoration(isDark: false, radius: 20),
          child: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: color,
                    fontSize: 13,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _catalogRoleIcon(ProfessionalProfileType role) {
  return switch (role) {
    ProfessionalProfileType.model => Icons.person_rounded,
    ProfessionalProfileType.actor => Icons.theater_comedy_rounded,
    ProfessionalProfileType.photographer => Icons.photo_camera_rounded,
    ProfessionalProfileType.videographer => Icons.videocam_rounded,
    ProfessionalProfileType.stylist => Icons.checkroom_rounded,
    ProfessionalProfileType.makeupArtist => Icons.brush_rounded,
    ProfessionalProfileType.hairStylist => Icons.content_cut_rounded,
  };
}

class _CatalogResultsBody extends StatelessWidget {
  const _CatalogResultsBody({
    required this.controller,
    required this.filteredItems,
    required this.selectedIds,
    required this.gridController,
    required this.onRefresh,
    required this.onOpenModel,
    required this.onToggleSelected,
    required this.onQuickAdd,
    required this.onPreviewPhoto,
    required this.onHidePreviewPhoto,
    required this.isSelectionMode,
    required this.canSelect,
    required this.cmLabel,
    required this.bottomInset,
    required this.onAutoLoadMore,
  });

  final CatalogController controller;
  final List<ModelVm> filteredItems;
  final Set<String> selectedIds;
  final ScrollController gridController;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String modelId) onOpenModel;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<ModelVm> onQuickAdd;
  final void Function(String heroTag, String photoUrl) onPreviewPhoto;
  final VoidCallback onHidePreviewPhoto;
  final bool isSelectionMode;
  final bool canSelect;
  final String cmLabel;
  final double bottomInset;
  final VoidCallback onAutoLoadMore;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (controller.isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kTextDark),
        ),
      );
    }

    if (controller.lastError != null && controller.loaded.isEmpty) {
      return _CatalogEmptyState(
        onRefresh: onRefresh,
        title: AppErrorMapper.message(controller.lastError!, t),
        subtitle: t.retryUpper,
      );
    }

    controller.maybeAutoFillMore(itemsEmpty: filteredItems.isEmpty);
    if (controller.shouldAutoFillNow && filteredItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onAutoLoadMore());
    }

    if (filteredItems.isEmpty) {
      return _CatalogEmptyState(
        onRefresh: onRefresh,
        title: t.noApprovedProfilesYet,
        subtitle: t.catalogSearchHintUpper,
      );
    }

    return _CatalogGrid(
      items: filteredItems,
      selectedIds: selectedIds,
      gridController: gridController,
      onRefresh: onRefresh,
      onOpenModel: onOpenModel,
      onToggleSelected: onToggleSelected,
      onQuickAdd: onQuickAdd,
      onPreviewPhoto: onPreviewPhoto,
      onHidePreviewPhoto: onHidePreviewPhoto,
      isSelectionMode: isSelectionMode,
      canSelect: canSelect,
      cmLabel: cmLabel,
      bottomInset: bottomInset,
    );
  }
}

class _CatalogDesktopPreview extends StatelessWidget {
  const _CatalogDesktopPreview({
    required this.model,
    required this.cmLabel,
    required this.onOpen,
    required this.onQuickAdd,
    required this.canUseAgentTools,
  });

  final ModelVm? model;
  final String cmLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onQuickAdd;
  final bool canUseAgentTools;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = model;

    return Container(
      decoration: catalogCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: m == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.noApprovedProfilesYet,
                  textAlign: TextAlign.center,
                  style: BrandTheme.pillText.copyWith(
                    color: kTextMuted,
                    fontSize: 14,
                    letterSpacing: 0.4,
                    height: 1.2,
                  ),
                ),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                AspectRatio(
                  aspectRatio: 0.86,
                  child: m.primaryPhotoUrl == null
                      ? const _CatalogPhotoPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: m.primaryPhotoUrl!,
                          memCacheWidth: _catalogOverlayPhotoCacheWidth,
                          maxWidthDiskCache: _catalogOverlayPhotoCacheWidth,
                          fit: BoxFit.cover,
                          alignment: _catalogCoverAlignmentFor(m),
                          placeholder: (_, _) =>
                              const _CatalogPhotoPlaceholder(),
                          errorWidget: (_, _, _) =>
                              const _CatalogPhotoPlaceholder(),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.fullName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kTextTitle,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (m.isProActive) const _ProBadge(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _PreviewInfoLine(
                        icon: Icons.badge_rounded,
                        text: _catalogProfileRolesLabel(
                          t,
                          m.effectiveProfileRoles,
                        ),
                      ),
                      _PreviewInfoLine(
                        icon: Icons.straighten_rounded,
                        text: '${m.age} • ${m.height} $cmLabel',
                      ),
                      if (m.city.isNotEmpty || m.country.isNotEmpty)
                        _PreviewInfoLine(
                          icon: Icons.place_rounded,
                          text: [m.city, m.country]
                              .where((value) => value.trim().isNotEmpty)
                              .join(', '),
                        ),
                      if (m.photoUrls.isNotEmpty || m.videoUrls.isNotEmpty)
                        _PreviewInfoLine(
                          icon: Icons.perm_media_rounded,
                          text:
                              '${m.photoUrls.length} фото • ${m.videoUrls.length} видео',
                        ),
                      if (m.resume.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          m.resume,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kTextMid,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.28,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _PreviewButton(
                        label: t.profileUpper,
                        isDark: true,
                        icon: Icons.open_in_new_rounded,
                        onTap: onOpen,
                      ),
                      if (canUseAgentTools) ...[
                        const SizedBox(height: 10),
                        _PreviewButton(
                          label: t.quickAddTitleUpper,
                          isDark: false,
                          icon: Icons.playlist_add_rounded,
                          onTap: onQuickAdd,
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

class _PreviewInfoLine extends StatelessWidget {
  const _PreviewInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kTextMid,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.1,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.label,
    required this.isDark,
    required this.icon,
    this.onTap,
  });

  final String label;
  final bool isDark;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : kTextDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: pillDecoration(isDark: isDark, radius: kPillRadius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: color,
                    fontSize: 13,
                    letterSpacing: 1.0,
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

String _catalogProfileTypeLabel(
  AppLocalizations t,
  ProfessionalProfileType type,
) {
  return switch (type) {
    ProfessionalProfileType.model => t.profileTypeModel,
    ProfessionalProfileType.actor => t.profileTypeActor,
    ProfessionalProfileType.photographer => t.profileTypePhotographer,
    ProfessionalProfileType.videographer => t.profileTypeVideographer,
    ProfessionalProfileType.stylist => t.profileTypeStylist,
    ProfessionalProfileType.makeupArtist => t.profileTypeMakeupArtist,
    ProfessionalProfileType.hairStylist => t.profileTypeHairStylist,
  };
}

String _catalogProfileRolesLabel(
  AppLocalizations t,
  Iterable<ProfessionalProfileType> roles,
) {
  return normalizeProfileRoles(
    roles,
  ).map((role) => _catalogProfileTypeLabel(t, role)).join(' • ');
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({
    required this.items,
    required this.selectedIds,
    required this.gridController,
    required this.onRefresh,
    required this.onOpenModel,
    required this.onToggleSelected,
    required this.onQuickAdd,
    required this.onPreviewPhoto,
    required this.onHidePreviewPhoto,
    required this.isSelectionMode,
    required this.canSelect,
    required this.cmLabel,
    required this.bottomInset,
  });

  final List<ModelVm> items;
  final Set<String> selectedIds;
  final ScrollController gridController;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String modelId) onOpenModel;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<ModelVm> onQuickAdd;
  final void Function(String heroTag, String photoUrl) onPreviewPhoto;
  final VoidCallback onHidePreviewPhoto;
  final bool isSelectionMode;
  final bool canSelect;
  final String cmLabel;
  final double bottomInset;

  int _crossAxisCount(double width) {
    if (width >= 1120) return 4;
    if (width >= 780) return 3;
    return kGridCrossAxisCount;
  }

  double _childAspectRatio(int columns) {
    if (columns >= 4) return 0.68;
    if (columns == 3) return 0.69;
    return kGridChildAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _crossAxisCount(constraints.maxWidth);
          return GridView.builder(
            controller: gridController,
            padding: kGridPadding.copyWith(
              bottom: kGridPadding.bottom + bottomInset,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: kGridGap,
              mainAxisSpacing: kGridGap,
              childAspectRatio: _childAspectRatio(columns),
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final selected = selectedIds.contains(m.id);
              final photo = m.primaryPhotoUrl;
              final heroTag = 'model-photo-${m.id}';

              return _GridProfileCard(
                onTap: () async {
                  if (canSelect && isSelectionMode) {
                    onToggleSelected(m.id);
                    return;
                  }
                  await onOpenModel(m.id);
                },
                onLongPressStart: photo == null
                    ? null
                    : (_) => onPreviewPhoto(heroTag, photo),
                onLongPressEnd: photo == null
                    ? null
                    : (_) => onHidePreviewPhoto(),
                onToggleSelected: () => onToggleSelected(m.id),
                onQuickAdd: () => onQuickAdd(m),
                isSelected: selected,
                canSelect: canSelect,
                name: m.fullName,
                ageText: '${m.age}',
                heightText: '${m.height} $cmLabel',
                photoUrl: photo,
                coverAlignment: _catalogCoverAlignmentFor(m),
                heroTag: heroTag,
                isPro: m.isProActive,
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchBarState extends State<_SearchBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final hasFocus = _focusNode.hasFocus;

    final radius = BorderRadius.circular(BrandTheme.pillRadius);

    return AnimatedContainer(
      duration: kAnim160,
      height: 58,
      decoration: catalogSearchDecoration(
        borderColor: hasFocus
            ? BrandTheme.redTop
            : Colors.white.withValues(alpha: 0.72),
        borderWidth: hasFocus ? 1.4 : 1,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: radius,
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(
            color: kTextDark,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            hintStyle: BrandTheme.pillText.copyWith(
              color: kTextMuted,
              fontSize: 15,
              letterSpacing: 1.15,
            ),
            prefixIcon: const Icon(Icons.search, color: kTextMid, size: 28),
            suffixIcon: !hasText
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: kTextMuted),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: kSearchContentPad,
          ),
        ),
      ),
    );
  }
}

class _GridProfileCard extends StatelessWidget {
  const _GridProfileCard({
    required this.onTap,
    required this.onToggleSelected,
    required this.onQuickAdd,
    required this.isSelected,
    required this.canSelect,
    required this.name,
    required this.ageText,
    required this.heightText,
    required this.photoUrl,
    required this.coverAlignment,
    required this.heroTag,
    required this.isPro,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final VoidCallback onTap;
  final VoidCallback onToggleSelected;
  final VoidCallback onQuickAdd;
  final bool isSelected;
  final bool canSelect;
  final String name;
  final String ageText;
  final String heightText;
  final String? photoUrl;
  final Alignment coverAlignment;
  final String heroTag;
  final bool isPro;

  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(LongPressEndDetails)? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        onLongPressEnd: onLongPressEnd,
        child: InkWell(
          borderRadius: BorderRadius.circular(kCardRadius),
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                decoration: catalogCardDecoration(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kCardRadius),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final photoH = (constraints.maxHeight - kInfoH).clamp(
                        0.0,
                        constraints.maxHeight,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: photoH,
                            width: double.infinity,
                            child: (photoUrl == null)
                                ? const _CatalogPhotoPlaceholder()
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Hero(
                                        tag: heroTag,
                                        child: CachedNetworkImage(
                                          imageUrl: photoUrl!,
                                          memCacheWidth:
                                              _catalogCardPhotoCacheWidth,
                                          maxWidthDiskCache:
                                              _catalogCardPhotoCacheWidth,
                                          fit: BoxFit.cover,
                                          alignment: coverAlignment,
                                          fadeInDuration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          placeholder: (_, _) =>
                                              const _CatalogPhotoPlaceholder(),
                                          errorWidget: (_, _, _) =>
                                              const _CatalogPhotoPlaceholder(),
                                        ),
                                      ),
                                      const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0x00000000),
                                              Color(0x14000000),
                                              Color(0x2A000000),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          Container(
                            height: kInfoH,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.98),
                                  const Color(
                                    0xFFF8F8F8,
                                  ).withValues(alpha: 0.96),
                                ],
                              ),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  width: 1,
                                ),
                              ),
                            ),
                            padding: kCardInfoPad,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: kTextTitle,
                                      height: 1.06,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: kGap4),
                                Text(
                                  ageText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kTextDanger,
                                    height: 1.05,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: kGap2),
                                Text(
                                  heightText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: kTextMuted,
                                    height: 1.05,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              if (isSelected)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: kAnim180,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(kCardRadius),
                    ),
                  ),
                ),

              if (canSelect)
                Positioned(
                  top: kCardCheckOffset,
                  right: kCardCheckOffset,
                  child: _CardCheck(value: isSelected, onTap: onToggleSelected),
                ),

              if (canSelect)
                Positioned(
                  top: isPro ? kCardCheckOffset + 42 : kCardCheckOffset,
                  left: kCardCheckOffset,
                  child: _QuickCardAction(onTap: onQuickAdd),
                ),

              if (isPro)
                const Positioned(
                  top: kCardCheckOffset,
                  left: kCardCheckOffset,
                  child: _ProBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogPhotoPlaceholder extends StatelessWidget {
  const _CatalogPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: catalogPhotoPlaceholderDecoration(),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.45, -0.35),
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: 0.46),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.person_rounded,
              size: 42,
              color: Colors.white.withValues(alpha: 0.56),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _QuickCardAction extends StatelessWidget {
  const _QuickCardAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardCheckRadius),
        onTap: onTap,
        child: Container(
          width: kCardCheckSize,
          height: kCardCheckSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(kCardCheckRadius),
            border: Border.all(color: kBorderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.playlist_add_rounded,
            size: 22,
            color: BrandTheme.redTop,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onAdvancedSearch,
    required this.accountLabel,
    required this.advancedSearchEnabled,
    required this.isDesktop,
    this.onFolders,
    this.leading,
  });

  final VoidCallback onAdvancedSearch;
  final VoidCallback? onFolders;
  final String accountLabel;
  final bool advancedSearchEnabled;
  final bool isDesktop;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final leadingWidth = leading == null
        ? (isDesktop ? 72.0 : kTopBarIconBoxW)
        : 96.0;

    return Row(
      children: [
        SizedBox(
          width: leadingWidth,
          height: kTopBarH,
          child: Center(child: leading ?? const BrandLogo(height: kBrandLogoH)),
        ),
        const SizedBox(width: kGap10),
        Expanded(child: _AccountPill(text: accountLabel)),
        const SizedBox(width: kGap10),
        if (onFolders != null) ...[
          _IconPill(icon: Icons.folder_rounded, onTap: onFolders),
          const SizedBox(width: kGap10),
        ],
        _IconPill(
          icon: Icons.tune_rounded,
          onTap: advancedSearchEnabled ? onAdvancedSearch : null,
        ),
      ],
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarH,
      alignment: Alignment.center,
      padding: kAccountPad,
      decoration: pillDecoration(isDark: true, radius: BrandTheme.pillRadius),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: BrandTheme.pillText.copyWith(
          fontSize: 15,
          letterSpacing: 1.45,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CardCheck extends StatelessWidget {
  const _CardCheck({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardCheckRadius),
        onTap: onTap,
        child: Container(
          width: kCardCheckSize,
          height: kCardCheckSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(kCardCheckRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            value ? Icons.check_rounded : Icons.check_box_outline_blank_rounded,
            size: kCardCheckIconSize,
            color: value ? BrandTheme.redTop : kTextMuted,
          ),
        ),
      ),
    );
  }
}

class _SelectAllPill extends StatelessWidget {
  const _SelectAllPill({required this.value, required this.onTap});

  final bool? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = value == true
        ? Icons.check_box_rounded
        : (value == null
              ? Icons.indeterminate_check_box_rounded
              : Icons.check_box_outline_blank_rounded);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: onTap,
        child: Container(
          height: kSelectAllPillSize,
          width: kSelectAllPillSize,
          decoration: catalogSearchDecoration(),
          child: Icon(
            icon,
            color: BrandTheme.redTop,
            size: kSquarePillIconSize,
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: onTap,
        child: Container(
          width: kTopBarIconBoxW,
          height: kTopBarH,
          decoration: pillDecoration(isDark: false, radius: kSearchRadius),
          child: Icon(icon, color: kTextDark, size: kIconSizeSmall),
        ),
      ),
    );
  }
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({
    required this.modelName,
    required this.folders,
    required this.onFavorite,
    required this.onCreateSelection,
    required this.onCreateFolder,
    required this.onAddToFolder,
  });

  final String modelName;
  final List<AgentFolder> folders;
  final VoidCallback onFavorite;
  final VoidCallback onCreateSelection;
  final VoidCallback onCreateFolder;
  final ValueChanged<AgentFolder> onAddToFolder;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: pillDecoration(isDark: false, radius: kCardRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.quickAddTitleUpper,
                textAlign: TextAlign.center,
                style: BrandTheme.pillText.copyWith(
                  color: kTextDark,
                  fontSize: 15,
                  letterSpacing: 1.15,
                ),
              ),
              const SizedBox(height: kGap4),
              Text(
                modelName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: kGap14),
              Row(
                children: [
                  Expanded(
                    child: _QuickAddMainAction(
                      icon: Icons.favorite_rounded,
                      label: t.quickAddFavorite,
                      onTap: onFavorite,
                    ),
                  ),
                  const SizedBox(width: kGap10),
                  Expanded(
                    child: _QuickAddMainAction(
                      icon: Icons.dashboard_customize_rounded,
                      label: t.quickAddSelection,
                      onTap: onCreateSelection,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kGap14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.quickAddFolder,
                      style: BrandTheme.pillText.copyWith(
                        color: kTextDark,
                        fontSize: 14,
                        letterSpacing: 0.55,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onCreateFolder,
                    icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                    label: Text(t.quickAddCreateFolder),
                    style: TextButton.styleFrom(
                      foregroundColor: BrandTheme.redTop,
                      textStyle: BrandTheme.pillText.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                ],
              ),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: kGap4),
                  child: Text(
                    t.agentNoFolders,
                    style: const TextStyle(
                      color: kTextMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final folder in folders)
                      _QuickFolderChip(
                        label: folder.title,
                        onTap: () => onAddToFolder(folder),
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

class _QuickAddMainAction extends StatelessWidget {
  const _QuickAddMainAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: pillDecoration(isDark: true, radius: kSearchRadius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.55,
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

class _QuickFolderChip extends StatelessWidget {
  const _QuickFolderChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: pillDecoration(
            isDark: false,
            radius: 999,
          ).copyWith(border: Border.all(color: kBorderColor)),
          child: Text(
            label,
            style: BrandTheme.pillText.copyWith(
              color: kTextDark,
              fontSize: 12,
              letterSpacing: 0.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveSearchDialog extends StatefulWidget {
  const _SaveSearchDialog({
    required this.title,
    required this.hint,
    required this.emptyError,
    required this.cancelLabel,
    required this.saveLabel,
    this.initialValue = '',
  });

  final String title;
  final String hint;
  final String emptyError;
  final String cancelLabel;
  final String saveLabel;
  final String initialValue;

  @override
  State<_SaveSearchDialog> createState() => _SaveSearchDialogState();
}

class _SaveSearchDialogState extends State<_SaveSearchDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeWithValue() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = widget.emptyError);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kDialogInsetPad,
      child: Container(
        padding: kDialogBodyPad,
        decoration: pillDecoration(isDark: false, radius: kCardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: BrandTheme.pillText.copyWith(
                color: kTextDark,
                fontSize: 15,
                letterSpacing: 1.15,
              ),
            ),
            const SizedBox(height: kGap14),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _closeWithValue(),
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w500,
                fontSize: 16,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: _error,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.94),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kPillRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: kGap14),
            Row(
              children: [
                Expanded(
                  child: _SmallDialogButton(
                    label: widget.cancelLabel,
                    isDark: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: kDialogActionsGap),
                Expanded(
                  child: _SmallDialogButton(
                    label: widget.saveLabel,
                    isDark: true,
                    onTap: _closeWithValue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallDialogButton extends StatelessWidget {
  const _SmallDialogButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Container(
          padding: kDialogButtonPad,
          decoration: pillDecoration(isDark: isDark, radius: kPillRadius),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : kTextDark,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.9,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectModelsButton extends StatelessWidget {
  const _SelectModelsButton({
    required this.visible,
    required this.selectedCount,
    required this.isBusy,
    required this.onTap,
  });

  final bool visible;
  final int selectedCount;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: kBottomSafePad),
          child: AnimatedSlide(
            duration: kAnim180,
            curve: Curves.easeOut,
            offset: visible ? Offset.zero : const Offset(0, 0.35),
            child: AnimatedOpacity(
              duration: kAnim180,
              opacity: visible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !visible,
                child: SizedBox(
                  height: kSelectModelsButtonHeight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(kSearchRadius),
                      onTap: isBusy ? null : onTap,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: pillDecoration(
                          isDark: true,
                          radius: kSearchRadius,
                        ),
                        child: isBusy
                            ? const SizedBox(
                                width: kBusyIndicatorSize,
                                height: kBusyIndicatorSize,
                                child: CircularProgressIndicator(
                                  strokeWidth: kBusyIndicatorStrokeWidth,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                '${t.selectUpper}${selectedCount > 0 ? ' ($selectedCount)' : ''}',
                                style: BrandTheme.pillText.copyWith(
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
