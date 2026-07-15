import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

final adminSupportTicketsProvider = FutureProvider.autoDispose
    .family<List<_AdminSupportTicket>, String>((ref, status) async {
      var query = ref
          .read(supabaseProvider)
          .from('support_tickets')
          .select(
            'id,user_id,category,subject,status,priority,assigned_to,created_at,updated_at',
          );
      if (status != 'all') query = query.eq('status', status);
      final rows = await query.order('updated_at', ascending: false).limit(200);
      return rows.map(_AdminSupportTicket.fromMap).toList(growable: false);
    });

final adminSupportMessagesProvider = FutureProvider.autoDispose
    .family<List<_AdminSupportMessage>, String>((ref, ticketId) async {
      final rows = await ref
          .read(supabaseProvider)
          .from('support_messages')
          .select('id,author_kind,body,is_internal,created_at')
          .eq('ticket_id', ticketId)
          .order('created_at');
      return rows.map(_AdminSupportMessage.fromMap).toList(growable: false);
    });

class AdminSupportPage extends ConsumerStatefulWidget {
  const AdminSupportPage({super.key});

  @override
  ConsumerState<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends ConsumerState<AdminSupportPage> {
  final _replyController = TextEditingController();
  String _filter = 'all';
  String? _selectedId;
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply(_AdminSupportTicket ticket) async {
    final body = _replyController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sb = ref.read(supabaseProvider);
      await sb.from('support_messages').insert({
        'ticket_id': ticket.id,
        'author_id': sb.auth.currentUser?.id,
        'author_kind': 'admin',
        'body': body,
        'source': 'admin',
      });
      _replyController.clear();
      ref.invalidate(adminSupportMessagesProvider(ticket.id));
      ref.invalidate(adminSupportTicketsProvider(_filter));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ответ отправлен пользователю.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить ответ: ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(_AdminSupportTicket ticket, String status) async {
    final values = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'resolved')
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'closed')
        'closed_at': DateTime.now().toUtc().toIso8601String(),
    };
    await ref
        .read(supabaseProvider)
        .from('support_tickets')
        .update(values)
        .eq('id', ticket.id);
    ref.invalidate(adminSupportTicketsProvider(_filter));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final ticketsAsync = ref.watch(adminSupportTicketsProvider(_filter));
    final width = MediaQuery.sizeOf(context).width;
    final split = width >= 900;

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(kPagePadH),
              child: Column(
                children: [
                  BrandAdminHeader(
                    title: ru ? 'ОБРАЩЕНИЯ В ПОДДЕРЖКУ' : 'SUPPORT INBOX',
                    onBack: () => context.go(Routes.admin),
                  ),
                  const SizedBox(height: 14),
                  _FilterBar(
                    value: _filter,
                    ru: ru,
                    onChanged: (value) => setState(() {
                      _filter = value;
                      _selectedId = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ticketsAsync.when(
                      data: (tickets) {
                        final selected = tickets
                            .where((item) => item.id == _selectedId)
                            .firstOrNull;
                        if (!split) {
                          return selected == null
                              ? _TicketList(
                                  tickets: tickets,
                                  selectedId: _selectedId,
                                  onSelect: (ticket) =>
                                      setState(() => _selectedId = ticket.id),
                                )
                              : _TicketDetail(
                                  ticket: selected,
                                  replyController: _replyController,
                                  sending: _sending,
                                  onBack: () =>
                                      setState(() => _selectedId = null),
                                  onReply: () => _sendReply(selected),
                                  onStatus: (status) =>
                                      _changeStatus(selected, status),
                                );
                        }
                        return Row(
                          children: [
                            SizedBox(
                              width: 390,
                              child: _TicketList(
                                tickets: tickets,
                                selectedId: _selectedId,
                                onSelect: (ticket) =>
                                    setState(() => _selectedId = ticket.id),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: selected == null
                                  ? const _EmptyDetail()
                                  : _TicketDetail(
                                      ticket: selected,
                                      replyController: _replyController,
                                      sending: _sending,
                                      onReply: () => _sendReply(selected),
                                      onStatus: (status) =>
                                          _changeStatus(selected, status),
                                    ),
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: Text(
                          'Не удалось загрузить обращения: $error',
                          textAlign: TextAlign.center,
                        ),
                      ),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.ru,
    required this.onChanged,
  });
  final String value;
  final bool ru;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: catalogCardDecoration(),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        items: _filterStatuses
            .map(
              (status) => DropdownMenuItem(
                value: status,
                child: Text(_supportStatus(status, ru)),
              ),
            )
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    ),
  );
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.selectedId,
    required this.onSelect,
  });
  final List<_AdminSupportTicket> tickets;
  final String? selectedId;
  final ValueChanged<_AdminSupportTicket> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const _EmptyDetail(text: 'Новых обращений нет.');
    }
    return ListView.separated(
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        final selected = ticket.id == selectedId;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(ticket),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: catalogCardDecoration().copyWith(
                border: Border.all(
                  color: selected ? BrandTheme.redTop : kBorderColor,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PriorityDot(priority: ticket.priority),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${_categoryLabel(ticket.category)} • ${_supportStatus(ticket.status, true)}',
                    style: const TextStyle(
                      color: kTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Пользователь: ${ticket.userId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTextMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TicketDetail extends ConsumerWidget {
  const _TicketDetail({
    required this.ticket,
    required this.replyController,
    required this.sending,
    required this.onReply,
    required this.onStatus,
    this.onBack,
  });
  final _AdminSupportTicket ticket;
  final TextEditingController replyController;
  final bool sending;
  final VoidCallback onReply;
  final ValueChanged<String> onStatus;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(adminSupportMessagesProvider(ticket.id));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${_categoryLabel(ticket.category)} • ${ticket.userId}',
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: ticket.status,
                items: _editableStatuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_supportStatus(status, true)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onStatus(value);
                },
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: messages.when(
              data: (items) => ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) =>
                    _MessageBubble(message: items[index]),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: replyController,
            minLines: 2,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: 'Ответ пользователю…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: sending ? null : onReply,
            icon: const Icon(Icons.send_rounded),
            label: Text(sending ? 'ОТПРАВКА…' : 'ОТПРАВИТЬ ОТВЕТ'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _AdminSupportMessage message;

  @override
  Widget build(BuildContext context) {
    final admin = message.authorKind == 'admin';
    return Align(
      alignment: admin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: admin ? const Color(0xFFEDEDED) : Colors.white,
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              admin ? 'Администратор' : 'Пользователь',
              style: TextStyle(
                color: admin ? BrandTheme.redTop : kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(message.body),
          ],
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({this.text = 'Выберите обращение слева.'});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: catalogCardDecoration(),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w600),
    ),
  );
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (priority) {
        'urgent' => BrandTheme.redTop,
        'high' => Colors.orange,
        _ => Colors.grey,
      },
    ),
  );
}

class _AdminSupportTicket {
  const _AdminSupportTicket({
    required this.id,
    required this.userId,
    required this.category,
    required this.subject,
    required this.status,
    required this.priority,
  });

  factory _AdminSupportTicket.fromMap(Map<String, dynamic> map) =>
      _AdminSupportTicket(
        id: (map['id'] ?? '').toString(),
        userId: (map['user_id'] ?? '').toString(),
        category: (map['category'] ?? 'other').toString(),
        subject: (map['subject'] ?? '').toString(),
        status: (map['status'] ?? 'new').toString(),
        priority: (map['priority'] ?? 'normal').toString(),
      );

  final String id;
  final String userId;
  final String category;
  final String subject;
  final String status;
  final String priority;
}

class _AdminSupportMessage {
  const _AdminSupportMessage({required this.authorKind, required this.body});

  factory _AdminSupportMessage.fromMap(Map<String, dynamic> map) =>
      _AdminSupportMessage(
        authorKind: (map['author_kind'] ?? 'user').toString(),
        body: (map['body'] ?? '').toString(),
      );

  final String authorKind;
  final String body;
}

const _filterStatuses = [
  'all',
  'queued_for_admin',
  'in_progress',
  'waiting_for_user',
  'resolved',
  'closed',
];
const _editableStatuses = [
  'queued_for_admin',
  'in_progress',
  'waiting_for_user',
  'resolved',
  'closed',
];

String _supportStatus(String status, bool ru) {
  if (status == 'all') return ru ? 'Все обращения' : 'All requests';
  if (!ru) return status.replaceAll('_', ' ');
  return switch (status) {
    'queued_for_admin' => 'Ожидает администратора',
    'in_progress' => 'В работе',
    'waiting_for_user' => 'Ждёт пользователя',
    'resolved' => 'Решено',
    'closed' => 'Закрыто',
    _ => 'Новое',
  };
}

String _categoryLabel(String category) => switch (category) {
  'account' => 'Аккаунт',
  'profile' => 'Анкета',
  'moderation' => 'Модерация',
  'billing' => 'Оплата',
  'casting' => 'Кастинги',
  'security' => 'Безопасность',
  _ => 'Другое',
};
