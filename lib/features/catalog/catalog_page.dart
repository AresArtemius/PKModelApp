import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_mapper.dart';
import '../../core/app_logger.dart';
import '../../core/account_profile_service.dart';
import '../../core/entitlements_provider.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_logo.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../analytics/profile_analytics.dart';
import '../profile/profile_model.dart';
import 'catalog_controller.dart';
import 'advanced_search_dialog.dart';
import 'catalog_providers.dart';
import 'catalog_saved_searches.dart';
import 'create_selection_dialog.dart';
import 'agent_workspace.dart';
import 'model_data.dart';
import 'model_agent_tools.dart';
import '../admin/selection_providers.dart';

part 'catalog_page_widgets.dart';

const double _overlayBlurSigma = 6;
const double _overlayBarrierOpacity = 0.65;
const double _overlayPreviewScaleBegin = 0.92;
const int _catalogCardPhotoCacheWidth = 560;
const int _catalogOverlayPhotoCacheWidth = 1000;
const double _catalogDesktopBreakpoint = 900;
const double _catalogDesktopMaxWidth = 1680;
const double _catalogDesktopSidePanelWidth = 320;
const double _catalogDesktopDetailWidth = 360;
const EdgeInsets _catalogDesktopPadding = EdgeInsets.fromLTRB(32, 28, 32, 28);

Alignment _catalogCoverAlignmentFor(ModelVm m) {
  return Alignment(
    m.coverPhotoFocalX.clamp(-1.0, 1.0),
    m.coverPhotoFocalY.clamp(-1.0, 1.0),
  );
}

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key, this.leading});
  final Widget? leading;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  late final ScrollController _gridC;

  bool _isSelectionMode(Set<String> selectedIds) => selectedIds.isNotEmpty;

  OverlayEntry? _photoOverlay;

  final _searchC = TextEditingController();
  Timer? _searchDebounce;
  bool _isSavingSelection = false;
  String? _desktopPreviewModelId;
  late final ProviderSubscription<CatalogController> _controllerSub;

  CatalogController get _c => ref.read(catalogControllerProvider);

  void _syncSearchController(String value) {
    if (_searchC.text == value) return;

    _searchC.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void initState() {
    super.initState();
    _gridC = ScrollController()..addListener(_onScroll);

    final controller = ref.read(catalogControllerProvider);
    _controllerSub = ref.listenManual<CatalogController>(
      catalogControllerProvider,
      (_, next) => _syncSearchController(next.query),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      unawaited(ref.read(catalogSavedSearchesProvider).load());
      await controller.loadBounds();
      if (!mounted) return;
      await controller.reload();
    });
  }

  @override
  void dispose() {
    _hideOverlayPhoto();
    _controllerSub.close();
    _searchDebounce?.cancel();
    _searchC.dispose();
    _gridC.dispose();
    super.dispose();
  }

  void _setSelectedIds(Set<String> ids) {
    ref.read(selectedCatalogModelIdsProvider.notifier).state = ids;
  }

  void _toggleSelected(String id) {
    final current = ref.read(selectedCatalogModelIdsProvider);
    final next = <String>{...current};

    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }

    _setSelectedIds(next);
  }

  void _clearSelection() {
    final current = ref.read(selectedCatalogModelIdsProvider);
    if (current.isEmpty) return;
    _setSelectedIds(<String>{});
  }

  void _setDesktopPreview(String modelId) {
    if (!mounted || _desktopPreviewModelId == modelId) return;
    setState(() => _desktopPreviewModelId = modelId);
  }

  bool _areAllVisibleSelected(Set<String> selectedIds, List<ModelVm> visible) {
    if (visible.isEmpty) return false;
    for (final m in visible) {
      if (!selectedIds.contains(m.id)) return false;
    }
    return true;
  }

  void _toggleSelectAllVisible(List<ModelVm> visible) {
    if (visible.isEmpty) return;

    final current = ref.read(selectedCatalogModelIdsProvider);
    final next = <String>{...current};
    final allSelected = _areAllVisibleSelected(current, visible);

    if (allSelected) {
      for (final m in visible) {
        next.remove(m.id);
      }
    } else {
      for (final m in visible) {
        next.add(m.id);
      }
    }

    _setSelectedIds(next);
  }

  void _onScroll() {
    if (!_gridC.hasClients) return;
    if (!_c.hasMore || _c.isLoadingMore || _c.isInitialLoading) return;
    if (_gridC.position.pixels >=
        _gridC.position.maxScrollExtent - kLoadMoreThresholdPx) {
      _c.scheduleLoadMoreThrottle();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(kSearchDebounce, () {
      if (!mounted) return;

      final trimmed = value.trim();
      if (_c.query == trimmed) return;

      _c.setQuery(trimmed);
      _c.reload();
    });
  }

  Future<void> _refresh() {
    return _c.refresh();
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _openAdvancedSearch() async {
    _unfocus();
    final res = await showDialog<AdvancedSearchResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AdvancedSearchDialog(
        initialAgeFrom: _c.ageFrom,
        initialAgeTo: _c.ageTo,
        initialHeightFrom: _c.heightFrom,
        initialHeightTo: _c.heightTo,
        initialShoeFrom: _c.shoeFrom,
        initialShoeTo: _c.shoeTo,
        initialBustFrom: _c.bustFrom,
        initialBustTo: _c.bustTo,
        initialWaistFrom: _c.waistFrom,
        initialWaistTo: _c.waistTo,
        initialHipsFrom: _c.hipsFrom,
        initialHipsTo: _c.hipsTo,
        initialMinHourlyRateFrom: _c.minHourlyRateFrom,
        initialMinHourlyRateTo: _c.minHourlyRateTo,
        initialMinDailyFeeFrom: _c.minDailyFeeFrom,
        initialMinDailyFeeTo: _c.minDailyFeeTo,
        initialEyeColor: _c.eyeColor,
        initialHairColor: _c.hairColor,
        initialCountry: _c.country,
        initialCity: _c.city,
        initialNeedDate: _c.needDate,
        ageMin: _c.bounds?.ageMin ?? kAgeMin,
        ageMax: _c.bounds?.ageMax ?? kAgeMax,
        heightMin: _c.bounds?.heightMin ?? kHeightMin,
        heightMax: _c.bounds?.heightMax ?? kHeightMax,
        shoeMin: _c.bounds?.shoeMin ?? kShoeMin,
        shoeMax: _c.bounds?.shoeMax ?? kShoeMax,
        bustMin: _c.bounds?.bustMin ?? kBustMin,
        bustMax: _c.bounds?.bustMax ?? kBustMax,
        waistMin: _c.bounds?.waistMin ?? kWaistMin,
        waistMax: _c.bounds?.waistMax ?? kWaistMax,
        hipsMin: _c.bounds?.hipsMin ?? kHipsMin,
        hipsMax: _c.bounds?.hipsMax ?? kHipsMax,
        minHourlyRateMin: _c.bounds?.minHourlyRateMin ?? 0,
        minHourlyRateMax: _c.bounds?.minHourlyRateMax ?? 10000,
        minDailyFeeMin: _c.bounds?.minDailyFeeMin ?? 0,
        minDailyFeeMax: _c.bounds?.minDailyFeeMax ?? 100000,
      ),
    );

    _unfocus();

    if (!mounted || res == null) return;

    _c.applyAdvancedFilters(
      reset: res.reset,
      ageFrom: res.ageFrom,
      ageTo: res.ageTo,
      heightFrom: res.heightFrom,
      heightTo: res.heightTo,
      shoeFrom: res.shoeFrom,
      shoeTo: res.shoeTo,
      bustFrom: res.bustFrom,
      bustTo: res.bustTo,
      waistFrom: res.waistFrom,
      waistTo: res.waistTo,
      hipsFrom: res.hipsFrom,
      hipsTo: res.hipsTo,
      minHourlyRateFrom: res.minHourlyRateFrom,
      minHourlyRateTo: res.minHourlyRateTo,
      minDailyFeeFrom: res.minDailyFeeFrom,
      minDailyFeeTo: res.minDailyFeeTo,
      eyeColor: res.eyeColor,
      hairColor: res.hairColor,
      country: res.country,
      city: res.city,
      needDate: res.needDate,
    );

    await _c.reload();
  }

  Future<void> _clearCatalogFilters() async {
    _unfocus();
    _searchDebounce?.cancel();
    _c.clearAllFilters();
    await _c.reload();
  }

  List<CatalogSavedSearch> _builtInSavedSearches(AppLocalizations t) {
    return const <CatalogSavedSearch>[];
  }

  Future<void> _applySavedSearch(CatalogSavedSearch search) async {
    _unfocus();
    _clearSelection();
    _c.applyFilterSnapshot(search.filters);
    await _c.reload();
  }

  Future<void> _saveCurrentSearch() async {
    _unfocus();
    final t = AppLocalizations.of(context)!;
    final title = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SaveSearchDialog(
        title: t.savedSearchSaveTitle,
        hint: t.savedSearchNameHint,
        emptyError: t.savedSearchNameRequired,
        cancelLabel: t.cancelUpper,
        saveLabel: t.saveUpper,
      ),
    );

    if (!mounted || title == null) return;

    try {
      await ref
          .read(catalogSavedSearchesProvider)
          .save(title: title, filters: _c.filterSnapshot);
      await ref.read(catalogSavedSearchesProvider).refresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.savedSearchSaved)));
  }

  Future<void> _deleteSavedSearch(CatalogSavedSearch search) async {
    if (search.isBuiltin) return;
    final t = AppLocalizations.of(context)!;

    try {
      await ref.read(catalogSavedSearchesProvider).delete(search.id);
    } catch (e) {
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.savedSearchDeleted)));
  }

  Future<void> _renameSavedSearch(CatalogSavedSearch search) async {
    if (search.isBuiltin) return;
    _unfocus();
    final t = AppLocalizations.of(context)!;
    final title = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SaveSearchDialog(
        title: t.savedSearchRenameTitle,
        hint: t.savedSearchNameHint,
        emptyError: t.savedSearchNameRequired,
        cancelLabel: t.cancelUpper,
        saveLabel: t.saveUpper,
        initialValue: search.title,
      ),
    );

    if (!mounted || title == null) return;

    try {
      await ref
          .read(catalogSavedSearchesProvider)
          .rename(id: search.id, title: title);
    } catch (e) {
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.savedSearchRenamed)));
  }

  void _showOverlayPhoto(String heroTag, String url) {
    if (_photoOverlay != null) return;

    _photoOverlay = OverlayEntry(
      builder: (_) {
        return Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerUp: (_) => _hideOverlayPhoto(),
            onPointerCancel: (_) => _hideOverlayPhoto(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _overlayBlurSigma,
                    sigmaY: _overlayBlurSigma,
                  ),
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: _overlayBarrierOpacity,
                    ),
                  ),
                ),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: _overlayPreviewScaleBegin, end: 1.0),
                    duration: kAnim160,
                    curve: Curves.easeOutBack,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(kSearchRadius),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          memCacheWidth: _catalogOverlayPhotoCacheWidth,
                          maxWidthDiskCache: _catalogOverlayPhotoCacheWidth,
                          fit: BoxFit.contain,
                          fadeInDuration: const Duration(milliseconds: 180),
                          placeholder: (_, _) => Container(
                            width: kOverlayImageSize,
                            height: kOverlayImageSize,
                            decoration: catalogPhotoPlaceholderDecoration(),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: kOverlayImageSize,
                            height: kOverlayImageSize,
                            decoration: catalogPhotoPlaceholderDecoration(),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: kTextMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_photoOverlay!);
  }

  void _hideOverlayPhoto() {
    _photoOverlay?.remove();
    _photoOverlay = null;
  }

  Future<SelectionDraft?> _showSelectionProjectDialog() async {
    _unfocus();
    return showDialog<SelectionDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CreateSelectionDialog(),
    );
  }

  Future<void> _createSelection({
    required SelectionDraft draft,
    required List<String> profileIds,
  }) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;

    Future<bool> createViaRpc() async {
      try {
        await sb.rpc(
          'create_selection_with_items',
          params: {
            'p_title': draft.title,
            'p_profile_ids': profileIds,
            'p_request_video_intro': draft.requestVideoIntro,
            'p_video_intro_requirements': draft.videoIntroRequirements,
          },
        );
        return true;
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
            .toLowerCase();
        if (msg.contains('create_selection_with_items') ||
            msg.contains('function') ||
            msg.contains('schema cache') ||
            e.code == 'PGRST202') {
          return false;
        }
        rethrow;
      }
    }

    if (await createViaRpc()) return;

    Future<Map<String, dynamic>> insertSelection({
      required bool includeVideoRequest,
      required bool includeCampaignFields,
    }) async {
      final payload = <String, dynamic>{
        'title': draft.title,
        if (uid != null) 'created_by': uid,
        if (includeCampaignFields) 'client_name': draft.clientName,
        if (includeCampaignFields) 'brand_name': draft.brandName,
        if (includeCampaignFields) 'budget': draft.budget,
        if (includeCampaignFields) 'location': draft.location,
        if (includeCampaignFields) 'project_dates': draft.projectDates,
        if (includeCampaignFields) 'project_roles': draft.projectRoles,
        if (includeVideoRequest) 'request_video_intro': draft.requestVideoIntro,
        if (includeVideoRequest)
          'video_intro_requirements': draft.videoIntroRequirements,
      };

      return await sb.from('selections').insert(payload).select('id').single();
    }

    Map<String, dynamic> inserted;
    try {
      inserted = await insertSelection(
        includeVideoRequest: true,
        includeCampaignFields: true,
      );
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
          .toLowerCase();
      if (!msg.contains('client_name') &&
          !msg.contains('brand_name') &&
          !msg.contains('budget') &&
          !msg.contains('location') &&
          !msg.contains('project_dates') &&
          !msg.contains('project_roles') &&
          !msg.contains('request_video_intro') &&
          !msg.contains('video_intro_requirements') &&
          !msg.contains('schema cache')) {
        rethrow;
      }
      try {
        inserted = await insertSelection(
          includeVideoRequest: true,
          includeCampaignFields: false,
        );
      } on PostgrestException {
        inserted = await insertSelection(
          includeVideoRequest: false,
          includeCampaignFields: false,
        );
      }
    }

    final selectionId = (inserted['id'] ?? '').toString();
    if (selectionId.isEmpty) {
      throw StateError('selection_insert_failed');
    }

    final items = profileIds
        .map(
          (profileId) => {'selection_id': selectionId, 'profile_id': profileId},
        )
        .toList(growable: false);

    await sb.from('selection_items').insert(items);
    for (final profileId in profileIds) {
      unawaited(
        ref.read(profileAnalyticsServiceProvider).trackSelectionAdd(profileId),
      );
    }
  }

  Future<void> _onSelectModelsTap(Set<String> selectedIds) async {
    if (selectedIds.isEmpty || _isSavingSelection) return;

    final t = AppLocalizations.of(context)!;
    final entitlements = await ref.read(accountEntitlementsProvider.future);
    final profileLimit = entitlements.maxProfilesPerSelection;
    if (profileLimit != null && selectedIds.length > profileLimit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(t.selectionProfileLimitMessage(profileLimit))),
        );
      return;
    }

    final selectionLimit = entitlements.maxActiveSelections;
    if (selectionLimit != null &&
        await _hasReachedSelectionLimit(selectionLimit)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(t.selectionCountLimitMessage(selectionLimit))),
        );
      return;
    }

    final draft = await _showSelectionProjectDialog();
    if (!mounted || draft == null) return;

    final trimmedTitle = draft.title.trim();
    if (trimmedTitle.isEmpty) return;

    final profileIds = selectedIds.toList(growable: false);

    setState(() => _isSavingSelection = true);
    try {
      await _createSelection(draft: draft, profileIds: profileIds);

      if (!mounted) return;

      ref.invalidate(adminSelectionListProvider);
      _clearSelection();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${t.selectionUpper}: $trimmedTitle')),
        );
    } catch (e) {
      assert(() {
        AppLogger.error('Catalog selection creation failed', error: e);
        return true;
      }());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(AppErrorMapper.message(e, t))));
    } finally {
      if (mounted) {
        setState(() => _isSavingSelection = false);
      }
    }
  }

  Future<void> _openQuickAdd(ModelVm model) async {
    _unfocus();

    final folders = await ref.read(agentFoldersProvider.future);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => _QuickAddSheet(
        modelName: model.fullName,
        folders: folders,
        onFavorite: () async {
          Navigator.of(context).pop();
          await _addModelToFavorite(model.id);
        },
        onCreateSelection: () async {
          Navigator.of(context).pop();
          await _createQuickSelection(model.id);
        },
        onCreateFolder: () async {
          Navigator.of(context).pop();
          await _createFolderAndAddModel(model.id);
        },
        onAddToFolder: (folder) async {
          Navigator.of(context).pop();
          await _addModelToFolder(model.id, folder);
        },
      ),
    );
  }

  Future<void> _addModelToFavorite(String profileId) async {
    final t = AppLocalizations.of(context)!;
    try {
      await ref
          .read(agentWorkspaceServiceProvider)
          .addProfileToNamedFolder(
            title: t.agentFavoriteFolderTitle,
            profileId: profileId,
          );
      _invalidateAgentWorkspace(profileId);
      if (!mounted) return;
      _showSnack(t.quickAddFavoriteDone);
    } catch (e) {
      assert(() {
        AppLogger.error('Catalog quick favorite failed', error: e);
        return true;
      }());
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
    }
  }

  Future<void> _addModelToFolder(String profileId, AgentFolder folder) async {
    final t = AppLocalizations.of(context)!;
    try {
      await ref
          .read(agentWorkspaceServiceProvider)
          .setProfileInFolder(
            folderId: folder.id,
            profileId: profileId,
            selected: true,
          );
      _invalidateAgentWorkspace(profileId);
      if (!mounted) return;
      _showSnack(t.quickAddFolderDone(folder.title));
    } catch (e) {
      assert(() {
        AppLogger.error('Catalog quick folder add failed', error: e);
        return true;
      }());
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
    }
  }

  Future<void> _createFolderAndAddModel(String profileId) async {
    final t = AppLocalizations.of(context)!;
    final title = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AgentTextInputDialog(
        title: t.agentFolderCreateTitle,
        hint: t.agentFolderName,
        actionLabel: t.saveUpper,
      ),
    );

    if (!mounted || title == null || title.trim().isEmpty) return;

    try {
      await ref
          .read(agentWorkspaceServiceProvider)
          .addProfileToNamedFolder(title: title, profileId: profileId);
      _invalidateAgentWorkspace(profileId);
      if (!mounted) return;
      _showSnack(t.quickAddFolderDone(title.trim()));
    } catch (e) {
      assert(() {
        AppLogger.error('Catalog quick folder create failed', error: e);
        return true;
      }());
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
    }
  }

  Future<void> _createQuickSelection(String profileId) async {
    final t = AppLocalizations.of(context)!;
    final selectionLimit = (await ref.read(
      accountEntitlementsProvider.future,
    )).maxActiveSelections;
    if (selectionLimit != null &&
        await _hasReachedSelectionLimit(selectionLimit)) {
      if (!mounted) return;
      _showSnack(t.selectionCountLimitMessage(selectionLimit));
      return;
    }

    final draft = await _showSelectionProjectDialog();
    if (!mounted || draft == null || draft.title.trim().isEmpty) return;

    setState(() => _isSavingSelection = true);
    try {
      await _createSelection(draft: draft, profileIds: <String>[profileId]);
      ref.invalidate(adminSelectionListProvider);
      if (!mounted) return;
      _showSnack(t.quickAddSelectionDone(draft.title.trim()));
    } catch (e) {
      assert(() {
        AppLogger.error('Catalog quick selection failed', error: e);
        return true;
      }());
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
    } finally {
      if (mounted) setState(() => _isSavingSelection = false);
    }
  }

  void _invalidateAgentWorkspace(String profileId) {
    ref.invalidate(agentFoldersProvider);
    ref.invalidate(agentFoldersForProfileProvider(profileId));
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _hasReachedSelectionLimit(int limit) async {
    if (limit < 1) return true;

    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return true;

    try {
      final rows = await sb
          .from('selections')
          .select('id')
          .eq('created_by', uid)
          .limit(limit);

      return rows.length >= limit;
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
          .toLowerCase();
      if (msg.contains('created_by') || msg.contains('schema cache')) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(catalogSelectionAuthSyncProvider);

    final c = ref.watch(catalogControllerProvider);
    final selectedIds = ref.watch(selectedCatalogModelIdsProvider);
    final savedSearches = ref.watch(catalogSavedSearchesProvider);
    final t = AppLocalizations.of(context)!;
    final filteredItems = c.applyLocalFilters(c.loaded);

    final session = Supabase.instance.client.auth.currentSession;
    final accountProfile = ref.watch(accountOwnerProfileProvider).valueOrNull;
    final accountLabel = session == null
        ? t.guestUpper
        : (accountProfile?.publicHandleLabel.trim().isNotEmpty ?? false)
        ? accountProfile!.publicHandleLabel.trim()
        : (session.user.email ?? session.user.phone ?? t.accountUpper);
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final canCreateSelections = ref
        .watch(canCreateSelectionsProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final entitlements = ref.watch(accountEntitlementsProvider).valueOrNull;
    final canUseAgentFolders =
        canCreateSelections && (entitlements?.canUseAgentFolders ?? isAdmin);
    final effectiveSelectedIds = canCreateSelections
        ? selectedIds
        : const <String>{};
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _catalogDesktopBreakpoint;
    final pagePadding = isDesktop
        ? _catalogDesktopPadding
        : const EdgeInsets.fromLTRB(
            kPagePadH,
            kPagePadTop,
            kPagePadH,
            kPagePadBottom,
          );
    final savedSearchItems = [
      ..._builtInSavedSearches(t),
      ...savedSearches.items,
    ];
    final currentSearchAlreadySaved = savedSearchItems.any(
      (search) => search.filters == c.filterSnapshot,
    );
    final canSaveCurrentSearch =
        c.hasActiveFilters && !currentSearchAlreadySaved;
    final hasSavedSearchRail =
        canSaveCurrentSearch ||
        savedSearchItems.isNotEmpty ||
        savedSearches.isLoading ||
        savedSearches.lastError != null;
    final resetFiltersLabel =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru'
        ? 'СБРОСИТЬ ФИЛЬТРЫ'
        : 'RESET FILTERS';
    final previewModel = isDesktop && filteredItems.isNotEmpty
        ? filteredItems.firstWhere(
            (model) => model.id == _desktopPreviewModelId,
            orElse: () => filteredItems.first,
          )
        : null;
    final roleTabs = _CatalogRoleTabs(
      selectedRole: c.profileRole,
      onChanged: (role) {
        _unfocus();
        c.setProfileRole(role);
      },
    );

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop
                      ? _catalogDesktopMaxWidth
                      : double.infinity,
                ),
                child: Padding(
                  padding: pagePadding,
                  child: Stack(
                    children: [
                      if (isDesktop)
                        _CatalogDesktopLayout(
                          topBar: _TopBar(
                            onAdvancedSearch: _openAdvancedSearch,
                            onFolders: canUseAgentFolders
                                ? () => context.go(Routes.agentFolders)
                                : null,
                            accountLabel: accountLabel,
                            leading: widget.leading,
                            advancedSearchEnabled: !c.isInitialLoading,
                            isDesktop: true,
                          ),
                          onAdvancedSearch: _openAdvancedSearch,
                          advancedSearchEnabled: !c.isInitialLoading,
                          onResetFilters: c.hasActiveFilters
                              ? _clearCatalogFilters
                              : null,
                          resetFiltersLabel: resetFiltersLabel,
                          roleTabs: roleTabs,
                          search: _CatalogSearchRow(
                            controller: _searchC,
                            onChanged: _onSearchChanged,
                            hintText: t.catalogSearchHintUpper,
                            items: filteredItems,
                            selectedIds: effectiveSelectedIds,
                            canSelect: canCreateSelections,
                            onSelectAllTap: (items) {
                              _unfocus();
                              _toggleSelectAllVisible(items);
                            },
                          ),
                          savedSearches: hasSavedSearchRail
                              ? _SavedSearchRail(
                                  searches: savedSearchItems,
                                  activeFilters: c.filterSnapshot,
                                  onApply: _applySavedSearch,
                                  onRename: _renameSavedSearch,
                                  onSaveCurrent: _saveCurrentSearch,
                                  onDelete: _deleteSavedSearch,
                                  saveLabel: t.savedSearchSaveCurrent,
                                  canSaveCurrent: canSaveCurrentSearch,
                                  isLoading: savedSearches.isLoading,
                                  error: savedSearches.lastError,
                                  onRefresh: () => ref
                                      .read(catalogSavedSearchesProvider)
                                      .refresh(),
                                  isVertical: true,
                                )
                              : null,
                          grid: _CatalogResultsBody(
                            controller: c,
                            filteredItems: filteredItems,
                            selectedIds: effectiveSelectedIds,
                            gridController: _gridC,
                            onRefresh: _refresh,
                            onOpenModel: (modelId) async {
                              _unfocus();
                              _setDesktopPreview(modelId);
                            },
                            onToggleSelected: _toggleSelected,
                            onQuickAdd: _openQuickAdd,
                            onPreviewPhoto: (heroTag, photoUrl) {
                              _unfocus();
                              _showOverlayPhoto(heroTag, photoUrl);
                            },
                            onHidePreviewPhoto: _hideOverlayPhoto,
                            isSelectionMode: _isSelectionMode(
                              effectiveSelectedIds,
                            ),
                            canSelect: canCreateSelections,
                            cmLabel: t.cm,
                            bottomInset: 24,
                            onAutoLoadMore: () {
                              if (!mounted) return;
                              c.loadMore();
                            },
                          ),
                          detail: _CatalogDesktopPreview(
                            model: previewModel,
                            cmLabel: t.cm,
                            onOpen: previewModel == null
                                ? null
                                : () async {
                                    _unfocus();
                                    await context.push(
                                      '/model/${previewModel.id}',
                                    );
                                  },
                            onQuickAdd: previewModel == null
                                ? null
                                : () => _openQuickAdd(previewModel),
                            canUseAgentTools: canCreateSelections,
                          ),
                        )
                      else
                        Column(
                          children: [
                            _TopBar(
                              onAdvancedSearch: _openAdvancedSearch,
                              onFolders: canUseAgentFolders
                                  ? () => context.go(Routes.agentFolders)
                                  : null,
                              accountLabel: accountLabel,
                              leading: widget.leading,
                              advancedSearchEnabled: !c.isInitialLoading,
                              isDesktop: false,
                            ),
                            const SizedBox(height: kGap12),
                            _CatalogSearchRow(
                              controller: _searchC,
                              onChanged: _onSearchChanged,
                              hintText: t.catalogSearchHintUpper,
                              items: filteredItems,
                              selectedIds: effectiveSelectedIds,
                              canSelect: canCreateSelections,
                              onSelectAllTap: (items) {
                                _unfocus();
                                _toggleSelectAllVisible(items);
                              },
                            ),
                            if (hasSavedSearchRail) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _SavedSearchRail(
                                      searches: savedSearchItems,
                                      activeFilters: c.filterSnapshot,
                                      onApply: _applySavedSearch,
                                      onRename: _renameSavedSearch,
                                      onSaveCurrent: _saveCurrentSearch,
                                      onDelete: _deleteSavedSearch,
                                      saveLabel: t.savedSearchSaveCurrent,
                                      canSaveCurrent: canSaveCurrentSearch,
                                      isLoading: savedSearches.isLoading,
                                      error: savedSearches.lastError,
                                      onRefresh: () => ref
                                          .read(catalogSavedSearchesProvider)
                                          .refresh(),
                                    ),
                                  ),
                                  const SizedBox(width: kGap8),
                                  roleTabs,
                                ],
                              ),
                              if (c.hasActiveFilters) ...[
                                const SizedBox(height: kGap8),
                                _DesktopFilterAction(
                                  icon: Icons.restart_alt_rounded,
                                  label: resetFiltersLabel,
                                  onTap: _clearCatalogFilters,
                                ),
                              ],
                              const SizedBox(height: kGap12),
                            ] else ...[
                              roleTabs,
                              if (c.hasActiveFilters) ...[
                                const SizedBox(height: kGap8),
                                _DesktopFilterAction(
                                  icon: Icons.restart_alt_rounded,
                                  label: resetFiltersLabel,
                                  onTap: _clearCatalogFilters,
                                ),
                              ],
                              const SizedBox(height: kGap12),
                            ],
                            Expanded(
                              child: _CatalogResultsBody(
                                controller: c,
                                filteredItems: filteredItems,
                                selectedIds: effectiveSelectedIds,
                                gridController: _gridC,
                                onRefresh: _refresh,
                                onOpenModel: (modelId) async {
                                  _unfocus();
                                  await context.push('/model/$modelId');
                                },
                                onToggleSelected: _toggleSelected,
                                onQuickAdd: _openQuickAdd,
                                onPreviewPhoto: (heroTag, photoUrl) {
                                  _unfocus();
                                  _showOverlayPhoto(heroTag, photoUrl);
                                },
                                onHidePreviewPhoto: _hideOverlayPhoto,
                                isSelectionMode: _isSelectionMode(
                                  effectiveSelectedIds,
                                ),
                                canSelect: canCreateSelections,
                                cmLabel: t.cm,
                                bottomInset: 84,
                                onAutoLoadMore: () {
                                  if (!mounted) return;
                                  c.loadMore();
                                },
                              ),
                            ),
                          ],
                        ),
                      _SelectModelsButton(
                        visible:
                            canCreateSelections &&
                            _isSelectionMode(effectiveSelectedIds),
                        selectedCount: effectiveSelectedIds.length,
                        isBusy: _isSavingSelection,
                        onTap: () => _onSelectModelsTap(effectiveSelectedIds),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
