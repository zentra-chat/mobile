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
  final api = ref.watch(apiClientProvider);
  return api.getChannels(communityId);
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
