import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../support/support_unread_provider.dart';

final adminSupportAccessProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final result = await ref
      .read(supabaseProvider)
      .rpc('current_user_is_support_staff');
  return result == true;
});

final adminSupportTicketsProvider = FutureProvider.autoDispose
    .family<List<_AdminSupportTicket>, String>((ref, status) async {
      var query = ref
          .read(supabaseProvider)
          .from('support_tickets')
          .select(
            'id,user_id,channel,category,subject,status,priority,assigned_to,created_at,updated_at',
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
          .order('created_at', ascending: true);
      return rows.map(_AdminSupportMessage.fromMap).toList(growable: false);
    });

final adminSupportFaqProvider =
    FutureProvider.autoDispose<List<_SupportFaqItem>>((ref) async {
      final rows = await ref
          .read(supabaseProvider)
          .from('support_faq')
          .select('id,slug,question,answer,keywords,is_active,sort_order')
          .order('sort_order');
      return rows.map(_SupportFaqItem.fromMap).toList(growable: false);
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

  Future<void> _claimTicket(_AdminSupportTicket ticket) async {
    try {
      final claimed = await ref
          .read(supabaseProvider)
          .rpc('claim_support_ticket', params: {'p_ticket_id': ticket.id});
      ref.invalidate(adminSupportTicketsProvider(_filter));
      ref.invalidate(supportUnreadByTicketProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            claimed == true
                ? 'Обращение назначено вам.'
                : 'Обращение уже взял другой администратор.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось назначить: ${error.message}')),
      );
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

  Future<void> _deleteTicket(_AdminSupportTicket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить обращение?'),
        content: const Text(
          'Обращение и вся переписка будут удалены без восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(supabaseProvider)
          .from('support_tickets')
          .delete()
          .eq('id', ticket.id);
      ref.invalidate(adminSupportTicketsProvider(_filter));
      setState(() => _selectedId = null);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Обращение удалено.')));
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить: ${error.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final access = ref.watch(adminSupportAccessProvider);
    final allowed = access.valueOrNull;
    if (allowed != true) {
      if (allowed == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(Routes.support);
        });
      }
      return const Scaffold(
        body: Stack(
          children: [
            BrandBackground(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    final ticketsAsync = ref.watch(adminSupportTicketsProvider(_filter));
    final currentAdminId =
        ref.read(supabaseProvider).auth.currentUser?.id ?? '';
    final unreadByTicket = ref
        .watch(supportUnreadByTicketProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <String, int>{});
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
                  Row(
                    children: [
                      Expanded(
                        child: _FilterBar(
                          value: _filter,
                          ru: ru,
                          onChanged: (value) => setState(() {
                            _filter = value;
                            _selectedId = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const _FaqAdminDialog(),
                        ),
                        icon: const Icon(Icons.quiz_outlined),
                        label: const Text('FAQ'),
                      ),
                    ],
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
                                  unreadByTicket: unreadByTicket,
                                  onSelect: (ticket) {
                                    setState(() => _selectedId = ticket.id);
                                    markSupportTicketRead(ref, ticket.id);
                                  },
                                )
                              : _TicketDetail(
                                  ticket: selected,
                                  replyController: _replyController,
                                  sending: _sending,
                                  currentAdminId: currentAdminId,
                                  onClaim: () => _claimTicket(selected),
                                  onBack: () =>
                                      setState(() => _selectedId = null),
                                  onReply: () => _sendReply(selected),
                                  onStatus: (status) =>
                                      _changeStatus(selected, status),
                                  onDelete: () => _deleteTicket(selected),
                                );
                        }
                        return Row(
                          children: [
                            SizedBox(
                              width: 390,
                              child: _TicketList(
                                tickets: tickets,
                                selectedId: _selectedId,
                                unreadByTicket: unreadByTicket,
                                onSelect: (ticket) {
                                  setState(() => _selectedId = ticket.id);
                                  markSupportTicketRead(ref, ticket.id);
                                },
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
                                      currentAdminId: currentAdminId,
                                      onClaim: () => _claimTicket(selected),
                                      onReply: () => _sendReply(selected),
                                      onStatus: (status) =>
                                          _changeStatus(selected, status),
                                      onDelete: () => _deleteTicket(selected),
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
    required this.unreadByTicket,
    required this.onSelect,
  });
  final List<_AdminSupportTicket> tickets;
  final String? selectedId;
  final Map<String, int> unreadByTicket;
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
        final unreadCount = unreadByTicket[ticket.id] ?? 0;
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
                      if (unreadCount > 0) ...[
                        _AdminUnreadBadge(count: unreadCount),
                        const SizedBox(width: 8),
                      ],
                      _PriorityDot(priority: ticket.priority),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${_channelLabel(ticket.channel)} • ${_categoryLabel(ticket.category)} • ${_supportStatus(ticket.status, true)}',
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

class _AdminUnreadBadge extends StatelessWidget {
  const _AdminUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: BrandTheme.redTop,
      borderRadius: BorderRadius.all(Radius.circular(999)),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FaqAdminDialog extends ConsumerWidget {
  const _FaqAdminDialog();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    _SupportFaqItem? item,
  ]) async {
    final draft = await showDialog<_FaqDraft>(
      context: context,
      builder: (_) => _FaqEditDialog(item: item),
    );
    if (draft == null) return;
    final values = {
      'question': draft.question,
      'answer': draft.answer,
      'keywords': draft.keywords,
      'is_active': draft.active,
      'sort_order': draft.sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final table = ref.read(supabaseProvider).from('support_faq');
    if (item == null) {
      await table.insert({
        ...values,
        'slug': 'admin_${DateTime.now().microsecondsSinceEpoch}',
      });
    } else {
      await table.update(values).eq('id', item.id);
    }
    ref.invalidate(adminSupportFaqProvider);
  }

  Future<void> _delete(WidgetRef ref, _SupportFaqItem item) async {
    await ref
        .read(supabaseProvider)
        .from('support_faq')
        .delete()
        .eq('id', item.id);
    ref.invalidate(adminSupportFaqProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(adminSupportFaqProvider);
    return AlertDialog(
      title: const Text('FAQ ПОДДЕРЖКИ'),
      content: SizedBox(
        width: 760,
        height: 560,
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Ошибка загрузки: $error')),
          data: (rows) => rows.isEmpty
              ? const Center(child: Text('Вопросов пока нет.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) {
                    final item = rows[index];
                    return ListTile(
                      leading: Icon(
                        item.active
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_rounded,
                        color: item.active ? Colors.green : kTextMuted,
                      ),
                      title: Text(
                        item.question,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        item.answer,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _edit(context, ref, item),
                      trailing: IconButton(
                        tooltip: 'Удалить FAQ',
                        onPressed: () => _delete(ref, item),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ЗАКРЫТЬ'),
        ),
        FilledButton.icon(
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('ДОБАВИТЬ ВОПРОС'),
        ),
      ],
    );
  }
}

class _FaqEditDialog extends StatefulWidget {
  const _FaqEditDialog({this.item});
  final _SupportFaqItem? item;

  @override
  State<_FaqEditDialog> createState() => _FaqEditDialogState();
}

class _FaqEditDialogState extends State<_FaqEditDialog> {
  late final TextEditingController _question;
  late final TextEditingController _answer;
  late final TextEditingController _keywords;
  late final TextEditingController _sortOrder;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _question = TextEditingController(text: item?.question ?? '');
    _answer = TextEditingController(text: item?.answer ?? '');
    _keywords = TextEditingController(text: item?.keywords.join(', ') ?? '');
    _sortOrder = TextEditingController(text: '${item?.sortOrder ?? 100}');
    _active = item?.active ?? true;
  }

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _keywords.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _save() {
    final question = _question.text.trim();
    final answer = _answer.text.trim();
    if (question.length < 3 || answer.length < 3) return;
    Navigator.of(context).pop(
      _FaqDraft(
        question: question,
        answer: answer,
        keywords: _keywords.text
            .split(',')
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        active: _active,
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'НОВЫЙ ВОПРОС' : 'РЕДАКТИРОВАТЬ FAQ'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _question,
              decoration: const InputDecoration(labelText: 'Вопрос'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answer,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Ответ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keywords,
              decoration: const InputDecoration(
                labelText: 'Ключевые слова через запятую',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Порядок'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: const Text('Активный вопрос'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('ОТМЕНА'),
      ),
      FilledButton(onPressed: _save, child: const Text('СОХРАНИТЬ')),
    ],
  );
}

class _TicketDetail extends ConsumerWidget {
  const _TicketDetail({
    required this.ticket,
    required this.replyController,
    required this.sending,
    required this.currentAdminId,
    required this.onClaim,
    required this.onReply,
    required this.onStatus,
    required this.onDelete,
    this.onBack,
  });
  final _AdminSupportTicket ticket;
  final TextEditingController replyController;
  final bool sending;
  final String currentAdminId;
  final VoidCallback onClaim;
  final VoidCallback onReply;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(adminSupportMessagesProvider(ticket.id));
    final assignedToMe = ticket.assignedTo == currentAdminId;
    final assignedElsewhere =
        ticket.assignedTo != null && ticket.assignedTo != currentAdminId;
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
                      '${_channelLabel(ticket.channel)} • ${_categoryLabel(ticket.category)} • ${ticket.userId}',
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Удалить обращение',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
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
                onChanged: assignedToMe
                    ? (value) {
                        if (value != null) onStatus(value);
                      }
                    : null,
              ),
            ],
          ),
          const Divider(height: 24),
          if (!assignedToMe) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: assignedElsewhere
                    ? const Color(0xFFF3F3F3)
                    : BrandTheme.redTop.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      assignedElsewhere
                          ? 'Обращение назначено другому администратору.'
                          : 'Обращение пока никому не назначено.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!assignedElsewhere)
                    FilledButton(
                      onPressed: onClaim,
                      child: const Text('ВЗЯТЬ В РАБОТУ'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Text(
              'НАЗНАЧЕНО ВАМ',
              style: TextStyle(
                color: BrandTheme.redTop,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
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
            onPressed: sending || !assignedToMe ? null : onReply,
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
    required this.channel,
    required this.category,
    required this.subject,
    required this.status,
    required this.priority,
    required this.assignedTo,
  });

  factory _AdminSupportTicket.fromMap(Map<String, dynamic> map) =>
      _AdminSupportTicket(
        id: (map['id'] ?? '').toString(),
        userId: (map['user_id'] ?? '').toString(),
        channel: (map['channel'] ?? 'in_app').toString(),
        category: (map['category'] ?? 'other').toString(),
        subject: (map['subject'] ?? '').toString(),
        status: (map['status'] ?? 'new').toString(),
        priority: (map['priority'] ?? 'normal').toString(),
        assignedTo: (map['assigned_to'] as String?)?.trim(),
      );

  final String id;
  final String userId;
  final String channel;
  final String category;
  final String subject;
  final String status;
  final String priority;
  final String? assignedTo;
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

class _SupportFaqItem {
  const _SupportFaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.keywords,
    required this.active,
    required this.sortOrder,
  });

  factory _SupportFaqItem.fromMap(Map<String, dynamic> map) => _SupportFaqItem(
    id: (map['id'] ?? '').toString(),
    question: (map['question'] ?? '').toString(),
    answer: (map['answer'] ?? '').toString(),
    keywords: (map['keywords'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    active: map['is_active'] == true,
    sortOrder: int.tryParse((map['sort_order'] ?? 100).toString()) ?? 100,
  );

  final String id;
  final String question;
  final String answer;
  final List<String> keywords;
  final bool active;
  final int sortOrder;
}

class _FaqDraft {
  const _FaqDraft({
    required this.question,
    required this.answer,
    required this.keywords,
    required this.active,
    required this.sortOrder,
  });

  final String question;
  final String answer;
  final List<String> keywords;
  final bool active;
  final int sortOrder;
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

String _channelLabel(String channel) => switch (channel) {
  'telegram' => 'Telegram',
  'email' => 'Email',
  'admin' => 'Админ',
  _ => 'Приложение',
};
