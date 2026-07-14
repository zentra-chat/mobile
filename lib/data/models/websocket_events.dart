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
  static WebSocketEventType fromString(String value) {
    final normalized = value.toLowerCase();
    return WebSocketEventType.values.firstWhere(
      (type) => type.name.toLowerCase() == normalized,
      orElse: () => WebSocketEventType.ready,
    );
  }
}

class WebSocketEvent {
  final WebSocketEventType type;
  final dynamic data;

  const WebSocketEvent({required this.type, required this.data});

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: WebSocketEventTypeX.fromString(json['type'] as String),
      data: json['data'],
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
      status: UserStatusX.fromString(json['status'] as String?),
      customStatus: json['customStatus'] as String?,
    );
  }
}

class ReactionEvent {
  final String channelId;
  final String messageId;
  final String userId;
  final String emoji;

  const ReactionEvent({
    required this.channelId,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  factory ReactionEvent.fromJson(Map<String, dynamic> json) {
    return ReactionEvent(
      channelId: json['channelId'] as String,
      messageId: json['messageId'] as String,
      userId: json['userId'] as String,
      emoji: json['emoji'] as String,
    );
  }
}

class MessageDeleteEvent {
  final String channelId;
  final String messageId;

  const MessageDeleteEvent({
    required this.channelId,
    required this.messageId,
  });

  factory MessageDeleteEvent.fromJson(Map<String, dynamic> json) {
    return MessageDeleteEvent(
      channelId: json['channelId'] as String,
      messageId: json['messageId'] as String,
    );
  }
}
