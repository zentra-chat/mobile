import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import 'api_provider.dart';

final communitiesProvider = FutureProvider<List<Community>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getMyCommunities();
});

final selectedCommunityIdProvider = StateProvider<String?>((ref) => null);
final selectedChannelIdProvider = StateProvider<String?>((ref) => null);

final channelsProvider =
    FutureProvider.family<List<Channel>, String>((ref, communityId) async {
  final api = ref.watch(apiClientProvider);
  return api.getChannels(communityId);
});

// Holds the live message list for a single channel. Seeds from REST history
// then applies gateway events (create / update / delete) as they arrive.
class ChannelMessagesNotifier extends StateNotifier<List<Message>> {
  ChannelMessagesNotifier(this.ref, this.channelId) : super(const []) {
    _load();
    // Listen to the gateway stream directly rather than via a StreamProvider,
    // which wraps a broadcast stream and can silently drop events.
    _subscription = ref.read(websocketProvider).events.listen(_handleEvent);
    ref.read(websocketProvider).subscribe(channelId);
  }

  final Ref ref;
  final String channelId;
  late final StreamSubscription<WebSocketEvent> _subscription;

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final messages = await api.getMessages(channelId, limit: 50);
      state = messages.reversed.toList();
    } catch (_) {
      // Leave the list empty; the UI surfaces the load error separately.
    }
  }

  void _handleEvent(WebSocketEvent event) {
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

  @override
  void dispose() {
    _subscription.cancel();
    ref.read(websocketProvider).unsubscribe(channelId);
    super.dispose();
  }
}

final channelMessagesProvider =
    StateNotifierProvider.family<ChannelMessagesNotifier, List<Message>, String>(
  (ref, channelId) => ChannelMessagesNotifier(ref, channelId),
);
