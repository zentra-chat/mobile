import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

class TypingUser {
  const TypingUser({
    required this.userId,
    required this.username,
    required this.at,
  });

  final String userId;
  final String username;
  final DateTime at;
}

/// Gateway typing events arrive without a repeat marker, so entries expire on
/// their own the way the web client's five second window does.
class TypingNotifier extends Notifier<Map<String, Map<String, TypingUser>>> {
  static const Duration timeout = Duration(seconds: 5);

  late final StreamSubscription<WebSocketEvent> _subscription;
  Timer? _sweep;

  @override
  Map<String, Map<String, TypingUser>> build() {
    _subscription = ref.read(websocketProvider).events.listen(_handleEvent);
    _sweep = Timer.periodic(const Duration(seconds: 1), (_) => _expire());
    ref.onDispose(() {
      _subscription.cancel();
      _sweep?.cancel();
    });
    return const {};
  }

  void _handleEvent(WebSocketEvent event) {
    if (event.type != WebSocketEventType.typingStart) return;
    try {
      final data = TypingEvent.fromJson(event.data);
      if (data.channelId.isEmpty || data.userId.isEmpty) return;
      final entry = TypingUser(
        userId: data.userId,
        username: data.user.username,
        at: DateTime.now(),
      );
      state = {
        ...state,
        data.channelId: {...(state[data.channelId] ?? const {}), data.userId: entry},
      };
    } catch (e) {
      debugPrint('Failed to handle typing event: $e');
    }
  }

  void _expire() {
    final cutoff = DateTime.now().subtract(timeout);
    var changed = false;
    final next = <String, Map<String, TypingUser>>{};
    for (final entry in state.entries) {
      final live = <String, TypingUser>{
        for (final user in entry.value.entries)
          if (user.value.at.isAfter(cutoff)) user.key: user.value,
      };
      if (live.length != entry.value.length) {
        changed = true;
      }
      if (live.isNotEmpty) {
        next[entry.key] = live;
      } else if (entry.value.isNotEmpty) {
        changed = true;
      }
    }
    if (changed) state = next;
  }

  void clear(String channelId) {
    if (state.containsKey(channelId)) state = {...state}..remove(channelId);
  }
}

final typingProvider =
    NotifierProvider<TypingNotifier, Map<String, Map<String, TypingUser>>>(
      TypingNotifier.new,
    );

/// Names of other people typing in a stream, in the order the gateway
/// reported them.
final typingNamesProvider = Provider.family<List<String>, String>((ref, streamId) {
  final selfId = ref.watch(authProvider).session?.user.id;
  final users = ref.watch(typingProvider)[streamId]?.values ?? const <TypingUser>[];
  return [
    for (final user in users)
      if (user.userId != selfId) user.username,
  ];
});