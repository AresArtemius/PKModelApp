import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../profile/profile_model.dart';
import 'admin_style.dart';

const _kProfilesPageBg = BrandTheme.greyMid;
const _kProfilesPad = 16.0;
const _kProfilesDesktopBreakpoint = 920.0;
const _kProfilesListCacheExtent = 900.0;
const _kProfilesPageSize = 80;

class _AdminProfilesPageData {
  const _AdminProfilesPageData({required this.rows, required this.hasMore});

  final List<_AdminProfileRow> rows;
  final bool hasMore;
}

class _AdminProfilesQuery {
  const _AdminProfilesQuery({
    required this.limit,
    required this.search,
    required this.status,
    required this.role,
  });

  final int limit;
  final String search;
  final ProfileStatus? status;
  final ProfessionalProfileType? role;

  @override
  bool operator ==(Object other) {
    return other is _AdminProfilesQuery &&
        limit == other.limit &&
        search == other.search &&
        status == other.status &&
        role == other.role;
  }

  @override
  int get hashCode => Object.hash(limit, search, status, role);
}

final _adminProfilesProvider = FutureProvider.autoDispose
    .family<_AdminProfilesPageData, _AdminProfilesQuery>((ref, params) async {
      final sb = ref.watch(supabaseProvider);
      final ownerIds = await _loadProfileOwnerIdsForSearch(sb, params.search);
      try {
        var request = sb
            .from('profiles')
            .select(_adminProfilesColumns(includeProfileRoles: true));
        request = _applyProfileServerFilters(
          request,
          params: params,
          ownerIds: ownerIds,
          includeProfileRoles: true,
        );
        final rows = await request
            .order('updated_at', ascending: false)
            .range(0, params.limit);
        final ownersByUserId = await _loadOwnersByUserId(sb);
        final list = rows as List;
        return _AdminProfilesPageData(
          hasMore: list.length > params.limit,
          rows: list
              .take(params.limit)
              .map((row) {
                final map = Map<String, dynamic>.from(row as Map);
                return _AdminProfileRow.fromMap(
                  map,
                  owner: ownersByUserId[(map['user_id'] ?? '').toString()],
                );
              })
              .toList(growable: false),
        );
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingColumn(e, 'profile_roles')) {
          var request = sb
              .from('profiles')
              .select(_adminProfilesColumns(includeProfileRoles: false));
          request = _applyProfileServerFilters(
            request,
            params: params,
            ownerIds: ownerIds,
            includeProfileRoles: false,
          );
          final rows = await request
              .order('updated_at', ascending: false)
              .range(0, params.limit);
          final ownersByUserId = await _loadOwnersByUserId(sb);
          final list = rows as List;
          return _AdminProfilesPageData(
            hasMore: list.length > params.limit,
            rows: list
                .take(params.limit)
                .map((row) {
                  final map = Map<String, dynamic>.from(row as Map);
                  return _AdminProfileRow.fromMap(
                    map,
                    owner: ownersByUserId[(map['user_id'] ?? '').toString()],
                  );
                })
                .toList(growable: false),
          );
        }
        if (SupabaseCompat.isMissingRelation(e, const ['profiles'])) {
          return const _AdminProfilesPageData(
            rows: <_AdminProfileRow>[],
            hasMore: false,
          );
        }
        rethrow;
      }
    });

dynamic _applyProfileServerFilters(
  dynamic request, {
  required _AdminProfilesQuery params,
  required Set<String>? ownerIds,
  required bool includeProfileRoles,
}) {
  var next = request;
  final status = params.status;
  if (status != null) {
    next = next.eq('status', statusToString(status));
  }

  final role = params.role;
  if (role != null) {
    final storage = role.storageValue;
    next = includeProfileRoles
        ? next.filter('profile_roles', 'cs', '{$storage}')
        : next.eq('profile_type', storage);
  }

  final clean = _adminSearchTerm(params.search);
  if (clean.isNotEmpty) {
    final parts = <String>[
      'full_name.ilike.%$clean%',
      'city.ilike.%$clean%',
      'country.ilike.%$clean%',
      if (ownerIds != null && ownerIds.isNotEmpty)
        'user_id.in.(${ownerIds.join(',')})',
    ];
    next = next.or(parts.join(','));
  }

  return next;
}

String _adminSearchTerm(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[,()]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('%', r'\%')
      .replaceAll('*', r'\*');
}

Future<Set<String>?> _loadProfileOwnerIdsForSearch(
  SupabaseClient sb,
  String search,
) async {
  final clean = _adminSearchTerm(search);
  if (clean.isEmpty) return null;

  Future<Set<String>> run({required bool includeTag}) async {
    var request = sb
        .from('user_profiles')
        .select('user_id,email,phone,full_name,company_name');
    final fields = [
      'email',
      'phone',
      if (includeTag) 'account_tag',
      'full_name',
      'company_name',
    ];
    request = request.or(
      fields.map((field) => '$field.ilike.%$clean%').join(','),
    );
    final rows = await request.limit(250);
    return {
      for (final row in rows as List)
        ((row as Map)['user_id'] ?? '').toString().trim(),
    }..remove('');
  }

  try {
    return await run(includeTag: true);
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingColumn(e, 'account_tag')) {
      return run(includeTag: false);
    }
    if (SupabaseCompat.isMissingRelation(e, const ['user_profiles'])) {
      return const <String>{};
    }
    rethrow;
  }
}

String _adminProfilesColumns({required bool includeProfileRoles}) {
  return [
    'id',
    'user_id',
    'full_name',
    'profile_type',
    if (includeProfileRoles) 'profile_roles',
    'status',
    'verification_status',
    'is_verified',
    'birth_date',
    'age',
    'height',
    'city',
    'country',
    'photo_urls',
    'video_urls',
    'cover_photo_url',
    'has_pending_media',
    'updated_at',
    'created_at',
  ].join(',');
}

Future<Map<String, _AdminProfileOwner>> _loadOwnersByUserId(
  SupabaseClient sb,
) async {
  try {
    final rows = await sb
        .from('user_profiles')
        .select('user_id,email,phone,account_tag,full_name,company_name')
        .limit(1000);
    return {
      for (final row in rows as List)
        _AdminProfileOwner.fromMap(
          Map<String, dynamic>.from(row as Map),
        ).userId: _AdminProfileOwner.fromMap(
          Map<String, dynamic>.from(row),
        ),
    };
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['user_profiles'])) {
      return const <String, _AdminProfileOwner>{};
    }
    if (SupabaseCompat.isMissingColumn(e, 'account_tag')) {
      final rows = await sb
          .from('user_profiles')
          .select('user_id,email,phone,full_name,company_name')
          .limit(1000);
      return {
        for (final row in rows as List)
          _AdminProfileOwner.fromMap(
            Map<String, dynamic>.from(row as Map),
          ).userId: _AdminProfileOwner.fromMap(
            Map<String, dynamic>.from(row),
          ),
      };
    }
    rethrow;
  }
}

class AdminProfilesPage extends ConsumerStatefulWidget {
  const AdminProfilesPage({super.key});

  @override
  ConsumerState<AdminProfilesPage> createState() => _AdminProfilesPageState();
}

class _AdminProfilesPageState extends ConsumerState<AdminProfilesPage> {
  final TextEditingController _searchC = TextEditingController();
  _AdminProfileStatusFilter _statusFilter = _AdminProfileStatusFilter.all;
  ProfessionalProfileType? _roleFilter;
  int _profilesLimit = _kProfilesPageSize;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String message) async {
    return showAdminConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: 'Удалить',
      destructive: true,
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _deleteProfile(_AdminProfileRow profile) async {
    final confirmed = await _confirm(
      'Удалить анкету',
      'Удалить анкету ${profile.displayName(true)}?',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(supabaseProvider)
          .rpc('admin_delete_profile', params: {'p_profile_id': profile.id});
      ref.invalidate(_adminProfilesProvider);
      _snack('Анкета удалена');
    } catch (e) {
      _snack(_adminProfilesActionError(e, 'Не удалось удалить анкету'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isAdminAsync = ref.watch(isAdminProvider);
    final profilesQuery = _AdminProfilesQuery(
      limit: _profilesLimit,
      search: _searchC.text,
      status: _statusFilter.status,
      role: _roleFilter,
    );
    final profilesAsync = ref.watch(_adminProfilesProvider(profilesQuery));

    return Scaffold(
      backgroundColor: _kProfilesPageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_kProfilesPad),
          child: Column(
            children: [
              BrandAdminHeader(
                title: ru ? 'ВСЕ АНКЕТЫ' : 'ALL PROFILES',
                onBack: () => context.go(Routes.admin),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: isAdminAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => AdminMessageCard(
                    text: ru ? 'Только для администратора' : 'Admins only',
                    isError: true,
                  ),
                  data: (isAdmin) {
                    if (!isAdmin) {
                      return AdminMessageCard(
                        text: ru ? 'Только для администратора' : 'Admins only',
                        isError: true,
                      );
                    }
                    return profilesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => AdminMessageCard(
                        text: ru
                            ? 'Не удалось загрузить анкеты: $error'
                            : 'Could not load profiles: $error',
                        isError: true,
                        maxWidth: 680,
                      ),
                      data: (data) => _ProfilesTablePanel(
                        profiles: data.rows,
                        hasMore: data.hasMore,
                        searchController: _searchC,
                        statusFilter: _statusFilter,
                        roleFilter: _roleFilter,
                        onStatusFilterChanged: (value) => setState(() {
                          _statusFilter = value;
                          _profilesLimit = _kProfilesPageSize;
                        }),
                        onRoleFilterChanged: (value) => setState(() {
                          _roleFilter = value;
                          _profilesLimit = _kProfilesPageSize;
                        }),
                        onSearchChanged: () => setState(() {
                          _profilesLimit = _kProfilesPageSize;
                        }),
                        onLoadMore: () => setState(
                          () => _profilesLimit += _kProfilesPageSize,
                        ),
                        onDeleteProfile: _deleteProfile,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilesTablePanel extends StatelessWidget {
  const _ProfilesTablePanel({
    required this.profiles,
    required this.hasMore,
    required this.searchController,
    required this.statusFilter,
    required this.roleFilter,
    required this.onStatusFilterChanged,
    required this.onRoleFilterChanged,
    required this.onSearchChanged,
    required this.onLoadMore,
    required this.onDeleteProfile,
  });

  final List<_AdminProfileRow> profiles;
  final bool hasMore;
  final TextEditingController searchController;
  final _AdminProfileStatusFilter statusFilter;
  final ProfessionalProfileType? roleFilter;
  final ValueChanged<_AdminProfileStatusFilter> onStatusFilterChanged;
  final ValueChanged<ProfessionalProfileType?> onRoleFilterChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onLoadMore;
  final ValueChanged<_AdminProfileRow> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final query = searchController.text.trim().toLowerCase();
    final filtered = profiles
        .where((profile) {
          final statusOk =
              statusFilter == _AdminProfileStatusFilter.all ||
              profile.status == statusFilter.status;
          final roleOk =
              roleFilter == null || profile.roles.contains(roleFilter);
          final searchOk = query.isEmpty || profile.searchable.contains(query);
          return statusOk && roleOk && searchOk;
        })
        .toList(growable: false);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kProfilesDesktopBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfilesToolbar(
          controller: searchController,
          statusFilter: statusFilter,
          roleFilter: roleFilter,
          onStatusFilterChanged: onStatusFilterChanged,
          onRoleFilterChanged: onRoleFilterChanged,
          onSearchChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? Column(
                  children: [
                    Expanded(
                      child: _ProfilesEmptyState(
                        text: ru ? 'Анкеты не найдены' : 'No profiles found',
                      ),
                    ),
                    if (hasMore)
                      AdminLoadMoreFooter(
                        label: ru ? 'Загрузить еще' : 'Load more',
                        onPressed: onLoadMore,
                      ),
                  ],
                )
              : isDesktop
              ? DecoratedBox(
                  decoration: catalogCardDecoration().copyWith(
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Scrollbar(
                    thumbVisibility: isDesktop,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isDesktop ? 1160 : 1040,
                        ),
                        child: ListView.separated(
                          // ignore: deprecated_member_use
                          cacheExtent: _kProfilesListCacheExtent,
                          padding: const EdgeInsets.all(10),
                          itemCount: filtered.length + 1 + (hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: kBorderColor),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const _ProfilesTableHeader();
                            }
                            if (hasMore && index == filtered.length + 1) {
                              return AdminLoadMoreFooter(
                                label: ru ? 'Загрузить еще' : 'Load more',
                                onPressed: onLoadMore,
                              );
                            }
                            return _ProfileTableRow(
                              profile: filtered[index - 1],
                              onDeleteProfile: onDeleteProfile,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                )
              : _ProfilesMobileList(
                  profiles: filtered,
                  hasMore: hasMore,
                  onLoadMore: onLoadMore,
                  onDeleteProfile: onDeleteProfile,
                ),
        ),
      ],
    );
  }
}

class _ProfilesEmptyState extends StatelessWidget {
  const _ProfilesEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(color: kBorderColor),
      ),
      child: Center(
        child: Text(
          text,
          style: adminCommandStyle(
            size: 13,
            letterSpacing: 0.7,
            color: kTextMuted,
          ),
        ),
      ),
    );
  }
}

class _ProfilesMobileList extends StatelessWidget {
  const _ProfilesMobileList({
    required this.profiles,
    required this.hasMore,
    required this.onLoadMore,
    required this.onDeleteProfile,
  });

  final List<_AdminProfileRow> profiles;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<_AdminProfileRow> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // ignore: deprecated_member_use
      cacheExtent: _kProfilesListCacheExtent,
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: profiles.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= profiles.length) {
          final ru = Localizations.localeOf(context).languageCode == 'ru';
          return AdminLoadMoreFooter(
            label: ru ? 'Загрузить еще' : 'Load more',
            onPressed: onLoadMore,
          );
        }
        return _ProfileMobileCard(
          profile: profiles[index],
          onDeleteProfile: onDeleteProfile,
        );
      },
    );
  }
}

class _ProfileMobileCard extends StatelessWidget {
  const _ProfileMobileCard({
    required this.profile,
    required this.onDeleteProfile,
  });

  final _AdminProfileRow profile;
  final ValueChanged<_AdminProfileRow> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final meta = [
      profile.rolesLabel(ru),
      profile.ownerLabel,
      profile.locationLabel,
      profile.basicsLabel(ru),
      profile.mediaLabel(ru),
    ].where((part) => part.trim().isNotEmpty).join(' • ');
    return DecoratedBox(
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(color: kBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileCover(profile: profile),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          profile.displayName(ru),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: adminCommandStyle(
                            size: 14,
                            letterSpacing: 0.1,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: profile.status),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    profile.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminBodyStyle(size: 11),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: adminBodyStyle(size: 12, color: kTextDark),
                    ),
                  ],
                ],
              ),
            ),
            _ProfileActionsMenu(
              profile: profile,
              onDeleteProfile: onDeleteProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilesToolbar extends StatelessWidget {
  const _ProfilesToolbar({
    required this.controller,
    required this.statusFilter,
    required this.roleFilter,
    required this.onStatusFilterChanged,
    required this.onRoleFilterChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final _AdminProfileStatusFilter statusFilter;
  final ProfessionalProfileType? roleFilter;
  final ValueChanged<_AdminProfileStatusFilter> onStatusFilterChanged;
  final ValueChanged<ProfessionalProfileType?> onRoleFilterChanged;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return AdminMobileToolbar(
      controller: controller,
      hintText: ru ? 'Поиск по имени, городу, владельцу' : 'Search',
      onSearchChanged: onSearchChanged,
      filters: [
        AdminMenuFilter<_AdminProfileStatusFilter>(
          label: ru ? 'Статус' : 'Status',
          valueLabel: statusFilter.label(ru),
          options: [
            for (final filter in _AdminProfileStatusFilter.values)
              AdminMenuOption(value: filter, label: filter.label(ru)),
          ],
          onSelected: onStatusFilterChanged,
        ),
        AdminMenuFilter<ProfessionalProfileType?>(
          label: ru ? 'Роль' : 'Role',
          valueLabel: roleFilter == null
              ? (ru ? 'Все роли' : 'All roles')
              : _roleLabel(roleFilter!, ru),
          options: [
            AdminMenuOption<ProfessionalProfileType?>(
              value: null,
              label: ru ? 'Все роли' : 'All roles',
            ),
            for (final role in ProfessionalProfileType.values)
              AdminMenuOption(value: role, label: _roleLabel(role, ru)),
          ],
          onSelected: onRoleFilterChanged,
        ),
      ],
    );
  }
}

class _ProfilesTableHeader extends StatelessWidget {
  const _ProfilesTableHeader();

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _HeaderCell(width: 310, text: ru ? 'Анкета' : 'Profile'),
          _HeaderCell(width: 132, text: ru ? 'Статус' : 'Status'),
          _HeaderCell(width: 180, text: ru ? 'Роли' : 'Roles'),
          _HeaderCell(width: 180, text: ru ? 'Владелец' : 'Owner'),
          _HeaderCell(width: 160, text: ru ? 'Город' : 'City'),
          _HeaderCell(width: 110, text: ru ? 'Параметры' : 'Basics'),
          _HeaderCell(width: 96, text: ru ? 'Медиа' : 'Media'),
          const SizedBox(width: 96),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: adminCommandStyle(
          size: 11,
          letterSpacing: 0.8,
          color: kTextMuted,
        ),
      ),
    );
  }
}

class _ProfileTableRow extends StatelessWidget {
  const _ProfileTableRow({
    required this.profile,
    required this.onDeleteProfile,
  });

  final _AdminProfileRow profile;
  final ValueChanged<_AdminProfileRow> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SizedBox(
      height: 82,
      child: Row(
        children: [
          SizedBox(
            width: 310,
            child: Row(
              children: [
                _ProfileCover(profile: profile),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName(ru),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: adminCommandStyle(
                          size: 13,
                          letterSpacing: 0.2,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: adminBodyStyle(size: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 132, child: _StatusBadge(status: profile.status)),
          _BodyCell(width: 180, text: profile.rolesLabel(ru)),
          _BodyCell(width: 180, text: profile.ownerLabel),
          _BodyCell(width: 160, text: profile.locationLabel),
          _BodyCell(width: 110, text: profile.basicsLabel(ru)),
          _BodyCell(width: 96, text: profile.mediaLabel(ru)),
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerRight,
              child: _ProfileActionsMenu(
                profile: profile,
                onDeleteProfile: onDeleteProfile,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionsMenu extends StatelessWidget {
  const _ProfileActionsMenu({
    required this.profile,
    required this.onDeleteProfile,
  });

  final _AdminProfileRow profile;
  final ValueChanged<_AdminProfileRow> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return AdminPopupMenuButton<String>(
      tooltip: ru ? 'Действия' : 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'open':
            context.go('${Routes.modelPrefix}${profile.id}?from=admin');
            return;
          case 'moderation':
            context.go(Routes.moderationAdmin);
            return;
          case 'delete':
            onDeleteProfile(profile);
            return;
        }
      },
      options: [
        AdminMenuOption(
          value: 'open',
          label: ru ? 'Открыть' : 'Open',
          icon: Icons.open_in_new_rounded,
        ),
        if (profile.status == ProfileStatus.pending)
          AdminMenuOption(
            value: 'moderation',
            label: ru ? 'Модерация' : 'Moderation',
            icon: Icons.verified_user_rounded,
          ),
        AdminMenuOption(
          value: 'delete',
          label: ru ? 'Удалить' : 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
      child: const _AdminActionDots(),
    );
  }
}

class _AdminActionDots extends StatelessWidget {
  const _AdminActionDots();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 40,
      child: Center(child: Icon(Icons.more_horiz_rounded, color: kTextDark)),
    );
  }
}

class _ProfileCover extends StatelessWidget {
  const _ProfileCover({required this.profile});

  final _AdminProfileRow profile;

  @override
  Widget build(BuildContext context) {
    final cover = profile.coverPhotoUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 58,
        color: kTextDark,
        child: cover.isEmpty
            ? Center(
                child: Text(
                  profile.initials,
                  style: adminCommandStyle(
                    size: 12,
                    letterSpacing: 0,
                    color: Colors.white,
                  ),
                ),
              )
            : Image.network(cover, fit: BoxFit.cover),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text.trim().isEmpty ? '—' : text.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: adminBodyStyle(size: 12, color: kTextDark),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ProfileStatus status;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final text = _statusLabel(status, ru);
    final bg = switch (status) {
      ProfileStatus.approved => kTextDark,
      ProfileStatus.pending => BrandTheme.redTop,
      ProfileStatus.rejected => const Color(0xFFE7E7E7),
      ProfileStatus.draft => const Color(0xFFF3F3F3),
    };
    final color =
        status == ProfileStatus.approved || status == ProfileStatus.pending
        ? Colors.white
        : kTextDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminCommandStyle(
              size: 10,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminProfileRow {
  const _AdminProfileRow({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.profileType,
    required this.roles,
    required this.status,
    required this.verificationStatus,
    required this.isVerified,
    required this.birthDate,
    required this.age,
    required this.height,
    required this.city,
    required this.country,
    required this.photoCount,
    required this.videoCount,
    required this.coverPhotoUrl,
    required this.hasPendingMedia,
    required this.updatedAt,
    required this.createdAt,
    required this.owner,
  });

  factory _AdminProfileRow.fromMap(
    Map<String, dynamic> map, {
    _AdminProfileOwner? owner,
  }) {
    final profileType = profileTypeFromString(map['profile_type']?.toString());
    return _AdminProfileRow(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString().trim(),
      profileType: profileType,
      roles: profileRolesFromValue(map['profile_roles'], fallback: profileType),
      status: statusFromString(map['status']?.toString()),
      verificationStatus: verificationStatusFromString(
        map['verification_status']?.toString(),
      ),
      isVerified: _boolFromMap(map['is_verified']),
      birthDate: (map['birth_date'] ?? '').toString().trim(),
      age: _intFromMap(map['age']),
      height: _intFromMap(map['height']),
      city: (map['city'] ?? '').toString().trim(),
      country: (map['country'] ?? '').toString().trim(),
      photoCount: _listCount(map['photo_urls']),
      videoCount: _listCount(map['video_urls']),
      coverPhotoUrl: (map['cover_photo_url'] ?? '').toString().trim(),
      hasPendingMedia: _boolFromMap(map['has_pending_media']),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      owner: owner ?? const _AdminProfileOwner.empty(),
    );
  }

  final String id;
  final String userId;
  final String fullName;
  final ProfessionalProfileType profileType;
  final List<ProfessionalProfileType> roles;
  final ProfileStatus status;
  final ProfileVerificationStatus verificationStatus;
  final bool isVerified;
  final String birthDate;
  final int age;
  final int height;
  final String city;
  final String country;
  final int photoCount;
  final int videoCount;
  final String coverPhotoUrl;
  final bool hasPendingMedia;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final _AdminProfileOwner owner;

  String displayName(bool ru) {
    if (fullName.isNotEmpty) return fullName;
    return ru ? 'Без имени' : 'Untitled';
  }

  String get initials {
    final words = displayName(true)
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'PK';
    final value = words.take(2).map((part) => part[0]).join().toUpperCase();
    return value.isEmpty ? 'PK' : value;
  }

  String rolesLabel(bool ru) =>
      roles.map((role) => _roleLabel(role, ru)).join(', ');

  String get ownerLabel {
    final label = owner.displayLabel;
    if (label.isNotEmpty) return label;
    return userId;
  }

  String get locationLabel =>
      [city, country].where((part) => part.isNotEmpty).join(', ');

  String basicsLabel(bool ru) {
    final parts = <String>[];
    final displayAge = _displayAge;
    if (displayAge > 0) parts.add(ru ? '$displayAge лет' : '$displayAge y.o.');
    if (height > 0) parts.add('$height см');
    return parts.join(' • ');
  }

  String mediaLabel(bool ru) {
    final parts = <String>[];
    if (photoCount > 0) {
      parts.add(ru ? 'Фото $photoCount' : 'Photos $photoCount');
    }
    if (videoCount > 0) {
      parts.add(ru ? 'Видео $videoCount' : 'Videos $videoCount');
    }
    if (hasPendingMedia) parts.add(ru ? 'pending' : 'pending');
    return parts.join(' • ');
  }

  int get _displayAge {
    final parsed = DateTime.tryParse(birthDate);
    if (parsed == null) return age;
    final now = DateTime.now();
    var result = now.year - parsed.year;
    final hadBirthday =
        now.month > parsed.month ||
        (now.month == parsed.month && now.day >= parsed.day);
    if (!hadBirthday) result -= 1;
    return result.clamp(0, 120);
  }

  String get searchable =>
      '$id $userId $fullName $city $country ${owner.searchable} ${roles.map((r) => r.storageValue).join(' ')} ${status.name}'
          .toLowerCase();
}

class _AdminProfileOwner {
  const _AdminProfileOwner({
    required this.userId,
    required this.email,
    required this.phone,
    required this.accountTag,
    required this.fullName,
    required this.companyName,
  });

  const _AdminProfileOwner.empty()
    : userId = '',
      email = '',
      phone = '',
      accountTag = '',
      fullName = '',
      companyName = '';

  factory _AdminProfileOwner.fromMap(Map<String, dynamic> map) {
    return _AdminProfileOwner(
      userId: (map['user_id'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      accountTag: (map['account_tag'] ?? '').toString().trim(),
      fullName: (map['full_name'] ?? '').toString().trim(),
      companyName: (map['company_name'] ?? '').toString().trim(),
    );
  }

  final String userId;
  final String email;
  final String phone;
  final String accountTag;
  final String fullName;
  final String companyName;

  String get displayLabel {
    if (accountTag.isNotEmpty) return '@$accountTag';
    if (fullName.isNotEmpty) return fullName;
    if (companyName.isNotEmpty) return companyName;
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;
    return '';
  }

  String get searchable =>
      '$userId $email $phone $accountTag $fullName $companyName';
}

enum _AdminProfileStatusFilter {
  all(null),
  approved(ProfileStatus.approved),
  pending(ProfileStatus.pending),
  draft(ProfileStatus.draft),
  rejected(ProfileStatus.rejected);

  const _AdminProfileStatusFilter(this.status);

  final ProfileStatus? status;

  String label(bool ru) => switch (this) {
    _AdminProfileStatusFilter.all => ru ? 'Все статусы' : 'All statuses',
    _AdminProfileStatusFilter.approved => ru ? 'Утвержденные' : 'Approved',
    _AdminProfileStatusFilter.pending => _statusLabel(
      ProfileStatus.pending,
      ru,
    ),
    _AdminProfileStatusFilter.draft => _statusLabel(ProfileStatus.draft, ru),
    _AdminProfileStatusFilter.rejected => _statusLabel(
      ProfileStatus.rejected,
      ru,
    ),
  };
}

String _statusLabel(ProfileStatus status, bool ru) => switch (status) {
  ProfileStatus.approved => ru ? 'Утверждена' : 'Approved',
  ProfileStatus.pending => ru ? 'На проверке' : 'Pending',
  ProfileStatus.draft => ru ? 'Черновик' : 'Draft',
  ProfileStatus.rejected => ru ? 'Отклонена' : 'Rejected',
};

String _roleLabel(ProfessionalProfileType role, bool ru) => switch (role) {
  ProfessionalProfileType.model => ru ? 'Модель' : 'Model',
  ProfessionalProfileType.actor => ru ? 'Актер' : 'Actor',
  ProfessionalProfileType.photographer => ru ? 'Фотограф' : 'Photographer',
  ProfessionalProfileType.videographer => ru ? 'Видеограф' : 'Videographer',
  ProfessionalProfileType.stylist => ru ? 'Стилист' : 'Stylist',
  ProfessionalProfileType.makeupArtist => ru ? 'Визажист' : 'Makeup',
  ProfessionalProfileType.hairStylist => ru ? 'Hair-стилист' : 'Hair',
};

int _intFromMap(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolFromMap(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

int _listCount(Object? value) {
  if (value is List) return value.length;
  return 0;
}

String _adminProfilesActionError(Object error, String prefix) {
  if (error is PostgrestException) {
    final details = [
      error.message,
      if ((error.details ?? '').toString().trim().isNotEmpty) error.details,
      if ((error.hint ?? '').toString().trim().isNotEmpty) error.hint,
      if ((error.code ?? '').toString().trim().isNotEmpty)
        'code: ${error.code}',
    ].map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('\n');
    if (details.toLowerCase().contains('admin_delete_profile')) {
      return '$prefix.\nПримените SQL: supabase/sql/admin_backoffice_actions.sql';
    }
    return '$prefix: $details';
  }
  return '$prefix: $error';
}
