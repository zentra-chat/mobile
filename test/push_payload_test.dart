import 'package:flutter_test/flutter_test.dart';
import 'package:zentra/providers/notifications_provider.dart';
import 'package:zentra/services/push_payload.dart';

/// Mirrors the data payload the gateway sends. The gateway omits anything it
/// has no value for, so empty fields are left out here too.
Map<String, dynamic> gatewayPushPayload({
  String? notificationId,
  String? title,
  String? body,
  String? channelId,
  String? conversationId,
  String? communityId,
  String? messageId,
  String? actorId,
}) {
  return {
    'title': ?title,
    'body': ?body,
    'notificationId': ?notificationId,
    'channelId': ?channelId,
    'conversationId': ?conversationId,
    'communityId': ?communityId,
    'messageId': ?messageId,
    'actorId': ?actorId,
  };
}

void main() {
  group('push target', () {
    test('a channel notification round trips through the tray payload', () {
      final payload = encodePushTarget(gatewayPushPayload(
        notificationId: 'notif-1',
        channelId: 'channel-1',
        communityId: 'community-1',
        messageId: 'message-1',
      ));

      final target = decodePushTarget(payload);
      expect(target, isNotNull);
      expect(target!['notificationId'], 'notif-1');
      expect(target['channelId'], 'channel-1');
      expect(target['communityId'], 'community-1');
      expect(target['messageId'], 'message-1');
    });

    test('a direct message carries a conversation instead of a channel', () {
      final payload = encodePushTarget(gatewayPushPayload(
        notificationId: 'notif-2',
        conversationId: 'conv-1',
      ));

      final target = decodePushTarget(payload);
      expect(target!['conversationId'], 'conv-1');
      expect(target.containsKey('channelId'), isFalse);
    });

    test('the fields a tap does not need are left out', () {
      final payload = encodePushTarget(gatewayPushPayload(
        notificationId: 'notif-3',
        title: 'You were mentioned',
        actorId: 'user-2',
      ));

      expect(payload, isNot(contains('title')));
      expect(payload, isNot(contains('actorId')));
    });

    test('a payload that is absent or unreadable does not route', () {
      expect(decodePushTarget(null), isNull);
      expect(decodePushTarget(''), isNull);
      expect(decodePushTarget('notif-1'), isNull);
      expect(decodePushTarget('[1, 2]'), isNull);
    });
  });

  group('redundant notifications', () {
    bool isRedundant({
      String? selfId = 'user-1',
      String? activeStreamId,
      String? actorId,
      String? streamId,
    }) {
      return isRedundantNotification(
        selfId: selfId,
        activeStreamId: activeStreamId,
        actorId: actorId,
        streamId: streamId,
      );
    }

    test('the user does not get notified about their own actions', () {
      expect(isRedundant(actorId: 'user-1'), isTrue);
      expect(isRedundant(actorId: 'user-2'), isFalse);
    });

    test('a conversation that is already open is left alone', () {
      expect(isRedundant(activeStreamId: 'channel-1', streamId: 'channel-1'),
          isTrue);
      expect(isRedundant(activeStreamId: 'channel-1', streamId: 'channel-2'),
          isFalse);
      expect(isRedundant(streamId: 'channel-1'), isFalse);
    });
  });
}