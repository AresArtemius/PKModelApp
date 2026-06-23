import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_mapper.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';

final castingAgentApplicationsProvider =
    FutureProvider.autoDispose<List<CastingAgentApplication>>((ref) async {
      List<dynamic> rows;
      try {
        try {
          rows = await Supabase.instance.client
              .from('casting_agent_applications')
              .select(
                'id,user_id,status,comment,requested_account_type,created_at',
              )
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(100);
        } on PostgrestException catch (e) {
          final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
              .toLowerCase();
          if (!msg.contains('requested_account_type')) rethrow;
          rows = await Supabase.instance.client
              .from('casting_agent_applications')
              .select('id,user_id,status,comment,created_at')
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(100);
        }
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
            .toLowerCase();
        final missingTable =
            msg.contains('casting_agent_applications') &&
            (e.code == 'PGRST205' ||
                msg.contains('schema cache') ||
                msg.contains('could not find the table'));
        if (!missingTable) rethrow;
        return const <CastingAgentApplication>[];
      }

      final items = rows
          .map((row) => CastingAgentApplication.fromMap(row))
          .toList();
      await _hydrateOwnerProfiles(items);
      return items;
    });

Future<void> _hydrateOwnerProfiles(List<CastingAgentApplication> items) async {
  final sb = Supabase.instance.client;
  final userIds = items
      .map((item) => item.userId.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (userIds.isEmpty) return;

  for (final item in items) {
    item.owner = AccountApplicationOwner.empty();
  }

  try {
    final rows = await sb
        .from('user_profiles')
        .select(
          'user_id,email,phone,full_name,company_name,position,city,country',
        )
        .inFilter('user_id', userIds);
    final byUserId = <String, AccountApplicationOwner>{};
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final userId = (row['user_id'] ?? '').toString().trim();
      if (userId.isEmpty) continue;
      byUserId[userId] = AccountApplicationOwner.fromMap(row);
    }
    for (final item in items) {
      item.owner = byUserId[item.userId] ?? AccountApplicationOwner.empty();
    }
  } on PostgrestException {
    for (final item in items) {
      item.owner = AccountApplicationOwner.empty();
    }
  }
}

class AccountApplicationOwner {
  const AccountApplicationOwner({
    required this.email,
    required this.phone,
    required this.fullName,
    required this.companyName,
    required this.position,
    required this.city,
    required this.country,
  });

  final String email;
  final String phone;
  final String fullName;
  final String companyName;
  final String position;
  final String city;
  final String country;

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (companyName.isNotEmpty) return companyName;
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;
    return '';
  }

  factory AccountApplicationOwner.empty() {
    return const AccountApplicationOwner(
      email: '',
      phone: '',
      fullName: '',
      companyName: '',
      position: '',
      city: '',
      country: '',
    );
  }

  factory AccountApplicationOwner.fromMap(Map<String, dynamic>? map) {
    String value(String key) => (map?[key] ?? '').toString().trim();
    return AccountApplicationOwner(
      email: value('email'),
      phone: value('phone'),
      fullName: value('full_name'),
      companyName: value('company_name'),
      position: value('position'),
      city: value('city'),
      country: value('country'),
    );
  }
}

class CastingAgentApplication {
  CastingAgentApplication({
    required this.id,
    required this.userId,
    required this.status,
    required this.comment,
    required this.requestedType,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String status;
  final String comment;
  final RegistrationAccountType requestedType;
  final DateTime? createdAt;
  AccountApplicationOwner owner = AccountApplicationOwner.empty();

  factory CastingAgentApplication.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['created_at']?.toString();
    return CastingAgentApplication(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
      requestedType: registrationAccountTypeFromStorage(
        map['requested_account_type'] ?? map['comment'],
      ),
      createdAt: rawCreatedAt == null ? null : DateTime.tryParse(rawCreatedAt),
    );
  }
}

class CastingAgentApplicationsPage extends ConsumerWidget {
  const CastingAgentApplicationsPage({super.key});

  Future<void> _decide({
    required BuildContext context,
    required WidgetRef ref,
    required CastingAgentApplication application,
    required bool approved,
  }) async {
    final t = AppLocalizations.of(context)!;
    try {
      await Supabase.instance.client.rpc(
        'admin_decide_casting_agent_application',
        params: {
          'p_application_id': application.id,
          'p_approved': approved,
          'p_comment': '',
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = AppErrorMapper.message(error, t);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.contains('updated_at') && message.contains('user_roles')
                ? 'Не удалось обработать заявку. Примените SQL fix_user_roles_updated_at.sql в Supabase.'
                : message,
          ),
        ),
      );
      return;
    }

    ref.invalidate(castingAgentApplicationsProvider);
    ref.invalidate(accountRoleProvider);
    ref.invalidate(isAdminProvider);
    ref.invalidate(canCreateSelectionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(castingAgentApplicationsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                kPagePadH,
                kPagePadTop,
                kPagePadH,
                kPagePadBottom,
              ),
              child: Column(
                children: [
                  BrandAdminHeader(
                    title: t.adminAgentApplicationsUpper,
                    onBack: () => context.go(Routes.admin),
                  ),
                  const SizedBox(height: kGap16),
                  Expanded(
                    child: itemsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => _MessageCard(
                        text:
                            '${t.errorUpper}: ${AppErrorMapper.message(error, t)}',
                        isError: true,
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return _MessageCard(
                            text: t.adminAgentApplicationsEmpty,
                          );
                        }

                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: kGap12),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _ApplicationCard(
                              application: item,
                              approveLabel: t.agentApplicationApproveUpper,
                              rejectLabel: t.agentApplicationRejectUpper,
                              onApprove: () => _decide(
                                context: context,
                                ref: ref,
                                application: item,
                                approved: true,
                              ),
                              onReject: () => _decide(
                                context: context,
                                ref: ref,
                                application: item,
                                approved: false,
                              ),
                            );
                          },
                        );
                      },
                    ),
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

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.approveLabel,
    required this.rejectLabel,
    required this.onApprove,
    required this.onReject,
  });

  final CastingAgentApplication application;
  final String approveLabel;
  final String rejectLabel;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final created = application.createdAt;
    final typeLabel = _statusLabel(context, application.requestedType);
    final owner = application.owner;
    final ownerTitle = owner.displayName.isEmpty
        ? (Localizations.localeOf(context).languageCode == 'ru'
              ? 'Профиль аккаунта не заполнен'
              : 'Account profile is empty')
        : owner.displayName;
    final details = [
      if (owner.companyName.isNotEmpty && owner.companyName != ownerTitle)
        owner.companyName,
      if (owner.position.isNotEmpty) owner.position,
      if (owner.city.isNotEmpty) owner.city,
      if (owner.country.isNotEmpty) owner.country,
      if (owner.email.isNotEmpty) owner.email,
      if (owner.phone.isNotEmpty) owner.phone,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ownerTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminCommandStyle(size: 17, letterSpacing: 0.7),
          ),
          const SizedBox(height: 6),
          Text(
            typeLabel,
            style: adminCommandStyle(size: 14, letterSpacing: 0.2),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              details.join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: adminBodyStyle(weight: FontWeight.w700),
            ),
          ],
          if (created != null) ...[
            const SizedBox(height: 6),
            Text(
              '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year}',
              style: adminBodyStyle(weight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: kGap12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: rejectLabel,
                  isDark: false,
                  onTap: onReject,
                ),
              ),
              const SizedBox(width: kGap12),
              Expanded(
                child: _ActionButton(
                  label: approveLabel,
                  isDark: true,
                  onTap: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, RegistrationAccountType type) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return switch (type) {
      RegistrationAccountType.user =>
        ru ? 'Личный аккаунт' : 'Personal account',
      RegistrationAccountType.castingDirector =>
        ru ? 'Кастинг-директор' : 'Casting director',
      RegistrationAccountType.castingAgent =>
        ru ? 'Кастинг-агент' : 'Casting agent',
      RegistrationAccountType.directorProducer =>
        ru ? 'Режиссер / продюсер' : 'Director / producer',
      RegistrationAccountType.brandClient =>
        ru ? 'Бренд / заказчик' : 'Brand / client',
      RegistrationAccountType.agency => ru ? 'Агентство' : 'Agency',
      RegistrationAccountType.productionAgency =>
        ru ? 'Продакшн / рекламное агентство' : 'Production / ad agency',
      RegistrationAccountType.photoVideo =>
        ru ? 'Фотограф / видеограф' : 'Photographer / videographer',
      RegistrationAccountType.scoutBooker =>
        ru ? 'Скаут / буккер' : 'Scout / booker',
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: onTap,
        child: Container(
          height: kTopBarH,
          alignment: Alignment.center,
          decoration: pillDecoration(isDark: isDark, radius: kSearchRadius),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: adminCommandStyle(
              color: isDark ? Colors.white : kTextDark,
              size: 12,
              letterSpacing: 0.9,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return AdminMessageCard(text: text, isError: isError);
  }
}
