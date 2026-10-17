import 'dart:async';

import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import '../services/notification_service.dart';
import 'api_provider.dart';
import 'auth_provider.dart';
import 'data_providers.dart';
import 'dm_providers.dart';
import 'lifecycle_provider.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationsNotifier extends Notifier<List<Notification>> {
  late final StreamSubscription<WebSocketEvent> _subscription;

  @override
  List<Notification> build() {
    _load();
    _subscription = ref
        .read(websocketProvider)
        .events
        .listen(_handleEvent);
    ref.onDispose(_subscription.cancel);
    return const [];
  }

  Future<void> _load() async {
    try {
      final notifications = await ref
          .read(apiClientProvider)
          .getNotifications(limit: 50);
      state = notifications;
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }
  }

  void _handleEvent(WebSocketEvent event) {
    try {
      switch (event.type) {
        case WebSocketEventType.notification:
          final notification = Notification.fromJson(event.data);
          if (notification.id.isEmpty) return;
          if (state.any((n) => n.id == notification.id)) return;
          state = [notification, ...state];
          _post(notification);
        case WebSocketEventType.notificationRead:
          _applyReadEvent(NotificationReadEvent.fromJson(event.data));
        default:
          return;
      }
    } catch (e) {
      debugPrint('Failed to handle notification event ${event.type}: $e');
    }
  }

  /// The gateway reports reads per channel, for one id, or for everything.
  void _applyReadEvent(NotificationReadEvent event) {
    if (event.all) {
      state = [for (final n in state) n.copyWith(isRead: true)];
      return;
    }
    final id = event.id;
    if (id != null) {
      state = [
        for (final n in state)
          if (n.id == id) n.copyWith(isRead: true) else n,
      ];
      return;
    }
    final channelId = event.channelId;
    if (channelId != null) {
      state = [
        for (final n in state)
          if (n.channelId == channelId) n.copyWith(isRead: true) else n,
      ];
    }
  }

  Future<void> _post(Notification notification) async {
    final redundant = isRedundantNotification(
      selfId: ref.read(authProvider).session?.user.id,
      activeStreamId: ref.read(activeStreamIdProvider),
      actorId: notification.actorId,
      streamId: notification.conversationId ?? notification.channelId,
    );
    // While the app is in front the notification is already on screen.
    if (redundant ||
        ref.read(lifecycleProvider) == AppLifecycleState.resumed) {
      return;
    }
    await ref.read(notificationServiceProvider).show(notification);
  }

  Future<void> markRead(String id) async {
    try {
      await ref.read(apiClientProvider).markNotificationRead(id);
    } catch (e) {
      debugPrint('Failed to mark notification $id as read: $e');
      return;
    }
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  Future<void> refresh() => _load();

  Future<void> markAllRead() async {
    try {
      await ref.read(apiClientProvider).markAllNotificationsRead();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
      return;
    }
    state = [for (final n in state) n.copyWith(isRead: true)];
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<Notification>>(
      NotificationsNotifier.new,
    );

/// The channel or direct message conversation currently on screen. Used to
/// decide whether an incoming notification is already being looked at.
final activeStreamIdProvider = Provider<String?>((ref) {
  final channelId = ref.watch(selectedChannelIdProvider);
  if (channelId != null) return channelId;
  return ref.watch(selectedConversationIdProvider);
});

/// Whether an incoming notification repeats what the user can already see: it
/// came from the user themselves, or it belongs to the conversation that is
/// open right now.
///
/// Shared by the websocket and push paths so the two cannot disagree about
/// what counts as redundant.
///
/// Takes the resolved values rather than a ref, since it is reached from both
/// a notifier and a widget.
bool isRedundantNotification({
  required String? selfId,
  required String? activeStreamId,
  String? actorId,
  String? streamId,
}) {
  if (actorId != null && actorId == selfId) return true;
  return activeStreamId != null && activeStreamId == streamId;
}
