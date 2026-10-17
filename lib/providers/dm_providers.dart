import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messages/message_ops.dart';
import '../data/models/index.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

class _StringNullNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

/// The direct message conversation currently open, if any.
final selectedConversationIdProvider =
    NotifierProvider<_StringNullNotifier, String?>(_StringNullNotifier.new);

/// Direct message conversations, newest activity first. The list stays live
/// through the gateway so a new message updates the preview and the unread
/// badge without a refetch.
class DmConversationsNotifier extends Notifier<List<DMConversation>> {
  late final StreamSubscription<WebSocketEvent> _subscription;

  @override
  List<DMConversation> build() {
    _load();
    _subscription = ref
        .read(websocketProvider)
        .events
        .listen(_handleEvent);
    ref.onDispose(_subscription.cancel);
    return const [];
  }

  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> _load() async {
    try {
      final conversations = await ref
          .read(apiClientProvider)
          .getDmConversations();
      state = conversations;
    } catch (e) {
      debugPrint('Failed to load DM conversations: $e');
    } finally {
      _loaded = true;
    }
  }

  Future<void> refresh() => _load();

  void _handleEvent(WebSocketEvent event) {
    try {
      final selfId = ref.read(authProvider).session?.user.id ?? '';
      switch (event.type) {
        case WebSocketEventType.dmMessageCreate:
          final message = mapDmMessage(RawDmMessage.fromJson(event.data));
          _applyMessage(message, selfId: selfId, isNew: true);
        case WebSocketEventType.dmMessageUpdate:
          final message = mapDmMessage(RawDmMessage.fromJson(event.data));
          _applyMessage(message, selfId: selfId, isNew: false);
        case WebSocketEventType.dmMessageDelete:
          final data = DmMessageDeleteEvent.fromJson(event.data);
          final index = state.indexWhere((c) => c.id == data.conversationId);
          if (index == -1) return;
          final next = [...state];
          next[index] = next[index].copyWith(
            lastMessage: next[index].lastMessage?.id == data.messageId
                ? null
                : next[index].lastMessage,
          );
          state = next;
        default:
          return;
      }
    } catch (e) {
      debugPrint('Failed to handle DM event ${event.type}: $e');
    }
  }

  void _applyMessage(
    Message message, {
    required String selfId,
    required bool isNew,
  }) {
    final index = state.indexWhere((c) => c.id == message.channelId);
    final isOpen = ref.read(selectedConversationIdProvider) == message.channelId;
    final isMine = message.authorId == selfId;

    if (index == -1) {
      // A conversation opened on another device, or a DM from someone new.
      unawaited(_reloadAfterUnknownConversation(message.channelId));
      return;
    }

    final existing = state[index];
    // Only a new message raises the unread count; an edit does not.
    final unread = !isNew || isOpen || isMine
        ? existing.unreadCount
        : existing.unreadCount + 1;
    final next = [...state];
    next[index] = existing.copyWith(
      lastMessage: message,
      unreadCount: unread,
    );
    next.sort((a, b) {
      final aTime = a.lastMessage?.createdAt ?? a.updatedAt;
      final bTime = b.lastMessage?.createdAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });
    state = next;
  }

  Future<void> _reloadAfterUnknownConversation(String conversationId) async {
    final before = state.length;
    await _load();
    if (state.length == before) {
      debugPrint('Unknown DM conversation $conversationId could not be loaded');
    }
  }

  void markRead(String conversationId) {
    final index = state.indexWhere((c) => c.id == conversationId);
    if (index == -1 || state[index].unreadCount == 0) return;
    final next = [...state];
    next[index] = next[index].copyWith(unreadCount: 0);
    state = next;
  }

  Future<DMConversation> openWith(User user) async {
    final conversation = await ref
        .read(apiClientProvider)
        .createDmConversation(user.id);
    if (!state.any((c) => c.id == conversation.id)) {
      state = [conversation, ...state];
    }
    return conversation;
  }
}

final dmConversationsProvider =
    NotifierProvider<DmConversationsNotifier, List<DMConversation>>(
      DmConversationsNotifier.new,
    );

/// Live message list for a direct message conversation.
class DmMessagesNotifier extends Notifier<List<Message>> {
  DmMessagesNotifier(this.conversationId);

  final String conversationId;
  late final StreamSubscription<WebSocketEvent> _subscription;

  bool _hasMore = true;
  bool _loadingOlder = false;
  Future<void>? _firstPage;

  bool get hasMore => _hasMore;
  bool get isLoadingOlder => _loadingOlder;

  @override
  List<Message> build() {
    _firstPage = _load();
    final socket = ref.read(websocketProvider);
    _subscription = socket.events.listen(_handleEvent);
    socket.subscribe(conversationId);
    ref.onDispose(() {
      _subscription.cancel();
      socket.unsubscribe(conversationId);
    });
    return const [];
  }

  Future<void> _load() async {
    try {
      final messages = await ref
          .read(apiClientProvider)
          .getDmMessages(conversationId, limit: kMessagePageSize);
      state = appendOlder(const [], messages, limit: 100);
      _hasMore = messages.length >= kMessagePageSize;
    } catch (e) {
      debugPrint('Failed to load DM messages for $conversationId: $e');
    }
  }

  Future<void> loadOlder() async {
    // Paging before the first page lands would page from the wrong cursor.
    await _firstPage;
    if (_loadingOlder || !_hasMore || state.isEmpty) return;
    _loadingOlder = true;
    try {
      final older = await ref.read(apiClientProvider).getDmMessages(
        conversationId,
        limit: kMessagePageSize,
        before: state.first.id,
      );
      _hasMore = older.length >= kMessagePageSize;
      state = appendOlder(state, older, limit: 100);
    } catch (e) {
      debugPrint('Failed to load older DM messages for $conversationId: $e');
    } finally {
      _loadingOlder = false;
    }
  }

  void _handleEvent(WebSocketEvent event) {
    try {
      final selfId = ref.read(authProvider).session?.user.id ?? '';
      switch (event.type) {
        case WebSocketEventType.dmMessageCreate:
          final message = mapDmMessage(RawDmMessage.fromJson(event.data));
          if (message.channelId != conversationId) return;
          if (state.any((m) => m.id == message.id)) return;
          state = [...state, message];
        case WebSocketEventType.dmMessageUpdate:
          final message = mapDmMessage(RawDmMessage.fromJson(event.data));
          if (message.channelId != conversationId) return;
          state = replaceMessage(state, message);
        case WebSocketEventType.dmMessageDelete:
          final data = DmMessageDeleteEvent.fromJson(event.data);
          if (data.conversationId != conversationId) return;
          state = state.where((m) => m.id != data.messageId).toList();
        case WebSocketEventType.dmReactionAdd:
          final data = DmReactionEvent.fromJson(event.data);
          if (data.conversationId != conversationId) return;
          state = updateReaction(
            state,
            messageId: data.messageId,
            emoji: data.emoji,
            userId: data.userId,
            added: true,
            currentUserId: selfId,
          );
        case WebSocketEventType.dmReactionRemove:
          final data = DmReactionEvent.fromJson(event.data);
          if (data.conversationId != conversationId) return;
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
      debugPrint('Failed to handle DM event ${event.type}: $e');
    }
  }

  Future<void> send(String content, {String? replyToId}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final message = await ref.read(apiClientProvider).sendDmMessage(
      conversationId,
      trimmed,
      replyToId: replyToId,
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
        await api.removeDmReaction(messageId, emoji);
      } else {
        await api.addDmReaction(messageId, emoji);
      }
    } catch (e) {
      debugPrint('Failed to toggle DM reaction $emoji on $messageId: $e');
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
    await ref.read(apiClientProvider).editDmMessage(messageId, content.trim());
    final index = state.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final next = [...state];
    next[index] = next[index].copyWith(content: content.trim(), isEdited: true);
    state = next;
  }

  Future<void> delete(String messageId) async {
    await ref.read(apiClientProvider).deleteDmMessage(messageId);
    state = state.where((m) => m.id != messageId).toList();
  }
}

final dmMessagesProvider =
    NotifierProvider.family<DmMessagesNotifier, List<Message>, String>(
      DmMessagesNotifier.new,
    );