import 'package:flutter_test/flutter_test.dart';
import 'package:zentra/data/models/index.dart';

void main() {
  group('WebSocketEvent.fromJson', () {
    test('maps the SCREAMING_SNAKE_CASE names the gateway sends', () {
      final cases = {
        'MESSAGE_CREATE': WebSocketEventType.messageCreate,
        'MESSAGE_UPDATE': WebSocketEventType.messageUpdate,
        'MESSAGE_DELETE': WebSocketEventType.messageDelete,
        'DM_MESSAGE_CREATE': WebSocketEventType.dmMessageCreate,
        'DM_REACTION_ADD': WebSocketEventType.dmReactionAdd,
        'TYPING_START': WebSocketEventType.typingStart,
        'PRESENCE_UPDATE': WebSocketEventType.presenceUpdate,
        'NOTIFICATION_READ': WebSocketEventType.notificationRead,
        'FRIEND_STATE_UPDATE': WebSocketEventType.friendStateUpdate,
        'VOICE_STATE_UPDATE': WebSocketEventType.voiceStateUpdate,
        'READY': WebSocketEventType.ready,
      };

      cases.forEach((name, expected) {
        final event = WebSocketEvent.fromJson({
          'type': name,
          'data': <String, dynamic>{},
        });
        expect(event, isNotNull, reason: '$name should be recognised');
        expect(event!.type, expected);
      });
    });

    test('returns null for event names the client does not model', () {
      expect(
        WebSocketEvent.fromJson({
          'type': 'HEARTBEAT_ACK',
          'data': <String, dynamic>{'timestamp': 1},
        }),
        isNull,
      );
      expect(
        WebSocketEvent.fromJson({'data': <String, dynamic>{}}),
        isNull,
      );
    });

    test('keeps the data payload alongside the type', () {
      final event = WebSocketEvent.fromJson({
        'type': 'MESSAGE_CREATE',
        'data': {'id': 'm1', 'channelId': 'c1'},
      });

      expect(event!.data['id'], 'm1');
      expect(event.data['channelId'], 'c1');
    });
  });
}