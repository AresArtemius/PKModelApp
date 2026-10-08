import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/chat/chat_providers.dart';
import '../features/notifications/app_notifications.dart';
import 'auth_providers.dart';
import 'go_router_provider.dart';
import 'router.dart';
import 'supabase_provider.dart';
import 'tab_alerts_stub.dart' if (dart.library.js_interop) 'tab_alerts_web.dart';

export 'tab_alerts_stub.dart' if (dart.library.js_interop) 'tab_alerts_web.dart';

/// Browser-tab alerts (step 37): unread badge in the tab title, a sound and
/// a system notification for a new message while the tab is open.
final tabAlertsProvider = Provider<TabAlerts>((ref) => TabAlerts());

/// Keeps the tab badge in sync and fires sound / notification on incoming
/// messages. Watched by the app shell on web; a no-op elsewhere.
final tabAlertsSyncProvider = Provider.autoDispose<void>((ref) {
  if (!kIsWeb) return;
  final alerts = ref.watch(tabAlertsProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) {
    alerts.setBadge(0);
    return;
  }

  // Badge: unread chats + unread notifications.
  final chats = ref.watch(unreadChatCountProvider).valueOrNull ?? 0;
  final notifications =
      ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
  alerts.setBadge(chats + notifications);

  // Incoming messages: sound, and a system notification when the tab is in
  // the background or another chat is open.
  final sb = ref.read(supabaseProvider);
  final channel = sb
      .channel('tab-alerts-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'selection_chat_messages',
        callback: (payload) {
          final row = payload.newRecord;
          final sender = (row['sender_id'] ?? '').toString();
          if (sender.isEmpty || sender == userId) return;
          final chatId = (row['chat_id'] ?? '').toString();
          _onIncomingMessage(ref, alerts, userId, chatId, row);
        },
      )
      .subscribe();
  ref.onDispose(() => sb.removeChannel(channel));
});

DateTime? _lastSoundAt;

void _onIncomingMessage(
  Ref ref,
  TabAlerts alerts,
  String userId,
  String chatId,
  Map<String, dynamic> row,
) {
  // Only chats I take part in: the list cache knows them.
  final chats = ref.read(myChatsProvider(false)).valueOrNull;
  final chat = chats?.where((c) => c.id == chatId).firstOrNull;
  if (chats != null && chat == null) return;

  final router = ref.read(goRouterProvider);
  final uri = router.routerDelegate.currentConfiguration.uri;
  final openChatId = uri.path.startsWith(Routes.chatPrefix)
      ? uri.path.substring(Routes.chatPrefix.length)
      : uri.path == Routes.chats
      ? (uri.queryParameters[Routes.chatsChatParam] ?? '')
      : '';
  final chatIsOnScreen = openChatId == chatId && !alerts.hidden;

  // Sound: not more than once per two seconds, and not for the chat the
  // user is looking at right now.
  final now = DateTime.now();
  if (!chatIsOnScreen &&
      (_lastSoundAt == null ||
          now.difference(_lastSoundAt!) > const Duration(seconds: 2))) {
    _lastSoundAt = now;
    alerts.playSound();
  }

  if (chatIsOnScreen) return;
  if (!alerts.notificationsGranted) return;

  final title = chat == null
      ? 'PK Management'
      : [
          chat.profileName,
          chat.selectionTitle,
        ].where((s) => s.trim().isNotEmpty).join(' · ');
  final mediaType = (row['media_type'] ?? 'text').toString();
  final body = switch (mediaType) {
    'image' => '📷 Фото',
    'video' => '🎬 Видео',
    'audio' => '🎤 Голосовое сообщение',
    'file' => '📎 Файл',
    _ => _plainBody((row['body'] ?? '').toString()),
  };
  alerts.notify(
    title: title.isEmpty ? 'PK Management' : title,
    body: body,
    tag: 'chat-$chatId',
    onClick: () => router.go(Routes.chatLocation(chatId)),
  );
}

/// Strips the reply-quote prefix the chat uses inside message bodies.
String _plainBody(String raw) {
  var text = raw.trim();
  const prefix = '↩ ';
  const separator = '\n\n';
  if (text.startsWith(prefix)) {
    final index = text.indexOf(separator);
    if (index > 0) text = text.substring(index + separator.length).trim();
  }
  return text.length > 140 ? '${text.substring(0, 140)}…' : text;
}
