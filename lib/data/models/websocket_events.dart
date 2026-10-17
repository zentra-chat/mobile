// Websocket event types and payloads, mirroring the Zentra gateway protocol.
// Frames are newline-delimited JSON objects; see websocket_client.dart.

import 'user.dart';

enum WebSocketEventType {
  ready,
  messageCreate,
  messageUpdate,
  messageDelete,
  dmMessageCreate,
  dmMessageUpdate,
  dmMessageDelete,
  dmReactionAdd,
  dmReactionRemove,
  typingStart,
  presenceUpdate,
  channelCreate,
  channelUpdate,
  channelDelete,
  communityUpdate,
  userUpdate,
  memberJoin,
  memberLeave,
  memberUpdate,
  reactionAdd,
  reactionRemove,
  notification,
  notificationRead,
  friendStateUpdate,
  voiceJoin,
  voiceLeave,
  voiceStateUpdate,
  voiceSignal,
  voiceError,
}

extension WebSocketEventTypeX on WebSocketEventType {
  /// The gateway names events in SCREAMING_SNAKE_CASE, so `DM_MESSAGE_CREATE`
  /// maps onto the lowerCamelCase enum value `dmMessageCreate`. Returns null
  /// for event names this client does not model, such as `HEARTBEAT_ACK`.
  static WebSocketEventType? fromString(String value) {
    final words = value.toLowerCase().split('_');
    final name = words.first +
        words
            .skip(1)
            .map((word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}')
            .join();

    for (final type in WebSocketEventType.values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

class WebSocketEvent {
  final WebSocketEventType type;
  final Map<String, dynamic> data;

  const WebSocketEvent({required this.type, required this.data});

  /// Returns null when the frame names an event this client does not model.
  static WebSocketEvent? fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    final type =
        rawType == null ? null : WebSocketEventTypeX.fromString(rawType);
    if (type == null) return null;

    return WebSocketEvent(
      type: type,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

class ReadyEvent {
  final FullUser user;
  final String sessionId;

  const ReadyEvent({required this.user, required this.sessionId});

  factory ReadyEvent.fromJson(Map<String, dynamic> json) {
    return ReadyEvent(
      user: FullUser.fromJson(json['user'] as Map<String, dynamic>),
      sessionId: json['sessionId'] as String,
    );
  }
}

class TypingEvent {
  final String channelId;
  final String userId;
  final User user;

  const TypingEvent({
    required this.channelId,
    required this.userId,
    required this.user,
  });

  factory TypingEvent.fromJson(Map<String, dynamic> json) {
    return TypingEvent(
      channelId: json['channelId'] as String,
      userId: json['userId'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class PresenceEvent {
  final String userId;
  final UserStatus status;
  final String? customStatus;

  const PresenceEvent({
    required this.userId,
    required this.status,
    this.customStatus,
  });

  factory PresenceEvent.fromJson(Map<String, dynamic> json) {
    return PresenceEvent(
      userId: json['userId'] as String,
      status: UserStatusX.fromString(json['status'] as String),
      customStatus: json['customStatus'] as String?,
    );
  }
}

/// `REACTION_ADD` and `REACTION_REMOVE` for channel messages.
class ChannelReactionEvent {
  final String channelId;
  final String messageId;
  final String userId;
  final String emoji;

  const ChannelReactionEvent({
    required this.channelId,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  factory ChannelReactionEvent.fromJson(Map<String, dynamic> json) {
    return ChannelReactionEvent(
      channelId: json['channelId'] as String,
      messageId: json['messageId'] as String,
      userId: json['userId'] as String,
      emoji: json['emoji'] as String,
    );
  }
}

/// `DM_REACTION_ADD` and `DM_REACTION_REMOVE`, which name the conversation.
class DmReactionEvent {
  final String conversationId;
  final String messageId;
  final String userId;
  final String emoji;

  const DmReactionEvent({
    required this.conversationId,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  factory DmReactionEvent.fromJson(Map<String, dynamic> json) {
    return DmReactionEvent(
      conversationId: json['conversationId'] as String,
      messageId: json['messageId'] as String,
      userId: json['userId'] as String,
      emoji: json['emoji'] as String,
    );
  }
}

class ChannelMessageDeleteEvent {
  final String channelId;
  final String messageId;

  const ChannelMessageDeleteEvent({
    required this.channelId,
    required this.messageId,
  });

  factory ChannelMessageDeleteEvent.fromJson(Map<String, dynamic> json) {
    return ChannelMessageDeleteEvent(
      channelId: json['channelId'] as String,
      messageId: json['messageId'] as String,
    );
  }
}

class DmMessageDeleteEvent {
  final String conversationId;
  final String messageId;

  const DmMessageDeleteEvent({
    required this.conversationId,
    required this.messageId,
  });

  factory DmMessageDeleteEvent.fromJson(Map<String, dynamic> json) {
    return DmMessageDeleteEvent(
      conversationId: json['conversationId'] as String,
      messageId: json['messageId'] as String,
    );
  }
}

/// The gateway reports notifications read in one of three shapes: for a whole
/// channel, for every notification, or for a single one.
class NotificationReadEvent {
  final String? channelId;
  final String? id;
  final bool all;

  const NotificationReadEvent({this.channelId, this.id, this.all = false});

  factory NotificationReadEvent.fromJson(Map<String, dynamic> json) {
    if (json['all'] == true) return const NotificationReadEvent(all: true);
    final id = json['id'] as String?;
    if (id != null) return NotificationReadEvent(id: id);
    return NotificationReadEvent(channelId: json['channelId'] as String);
  }
}