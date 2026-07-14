import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import 'api_provider.dart';

class NotificationsNotifier extends Notifier<List<Notification>> {
  late final StreamSubscription<WebSocketEvent> _subscription;

  @override
  List<Notification> build() {
    _load();
    _subscription = ref.read(websocketProvider).events.listen(_handleEvent);
    ref.onDispose(_subscription.cancel);
    return [];
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final notifications = await api.getNotifications(limit: 50);
      state = notifications;
    } catch (_) {}
  }

  void _handleEvent(WebSocketEvent event) {
    switch (event.type) {
      case WebSocketEventType.notification:
        final notification =
            Notification.fromJson(event.data as Map<String, dynamic>);
        if (state.any((n) => n.id == notification.id)) return;
        state = [notification, ...state];
      case WebSocketEventType.notificationRead:
        final ids = event.data as List<dynamic>;
        final readIds = ids.map((e) => e as String).toSet();
        state = [
          for (final n in state)
            if (readIds.contains(n.id)) n.copyWith(isRead: true) else n,
        ];
      default:
        break;
    }
  }

  Future<void> markRead(String id) async {
    try {
      await ref.read(apiClientProvider).markNotificationRead(id);
      state = [
        for (final n in state)
          if (n.id == id) n.copyWith(isRead: true) else n,
      ];
    } catch (_) {}
  }

  Future<void> refresh() => _load();

  Future<void> markAllRead() async {
    try {
      await ref.read(apiClientProvider).markAllNotificationsRead();
      state = [for (final n in state) n.copyWith(isRead: true)];
    } catch (_) {}
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<Notification>>(
  NotificationsNotifier.new,
);
