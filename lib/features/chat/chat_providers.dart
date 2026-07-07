import 'package:flutter_riverpod/flutter_riverpod.dart';

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
