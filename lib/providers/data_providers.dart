import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messages/message_ops.dart';
import '../data/models/index.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final communitiesProvider = FutureProvider<List<Community>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getMyCommunities();
});

class _StringNullNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedCommunityIdProvider =
    NotifierProvider<_StringNullNotifier, String?>(_StringNullNotifier.new);
final selectedChannelIdProvider =
    NotifierProvider<_StringNullNotifier, String?>(_StringNullNotifier.new);

/// A message the channel view should scroll to once it is loaded. Set when
/// jumping in from a notification, mirroring the web client's pending store.
final pendingMessageIdProvider =
    NotifierProvider<_StringNullNotifier, String?>(_StringNullNotifier.new);

final channelsProvider =
    FutureProvider.family<List<Channel>, String>((ref, communityId) async {
      final api = ref.read(apiClientProvider);
      return api.getChannels(communityId);
    });

// Categories are the folder headers that channels are grouped under in the
// channel list. Fetched alongside channels whenever the list is shown.
final categoriesProvider =
    FutureProvider.family<List<ChannelCategory>, String>((ref, communityId) async {
      final api = ref.read(apiClientProvider);
      return api.getCategories(communityId);
    });

// Per channel unread and mention counts for a community. Drives the unread
// dots in the channel sidebar and the badges on the server rail. Invalidated
// whenever a channel is opened or a message arrives.
final channelUnreadProvider =
    FutureProvider.family<UnreadCounts, String>((ref, communityId) async {
      final api = ref.read(apiClientProvider);
      return api.getChannelUnreadCounts(communityId);
    });

// Live message list for a channel: seeded from REST history, then fed by
// gateway events. One notifier per channel, so switching channels starts a
// fresh subscription and drops the previous one.
class ChannelMessagesNotifier extends Notifier<List<Message>> {
  ChannelMessagesNotifier(this.channelId);

  final String channelId;
  late final StreamSubscription<WebSocketEvent> _subscription;

  bool _loading = true;
  bool _hasMore = true;
  bool _loadingOlder = false;
  Future<void>? _firstPage;

  /// Whether history before the oldest loaded message exists.
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  bool get isLoadingOlder => _loadingOlder;

  @override
  List<Message> build() {
    _firstPage = _load();
    final socket = ref.read(websocketProvider);
    _subscription = socket.events.listen(_handleEvent);
    socket.subscribe(channelId);
    ref.onDispose(() {
      _subscription.cancel();
      socket.unsubscribe(channelId);
    });
    return const [];
  }

  Future<void> _load() async {
    try {
      final messages = await ref
          .read(apiClientProvider)
          .getMessages(channelId, limit: kMessagePageSize);
      state = appendOlder(const [], messages, limit: 100);
      _hasMore = messages.length >= kMessagePageSize;
    } catch (e) {
      debugPrint('Failed to load messages for channel $channelId: $e');
    } finally {
      _loading = false;
    }
  }

  /// Pages in older messages using the oldest loaded message as the cursor.
  Future<void> loadOlder() async {
    // Paging before the first page lands would page from the wrong cursor.
    await _firstPage;
    if (_loadingOlder || !_hasMore || state.isEmpty) return;
    _loadingOlder = true;
    try {
      final older = await ref
          .read(apiClientProvider)
          .getMessages(
            channelId,
            limit: kMessagePageSize,
            before: state.first.id,
          );
      _hasMore = older.length >= kMessagePageSize;
      state = appendOlder(state, older, limit: 100);
    } catch (e) {
      debugPrint('Failed to load older messages for channel $channelId: $e');
    } finally {
      _loadingOlder = false;
    }
  }

  void _handleEvent(WebSocketEvent event) {
    try {
      final selfId = ref.read(authProvider).session?.user.id ?? '';
      switch (event.type) {
        case WebSocketEventType.messageCreate:
          final message = Message.fromJson(event.data);
          if (message.channelId != channelId) return;
          if (state.any((m) => m.id == message.id)) return;
          state = [...state, message];
        case WebSocketEventType.messageUpdate:
          final message = Message.fromJson(event.data);
          if (message.channelId != channelId) return;
          state = replaceMessage(state, message);
        case WebSocketEventType.messageDelete:
          final data = ChannelMessageDeleteEvent.fromJson(event.data);
          if (data.channelId != channelId) return;
          state = state.where((m) => m.id != data.messageId).toList();
        case WebSocketEventType.reactionAdd:
          final data = ChannelReactionEvent.fromJson(event.data);
          if (data.channelId != channelId) return;
          state = updateReaction(
            state,
            messageId: data.messageId,
            emoji: data.emoji,
            userId: data.userId,
            added: true,
            currentUserId: selfId,
          );
        case WebSocketEventType.reactionRemove:
          final data = ChannelReactionEvent.fromJson(event.data);
          if (data.channelId != channelId) return;
          state = updateReaction(
            state,
            messageId: data.messageId,
            emoji: data.emoji,
            userId: data.userId,
            added: false,
            currentUserId: selfId,
          );
        default:
          return;
      }
    } catch (e) {
      debugPrint('Failed to handle WebSocket event ${event.type}: $e');
    }
  }

  Future<void> send(String content, {String? replyToId}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final api = ref.read(apiClientProvider);
    final message = await api.sendMessage(
      channelId,
      SendMessageRequest(content: trimmed, replyToId: replyToId),
    );
    state = normaliseOrder([...state, message]);
  }

  Future<void> toggleReaction(String messageId, String emoji, bool reacted) async {
    final selfId = ref.read(authProvider).session?.user.id ?? '';
    state = toggleReactionLocally(
      state,
      messageId: messageId,
      emoji: emoji,
      currentUserId: selfId,
    );
    final api = ref.read(apiClientProvider);
    try {
      if (reacted) {
        await api.removeReaction(messageId, emoji);
      } else {
        await api.addReaction(messageId, emoji);
      }
    } catch (e) {
      debugPrint('Failed to toggle reaction $emoji on $messageId: $e');
      // Drop the optimistic change so the bar matches the server again, then
      // let the caller report the failure.
      state = updateReaction(
        state,
        messageId: messageId,
        emoji: emoji,
        userId: selfId,
        added: !reacted,
        currentUserId: selfId,
      );
      rethrow;
    }
  }

  Future<void> edit(String messageId, String content) async {
    final updated = await ref
        .read(apiClientProvider)
        .editMessage(messageId, content.trim());
    state = replaceMessage(state, updated);
  }

  Future<void> delete(String messageId) async {
    await ref.read(apiClientProvider).deleteMessage(messageId);
    state = state.where((m) => m.id != messageId).toList();
  }

  Future<void> setPinned(String messageId, bool pinned) async {
    await ref.read(apiClientProvider).setPinned(messageId, pinned);
    final index = state.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final next = [...state];
    next[index] = next[index].copyWith(isPinned: pinned);
    state = next;
  }
}

final channelMessagesProvider =
    NotifierProvider.family<ChannelMessagesNotifier, List<Message>, String>(
      ChannelMessagesNotifier.new,
    );