import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'support_unread_provider.dart';

final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((
  ref,
) async {
  final sb = ref.read(supabaseProvider);
  try {
    final rows = await sb
        .from('support_tickets')
        .select('id,category,subject,status,created_at,updated_at')
        .order('updated_at', ascending: false)
        .limit(50);
    return rows.map(SupportTicket.fromMap).toList(growable: false);
  } on PostgrestException catch (error) {
    if (SupabaseCompat.isMissingRelation(error, const ['support_tickets'])) {
      throw const SupportSetupRequiredException();
    }
    rethrow;
  }
});

final supportTicketMessagesProvider = FutureProvider.autoDispose
    .family<List<SupportTicketMessage>, String>((ref, ticketId) async {
      final rows = await ref
          .read(supabaseProvider)
          .from('support_messages')
          .select('id,author_kind,body,created_at')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return rows.map(SupportTicketMessage.fromMap).toList(growable: false);
    });

final supportTicketAttachmentsProvider = FutureProvider.autoDispose
    .family<List<SupportAttachment>, String>((ref, ticketId) async {
      final sb = ref.read(supabaseProvider);
      final rows = await sb
          .from('support_attachments')
          .select('id,original_name,storage_path,created_at')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return Future.wait(
        rows.map((row) async {
          final path = row['storage_path'] as String;
          final url = await sb.storage
              .from('support-attachments')
              .createSignedUrl(path, 900);
          return SupportAttachment(
            name: row['original_name'] as String,
            signedUrl: url,
          );
        }),
      );
    });

final telegramSupportLinkProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  try {
    final row = await ref
        .read(supabaseProvider)
        .from('telegram_support_links')
        .select('user_id')
        .isFilter('revoked_at', null)
        .maybeSingle();
    return row != null;
  } on PostgrestException {
    return false;
  }
});

class SupportSetupRequiredException implements Exception {
  const SupportSetupRequiredException();
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    required this.updatedAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map) => SupportTicket(
    id: (map['id'] ?? '').toString(),
    category: (map['category'] ?? 'other').toString(),
    subject: (map['subject'] ?? '').toString(),
    status: (map['status'] ?? 'new').toString(),
    updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
  );

  final String id;
  final String category;
  final String subject;
  final String status;
  final DateTime? updatedAt;
}

class SupportTicketMessage {
  const SupportTicketMessage({required this.authorKind, required this.body});

  factory SupportTicketMessage.fromMap(Map<String, dynamic> map) =>
      SupportTicketMessage(
        authorKind: (map['author_kind'] ?? 'user').toString(),
        body: (map['body'] ?? '').toString(),
      );

  final String authorKind;
  final String body;
}

class SupportAttachment {
  const SupportAttachment({required this.name, required this.signedUrl});

  final String name;
  final String signedUrl;
}

Future<void> _uploadSupportAttachment(
  SupabaseClient sb,
  String ticketId,
  PlatformFile file, {
  String? messageId,
}) async {
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw const FormatException('Invalid support attachment');
  }
  final userId = sb.auth.currentUser!.id;
  final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9._-]'), '_');
  final path =
      '$ticketId/$userId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
  final mimeType = switch (file.extension?.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
  await sb.storage
      .from('support-attachments')
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType),
      );
  await sb.from('support_attachments').insert({
    'ticket_id': ticketId,
    'message_id': messageId,
    'uploader_id': userId,
    'source': 'in_app',
    'storage_path': path,
    'original_name': file.name,
    'mime_type': mimeType,
    'size_bytes': bytes.length,
  });
}

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  static const _telegramBotUsername = 'pkmodelapp_bot';

  Future<void> _connectTelegram(BuildContext context, WidgetRef ref) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    try {
      final raw = await ref
          .read(supabaseProvider)
          .rpc('create_telegram_support_link_code');
      final code = (raw ?? '').toString().trim();
      if (code.isEmpty) throw StateError('Empty Telegram link code');
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(ru ? 'Подключить Telegram' : 'Connect Telegram'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ru
                    ? 'Код действует 10 минут. Нажмите кнопку ниже — бот получит код автоматически.'
                    : 'The code is valid for 10 minutes. Tap below and the bot will receive it automatically.',
              ),
              const SizedBox(height: 14),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(ru ? 'ОТМЕНА' : 'CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.parse(
                  'https://t.me/$_telegramBotUsername?start=$code',
                );
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (opened && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              icon: const Icon(Icons.telegram_rounded),
              label: Text(ru ? 'ОТКРЫТЬ БОТА' : 'OPEN BOT'),
            ),
          ],
        ),
      );
      ref.invalidate(telegramSupportLinkProvider);
    } on PostgrestException catch (error) {
      if (!context.mounted) return;
      debugPrint('Telegram support link failed: ${error.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ru
                ? 'Не удалось создать код подключения. Попробуйте ещё раз.'
                : 'Could not create a connection code. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _disconnectTelegram(BuildContext context, WidgetRef ref) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    await ref.read(supabaseProvider).rpc('revoke_my_telegram_support_link');
    ref.invalidate(telegramSupportLinkProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ru ? 'Telegram отключён от поддержки.' : 'Telegram disconnected.',
        ),
      ),
    );
  }

  Future<void> _deleteTicket(
    BuildContext context,
    WidgetRef ref,
    SupportTicket ticket,
  ) async {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'Удалить обращение?' : 'Delete request?'),
        content: Text(
          ru
              ? 'Обращение и вся переписка будут удалены без восстановления.'
              : 'The request and its message history will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ru ? 'ОТМЕНА' : 'CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(ru ? 'УДАЛИТЬ' : 'DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(supabaseProvider)
          .from('support_tickets')
          .delete()
          .eq('id', ticket.id);
      ref.invalidate(supportTicketsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ru ? 'Обращение удалено.' : 'Request deleted.')),
      );
    } on PostgrestException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить: ${error.message}')),
      );
    }
  }

  Future<void> _createTicket(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_SupportDraft>(
      context: context,
      builder: (_) => const _NewSupportTicketDialog(),
    );
    if (draft == null || !context.mounted) return;

    try {
      final ticketId = await ref
          .read(supabaseProvider)
          .rpc(
            'create_support_ticket',
            params: {
              'p_category': draft.category,
              'p_subject': draft.subject,
              'p_message': draft.message,
            },
          );
      if (draft.attachment != null) {
        await _uploadSupportAttachment(
          ref.read(supabaseProvider),
          ticketId.toString(),
          draft.attachment!,
        );
      }
      ref.invalidate(supportTicketsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Обращение отправлено администратору.')),
      );
    } on PostgrestException catch (error) {
      if (!context.mounted) return;
      final setupRequired =
          SupabaseCompat.isMissingRelation(error, const ['support_tickets']) ||
          SupabaseCompat.isMissingRpc(error, 'create_support_ticket');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            setupRequired
                ? 'Центр поддержки еще настраивается. Примените support_center_mvp.sql.'
                : 'Не удалось отправить обращение. Попробуйте еще раз.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final tickets = ref.watch(supportTicketsProvider);
    final unreadByTicket = ref
        .watch(supportUnreadByTicketProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <String, int>{});
    final telegramLinked = ref
        .watch(telegramSupportLinkProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final compact = MediaQuery.sizeOf(context).width < 720;

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
                    title: ru ? 'ПОМОЩЬ И ПОДДЕРЖКА' : 'HELP & SUPPORT',
                    onBack: () => context.go(Routes.me),
                  ),
                  const SizedBox(height: kGap16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SupportHero(
                                compact: compact,
                                ru: ru,
                                onContact: () => _createTicket(context, ref),
                              ),
                              const SizedBox(height: kGap12),
                              _TelegramSupportCard(
                                ru: ru,
                                linked: telegramLinked,
                                onConnect: () => _connectTelegram(context, ref),
                                onDisconnect: () =>
                                    _disconnectTelegram(context, ref),
                              ),
                              const SizedBox(height: kGap16),
                              Text(
                                ru ? 'ЧАСТЫЕ ВОПРОСЫ' : 'POPULAR QUESTIONS',
                                style: BrandTheme.pillText.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: kGap12),
                              ..._faq(ru).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _FaqTile(item: item),
                                ),
                              ),
                              const SizedBox(height: kGap16),
                              Text(
                                ru ? 'МОИ ОБРАЩЕНИЯ' : 'MY REQUESTS',
                                style: BrandTheme.pillText.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: kGap12),
                              tickets.when(
                                data: (items) => items.isEmpty
                                    ? _InfoCard(
                                        text: ru
                                            ? 'У вас пока нет обращений.'
                                            : 'You have no support requests yet.',
                                      )
                                    : Column(
                                        children: items
                                            .map(
                                              (ticket) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                child: _TicketCard(
                                                  ticket: ticket,
                                                  ru: ru,
                                                  unreadCount:
                                                      unreadByTicket[ticket
                                                          .id] ??
                                                      0,
                                                  onTap: () => showDialog<void>(
                                                    context: context,
                                                    builder: (_) =>
                                                        _SupportTicketDialog(
                                                          ticket: ticket,
                                                          ru: ru,
                                                        ),
                                                  ),
                                                  onDelete: () => _deleteTicket(
                                                    context,
                                                    ref,
                                                    ticket,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(growable: false),
                                      ),
                                loading: () => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                error: (error, _) => _InfoCard(
                                  text: error is SupportSetupRequiredException
                                      ? (ru
                                            ? 'Центр обращений готов в приложении и ожидает применения support_center_mvp.sql.'
                                            : 'The support center is waiting for support_center_mvp.sql setup.')
                                      : (ru
                                            ? 'Не удалось загрузить обращения.'
                                            : 'Could not load support requests.'),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
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

class _TelegramSupportCard extends StatelessWidget {
  const _TelegramSupportCard({
    required this.ru,
    required this.linked,
    required this.onConnect,
    required this.onDisconnect,
  });

  final bool ru;
  final bool linked;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: catalogCardDecoration(),
    child: Row(
      children: [
        const Icon(Icons.telegram_rounded, color: Color(0xFF229ED9), size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ru ? 'TELEGRAM-ПОДДЕРЖКА' : 'TELEGRAM SUPPORT',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                linked
                    ? (ru
                          ? 'Подключено к @pkmodelapp_bot'
                          : 'Connected to @pkmodelapp_bot')
                    : (ru
                          ? 'Быстрые ответы и связь с администратором'
                          : 'Quick answers and administrator contact'),
                style: const TextStyle(color: kTextMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (linked)
          OutlinedButton(
            onPressed: onDisconnect,
            child: Text(ru ? 'ОТКЛЮЧИТЬ' : 'DISCONNECT'),
          )
        else
          FilledButton(
            onPressed: onConnect,
            child: Text(ru ? 'ПОДКЛЮЧИТЬ' : 'CONNECT'),
          ),
      ],
    ),
  );
}

class _SupportHero extends StatelessWidget {
  const _SupportHero({
    required this.compact,
    required this.ru,
    required this.onContact,
  });

  final bool compact;
  final bool ru;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ru ? 'ЧЕМ МЫ МОЖЕМ ПОМОЧЬ?' : 'HOW CAN WE HELP?',
          style: BrandTheme.pillText.copyWith(
            fontSize: compact ? 21 : 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ru
              ? 'Посмотрите быстрые ответы или отправьте обращение администратору. История запроса сохранится в приложении.'
              : 'Browse quick answers or contact an administrator. Your request history stays in the app.',
          style: const TextStyle(
            color: kTextMuted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
    final button = BrandPillButton(
      label: ru ? 'НАПИСАТЬ АДМИНИСТРАТОРУ' : 'CONTACT ADMINISTRATOR',
      style: BrandPillStyle.dark,
      onTap: onContact,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: catalogCardDecoration(),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 18), button],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 24),
                SizedBox(width: 350, child: button),
              ],
            ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});
  final ({String question, String answer}) item;

  @override
  Widget build(BuildContext context) => Container(
    decoration: catalogCardDecoration(),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        item.question,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.answer,
              style: const TextStyle(
                color: kTextMuted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.ru,
    required this.unreadCount,
    required this.onTap,
    required this.onDelete,
  });
  final SupportTicket ticket;
  final bool ru;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: catalogCardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.forum_rounded, color: BrandTheme.redTop),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.subject,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusLabel(ticket.status, ru),
                    style: const TextStyle(
                      color: kTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              _UnreadBadge(count: unreadCount),
              const SizedBox(width: 8),
            ],
            IconButton(
              tooltip: ru ? 'Удалить обращение' : 'Delete request',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: kTextMuted),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ],
        ),
      ),
    ),
  );
}

class _SupportTicketDialog extends ConsumerStatefulWidget {
  const _SupportTicketDialog({required this.ticket, required this.ru});
  final SupportTicket ticket;
  final bool ru;

  @override
  ConsumerState<_SupportTicketDialog> createState() =>
      _SupportTicketDialogState();
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

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

class _SupportTicketDialogState extends ConsumerState<_SupportTicketDialog> {
  final _replyController = TextEditingController();
  bool _sending = false;
  PlatformFile? _attachment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) markSupportTicketRead(ref, widget.ticket.id);
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final body = _replyController.text.trim();
    if ((body.isEmpty && _attachment == null) || _sending) return;
    setState(() => _sending = true);
    try {
      final sb = ref.read(supabaseProvider);
      final row = await sb
          .from('support_messages')
          .insert({
            'ticket_id': widget.ticket.id,
            'author_id': sb.auth.currentUser?.id,
            'author_kind': 'user',
            'body': body.isEmpty ? 'Пользователь отправил скриншот.' : body,
            'source': 'in_app',
          })
          .select('id')
          .single();
      if (_attachment != null) {
        await _uploadSupportAttachment(
          sb,
          widget.ticket.id,
          _attachment!,
          messageId: row['id'] as String,
        );
      }
      _replyController.clear();
      setState(() => _attachment = null);
      ref.invalidate(supportTicketMessagesProvider(widget.ticket.id));
      ref.invalidate(supportTicketAttachmentsProvider(widget.ticket.id));
      ref.invalidate(supportTicketsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.ru
                ? 'Ответ отправлен администратору.'
                : 'Your reply was sent to the administrator.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.ru
                ? 'Не удалось отправить ответ: ${error.message}'
                : 'Could not send reply: ${error.message}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(supportTicketMessagesProvider(widget.ticket.id));
    final attachments = ref.watch(
      supportTicketAttachmentsProvider(widget.ticket.id),
    );
    return AlertDialog(
      title: Text(widget.ticket.subject),
      content: SizedBox(
        width: 620,
        height: 520,
        child: Column(
          children: [
            Expanded(
              child: messages.when(
                data: (items) => items.isEmpty
                    ? Center(
                        child: Text(
                          widget.ru
                              ? 'Сообщений пока нет.'
                              : 'No messages yet.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final message = items[index];
                          final admin = message.authorKind == 'admin';
                          return Align(
                            alignment: admin
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 500),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: admin
                                    ? Colors.white
                                    : const Color(0xFFEDEDED),
                                border: Border.all(color: kBorderColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    admin
                                        ? (widget.ru ? 'Поддержка' : 'Support')
                                        : (widget.ru ? 'Вы' : 'You'),
                                    style: TextStyle(
                                      color: admin
                                          ? BrandTheme.redTop
                                          : kTextMuted,
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
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
              ),
            ),
            attachments.when(
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) =>
                            _SupportAttachmentTile(attachment: items[index]),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _replyController,
              minLines: 2,
              maxLines: 4,
              maxLength: 5000,
              decoration: InputDecoration(
                hintText: widget.ru
                    ? 'Ответить администратору…'
                    : 'Reply to the administrator…',
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _sending
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                            withData: true,
                          );
                          final file = result?.files.first;
                          if (file == null || !context.mounted) return;
                          if (file.size > 10 * 1024 * 1024) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Файл должен быть не больше 10 МБ.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _attachment = file);
                        },
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(
                    _attachment?.name ??
                        (widget.ru
                            ? 'ПРИЛОЖИТЬ СКРИНШОТ'
                            : 'ATTACH SCREENSHOT'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_attachment != null)
                  IconButton(
                    onPressed: () => setState(() => _attachment = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.ru ? 'ЗАКРЫТЬ' : 'CLOSE'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _sendReply,
          icon: const Icon(Icons.send_rounded),
          label: Text(
            _sending
                ? (widget.ru ? 'ОТПРАВКА…' : 'SENDING…')
                : (widget.ru ? 'ОТПРАВИТЬ' : 'SEND'),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: catalogCardDecoration(),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w600),
    ),
  );
}

class _SupportAttachmentTile extends StatelessWidget {
  const _SupportAttachmentTile({required this.attachment});

  final SupportAttachment attachment;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => launchUrl(
      Uri.parse(attachment.signedUrl),
      mode: LaunchMode.externalApplication,
    ),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 125,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(attachment.signedUrl, fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NewSupportTicketDialog extends StatefulWidget {
  const _NewSupportTicketDialog();

  @override
  State<_NewSupportTicketDialog> createState() =>
      _NewSupportTicketDialogState();
}

class _NewSupportTicketDialogState extends State<_NewSupportTicketDialog> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'other';
  PlatformFile? _attachment;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return AlertDialog(
      title: Text(ru ? 'Новое обращение' : 'New support request'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: ru ? 'Категория' : 'Category',
              ),
              items: _categories(ru)
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item.$1, child: Text(item.$2)),
                  )
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _category = value ?? 'other'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subject,
              maxLength: 160,
              decoration: InputDecoration(labelText: ru ? 'Тема' : 'Subject'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              minLines: 4,
              maxLines: 7,
              maxLength: 5000,
              decoration: InputDecoration(
                labelText: ru ? 'Опишите вопрос' : 'Describe your question',
                alignLabelWithHint: true,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Flexible(
                    child: TextButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                          withData: true,
                        );
                        final file = result?.files.first;
                        if (file == null || !context.mounted) return;
                        if (file.size > 10 * 1024 * 1024) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ru
                                    ? 'Файл должен быть не больше 10 МБ.'
                                    : 'The file must be no larger than 10 MB.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _attachment = file);
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        _attachment?.name ??
                            (ru ? 'ПРИЛОЖИТЬ СКРИНШОТ' : 'ATTACH SCREENSHOT'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_attachment != null)
                    IconButton(
                      onPressed: () => setState(() => _attachment = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ru ? 'ОТМЕНА' : 'CANCEL'),
        ),
        FilledButton(
          onPressed: () {
            final subject = _subject.text.trim();
            final message = _message.text.trim();
            if (subject.length < 3 || message.isEmpty) return;
            Navigator.of(context).pop(
              _SupportDraft(
                category: _category,
                subject: subject,
                message: message,
                attachment: _attachment,
              ),
            );
          },
          child: Text(ru ? 'ОТПРАВИТЬ' : 'SEND'),
        ),
      ],
    );
  }
}

class _SupportDraft {
  const _SupportDraft({
    required this.category,
    required this.subject,
    required this.message,
    this.attachment,
  });
  final String category;
  final String subject;
  final String message;
  final PlatformFile? attachment;
}

List<(String, String)> _categories(bool ru) => [
  ('account', ru ? 'Аккаунт и вход' : 'Account and sign-in'),
  ('profile', ru ? 'Анкета' : 'Profile'),
  ('moderation', ru ? 'Модерация' : 'Moderation'),
  ('billing', ru ? 'Оплата' : 'Billing'),
  ('casting', ru ? 'Кастинги и отклики' : 'Castings and responses'),
  ('security', ru ? 'Безопасность' : 'Security'),
  ('other', ru ? 'Другое' : 'Other'),
];

List<({String question, String answer})> _faq(bool ru) => ru
    ? const [
        (
          question: 'Почему анкета не видна в каталоге?',
          answer:
              'В каталоге показываются одобренные анкеты с активным периодом размещения. Свою анкету и статус модерации вы всегда видите в аккаунте.',
        ),
        (
          question: 'Сколько длится модерация?',
          answer:
              'Администратор проверяет точность данных и качество портфолио. Если нужны уточнения, комментарий появится в карточке анкеты.',
        ),
        (
          question: 'Как оплатить размещение?',
          answer:
              'После одобрения анкеты откройте раздел оплаты в аккаунте, выберите срок и завершите платеж на защищенной странице ЮKassa.',
        ),
        (
          question: 'Как откликнуться на кастинг?',
          answer:
              'Откройте кастинг, выберите подходящую анкету и отправьте отклик. Его дальнейший статус будет доступен в приложении.',
        ),
      ]
    : const [
        (
          question: 'Why is my profile not visible in the catalogue?',
          answer:
              'The catalogue shows approved profiles with an active placement period. Your profile and moderation status remain available in your account.',
        ),
        (
          question: 'How long does moderation take?',
          answer:
              'An administrator checks profile accuracy and portfolio quality. Any requested changes appear on your profile card.',
        ),
        (
          question: 'How do I pay for placement?',
          answer:
              'After approval, open Billing in your account, choose a period and complete payment on the secure YooKassa page.',
        ),
        (
          question: 'How do I respond to a casting?',
          answer:
              'Open a casting, choose an eligible profile and submit it. The response status remains available in the app.',
        ),
      ];

String _statusLabel(String status, bool ru) {
  if (!ru) {
    return switch (status) {
      'queued_for_admin' => 'Waiting for administrator',
      'in_progress' => 'In progress',
      'waiting_for_user' => 'Waiting for your reply',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      'bot_answered' => 'Answered by assistant',
      _ => 'New request',
    };
  }
  return switch (status) {
    'queued_for_admin' => 'Ожидает администратора',
    'in_progress' => 'В работе',
    'waiting_for_user' => 'Ожидает вашего ответа',
    'resolved' => 'Решено',
    'closed' => 'Закрыто',
    'bot_answered' => 'Ответил помощник',
    _ => 'Новое обращение',
  };
}
