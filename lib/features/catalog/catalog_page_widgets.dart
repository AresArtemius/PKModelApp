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
              SizedBox(width: kIsWeb ? 8 : kGap10),
              _SelectAllPill(
                value: items.isEmpty
                    ? false
                    : (allSelected ? true : (someSelected ? null : false)),
                onTap: () => onSelectAllTap(items),
              ),
            ],
          ],
        ),
        if (!kIsWeb) const SizedBox(height: kGap12),
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

/// One active filter shown as a removable chip above the grid.
class _ActiveFilter {
  const _ActiveFilter({required this.label, required this.onRemove});

  final String label;
  final Future<void> Function() onRemove;
}

/// Builds chips for every active filter; removing a chip clears only it.
List<_ActiveFilter> _activeFilters(
  AppLocalizations t,
  CatalogController c, {
  required Future<void> Function() reload,
}) {
  final out = <_ActiveFilter>[];
  String range(String label, int? from, int? to, [String unit = '']) {
    final suffix = unit.isEmpty ? '' : ' $unit';
    if (from != null && to != null) return '$label $from–$to$suffix';
    if (from != null) return '$label ≥ $from$suffix';
    return '$label ≤ $to$suffix';
  }

  void add(String label, void Function() clear) {
    out.add(
      _ActiveFilter(
        label: label,
        onRemove: () async {
          clear();
          await reload();
        },
      ),
    );
  }

  if (c.profileRole != null) {
    add(_catalogProfileTypeLabel(t, c.profileRole!), () {
      c.setProfileRole(null);
    });
  }
  if (c.ageFrom != null || c.ageTo != null) {
    add(range(t.age, c.ageFrom, c.ageTo), () {
      c.ageFrom = null;
      c.ageTo = null;
    });
  }
  if (c.heightFrom != null || c.heightTo != null) {
    add(range(t.height, c.heightFrom, c.heightTo, t.cm), () {
      c.heightFrom = null;
      c.heightTo = null;
    });
  }
  if (c.shoeFrom != null || c.shoeTo != null) {
    add(range(t.shoeSize, c.shoeFrom, c.shoeTo), () {
      c.shoeFrom = null;
      c.shoeTo = null;
    });
  }
  if (c.bustFrom != null || c.bustTo != null) {
    add(range(t.bust, c.bustFrom, c.bustTo), () {
      c.bustFrom = null;
      c.bustTo = null;
    });
  }
  if (c.waistFrom != null || c.waistTo != null) {
    add(range(t.waist, c.waistFrom, c.waistTo), () {
      c.waistFrom = null;
      c.waistTo = null;
    });
  }
  if (c.hipsFrom != null || c.hipsTo != null) {
    add(range(t.hips, c.hipsFrom, c.hipsTo), () {
      c.hipsFrom = null;
      c.hipsTo = null;
    });
  }
  if (c.eyeColor.trim().isNotEmpty) {
    add('${t.eyeColor}: ${c.eyeColor.trim()}', () => c.eyeColor = '');
  }
  if (c.hairColor.trim().isNotEmpty) {
    add('${t.hairColor}: ${c.hairColor.trim()}', () => c.hairColor = '');
  }
  if (c.country.trim().isNotEmpty) {
    add('${t.country}: ${c.country.trim()}', () => c.country = '');
  }
  if (c.city.trim().isNotEmpty) {
    add('${t.city}: ${c.city.trim()}', () => c.city = '');
  }
  if (c.needDate != null) {
    final d = c.needDate!;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    add('$dd.$mm.${d.year}', () => c.needDate = null);
  }
  return out;
}

/// Desktop header above the grid: result count, active-filter chips and the
/// folder / advanced-search actions.
class _CatalogResultsHeader extends StatelessWidget {
  const _CatalogResultsHeader({
    required this.countLabel,
    required this.filters,
    required this.onAdvancedSearch,
    required this.advancedSearchEnabled,
    this.onFolders,
    this.onResetFilters,
    this.resetLabel,
    this.selectAllValue,
    this.onSelectAll,
    this.sort = CatalogSort.recommended,
    this.onSortChanged,
  });

  final String countLabel;
  final List<_ActiveFilter> filters;
  final VoidCallback onAdvancedSearch;
  final bool advancedSearchEnabled;
  final VoidCallback? onFolders;
  final Future<void> Function()? onResetFilters;
  final String? resetLabel;

  /// Agent «select all visible» control: true / null (some) / false.
  final bool? selectAllValue;
  final VoidCallback? onSelectAll;

  final CatalogSort sort;
  final ValueChanged<CatalogSort>? onSortChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(countLabel, style: AppText.h1.copyWith(fontSize: 24)),
            const Spacer(),
            if (onSelectAll != null) ...[
              _SelectAllPill(value: selectAllValue, onTap: onSelectAll!),
              const SizedBox(width: 8),
            ],
            if (onFolders != null) ...[
              _HeaderIconButton(
                icon: Icons.folder_outlined,
                tooltip: _sentenceCase(t.agentFoldersUpper),
                onTap: onFolders,
              ),
              const SizedBox(width: 8),
            ],
            if (onSortChanged != null)
              _CatalogSortMenu(value: sort, onChanged: onSortChanged!),
          ],
        ),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final f in filters)
                _FilterChip(label: f.label, onRemove: f.onRemove),
              if (onResetFilters != null && resetLabel != null)
                TextButton(
                  onPressed: onResetFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Tokens.textSecondary,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(_sentenceCase(resetLabel!)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// «Sort: …» text button with a menu (header of the results).
class _CatalogSortMenu extends StatelessWidget {
  const _CatalogSortMenu({required this.value, required this.onChanged});

  final CatalogSort value;
  final ValueChanged<CatalogSort> onChanged;

  static String label(BuildContext context, CatalogSort sort) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return switch (sort) {
      CatalogSort.recommended => ru ? 'Рекомендуемые' : 'Recommended',
      CatalogSort.newest => ru ? 'Сначала новые' : 'Newest first',
      CatalogSort.ageAsc => ru ? 'Возраст: младше' : 'Age: youngest',
      CatalogSort.ageDesc => ru ? 'Возраст: старше' : 'Age: oldest',
      CatalogSort.heightAsc => ru ? 'Рост: ниже' : 'Height: shortest',
      CatalogSort.heightDesc => ru ? 'Рост: выше' : 'Height: tallest',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return PopupMenuButton<CatalogSort>(
      tooltip: ru ? 'Сортировка' : 'Sort',
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final sort in CatalogSort.values)
          PopupMenuItem(
            value: sort,
            child: Row(
              children: [
                Expanded(
                  child: Text(label(context, sort), style: AppText.small),
                ),
                if (sort == value)
                  const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: Tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${ru ? 'Сортировка' : 'Sort'}: ${label(context, value)}',
              style: AppText.small,
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          side: const BorderSide(color: Tokens.border),
          foregroundColor: Tokens.text,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.smallStrong),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 16, color: Tokens.text),
            ),
          ),
        ],
      ),
    );
  }
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
    required this.showDetail,
    this.filters,
    this.savedSearches,
  });

  /// The hover preview column needs room; hidden on narrower desktops.
  final bool showDetail;
  final Widget topBar;
  final VoidCallback onAdvancedSearch;
  final bool advancedSearchEnabled;
  final Future<void> Function()? onResetFilters;
  final String resetFiltersLabel;
  final Widget roleTabs;
  final Widget search;

  /// Inline range filters (age, height, …) shown in the rail.
  final Widget? filters;
  final Widget? savedSearches;
  final Widget grid;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    // Three columns separated by hairlines, like the castings page: the
    // filter rail, the results and (on wide screens) the live preview.
    return Row(
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
            filters: filters,
            savedSearches: savedSearches,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Tokens.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topBar,
                const SizedBox(height: 20),
                Expanded(child: grid),
              ],
            ),
          ),
        ),
        if (showDetail) ...[
          const VerticalDivider(width: 1, thickness: 1, color: Tokens.border),
          SizedBox(width: _catalogDesktopDetailWidth, child: detail),
        ],
      ],
    );
  }
}

/// Filter rail: title, search, role list, inline ranges, links.
class _CatalogDesktopFilterPanel extends StatelessWidget {
  const _CatalogDesktopFilterPanel({
    required this.search,
    required this.onAdvancedSearch,
    required this.advancedSearchEnabled,
    required this.onResetFilters,
    required this.resetFiltersLabel,
    required this.roleTabs,
    this.filters,
    this.savedSearches,
  });

  final Widget search;
  final VoidCallback onAdvancedSearch;
  final bool advancedSearchEnabled;
  final Future<void> Function()? onResetFilters;
  final String resetFiltersLabel;
  final Widget roleTabs;
  final Widget? filters;
  final Widget? savedSearches;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 36, 24, 32),
      children: [
        Text(t.catalogTab, style: AppText.h1.copyWith(fontSize: 32)),
        const SizedBox(height: 20),
        search,
        const SizedBox(height: 28),
        _CatalogRailLabel(ru ? 'Роль' : 'Role'),
        const SizedBox(height: 8),
        roleTabs,
        if (filters != null) ...[
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          filters!,
        ],
        const SizedBox(height: 12),
        if (onResetFilters != null)
          _CatalogRailLink(
            icon: Icons.restart_alt_rounded,
            label: _sentenceCase(resetFiltersLabel),
            onTap: onResetFilters,
            accent: true,
          ),
        if (savedSearches != null) ...[
          const SizedBox(height: 24),
          Text(_sentenceCase(t.savedSearchSaveTitle), style: AppText.label),
          const SizedBox(height: 10),
          savedSearches!,
        ],
      ],
    );
  }
}

/// Full-width outlined action (mobile «reset filters»).
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
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _sentenceCase(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

/// Uppercase group label in the rail.
class _CatalogRailLabel extends StatelessWidget {
  const _CatalogRailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.label.copyWith(fontSize: 12, letterSpacing: 1),
    );
  }
}

/// Text link with an icon at the bottom of the rail.
class _CatalogRailLink extends StatelessWidget {
  const _CatalogRailLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: accent ? Tokens.accent : Tokens.text,
          textStyle: AppText.small.copyWith(fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          minimumSize: const Size(0, 40),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// Vertical role list for the rail: every role is one flat row, the
/// selected one is black with a check mark.
class _CatalogRoleList extends StatelessWidget {
  const _CatalogRoleList({required this.selectedRole, required this.onChanged});

  final ProfessionalProfileType? selectedRole;
  final ValueChanged<ProfessionalProfileType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final items = <({ProfessionalProfileType? role, String label, IconData icon})>[
      (role: null, label: ru ? 'Все' : 'All', icon: Icons.grid_view_rounded),
      for (final role in _CatalogRoleTabs._roles)
        (
          role: role,
          label: _catalogProfileTypeLabel(t, role),
          icon: _catalogRoleIcon(role),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          _CatalogRoleRow(
            label: item.label,
            icon: item.icon,
            selected: selectedRole == item.role,
            onTap: () => onChanged(item.role),
          ),
      ],
    );
  }
}

class _CatalogRoleRow extends StatelessWidget {
  const _CatalogRoleRow({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        hoverColor: Tokens.surface,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Tokens.text : Tokens.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppText.small.copyWith(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Tokens.text : Tokens.textSecondary,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 18, color: Tokens.text),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every filter group of the rail (and of the mobile sheet), built straight
/// from the controller: ranges, appearance facets, place, date, rates.
class _CatalogFilterGroups extends StatelessWidget {
  const _CatalogFilterGroups({
    required this.controller,
    required this.onApply,
    this.includeRoles = false,
    this.onRoleChanged,
  });

  final CatalogController controller;

  /// Mutates the controller fields inside [set] and reloads.
  final Future<void> Function(void Function() set) onApply;
  final bool includeRoles;
  final ValueChanged<ProfessionalProfileType?>? onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final ru = locale.languageCode == 'ru';
    final c = controller;
    final b = c.bounds;
    final facets = c.facets;

    String rangeSummary(int? from, int? to, [String unit = '']) {
      if (from == null && to == null) return '';
      final u = unit.isEmpty ? '' : ' $unit';
      if (from != null && to != null) return '$from–$to$u';
      if (from != null) return '≥ $from$u';
      return '≤ $to$u';
    }

    final measurementsSummary = [
      rangeSummary(c.ageFrom, c.ageTo),
      rangeSummary(c.heightFrom, c.heightTo, t.cm),
      rangeSummary(c.shoeFrom, c.shoeTo),
      rangeSummary(c.bustFrom, c.bustTo),
      rangeSummary(c.waistFrom, c.waistTo),
      rangeSummary(c.hipsFrom, c.hipsTo),
    ].where((v) => v.isNotEmpty).join(' · ');
    final appearanceSummary = [
      eyeColorDisplayValue(c.eyeColor, locale),
      hairColorDisplayValue(c.hairColor, locale),
    ].where((v) => v.isNotEmpty).join(' · ');
    final placeSummary = [
      c.country.trim(),
      c.city.trim(),
    ].where((v) => v.isNotEmpty).join(', ');
    final need = c.needDate;
    final dateSummary = need == null
        ? ''
        : '${need.day.toString().padLeft(2, '0')}.'
              '${need.month.toString().padLeft(2, '0')}.${need.year}';
    final ratesSummary = [
      rangeSummary(c.minHourlyRateFrom, c.minHourlyRateTo, '₽'),
      rangeSummary(c.minDailyFeeFrom, c.minDailyFeeTo, '₽'),
    ].where((v) => v.isNotEmpty).join(' · ');

    _CatalogRangeFilter range({
      required String field,
      required String label,
      required int min,
      required int max,
      required int? from,
      required int? to,
      required void Function(int? from, int? to) set,
      String unit = '',
      bool initiallyOpen = false,
    }) {
      return _CatalogRangeFilter(
        label: label,
        unit: unit,
        min: min,
        max: max,
        from: from,
        to: to,
        initiallyOpen: initiallyOpen,
        onChanged: (f, tt) => onApply(() => set(f, tt)),
        countPreview: (f, tt) => c.previewCount(field: field, from: f, to: tt),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeRoles && onRoleChanged != null) ...[
          _CatalogRailGroup(
            title: ru ? 'Роль' : 'Role',
            summary: c.profileRole == null
                ? ''
                : _catalogProfileTypeLabel(t, c.profileRole!),
            initiallyOpen: true,
            child: _CatalogRoleList(
              selectedRole: c.profileRole,
              onChanged: onRoleChanged!,
            ),
          ),
        ],
        _CatalogRailGroup(
          title: ru ? 'Параметры' : 'Measurements',
          summary: measurementsSummary,
          initiallyOpen: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              range(
                field: 'age',
                label: t.age,
                min: b?.ageMin ?? kAgeMin,
                max: b?.ageMax ?? kAgeMax,
                from: c.ageFrom,
                to: c.ageTo,
                initiallyOpen: true,
                set: (f, tt) {
                  c.ageFrom = f;
                  c.ageTo = tt;
                },
              ),
              range(
                field: 'height',
                label: t.height,
                unit: t.cm,
                min: b?.heightMin ?? kHeightMin,
                max: b?.heightMax ?? kHeightMax,
                from: c.heightFrom,
                to: c.heightTo,
                set: (f, tt) {
                  c.heightFrom = f;
                  c.heightTo = tt;
                },
              ),
              range(
                field: 'shoe',
                label: t.shoeSize,
                min: b?.shoeMin ?? kShoeMin,
                max: b?.shoeMax ?? kShoeMax,
                from: c.shoeFrom,
                to: c.shoeTo,
                set: (f, tt) {
                  c.shoeFrom = f;
                  c.shoeTo = tt;
                },
              ),
              range(
                field: 'bust',
                label: t.bust,
                min: b?.bustMin ?? kBustMin,
                max: b?.bustMax ?? kBustMax,
                from: c.bustFrom,
                to: c.bustTo,
                set: (f, tt) {
                  c.bustFrom = f;
                  c.bustTo = tt;
                },
              ),
              range(
                field: 'waist',
                label: t.waist,
                min: b?.waistMin ?? kWaistMin,
                max: b?.waistMax ?? kWaistMax,
                from: c.waistFrom,
                to: c.waistTo,
                set: (f, tt) {
                  c.waistFrom = f;
                  c.waistTo = tt;
                },
              ),
              range(
                field: 'hips',
                label: t.hips,
                min: b?.hipsMin ?? kHipsMin,
                max: b?.hipsMax ?? kHipsMax,
                from: c.hipsFrom,
                to: c.hipsTo,
                set: (f, tt) {
                  c.hipsFrom = f;
                  c.hipsTo = tt;
                },
              ),
            ],
          ),
        ),
        if (facets.eyeColors.isNotEmpty || facets.hairColors.isNotEmpty)
          _CatalogRailGroup(
            title: ru ? 'Внешность' : 'Appearance',
            summary: appearanceSummary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (facets.eyeColors.isNotEmpty)
                  _CatalogFacetChips(
                    title: t.eyeColor,
                    values: facets.eyeColors,
                    selected: c.eyeColor,
                    display: (v) => eyeColorDisplayValue(v, locale),
                    onChanged: (v) => onApply(() => c.eyeColor = v),
                  ),
                if (facets.hairColors.isNotEmpty)
                  _CatalogFacetChips(
                    title: t.hairColor,
                    values: facets.hairColors,
                    selected: c.hairColor,
                    display: (v) => hairColorDisplayValue(v, locale),
                    onChanged: (v) => onApply(() => c.hairColor = v),
                  ),
              ],
            ),
          ),
        if (facets.countries.isNotEmpty || facets.cities.isNotEmpty)
          _CatalogRailGroup(
            title: ru ? 'Где' : 'Where',
            summary: placeSummary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (facets.countries.length > 1)
                  _CatalogFacetChips(
                    title: t.country,
                    values: facets.countries,
                    selected: c.country,
                    display: (v) => v,
                    onChanged: (v) => onApply(() => c.country = v),
                  ),
                if (facets.cities.isNotEmpty)
                  _CatalogFacetChips(
                    title: t.city,
                    values: facets.cities,
                    selected: c.city,
                    display: (v) => v,
                    onChanged: (v) => onApply(() => c.city = v),
                  ),
              ],
            ),
          ),
        _CatalogRailGroup(
          title: ru ? 'Доступность' : 'Availability',
          summary: dateSummary,
          child: _CatalogDateFilter(
            value: c.needDate,
            onChanged: (d) => onApply(() => c.needDate = d),
          ),
        ),
        _CatalogRailGroup(
          title: ru ? 'Ставки' : 'Rates',
          summary: ratesSummary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              range(
                field: 'hourly',
                label: ru ? 'За час' : 'Per hour',
                unit: '₽',
                min: b?.minHourlyRateMin ?? 0,
                max: b?.minHourlyRateMax ?? 10000,
                from: c.minHourlyRateFrom,
                to: c.minHourlyRateTo,
                set: (f, tt) {
                  c.minHourlyRateFrom = f;
                  c.minHourlyRateTo = tt;
                },
              ),
              range(
                field: 'daily',
                label: ru ? 'За смену' : 'Per day',
                unit: '₽',
                min: b?.minDailyFeeMin ?? 0,
                max: b?.minDailyFeeMax ?? 100000,
                from: c.minDailyFeeFrom,
                to: c.minDailyFeeTo,
                set: (f, tt) {
                  c.minDailyFeeFrom = f;
                  c.minDailyFeeTo = tt;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Collapsible group of the rail: uppercase title, the active values on
/// the right, hairline underneath.
class _CatalogRailGroup extends StatefulWidget {
  const _CatalogRailGroup({
    required this.title,
    required this.child,
    this.summary = '',
    this.initiallyOpen = false,
  });

  final String title;
  final String summary;
  final bool initiallyOpen;
  final Widget child;

  @override
  State<_CatalogRailGroup> createState() => _CatalogRailGroupState();
}

class _CatalogRailGroupState extends State<_CatalogRailGroup> {
  late bool _open = widget.initiallyOpen || widget.summary.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: AppText.label.copyWith(
                        fontSize: 12,
                        letterSpacing: 1,
                        color: Tokens.text,
                      ),
                    ),
                  ),
                  if (widget.summary.isNotEmpty)
                    Flexible(
                      child: Text(
                        widget.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppText.caption.copyWith(color: Tokens.accent),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Tokens.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: widget.child,
          ),
        const Divider(height: 1, thickness: 1, color: Tokens.border),
      ],
    );
  }
}

/// One range (age, height, …): label and the current values in a row;
/// tapping opens a slider, «from/to» fields and the live «N profiles» hint.
/// Applies on slider release or when a field loses focus.
class _CatalogRangeFilter extends StatefulWidget {
  const _CatalogRangeFilter({
    required this.label,
    required this.min,
    required this.max,
    required this.from,
    required this.to,
    required this.onChanged,
    this.countPreview,
    this.unit = '',
    this.initiallyOpen = false,
  });

  final String label;
  final int min;
  final int max;
  final int? from;
  final int? to;
  final String unit;
  final bool initiallyOpen;
  final void Function(int? from, int? to) onChanged;
  final Future<int> Function(int? from, int? to)? countPreview;

  @override
  State<_CatalogRangeFilter> createState() => _CatalogRangeFilterState();
}

class _CatalogRangeFilterState extends State<_CatalogRangeFilter> {
  late bool _open = widget.initiallyOpen || widget.from != null || widget.to != null;
  RangeValues? _dragging;
  int? _previewCount;
  Timer? _previewTimer;
  late final TextEditingController _fromC = TextEditingController();
  late final TextEditingController _toC = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  int get _lo => (widget.from ?? widget.min).clamp(widget.min, widget.max);
  int get _hi => (widget.to ?? widget.max).clamp(widget.min, widget.max);

  @override
  void initState() {
    super.initState();
    _syncFields();
    _fromFocus.addListener(() {
      if (!_fromFocus.hasFocus) _commitFields();
    });
    _toFocus.addListener(() {
      if (!_toFocus.hasFocus) _commitFields();
    });
  }

  @override
  void didUpdateWidget(covariant _CatalogRangeFilter old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from ||
        old.to != widget.to ||
        old.min != widget.min ||
        old.max != widget.max) {
      _syncFields();
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _fromC.dispose();
    _toC.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _syncFields() {
    if (!_fromFocus.hasFocus) _fromC.text = '$_lo';
    if (!_toFocus.hasFocus) _toC.text = '$_hi';
  }

  void _apply(int lo, int hi) {
    var from = lo.clamp(widget.min, widget.max);
    var to = hi.clamp(widget.min, widget.max);
    if (from > to) {
      final swap = from;
      from = to;
      to = swap;
    }
    setState(() {
      _dragging = null;
      _previewCount = null;
    });
    widget.onChanged(
      from == widget.min ? null : from,
      to == widget.max ? null : to,
    );
  }

  void _commitFields() {
    final lo = int.tryParse(_fromC.text.trim()) ?? _lo;
    final hi = int.tryParse(_toC.text.trim()) ?? _hi;
    if (lo == _lo && hi == _hi) {
      _syncFields();
      return;
    }
    _apply(lo, hi);
  }

  void _schedulePreview(RangeValues values) {
    final preview = widget.countPreview;
    if (preview == null) return;
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 250), () async {
      final lo = values.start.round();
      final hi = values.end.round();
      try {
        final n = await preview(
          lo == widget.min ? null : lo,
          hi == widget.max ? null : hi,
        );
        if (!mounted || _dragging == null) return;
        setState(() => _previewCount = n);
      } catch (_) {
        // The hint is optional.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final min = widget.min.toDouble();
    final max = widget.max.toDouble();
    final active = widget.from != null || widget.to != null;
    final values = _dragging ?? RangeValues(_lo.toDouble(), _hi.toDouble());
    final unit = widget.unit.isEmpty ? '' : ' ${widget.unit}';
    final single = widget.max <= widget.min;
    final valueText = single
        ? '${widget.min}$unit'
        : (active || _dragging != null
              ? '${values.start.round()}–${values.end.round()}$unit'
              : (ru ? 'Любой' : 'Any'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            hoverColor: Tokens.surface,
            onTap: single ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppText.small.copyWith(
                        fontSize: 15,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    valueText,
                    style: AppText.small.copyWith(
                      color: active ? Tokens.text : Tokens.textSecondary,
                    ),
                  ),
                  if (!single) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Tokens.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_open && !single) ...[
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: Tokens.text,
              inactiveTrackColor: Tokens.border,
              thumbColor: Tokens.bg,
              overlayColor: Tokens.text.withValues(alpha: 0.08),
              rangeThumbShape: const _CatalogRangeThumb(),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: RangeSlider(
              min: min,
              max: max,
              divisions: (max - min).round(),
              values: values,
              onChanged: (next) {
                setState(() => _dragging = next);
                _fromC.text = '${next.start.round()}';
                _toC.text = '${next.end.round()}';
                _schedulePreview(next);
              },
              onChangeEnd: (next) =>
                  _apply(next.start.round(), next.end.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                _CatalogRangeField(
                  controller: _fromC,
                  focusNode: _fromFocus,
                  prefix: ru ? 'от' : 'from',
                  onSubmitted: _commitFields,
                ),
                const SizedBox(width: 8),
                _CatalogRangeField(
                  controller: _toC,
                  focusNode: _toFocus,
                  prefix: ru ? 'до' : 'to',
                  onSubmitted: _commitFields,
                ),
                const Spacer(),
                if (_dragging != null && _previewCount != null)
                  Text(
                    t.catalogFoundCount(_previewCount!),
                    style: AppText.caption,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Tiny numeric field («от 12») under a range slider.
class _CatalogRangeField extends StatelessWidget {
  const _CatalogRangeField({
    required this.controller,
    required this.focusNode,
    required this.prefix,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String prefix;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 36,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        style: AppText.small,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '$prefix ',
          prefixStyle: AppText.caption,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

/// Chips with counts for one text facet (eye colour, city, …); a single
/// value can be selected, tapping it again clears the filter.
class _CatalogFacetChips extends StatelessWidget {
  const _CatalogFacetChips({
    required this.title,
    required this.values,
    required this.selected,
    required this.display,
    required this.onChanged,
  });

  final String title;
  final Map<String, int> values;
  final String selected;
  final String Function(String value) display;
  final ValueChanged<String> onChanged;

  static const int _visible = 10;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final entries = values.entries.toList(growable: false);
    final selectedKey = selected.trim().toLowerCase();
    final shown = entries.length <= _visible + 1
        ? entries
        : entries.take(_visible).toList(growable: false);
    final hiddenSelected =
        selectedKey.isNotEmpty &&
        !shown.any((e) => e.key.toLowerCase() == selectedKey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.small.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in shown)
                _CatalogFacetChip(
                  label: display(e.key),
                  count: e.value,
                  selected: e.key.toLowerCase() == selectedKey,
                  onTap: () => onChanged(
                    e.key.toLowerCase() == selectedKey ? '' : e.key,
                  ),
                ),
              if (hiddenSelected)
                _CatalogFacetChip(
                  label: display(selected),
                  count: values[selected] ?? 0,
                  selected: true,
                  onTap: () => onChanged(''),
                ),
              if (shown.length < entries.length)
                _CatalogFacetChip(
                  label: ru
                      ? 'Ещё ${entries.length - shown.length}'
                      : '${entries.length - shown.length} more',
                  count: null,
                  selected: false,
                  onTap: () async {
                    final picked = await _pickFacetValue(
                      context,
                      title: title,
                      values: values,
                      display: display,
                      selected: selected,
                    );
                    if (picked != null) onChanged(picked);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogFacetChip extends StatelessWidget {
  const _CatalogFacetChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Tokens.ink : Tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.small.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Tokens.textOnDark : Tokens.text,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: AppText.caption.copyWith(
                    color: selected
                        ? Tokens.textOnDark.withValues(alpha: 0.7)
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

/// Dialog with every facet value and a search box (long city lists).
Future<String?> _pickFacetValue(
  BuildContext context, {
  required String title,
  required Map<String, int> values,
  required String Function(String value) display,
  required String selected,
}) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      var filter = '';
      return StatefulBuilder(
        builder: (ctx, setState) {
          final entries = values.entries
              .where(
                (e) =>
                    filter.isEmpty ||
                    display(e.key).toLowerCase().contains(filter) ||
                    e.key.toLowerCase().contains(filter),
              )
              .toList(growable: false);
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 360,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) =>
                        setState(() => filter = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: ru ? 'Найти' : 'Search',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        final isSelected =
                            e.key.toLowerCase() == selected.trim().toLowerCase();
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(display(e.key), style: AppText.small),
                          trailing: Text('${e.value}', style: AppText.caption),
                          selected: isSelected,
                          onTap: () => Navigator.of(ctx).pop(e.key),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              if (selected.trim().isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(''),
                  child: Text(ru ? 'Сбросить' : 'Clear'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppLocalizations.of(ctx)!.cancel),
              ),
            ],
          );
        },
      );
    },
  );
}

/// «Shoot date»: profiles unavailable on that day are hidden.
class _CatalogDateFilter extends StatelessWidget {
  const _CatalogDateFilter({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final v = value;
    final text = v == null
        ? (ru ? 'Любая' : 'Any')
        : '${v.day.toString().padLeft(2, '0')}.'
              '${v.month.toString().padLeft(2, '0')}.${v.year}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        hoverColor: Tokens.surface,
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: v ?? now,
            firstDate: DateTime(now.year, now.month, now.day),
            lastDate: DateTime(now.year + 2),
          );
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ru ? 'Дата съёмки' : 'Shoot date',
                  style: AppText.small.copyWith(
                    fontSize: 15,
                    fontWeight: v == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                text,
                style: AppText.small.copyWith(
                  color: v == null ? Tokens.textSecondary : Tokens.text,
                ),
              ),
              if (v != null)
                IconButton(
                  onPressed: () => onChanged(null),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: Tokens.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobile: the same groups in a full-height sheet with a close button.
Future<void> showCatalogFilterSheet(
  BuildContext context, {
  required CatalogController controller,
  required Future<void> Function(void Function() set) onApply,
  required ValueChanged<ProfessionalProfileType?> onRoleChanged,
  required Future<void> Function()? onReset,
}) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Tokens.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusLg)),
    ),
    builder: (ctx) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: AnimatedBuilder(
          animation: controller,
          builder: (ctx, _) {
            final t = AppLocalizations.of(ctx)!;
            final n = controller.loaded.length;
            final countLabel = controller.hasMore
                ? t.catalogFoundMore(n)
                : t.catalogFoundCount(n);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ru ? 'Фильтры' : 'Filters',
                          style: AppText.h2,
                        ),
                      ),
                      if (onReset != null)
                        TextButton(
                          onPressed: onReset,
                          child: Text(ru ? 'Сбросить' : 'Reset'),
                        ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      _CatalogFilterGroups(
                        controller: controller,
                        onApply: onApply,
                        includeRoles: true,
                        onRoleChanged: onRoleChanged,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(Tokens.inputHeight),
                    ),
                    child: Text(
                      controller.isInitialLoading
                          ? t.loadingDots
                          : (ru ? 'Показать · $countLabel' : 'Show · $countLabel'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

/// Small white thumb with a hairline — matches the inputs.
class _CatalogRangeThumb extends RangeSliderThumbShape {
  const _CatalogRangeThumb();

  static const double _radius = 9;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    bool? isPressed,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, _radius, Paint()..color = Tokens.bg);
    canvas.drawCircle(
      center,
      _radius - 0.5,
      Paint()
        ..color = Tokens.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
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
    this.onHoverModel,
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

  /// Desktop only: the pointer entered a card (feeds the side preview).
  final ValueChanged<String>? onHoverModel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (controller.isInitialLoading) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = _CatalogGrid._columnsFor(constraints.maxWidth);
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: kGridPadding,
            child: SkeletonCardGrid(columns: columns, gap: kGridGap),
          );
        },
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
        title: controller.hasActiveFilters
            ? t.catalogNoFilterResults
            : t.noApprovedProfilesYet,
        subtitle: controller.hasActiveFilters
            ? t.catalogAdjustFiltersHint
            : t.catalogSearchHintUpper,
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
      onHoverModel: onHoverModel,
    );
  }
}

/// Live preview column: photo, name, facts and the two actions.
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
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final m = model;

    if (m == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t.noApprovedProfilesYet,
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
        ),
      );
    }

    final photo = m.primaryPhotoUrl == null
        ? const _CatalogPhotoPlaceholder()
        : CachedNetworkImage(
            imageUrl: storageImageVariant(
              m.primaryPhotoUrl!,
              width: kCatalogPreviewImageWidth,
            ),
            memCacheWidth: _catalogOverlayPhotoCacheWidth,
            maxWidthDiskCache: _catalogOverlayPhotoCacheWidth,
            fit: BoxFit.cover,
            alignment: _catalogCoverAlignmentFor(m),
            placeholder: (_, _) => const _CatalogPhotoPlaceholder(),
            errorWidget: (_, _, _) => CachedNetworkImage(
              imageUrl: m.primaryPhotoUrl!,
              memCacheWidth: _catalogOverlayPhotoCacheWidth,
              maxWidthDiskCache: _catalogOverlayPhotoCacheWidth,
              fit: BoxFit.cover,
              alignment: _catalogCoverAlignmentFor(m),
              placeholder: (_, _) => const _CatalogPhotoPlaceholder(),
              errorWidget: (_, _, _) => const _CatalogPhotoPlaceholder(),
            ),
          );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 28, 32, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          child: AspectRatio(aspectRatio: 3 / 4, child: photo),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                m.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.h1.copyWith(fontSize: 24, height: 1.2),
              ),
            ),
            if (m.isProActive) ...[
              const SizedBox(width: 8),
              const _ProBadge(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _catalogProfileRolesLabel(t, m.effectiveProfileRoles),
          style: AppText.small.copyWith(color: Tokens.textSecondary),
        ),
        const SizedBox(height: 16),
        _PreviewInfoLine(
          icon: Icons.cake_outlined,
          text: '${t.ageYears(m.age)} · ${m.height} $cmLabel',
        ),
        if (m.city.isNotEmpty || m.country.isNotEmpty)
          _PreviewInfoLine(
            icon: Icons.place_outlined,
            text: [m.city, m.country]
                .where((value) => value.trim().isNotEmpty)
                .join(', '),
          ),
        if (m.photoUrls.isNotEmpty || m.videoUrls.isNotEmpty)
          _PreviewInfoLine(
            icon: Icons.photo_library_outlined,
            text: ru
                ? '${m.photoUrls.length} фото · ${m.videoUrls.length} видео'
                : '${m.photoUrls.length} photos · ${m.videoUrls.length} videos',
          ),
        if (m.resume.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            m.resume,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onOpen,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(Tokens.inputHeight),
          ),
          child: Text(ru ? 'Открыть анкету' : 'Open profile'),
        ),
        if (canUseAgentTools) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onQuickAdd,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(Tokens.inputHeight),
            ),
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: Text(ru ? 'В подборку' : 'Add to selection'),
          ),
        ],
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Tokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.small.copyWith(fontSize: 15),
            ),
          ),
        ],
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
    this.onHoverModel,
  });

  final List<ModelVm> items;
  final Set<String> selectedIds;
  final ValueChanged<String>? onHoverModel;
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

  /// ~240 px cards on desktop (3–6 columns); phones keep two columns.
  static int _columnsFor(double width) {
    if (width < 600) return kGridCrossAxisCount;
    final columns = ((width + kGridGap) / (240 + kGridGap)).floor();
    return columns.clamp(2, 6);
  }

  int _crossAxisCount(double width) => _columnsFor(width);

  /// Card = 3:4 photo + text block, so the ratio depends on the column width.
  double _childAspectRatio(double width, int columns) {
    final columnWidth = (width - kGridGap * (columns - 1)) / columns;
    return columnWidth / (columnWidth * 4 / 3 + _kCardInfoHeightV2);
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
            // ignore: deprecated_member_use
            cacheExtent: _catalogGridCacheExtent,
            padding: kGridPadding.copyWith(
              bottom: kGridPadding.bottom + bottomInset,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: kGridGap,
              mainAxisSpacing: kGridGap,
              childAspectRatio: _childAspectRatio(constraints.maxWidth, columns),
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final selected = selectedIds.contains(m.id);
              final photo = m.primaryPhotoUrl;
              final heroTag = 'model-photo-${m.id}';

              return _GridProfileCard(
                onHover: onHoverModel == null
                    ? null
                    : () => onHoverModel!(m.id),
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
                ageText: AppLocalizations.of(context)!.ageYears(m.age),
                heightText: '${m.height} $cmLabel',
                cityText: m.city.trim(),
                photoUrl: photo,
                secondPhotoUrl: m.displayPhotoUrls.length > 1
                    ? m.displayPhotoUrls[1]
                    : null,
                coverAlignment: _catalogCoverAlignmentFor(m),
                heroTag: heroTag,
                isPro: m.isProActive,
                hoverActions: columns >= 3,
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

    if (kIsWeb) {
      // v2: the theme input (48 px, hairline, no pill), sentence-case hint.
      return TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: _sentenceCase(widget.hintText),
          hintStyle: AppText.body.copyWith(color: Tokens.textTertiary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 22,
            color: Tokens.textSecondary,
          ),
          suffixIcon: !hasText
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Tokens.textSecondary,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      );
    }

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

class _GridProfileCard extends StatefulWidget {
  const _GridProfileCard({
    required this.onTap,
    required this.onToggleSelected,
    required this.onQuickAdd,
    required this.isSelected,
    required this.canSelect,
    required this.name,
    required this.ageText,
    required this.heightText,
    required this.cityText,
    required this.photoUrl,
    required this.secondPhotoUrl,
    required this.coverAlignment,
    required this.heroTag,
    required this.isPro,
    required this.hoverActions,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onHover,
  });

  final VoidCallback onTap;

  /// Called when the mouse moves over the card (desktop side preview).
  final VoidCallback? onHover;
  final VoidCallback onToggleSelected;
  final VoidCallback onQuickAdd;
  final bool isSelected;
  final bool canSelect;
  final String name;
  final String ageText;
  final String heightText;
  final String cityText;
  final String? photoUrl;

  /// Shown instead of [photoUrl] while the pointer is over the card.
  final String? secondPhotoUrl;
  final Alignment coverAlignment;
  final String heroTag;
  final bool isPro;

  /// Desktop: the select / quick-add controls appear on hover only.
  final bool hoverActions;

  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(LongPressEndDetails)? onLongPressEnd;

  @override
  State<_GridProfileCard> createState() => _GridProfileCardState();
}

class _GridProfileCardState extends State<_GridProfileCard> {
  bool _hovered = false;

  /// Last global pointer position that produced a hover. Route transitions
  /// slide the grid under a stationary cursor, which the browser reports as
  /// hover events; those must not change the preview.
  static Offset? _lastHoverPosition;

  void _handleHover(PointerEvent event) {
    final last = _lastHoverPosition;
    _lastHoverPosition = event.position;
    if (last != null && (event.position - last).distance < 3) return;
    widget.onHover?.call();
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  Widget _photo(String url, {required bool hero}) {
    final image = CachedNetworkImage(
      // Resized by Storage; the original opens in the lightbox.
      imageUrl: storageImageVariant(url, width: kCatalogCardImageWidth),
      memCacheWidth: _catalogCardPhotoCacheWidth,
      maxWidthDiskCache: _catalogCardPhotoCacheWidth,
      fit: BoxFit.cover,
      alignment: widget.coverAlignment,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, _) => const _CatalogPhotoPlaceholder(),
      // If the transform endpoint is unavailable, fall back to the original.
      errorWidget: (_, _, _) => CachedNetworkImage(
        imageUrl: url,
        memCacheWidth: _catalogCardPhotoCacheWidth,
        maxWidthDiskCache: _catalogCardPhotoCacheWidth,
        fit: BoxFit.cover,
        alignment: widget.coverAlignment,
        placeholder: (_, _) => const _CatalogPhotoPlaceholder(),
        errorWidget: (_, _, _) => const _CatalogPhotoPlaceholder(),
      ),
    );
    if (!hero) return image;
    return Hero(tag: widget.heroTag, child: image);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final semanticsLabel = [
      w.name,
      w.ageText,
      w.heightText,
      w.cityText,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final details = [
      w.ageText,
      w.heightText,
      w.cityText,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final showActions =
        w.canSelect && (!w.hoverActions || _hovered || w.isSelected);
    final second = w.secondPhotoUrl;
    final showSecond = _hovered && second != null && second != w.photoUrl;

    return MouseRegion(
      opaque: false,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      onHover: w.onHover == null ? null : _handleHover,
      child: GestureDetector(
        onLongPressStart: w.onLongPressStart,
        onLongPressEnd: w.onLongPressEnd,
        child: Semantics(
          button: true,
          label: semanticsLabel,
          selected: w.isSelected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Tokens.radiusMd),
                  child: Material(
                    color: Tokens.surfaceAlt,
                    child: InkWell(
                      onTap: w.onTap,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (w.photoUrl == null)
                            const _CatalogPhotoPlaceholder()
                          else
                            _photo(w.photoUrl!, hero: true),
                          if (second != null && second != w.photoUrl)
                            AnimatedOpacity(
                              opacity: showSecond ? 1 : 0,
                              duration: Tokens.base,
                              child: showSecond || _hovered
                                  ? _photo(second, hero: false)
                                  : const SizedBox.shrink(),
                            ),
                          if (w.isSelected)
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0x33000000),
                              ),
                            ),
                          if (w.isPro)
                            const Positioned(
                              left: 10,
                              bottom: 10,
                              child: _ProBadge(),
                            ),
                          if (w.canSelect) ...[
                            Positioned(
                              top: 10,
                              right: 10,
                              child: AnimatedOpacity(
                                opacity: showActions ? 1 : 0,
                                duration: Tokens.fast,
                                child: IgnorePointer(
                                  ignoring: !showActions,
                                  child: _CardCheck(
                                    value: w.isSelected,
                                    onTap: w.onToggleSelected,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              left: 10,
                              child: AnimatedOpacity(
                                opacity: showActions ? 1 : 0,
                                duration: Tokens.fast,
                                child: IgnorePointer(
                                  ignoring: !showActions,
                                  child: _QuickCardAction(onTap: w.onQuickAdd),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                w.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.smallStrong,
              ),
              const SizedBox(height: 2),
              Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Height of the text block under the 3:4 photo (name + details line).
const double _kCardInfoHeightV2 = 8 + 20 + 2 + 17;

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
    final t = AppLocalizations.of(context)!;
    return Tooltip(
      message: _sentenceCase(t.quickAddTitleUpper),
      child: Material(
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

    // On desktop the shell's top bar already carries the logo.
    final showLeading = leading != null || !isDesktop;

    return Row(
      children: [
        if (showLeading) ...[
          SizedBox(
            width: leadingWidth,
            height: kTopBarH,
            child: Center(
              child: leading ?? const BrandLogo(height: kBrandLogoH),
            ),
          ),
          const SizedBox(width: kGap10),
        ],
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
    final t = AppLocalizations.of(context)!;
    return Semantics(
      checked: value,
      child: Tooltip(
        message: _sentenceCase(value ? t.selectedUpper : t.selectUpper),
        child: Material(
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

    if (kIsWeb) {
      return Tooltip(
        message: Localizations.localeOf(context).languageCode == 'ru'
            ? 'Выбрать все'
            : 'Select all',
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
            side: const BorderSide(color: Tokens.border),
            foregroundColor: value == false ? Tokens.textSecondary : Tokens.text,
          ),
          child: Icon(icon, size: 22),
        ),
      );
    }
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
    this.onMessage,
  });

  final String modelName;
  final List<AgentFolder> folders;
  final VoidCallback onFavorite;
  final VoidCallback onCreateSelection;
  final VoidCallback onCreateFolder;
  final ValueChanged<AgentFolder> onAddToFolder;
  final VoidCallback? onMessage;

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
              if (onMessage != null) ...[
                const SizedBox(height: kGap10),
                _QuickAddMainAction(
                  icon: Icons.chat_bubble_rounded,
                  label:
                      Localizations.localeOf(
                        context,
                      ).languageCode.toLowerCase().startsWith('ru')
                      ? 'НАПИСАТЬ'
                      : 'MESSAGE',
                  onTap: onMessage!,
                ),
              ],
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

/// «ВЫБРАТЬ» → «Выбрать» for tooltips and screen readers.
String _sentenceCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}
