import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_providers.dart';
import '../../core/supabase_provider.dart';
import 'chat_models.dart';
import 'chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(supabaseProvider));
});

final myInvitationsProvider =
    FutureProvider.autoDispose<List<CastingInvitation>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return const <CastingInvitation>[];
      return ref.watch(chatServiceProvider).fetchMyInvitations(userId);
    });

final myChatsProvider = FutureProvider.autoDispose
    .family<List<ChatListItem>, bool>((ref, archived) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return const <ChatListItem>[];
      return ref
          .watch(chatServiceProvider)
          .fetchMyChats(userId: userId, archived: archived);
    });

final unreadChatCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final chats = await ref.watch(myChatsProvider(false).future);
  return chats.fold<int>(0, (sum, item) => sum + item.unreadCount);
});

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
      return ref.watch(chatServiceProvider).watchMessages(chatId);
    });

final pinnedChatMessagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
      return ref.watch(chatServiceProvider).fetchPinnedMessages(chatId);
    });

final chatReactionsProvider = StreamProvider.autoDispose
    .family<List<ChatReaction>, String>((ref, chatId) {
      return ref.watch(chatServiceProvider).watchReactions(chatId);
    });

final chatTypingStatesProvider = StreamProvider.autoDispose
    .family<List<ChatTypingState>, String>((ref, chatId) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return const Stream<List<ChatTypingState>>.empty();
      return ref
          .watch(chatServiceProvider)
          .watchTypingStates(chatId: chatId, currentUserId: userId);
    });

final chatSummaryProvider = FutureProvider.autoDispose
    .family<ChatSummary?, String>((ref, chatId) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return Future.value(null);
      return ref
          .watch(chatServiceProvider)
          .fetchChat(chatId: chatId, currentUserId: userId);
    });

final chatContextsProvider = FutureProvider.autoDispose
    .family<List<ChatContextEntry>, String>((ref, chatId) {
      return ref.watch(chatServiceProvider).fetchChatContexts(chatId);
    });

final chatParticipantAvatarsProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, chatId) {
      return ref.watch(chatServiceProvider).fetchChatParticipantAvatars(chatId);
    });

final chatMentionTargetsProvider = FutureProvider.autoDispose
    .family<List<ChatMentionTarget>, String>((ref, chatId) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return Future.value(const <ChatMentionTarget>[]);
      return ref
          .watch(chatServiceProvider)
          .fetchMentionTargets(chatId: chatId, currentUserId: userId);
    });

/// Б3: sends the presence heartbeat every 30 s while the app is visible
/// and marks the user offline when it goes to the background. Watched by
/// the app shell so it runs on every page.
final presenceHeartbeatProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) return;
  final service = ref.read(chatServiceProvider);

  var visible = true;
  Future<void> beat() async {
    try {
      await service.touchPresence(online: visible);
    } catch (_) {
      // Presence is a soft signal; a failed beat is retried next tick.
    }
  }

  unawaited(beat());
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (visible) unawaited(beat());
  });
  final lifecycle = AppLifecycleListener(
    onShow: () {
      visible = true;
      unawaited(beat());
    },
    onResume: () {
      visible = true;
      unawaited(beat());
    },
    onHide: () {
      visible = false;
      unawaited(beat());
    },
    onPause: () {
      visible = false;
      unawaited(beat());
    },
  );

  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
    visible = false;
    unawaited(beat());
  });
});

final userPresenceProvider = StreamProvider.autoDispose
    .family<UserPresence?, String>((ref, userId) {
      return ref.watch(chatServiceProvider).watchPresence(userId);
    });

/// Step 36: Supabase Realtime Presence — the set of user ids connected
/// right now. One shared channel; every client tracks itself while its
/// tab is visible, and the server drops it the moment the socket closes,
/// so the status flips within seconds instead of waiting out a heartbeat.
/// Watched by the app shell so the channel stays alive on every page.
final onlineUsersProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final controller = StreamController<Set<String>>();
  if (userId == null || userId.isEmpty) {
    controller.add(const <String>{});
    ref.onDispose(controller.close);
    return controller.stream;
  }

  final sb = ref.read(supabaseProvider);
  final channel = sb.channel(
    'presence:online',
    opts: RealtimeChannelConfig(key: userId, enabled: true),
  );

  void sync() {
    final ids = <String>{};
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final id = (presence.payload['user_id'] ?? state.key).toString();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    if (!controller.isClosed) controller.add(ids);
  }

  var visible = true;
  var subscribed = false;
  Future<void> track() async {
    if (!subscribed || !visible) return;
    try {
      await channel.track(<String, dynamic>{
        'user_id': userId,
        'online_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Presence is a soft signal.
    }
  }

  Future<void> untrack() async {
    if (!subscribed) return;
    try {
      await channel.untrack();
    } catch (_) {
      // Presence is a soft signal.
    }
  }

  channel
      .onPresenceSync((_) => sync())
      .onPresenceJoin((_) => sync())
      .onPresenceLeave((_) => sync())
      .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          subscribed = true;
          unawaited(track());
        } else if (status == RealtimeSubscribeStatus.closed) {
          subscribed = false;
        }
      });

  // A hidden tab is not «в сети»: the same rule the heartbeat follows.
  final lifecycle = AppLifecycleListener(
    onShow: () {
      visible = true;
      unawaited(track());
    },
    onResume: () {
      visible = true;
      unawaited(track());
    },
    onHide: () {
      visible = false;
      unawaited(untrack());
    },
    onPause: () {
      visible = false;
      unawaited(untrack());
    },
  );

  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(sb.removeChannel(channel));
    controller.close();
  });
  return controller.stream;
});

/// Step 36: whether [userId] is online — connected over Realtime Presence,
/// or (while the presence channel is still connecting) fresh by the
/// heartbeat table.
final userIsOnlineProvider = Provider.autoDispose.family<bool, String>((
  ref,
  userId,
) {
  final id = userId.trim();
  if (id.isEmpty) return false;
  final live = ref.watch(onlineUsersProvider).valueOrNull;
  if (live != null) return live.contains(id);
  return ref.watch(userPresenceProvider(id)).valueOrNull?.isOnlineNow ??
      false;
});

/// Б4: the chat list and the unread badge follow realtime changes to
/// messages and chats instead of waiting for a manual refresh.
final chatListRealtimeProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) return;

  final sb = ref.read(supabaseProvider);
  Timer? debounce;
  void refresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      ref.invalidate(myChatsProvider(false));
      ref.invalidate(myChatsProvider(true));
    });
  }

  final channel = sb
      .channel('chat-list-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'selection_chat_messages',
        callback: (_) => refresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'selection_chats',
        callback: (_) => refresh(),
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    sb.removeChannel(channel);
  });
});
