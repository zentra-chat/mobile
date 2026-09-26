import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import 'api_provider.dart';

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
// whenever a channel is opened.
final channelUnreadProvider =
    FutureProvider.family<UnreadCounts, String>((ref, communityId) async {
  final api = ref.read(apiClientProvider);
  return api.getChannelUnreadCounts(communityId);
});

// Holds the live message list for a single channel. Seeds from REST history
// then applies gateway events (create / update / delete) as they arrive.
class ChannelMessagesNotifier extends Notifier<List<Message>> {
  ChannelMessagesNotifier(this.channelId);

  final String channelId;
  late final StreamSubscription<WebSocketEvent> _subscription;

  @override
  List<Message> build() {
    _load();
    _subscription = ref.read(websocketProvider).events.listen(_handleEvent);
    ref.read(websocketProvider).subscribe(channelId);
    ref.onDispose(() {
      _subscription.cancel();
      ref.read(websocketProvider).unsubscribe(channelId);
    });
    return const [];
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final messages = await api.getMessages(channelId, limit: 50);
      state = messages.reversed.toList();
    } catch (e) {
      debugPrint('Failed to load messages for channel $channelId: $e');
    }
  }

  void _handleEvent(WebSocketEvent event) {
    try {
      switch (event.type) {
        case WebSocketEventType.messageCreate:
          final message = Message.fromJson(event.data as Map<String, dynamic>);
          if (message.channelId != channelId) return;
          if (state.any((m) => m.id == message.id)) return;
          state = [...state, message];
        case WebSocketEventType.messageUpdate:
          final message = Message.fromJson(event.data as Map<String, dynamic>);
          if (message.channelId != channelId) return;
          state = [
            for (final m in state)
              if (m.id == message.id) message else m
          ];
        case WebSocketEventType.messageDelete:
          final data = MessageDeleteEvent.fromJson(
            event.data as Map<String, dynamic>,
          );
          if (data.channelId != channelId) return;
          state = state.where((m) => m.id != data.messageId).toList();
        default:
          break;
      }
    } catch (e) {
      debugPrint('Failed to handle WebSocket event ${event.type}: $e');
    }
  }

  Future<void> send(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final api = ref.read(apiClientProvider);
    final message = await api.sendMessage(
      channelId,
      SendMessageRequest(content: trimmed),
    );
    if (!state.any((m) => m.id == message.id)) {
      state = [...state, message];
    }
    ref.read(websocketProvider).sendTyping(channelId);
  }

}

final channelMessagesProvider = NotifierProvider
    .family<ChannelMessagesNotifier, List<Message>, String>(
  ChannelMessagesNotifier.new,
);
