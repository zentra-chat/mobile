import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_client.dart';
import '../services/push_service.dart';
import 'api_provider.dart';
import 'auth_provider.dart';
import 'data_providers.dart';
import 'instance_provider.dart';
import 'nav_provider.dart';
import 'notifications_provider.dart';

// Held for the lifetime of the app. Registration has to survive the
// registration notifier being rebuilt, which happens on every session change.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    notifications: ref.watch(notificationServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Keeps the gateway's record of this device in step with the current session.
///
/// Registration belongs to the account rather than the install, so it follows
/// logins, logouts and instance switches instead of happening once at startup.
class PushRegistrationNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Rebuilds whenever the account or the backend instance changes, which is
    // what re-points the device at the right backend.
    ref.watch(authProvider);
    ref.watch(instanceProvider);

    Future.microtask(register);
    return false;
  }

  PushService get _push => ref.read(pushServiceProvider);

  // The registration currently in flight, so [unregister] can wait for it.
  Future<void>? _pending;

  /// Registers the device with the gateway, waiting for the token if Firebase
  /// has not produced one yet.
  ///
  /// Safe to call at any point in the session lifecycle. Without a session
  /// there is no account to attach the device to and the gateway has no way to
  /// authorise the call, so the call is dropped rather than retried.
  Future<void> register() async {
    _pending = _register();
    await _pending;
  }

  Future<void> _register() async {
    if (ref.read(authProvider).session == null) return;

    final token = await _push.firstToken;
    if (token == null) return;

    // The session can disappear while waiting on the token.
    if (ref.read(authProvider).session == null) return;

    try {
      await ref.read(apiClientProvider).registerPushDevice(
        platform: PushService.platformFor(defaultTargetPlatform),
        token: token,
      );
      state = true;
    } on ApiException catch (e) {
      debugPrint('Failed to register this device for push: ${e.message}');
    } catch (e) {
      debugPrint('Failed to register this device for push: $e');
    }
  }

  /// Removes the device token from the gateway. Called before signing out so a
  /// shared device stops delivering to the previous account.
  Future<void> unregister() async {
    // Reading the provider builds it, which schedules a registration of its
    // own. Letting it land after the removal would leave the device attached
    // to the account that is signing out.
    await _pending;

    final token = _push.token;
    if (token == null) return;
    try {
      await ref.read(apiClientProvider).unregisterPushDevice(token);
    } catch (e) {
      // The stored token is already inert once the session ends, so failing
      // here is not worth blocking the sign out.
      debugPrint('Failed to unregister this device for push: $e');
    }
  }
}

final pushRegistrationProvider =
    NotifierProvider<PushRegistrationNotifier, bool>(
  PushRegistrationNotifier.new,
);

/// Routes a tapped push to the conversation it belongs to.
class PushNavigationNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Opens the channel or DM named by the push payload, mirroring what tapping
  /// the same notification inside the app does.
  Future<void> open(Map<String, dynamic> data) async {
    // Opening a conversation is what reading it means.
    final notificationId = data['notificationId'];
    if (notificationId is String && notificationId.isNotEmpty) {
      await ref.read(notificationsProvider.notifier).markRead(notificationId);
    }

    final conversationId = data['conversationId'] as String?;
    if (conversationId != null && conversationId.isNotEmpty) {
      await ref.read(navProvider.notifier).selectConversation(conversationId);
      return;
    }

    final channelId = data['channelId'] as String?;
    final communityId = data['communityId'] as String?;
    if (channelId == null ||
        channelId.isEmpty ||
        communityId == null ||
        communityId.isEmpty) {
      return;
    }

    ref.read(selectedCommunityIdProvider.notifier).set(communityId);
    final messageId = data['messageId'] as String?;
    ref.read(pendingMessageIdProvider.notifier).set(
      messageId == null || messageId.isEmpty ? null : messageId,
    );
    await ref.read(navProvider.notifier).selectChannel(communityId, channelId);
  }
}

final pushNavigationProvider = NotifierProvider<PushNavigationNotifier, void>(
  PushNavigationNotifier.new,
);