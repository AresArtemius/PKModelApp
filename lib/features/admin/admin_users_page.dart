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

final _adminUsersProvider = FutureProvider.autoDispose<List<_AdminUserRow>>((
  ref,
) async {
  final sb = ref.watch(supabaseProvider);
  try {
    final rows = await sb
        .from('user_profiles')
        .select(
          'user_id,email,phone,account_tag,full_name,company_name,position,city,country,avatar_url,updated_at,last_seen_at',
        )
        .order('updated_at', ascending: false)
        .limit(300);
    final rolesByUserId = await _loadRolesByUserId(sb);
    return (rows as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row);
          return _AdminUserRow.fromMap(
            map,
            role: rolesByUserId[(map['user_id'] ?? '').toString()],
          );
        })
        .toList(growable: false);
  } on PostgrestException catch (e) {
    if (SupabaseCompat.isMissingColumn(e, 'account_tag')) {
      final rows = await sb
          .from('user_profiles')
          .select(
            'user_id,email,phone,full_name,company_name,position,city,country,avatar_url,updated_at,last_seen_at',
          )
          .order('updated_at', ascending: false)
          .limit(300);
      final rolesByUserId = await _loadRolesByUserId(sb);
      return (rows as List)
          .map((row) {
            final map = Map<String, dynamic>.from(row);
            return _AdminUserRow.fromMap(
              map,
              role: rolesByUserId[(map['user_id'] ?? '').toString()],
            );
          })
          .toList(growable: false);
    }
    if (SupabaseCompat.isMissingRelation(e, const ['user_profiles'])) {
      return const <_AdminUserRow>[];
    }
    rethrow;
  }
});

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

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Да'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setUserRole(_AdminUserRow user, String role) async {
    final confirmed = await _confirm(
      'Изменить роль',
      'Назначить ${user.displayName} роль $role?',
    );
    if (!confirmed) return;
    try {
      await ref.read(supabaseProvider).from('user_roles').upsert({
        'user_id': user.id,
        'role': role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      await ref.read(supabaseProvider).from('user_profiles').upsert({
        'user_id': user.id,
        'account_type': role == 'casting_agent' ? 'casting_agent' : role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      ref.invalidate(_adminUsersProvider);
      _snack('Роль обновлена');
    } catch (e) {
      _snack('Не удалось обновить роль: $e');
    }
  }

  Future<void> _deleteUserProfile(_AdminUserRow user) async {
    final confirmed = await _confirm(
      'Удалить профиль аккаунта',
      'Удалить профиль ${user.displayName}? Auth-пользователь не удаляется.',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(supabaseProvider)
          .from('user_profiles')
          .delete()
          .eq('user_id', user.id);
      ref.invalidate(_adminUsersProvider);
      _snack('Профиль аккаунта удален');
    } catch (e) {
      _snack('Не удалось удалить профиль: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isAdminAsync = ref.watch(isAdminProvider);
    final usersAsync = ref.watch(_adminUsersProvider);

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
                      data: (users) => _UsersTablePanel(
                        users: users,
                        searchController: _searchC,
                        roleFilter: _roleFilter,
                        onRoleFilterChanged: (value) =>
                            setState(() => _roleFilter = value),
                        onSearchChanged: () => setState(() {}),
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
    required this.searchController,
    required this.roleFilter,
    required this.onRoleFilterChanged,
    required this.onSearchChanged,
    required this.onSetRole,
    required this.onDeleteUserProfile,
  });

  final List<_AdminUserRow> users;
  final TextEditingController searchController;
  final _AdminUserRoleFilter roleFilter;
  final ValueChanged<_AdminUserRoleFilter> onRoleFilterChanged;
  final VoidCallback onSearchChanged;
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
    final adminCount = users
        .where((user) => user.primaryRole == 'admin')
        .length;
    final agentCount = users
        .where((user) => user.primaryRole == 'casting_agent')
        .length;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kUsersDesktopBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UsersSummaryBar(
          total: users.length,
          admins: adminCount,
          agents: agentCount,
          filtered: filtered.length,
        ),
        const SizedBox(height: 12),
        _UsersToolbar(
          controller: searchController,
          roleFilter: roleFilter,
          onRoleFilterChanged: onRoleFilterChanged,
          onSearchChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? _UsersEmptyState(
                  text: ru ? 'Пользователи не найдены' : 'No users found',
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
                          padding: const EdgeInsets.all(10),
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: kBorderColor),
                          itemBuilder: (context, index) {
                            if (index == 0) return const _UsersTableHeader();
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
    required this.onSetRole,
    required this.onDeleteUserProfile,
  });

  final List<_AdminUserRow> users;
  final void Function(_AdminUserRow user, String role) onSetRole;
  final ValueChanged<_AdminUserRow> onDeleteUserProfile;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _UserMobileCard(
        user: users[index],
        onSetRole: onSetRole,
        onDeleteUserProfile: onDeleteUserProfile,
      ),
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
    return DecoratedBox(
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(color: kBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UserAvatar(user: user),
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
                          user.displayName,
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
                      _RoleBadge(role: user.primaryRole),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user.handleOrId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminBodyStyle(size: 12),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: adminBodyStyle(size: 12, color: kTextDark),
                    ),
                  ],
                ],
              ),
            ),
            _UserActionsMenu(
              user: user,
              onSetRole: onSetRole,
              onDeleteUserProfile: onDeleteUserProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersSummaryBar extends StatelessWidget {
  const _UsersSummaryBar({
    required this.total,
    required this.admins,
    required this.agents,
    required this.filtered,
  });

  final int total;
  final int admins;
  final int agents;
  final int filtered;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Align(
      alignment: Alignment.centerLeft,
      child: AdminCompactSummary(
        title: ru ? 'Сводка' : 'Summary',
        items: [
          (ru ? 'Всего' : 'Total', total),
          (ru ? 'В выборке' : 'Shown', filtered),
          (ru ? 'Админы' : 'Admins', admins),
          (ru ? 'Заказчики' : 'Clients', agents),
        ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final search = TextField(
          controller: controller,
          onChanged: (_) => onSearchChanged(),
          style: adminBodyStyle(color: kTextDark),
          decoration: InputDecoration(
            hintText: ru ? 'Поиск по имени, email, телефону, tag' : 'Search',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      onSearchChanged();
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: ru ? 'Очистить' : 'Clear',
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kTextDark, width: 1.2),
            ),
          ),
        );
        final filters = AdminMenuFilter<_AdminUserRoleFilter>(
          label: ru ? 'Роль' : 'Role',
          valueLabel: roleFilter.label(ru),
          options: [
            for (final filter in _AdminUserRoleFilter.values)
              AdminMenuOption(value: filter, label: filter.label(ru)),
          ],
          onSelected: onRoleFilterChanged,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 10), filters],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            Flexible(child: filters),
          ],
        );
      },
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
    return PopupMenuButton<String>(
      tooltip: ru ? 'Действия' : 'Actions',
      icon: const Icon(Icons.more_horiz_rounded, color: kTextDark),
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
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'chat',
          child: Text(ru ? 'Открыть чаты' : 'Chats'),
        ),
        PopupMenuItem(
          value: 'admin',
          child: Text(ru ? 'Выдать админку' : 'Make admin'),
        ),
        PopupMenuItem(
          value: 'user',
          child: Text(ru ? 'Снять админку / сделать user' : 'Make user'),
        ),
        PopupMenuItem(
          value: 'client',
          child: Text(ru ? 'Дать статус заказчика' : 'Make client'),
        ),
        PopupMenuItem(
          value: 'delete_profile',
          child: Text(
            ru ? 'Удалить профиль аккаунта' : 'Delete account profile',
          ),
        ),
      ],
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
