import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_mapper.dart';
import '../../core/admin_action_log_service.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'admin_style.dart';

final accountMergeRequestsProvider =
    FutureProvider.autoDispose<List<AccountMergeRequest>>((ref) async {
      try {
        final rows = await Supabase.instance.client
            .from('account_merge_requests')
            .select(
              'id,requester_user_id,requested_phone,requester_email,requester_phone,requester_full_name,requester_company_name,requester_note,status,created_at',
            )
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(100);

        return (rows as List)
            .map(
              (row) => AccountMergeRequest.fromMap(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
            .toLowerCase();
        final missingTable =
            msg.contains('account_merge_requests') &&
            (e.code == 'PGRST205' ||
                msg.contains('schema cache') ||
                msg.contains('could not find the table'));
        if (missingTable) return const <AccountMergeRequest>[];
        rethrow;
      }
    });

class AccountMergeRequest {
  const AccountMergeRequest({
    required this.id,
    required this.requesterUserId,
    required this.requestedPhone,
    required this.requesterEmail,
    required this.requesterPhone,
    required this.requesterFullName,
    required this.requesterCompanyName,
    required this.requesterNote,
    required this.createdAt,
  });

  final String id;
  final String requesterUserId;
  final String requestedPhone;
  final String requesterEmail;
  final String requesterPhone;
  final String requesterFullName;
  final String requesterCompanyName;
  final String requesterNote;
  final DateTime? createdAt;

  factory AccountMergeRequest.fromMap(Map<String, dynamic> map) {
    DateTime? createdAt;
    final rawDate = (map['created_at'] ?? '').toString();
    if (rawDate.isNotEmpty) createdAt = DateTime.tryParse(rawDate);

    return AccountMergeRequest(
      id: (map['id'] ?? '').toString(),
      requesterUserId: (map['requester_user_id'] ?? '').toString(),
      requestedPhone: (map['requested_phone'] ?? '').toString(),
      requesterEmail: (map['requester_email'] ?? '').toString(),
      requesterPhone: (map['requester_phone'] ?? '').toString(),
      requesterFullName: (map['requester_full_name'] ?? '').toString(),
      requesterCompanyName: (map['requester_company_name'] ?? '').toString(),
      requesterNote: (map['requester_note'] ?? '').toString(),
      createdAt: createdAt,
    );
  }

  String get title {
    if (requesterFullName.trim().isNotEmpty) return requesterFullName.trim();
    if (requesterCompanyName.trim().isNotEmpty) {
      return requesterCompanyName.trim();
    }
    if (requesterEmail.trim().isNotEmpty) return requesterEmail.trim();
    if (requesterPhone.trim().isNotEmpty) return requesterPhone.trim();
    return 'Аккаунт';
  }
}

class AccountMergeRequestsPage extends ConsumerWidget {
  const AccountMergeRequestsPage({super.key});

  Future<void> _decide({
    required BuildContext context,
    required WidgetRef ref,
    required AccountMergeRequest request,
    required bool approved,
  }) async {
    final t = AppLocalizations.of(context)!;
    try {
      final sb = Supabase.instance.client;
      await sb.rpc(
        'admin_decide_account_merge_request',
        params: {
          'p_request_id': request.id,
          'p_approved': approved,
          'p_admin_note': approved
              ? 'Проверено администратором. Номер записан в профиль аккаунта.'
              : 'Отклонено администратором.',
        },
      );
      await AdminActionLogService(sb).log(
        actionType: approved
            ? 'account_merge_request_approved'
            : 'account_merge_request_rejected',
        title: approved
            ? 'Одобрено объединение аккаунта'
            : 'Отклонено объединение аккаунта',
        description: approved
            ? 'Телефон ${request.requestedPhone} записан в профиль аккаунта.'
            : 'Заявка на объединение аккаунтов отклонена.',
        targetTable: 'account_merge_requests',
        targetId: request.id,
        targetText: request.title,
        status: approved ? 'approved' : 'rejected',
        metadata: {
          'requester_user_id': request.requesterUserId,
          'requested_phone': request.requestedPhone,
          'requester_email': request.requesterEmail,
          'requester_phone': request.requesterPhone,
          'requester_company_name': request.requesterCompanyName,
        },
      );
      ref.invalidate(accountMergeRequestsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Номер ${request.requestedPhone} записан в профиль.'
                : 'Заявка отклонена.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error, t))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final itemsAsync = ref.watch(accountMergeRequestsProvider);

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
                    title: ru ? 'ОБЪЕДИНЕНИЕ АККАУНТОВ' : 'ACCOUNT MERGES',
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
                            text: ru ? 'ЗАЯВОК НЕТ' : 'NO REQUESTS',
                          );
                        }

                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: kGap12),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _AccountMergeCard(
                              request: item,
                              onApprove: () => _decide(
                                context: context,
                                ref: ref,
                                request: item,
                                approved: true,
                              ),
                              onReject: () => _decide(
                                context: context,
                                ref: ref,
                                request: item,
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

class _AccountMergeCard extends StatelessWidget {
  const _AccountMergeCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final AccountMergeRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final created = request.createdAt;
    final contacts = [
      if (request.requesterEmail.isNotEmpty) request.requesterEmail,
      if (request.requesterPhone.isNotEmpty) request.requesterPhone,
      if (request.requesterCompanyName.isNotEmpty) request.requesterCompanyName,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminCommandStyle(size: 17, letterSpacing: 0.7),
          ),
          const SizedBox(height: 6),
          Text(
            ru
                ? 'Объединение аккаунта с номером ${request.requestedPhone}'
                : 'Merge account with ${request.requestedPhone}',
            style: adminCommandStyle(
              size: 13,
              color: BrandTheme.redTop,
              letterSpacing: 0.7,
            ),
          ),
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              contacts.join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: adminBodyStyle(weight: FontWeight.w700),
            ),
          ],
          if (request.requesterNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.requesterNote,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: adminBodyStyle(weight: FontWeight.w700),
            ),
          ],
          if (created != null) ...[
            const SizedBox(height: 8),
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
                  label: ru ? 'ОТКЛОНИТЬ' : 'REJECT',
                  isDark: false,
                  onTap: onReject,
                ),
              ),
              const SizedBox(width: kGap12),
              Expanded(
                child: _ActionButton(
                  label: ru ? 'ЗАПИСАТЬ НОМЕР' : 'SAVE PHONE',
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
