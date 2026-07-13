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
import 'admin_style.dart';

const _kUsersPageBg = BrandTheme.greyMid;
const _kUsersPad = 16.0;
const _kUsersDesktopBreakpoint = 920.0;
const _kUsersListCacheExtent = 900.0;
const _kUsersPageSize = 80;

class _AdminUsersPageData {
  const _AdminUsersPageData({required this.rows, required this.hasMore});

  final List<_AdminUserRow> rows;
  final bool hasMore;
}

class _AdminUsersQuery {
  const _AdminUsersQuery({
    required this.limit,
    required this.search,
    required this.role,
  });

  final int limit;
  final String search;
  final String role;

  @override
  bool operator ==(Object other) {
    return other is _AdminUsersQuery &&
        limit == other.limit &&
        search == other.search &&
        role == other.role;
  }

  @override
  int get hashCode => Object.hash(limit, search, role);
}

class _AdminUserRoleScope {
  const _AdminUserRoleScope({this.includeIds, this.excludeIds});

  final Set<String>? includeIds;
  final Set<String>? excludeIds;
}

final _adminUsersProvider = FutureProvider.autoDispose
    .family<_AdminUsersPageData, _AdminUsersQuery>((ref, params) async {
      final sb = ref.watch(supabaseProvider);
      final roleScope = await _loadUserRoleScope(sb, params.role);
      if (roleScope.includeIds != null && roleScope.includeIds!.isEmpty) {
        return const _AdminUsersPageData(
          rows: <_AdminUserRow>[],
          hasMore: false,
        );
      }
      try {
        var request = sb
            .from('user_profiles')
            .select(
              'user_id,email,phone,account_tag,full_name,company_name,position,city,country,avatar_url,updated_at,last_seen_at',
            );
        request = _applyUsersSearch(request, params.search, true);
        if (roleScope.includeIds != null) {
          request = request.inFilter(
            'user_id',
            roleScope.includeIds!.toList(growable: false),
          );
        }
        request = _applyUserRoleExclusion(request, roleScope.excludeIds);
        final rows = await request
            .order('updated_at', ascending: false)
            .range(0, params.limit);
        final rolesByUserId = await _loadRolesByUserId(sb);
        final list = rows as List;
        return _AdminUsersPageData(
          hasMore: list.length > params.limit,
          rows: list
              .take(params.limit)
              .map((row) {
                final map = Map<String, dynamic>.from(row);
                return _AdminUserRow.fromMap(
                  map,
                  role: rolesByUserId[(map['user_id'] ?? '').toString()],
                );
              })
              .toList(growable: false),
        );
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingColumn(e, 'account_tag')) {
          var request = sb
              .from('user_profiles')
              .select(
                'user_id,email,phone,full_name,company_name,position,city,country,avatar_url,updated_at,last_seen_at',
              );
          request = _applyUsersSearch(request, params.search, false);
          if (roleScope.includeIds != null) {
            request = request.inFilter(
              'user_id',
              roleScope.includeIds!.toList(growable: false),
            );
          }
          request = _applyUserRoleExclusion(request, roleScope.excludeIds);
          final rows = await request
              .order('updated_at', ascending: false)
              .range(0, params.limit);
          final rolesByUserId = await _loadRolesByUserId(sb);
          final list = rows as List;
          return _AdminUsersPageData(
            hasMore: list.length > params.limit,
            rows: list
                .take(params.limit)
                .map((row) {
                  final map = Map<String, dynamic>.from(row);
                  return _AdminUserRow.fromMap(
                    map,
                    role: rolesByUserId[(map['user_id'] ?? '').toString()],
                  );
                })
                .toList(growable: false),
          );
        }
        if (SupabaseCompat.isMissingRelation(e, const ['user_profiles'])) {
          return const _AdminUsersPageData(
            rows: <_AdminUserRow>[],
            hasMore: false,
          );
        }
        rethrow;
      }
    });

dynamic _applyUsersSearch(dynamic request, String search, bool includeTag) {
  final clean = _adminSearchTerm(search);
  if (clean.isEmpty) return request;
  final fields = [
    'email',
    'phone',
    if (includeTag) 'account_tag',
    'full_name',
    'company_name',
    'position',
    'city',
    'country',
  ];
  return request.or(fields.map((field) => '$field.ilike.%$clean%').join(','));
}

String _adminSearchTerm(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[,()]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('%', r'\%')
      .replaceAll('*', r'\*');
}

dynamic _applyUserRoleExclusion(dynamic request, Set<String>? excludeIds) {
  if (excludeIds == null || excludeIds.isEmpty) return request;
  return request.not('user_id', 'in', '(${excludeIds.join(',')})');
}

Future<_AdminUserRoleScope> _loadUserRoleScope(
  SupabaseClient sb,
  String role,
) async {
  final cleanRole = role.trim();
  if (cleanRole.isEmpty) return const _AdminUserRoleScope();
  try {
    if (cleanRole == 'user') {
      final rows = await sb.from('user_roles').select('user_id').inFilter(
        'role',
        const ['admin', 'casting_agent'],
      );
      final excluded = {
        for (final row in rows as List)
          ((row as Map)['user_id'] ?? '').toString().trim(),
      }..remove('');
      return _AdminUserRoleScope(excludeIds: excluded);
    }

    final rows = await sb
        .from('user_roles')
        .select('user_id')
        .eq('role', cleanRole);
    final included = {
      for (final row in rows as List)
        ((row as Map)['user_id'] ?? '').toString().trim(),
    }..remove('');
    return _AdminUserRoleScope(includeIds: included);
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['user_roles'])) {
      return cleanRole == 'user'
          ? const _AdminUserRoleScope()
          : const _AdminUserRoleScope(includeIds: <String>{});
    }
    rethrow;
  }
}

Future<Map<String, String>> _loadRolesByUserId(SupabaseClient sb) async {
  try {
    final rows = await sb.from('user_roles').select('user_id,role');
    final roles = <String, String>{};
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final userId = (map['user_id'] ?? '').toString().trim();
      final role = (map['role'] ?? '').toString().trim();
      if (userId.isEmpty || role.isEmpty) continue;
      final previous = roles[userId];
      if (previous == 'admin') continue;
      if (role == 'admin' || previous == null) {
        roles[userId] = role;
      }
    }
    return roles;
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingRelation(e, const ['user_roles'])) {
      return const <String, String>{};
    }
    rethrow;
  }
}

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final TextEditingController _searchC = TextEditingController();
  _AdminUserRoleFilter _roleFilter = _AdminUserRoleFilter.all;
  int _usersLimit = _kUsersPageSize;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<bool> _confirm(
    String title,
    String message, {
    bool destructive = false,
  }) async {
    return showAdminConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: 'Да',
      destructive: destructive,
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setUserRole(_AdminUserRow user, String role) async {
    final accountType = role == 'casting_agent' ? 'casting_agent' : role;
    final confirmed = await _confirm(
      'Изменить роль',
      'Назначить ${user.displayName} роль ${_roleActionLabel(role)}?',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(supabaseProvider)
          .rpc(
            'admin_set_user_account_access',
            params: {'p_user_id': user.id, 'p_account_type': accountType},
          );
      ref.invalidate(_adminUsersProvider);
      _snack('Роль обновлена');
    } catch (e) {
      _snack(_adminUsersActionError(e, 'Не удалось обновить роль'));
    }
  }

  Future<void> _deleteUserProfile(_AdminUserRow user) async {
    final confirmed = await _confirm(
      'Удалить профиль аккаунта',
      'Удалить профиль ${user.displayName}? Auth-пользователь не удаляется.',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(supabaseProvider)
          .rpc('admin_delete_user_profile', params: {'p_user_id': user.id});
      ref.invalidate(_adminUsersProvider);
      _snack('Профиль аккаунта удален');
    } catch (e) {
      _snack(_adminUsersActionError(e, 'Не удалось удалить профиль'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isAdminAsync = ref.watch(isAdminProvider);
    final usersQuery = _AdminUsersQuery(
      limit: _usersLimit,
      search: _searchC.text,
      role: _roleFilter.role,
    );
    final usersAsync = ref.watch(_adminUsersProvider(usersQuery));

    return Scaffold(
      backgroundColor: _kUsersPageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_kUsersPad),
          child: Column(
            children: [
              BrandAdminHeader(
                title: ru ? 'ПОЛЬЗОВАТЕЛИ' : 'USERS',
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
                    return usersAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => AdminMessageCard(
                        text: _usersErrorText(error, ru),
                        isError: true,
                        maxWidth: 620,
                      ),
                      data: (data) => _UsersTablePanel(
                        users: data.rows,
                        hasMore: data.hasMore,
                        searchController: _searchC,
                        roleFilter: _roleFilter,
                        onRoleFilterChanged: (value) => setState(() {
                          _roleFilter = value;
                          _usersLimit = _kUsersPageSize;
                        }),
                        onSearchChanged: () => setState(() {
                          _usersLimit = _kUsersPageSize;
                        }),
                        onLoadMore: () =>
                            setState(() => _usersLimit += _kUsersPageSize),
                        onSetRole: _setUserRole,
                        onDeleteUserProfile: _deleteUserProfile,
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

class _UsersTablePanel extends StatelessWidget {
  const _UsersTablePanel({
    required this.users,
    required this.hasMore,
    required this.searchController,
    required this.roleFilter,
    required this.onRoleFilterChanged,
    required this.onSearchChanged,
    required this.onLoadMore,
    required this.onSetRole,
    required this.onDeleteUserProfile,
  });

  final List<_AdminUserRow> users;
  final bool hasMore;
  final TextEditingController searchController;
  final _AdminUserRoleFilter roleFilter;
  final ValueChanged<_AdminUserRoleFilter> onRoleFilterChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onLoadMore;
  final void Function(_AdminUserRow user, String role) onSetRole;
  final ValueChanged<_AdminUserRow> onDeleteUserProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final query = searchController.text.trim().toLowerCase();
    final filtered = users
        .where((user) {
          final roleOk =
              roleFilter == _AdminUserRoleFilter.all ||
              user.primaryRole == roleFilter.role;
          final searchOk = query.isEmpty || user.searchable.contains(query);
          return roleOk && searchOk;
        })
        .toList(growable: false);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kUsersDesktopBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UsersToolbar(
          controller: searchController,
          roleFilter: roleFilter,
          onRoleFilterChanged: onRoleFilterChanged,
          onSearchChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? Column(
                  children: [
                    Expanded(
                      child: _UsersEmptyState(
                        text: ru ? 'Пользователи не найдены' : 'No users found',
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
                          minWidth: isDesktop ? 980 : 860,
                        ),
                        child: ListView.separated(
                          // ignore: deprecated_member_use
                          cacheExtent: _kUsersListCacheExtent,
                          padding: const EdgeInsets.all(10),
                          itemCount: filtered.length + 1 + (hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: kBorderColor),
                          itemBuilder: (context, index) {
                            if (index == 0) return const _UsersTableHeader();
                            if (hasMore && index == filtered.length + 1) {
                              return AdminLoadMoreFooter(
                                label: ru ? 'Загрузить еще' : 'Load more',
                                onPressed: onLoadMore,
                              );
                            }
                            return _UserTableRow(
                              user: filtered[index - 1],
                              onSetRole: onSetRole,
                              onDeleteUserProfile: onDeleteUserProfile,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                )
              : _UsersMobileList(
                  users: filtered,
                  hasMore: hasMore,
                  onLoadMore: onLoadMore,
                  onSetRole: onSetRole,
                  onDeleteUserProfile: onDeleteUserProfile,
                ),
        ),
      ],
    );
  }
}

class _UsersEmptyState extends StatelessWidget {
  const _UsersEmptyState({required this.text});

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

class _UsersMobileList extends StatelessWidget {
  const _UsersMobileList({
    required this.users,
    required this.hasMore,
    required this.onLoadMore,
    required this.onSetRole,
    required this.onDeleteUserProfile,
  });

  final List<_AdminUserRow> users;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(_AdminUserRow user, String role) onSetRole;
  final ValueChanged<_AdminUserRow> onDeleteUserProfile;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // ignore: deprecated_member_use
      cacheExtent: _kUsersListCacheExtent,
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: users.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          final ru = Localizations.localeOf(context).languageCode == 'ru';
          return AdminLoadMoreFooter(
            label: ru ? 'Загрузить еще' : 'Load more',
            onPressed: onLoadMore,
          );
        }
        return _UserMobileCard(
          user: users[index],
          onSetRole: onSetRole,
          onDeleteUserProfile: onDeleteUserProfile,
        );
      },
    );
  }
}

class _UserMobileCard extends StatelessWidget {
  const _UserMobileCard({
    required this.user,
    required this.onSetRole,
    required this.onDeleteUserProfile,
  });

  final _AdminUserRow user;
  final void Function(_AdminUserRow user, String role) onSetRole;
  final ValueChanged<_AdminUserRow> onDeleteUserProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final meta = [
      user.contactLabel.replaceAll('\n', ' • '),
      user.locationLabel,
      user.activityLabel(ru),
    ].where((part) => part.trim().isNotEmpty).join(' • ');
    return AdminMobileCard(
      leading: _UserAvatar(user: user),
      title: user.displayName,
      subtitle: user.handleOrId,
      meta: meta,
      badge: _RoleBadge(role: user.primaryRole),
      action: _UserActionsMenu(
        user: user,
        onSetRole: onSetRole,
        onDeleteUserProfile: onDeleteUserProfile,
      ),
    );
  }
}

class _UsersToolbar extends StatelessWidget {
  const _UsersToolbar({
    required this.controller,
    required this.roleFilter,
    required this.onRoleFilterChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final _AdminUserRoleFilter roleFilter;
  final ValueChanged<_AdminUserRoleFilter> onRoleFilterChanged;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return AdminMobileToolbar(
      controller: controller,
      hintText: ru ? 'Поиск по имени, email, телефону, tag' : 'Search',
      onSearchChanged: onSearchChanged,
      compactBreakpoint: 760,
      filters: [
        AdminMenuFilter<_AdminUserRoleFilter>(
          label: ru ? 'Роль' : 'Role',
          valueLabel: roleFilter.label(ru),
          options: [
            for (final filter in _AdminUserRoleFilter.values)
              AdminMenuOption(value: filter, label: filter.label(ru)),
          ],
          onSelected: onRoleFilterChanged,
        ),
      ],
    );
  }
}

class _UsersTableHeader extends StatelessWidget {
  const _UsersTableHeader();

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _HeaderCell(width: 300, text: ru ? 'Аккаунт' : 'Account'),
          _HeaderCell(width: 150, text: ru ? 'Роль' : 'Role'),
          _HeaderCell(width: 230, text: ru ? 'Контакт' : 'Contact'),
          _HeaderCell(width: 170, text: ru ? 'Город' : 'City'),
          _HeaderCell(width: 150, text: ru ? 'Активность' : 'Activity'),
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

class _UserTableRow extends StatelessWidget {
  const _UserTableRow({
    required this.user,
    required this.onSetRole,
    required this.onDeleteUserProfile,
  });

  final _AdminUserRow user;
  final void Function(_AdminUserRow user, String role) onSetRole;
  final ValueChanged<_AdminUserRow> onDeleteUserProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: Row(
              children: [
                _UserAvatar(user: user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
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
                        user.handleOrId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: adminBodyStyle(size: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 150, child: _RoleBadge(role: user.primaryRole)),
          _BodyCell(width: 230, text: user.contactLabel),
          _BodyCell(width: 170, text: user.locationLabel),
          _BodyCell(width: 150, text: user.activityLabel(ru)),
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerRight,
              child: _UserActionsMenu(
                user: user,
                onSetRole: onSetRole,
                onDeleteUserProfile: onDeleteUserProfile,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserActionsMenu extends StatelessWidget {
  const _UserActionsMenu({
    required this.user,
    required this.onSetRole,
    required this.onDeleteUserProfile,
  });

  final _AdminUserRow user;
  final void Function(_AdminUserRow user, String role) onSetRole;
  final ValueChanged<_AdminUserRow> onDeleteUserProfile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return AdminPopupMenuButton<String>(
      tooltip: ru ? 'Действия' : 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'chat':
            context.go('${Routes.chats}?user=${user.id}');
            return;
          case 'admin':
            onSetRole(user, 'admin');
            return;
          case 'client':
            onSetRole(user, 'casting_agent');
            return;
          case 'user':
            onSetRole(user, 'user');
            return;
          case 'delete_profile':
            onDeleteUserProfile(user);
            return;
        }
      },
      options: [
        AdminMenuOption(
          value: 'chat',
          label: ru ? 'Открыть чаты' : 'Chats',
          icon: Icons.chat_bubble_outline_rounded,
        ),
        AdminMenuOption(
          value: 'admin',
          label: ru ? 'Выдать админку' : 'Make admin',
          icon: Icons.admin_panel_settings_rounded,
        ),
        AdminMenuOption(
          value: 'user',
          label: ru ? 'Снять админку' : 'Make user',
          icon: Icons.person_outline_rounded,
        ),
        AdminMenuOption(
          value: 'client',
          label: ru ? 'Дать статус заказчика' : 'Make client',
          icon: Icons.business_center_outlined,
        ),
        AdminMenuOption(
          value: 'delete_profile',
          label: ru ? 'Удалить профиль аккаунта' : 'Delete account profile',
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

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final _AdminUserRow user;

  @override
  Widget build(BuildContext context) {
    final avatar = user.avatarUrl.trim();
    final initials = user.initials;
    return ClipOval(
      child: Container(
        width: 42,
        height: 42,
        color: kTextDark,
        child: avatar.isEmpty
            ? Center(
                child: Text(
                  initials,
                  style: adminCommandStyle(
                    size: 13,
                    letterSpacing: 0,
                    color: Colors.white,
                  ),
                ),
              )
            : Image.network(avatar, fit: BoxFit.cover),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final admin = role == 'admin';
    final agent = role == 'casting_agent';
    final text = admin
        ? (ru ? 'Админ' : 'Admin')
        : agent
        ? (ru ? 'Заказчик' : 'Client')
        : (ru ? 'Пользователь' : 'User');
    final bg = admin
        ? BrandTheme.redTop
        : agent
        ? kTextDark
        : const Color(0xFFF3F3F3);
    final color = admin || agent ? Colors.white : kTextDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: admin || agent ? bg : kBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminCommandStyle(
              size: 10,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminUserRow {
  const _AdminUserRow({
    required this.id,
    required this.email,
    required this.phone,
    required this.accountTag,
    required this.fullName,
    required this.companyName,
    required this.position,
    required this.city,
    required this.country,
    required this.avatarUrl,
    required this.primaryRole,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  factory _AdminUserRow.fromMap(Map<String, dynamic> map, {String? role}) {
    return _AdminUserRow(
      id: (map['user_id'] ?? '').toString(),
      email: (map['email'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      accountTag: (map['account_tag'] ?? '').toString().trim(),
      fullName: (map['full_name'] ?? '').toString().trim(),
      companyName: (map['company_name'] ?? '').toString().trim(),
      position: (map['position'] ?? '').toString().trim(),
      city: (map['city'] ?? '').toString().trim(),
      country: (map['country'] ?? '').toString().trim(),
      avatarUrl: (map['avatar_url'] ?? '').toString().trim(),
      primaryRole: role?.trim().isNotEmpty == true ? role!.trim() : 'user',
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
      lastSeenAt: DateTime.tryParse((map['last_seen_at'] ?? '').toString()),
    );
  }

  final String id;
  final String email;
  final String phone;
  final String accountTag;
  final String fullName;
  final String companyName;
  final String position;
  final String city;
  final String country;
  final String avatarUrl;
  final String primaryRole;
  final DateTime? updatedAt;
  final DateTime? lastSeenAt;

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (companyName.isNotEmpty) return companyName;
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;
    return id;
  }

  String get handleOrId {
    if (accountTag.isNotEmpty) return '@$accountTag';
    if (position.isNotEmpty) return position;
    return id;
  }

  String get contactLabel =>
      [email, phone].where((part) => part.isNotEmpty).join('\n');

  String get locationLabel =>
      [city, country].where((part) => part.isNotEmpty).join(', ');

  String activityLabel(bool ru) {
    final last = lastSeenAt ?? updatedAt;
    if (last == null) return ru ? 'Нет данных' : 'No data';
    final local = last.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    return ru ? 'Был: $date' : 'Seen: $date';
  }

  String get initials {
    final words = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'PK';
    final value = words.take(2).map((part) => part[0]).join().toUpperCase();
    return value.isEmpty ? 'PK' : value;
  }

  String get searchable =>
      '$id $email $phone $accountTag $fullName $companyName $position $city $country $primaryRole'
          .toLowerCase();
}

enum _AdminUserRoleFilter {
  all(''),
  user('user'),
  castingAgent('casting_agent'),
  admin('admin');

  const _AdminUserRoleFilter(this.role);

  final String role;

  String label(bool ru) => switch (this) {
    _AdminUserRoleFilter.all => ru ? 'Все' : 'All',
    _AdminUserRoleFilter.user => ru ? 'Пользователи' : 'Users',
    _AdminUserRoleFilter.castingAgent => ru ? 'Заказчики' : 'Clients',
    _AdminUserRoleFilter.admin => ru ? 'Админы' : 'Admins',
  };
}

String _usersErrorText(Object error, bool ru) {
  return ru
      ? 'Не удалось загрузить пользователей: $error'
      : 'Could not load users: $error';
}

String _roleActionLabel(String role) => switch (role) {
  'admin' => 'админ',
  'casting_agent' => 'заказчик',
  _ => 'пользователь',
};

String _adminUsersActionError(Object error, String prefix) {
  if (error is PostgrestException) {
    final details = [
      error.message,
      if ((error.details ?? '').toString().trim().isNotEmpty) error.details,
      if ((error.hint ?? '').toString().trim().isNotEmpty) error.hint,
      if ((error.code ?? '').toString().trim().isNotEmpty)
        'code: ${error.code}',
    ].map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('\n');
    if (details.toLowerCase().contains('admin_set_user_account_access') ||
        details.toLowerCase().contains('admin_delete_user_profile')) {
      return '$prefix.\nПримените SQL: supabase/sql/admin_backoffice_actions.sql';
    }
    return '$prefix: $details';
  }
  return '$prefix: $error';
}
