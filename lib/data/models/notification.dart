import 'user.dart';

enum NotificationType {
  mentionUser,
  mentionRole,
  mentionEveryone,
  mentionHere,
  reply,
  dmMessage,
}

extension NotificationTypeX on NotificationType {
  static NotificationType fromString(String value) {
    return switch (value) {
      'mention_user' => NotificationType.mentionUser,
      'mention_role' => NotificationType.mentionRole,
      'mention_everyone' => NotificationType.mentionEveryone,
      'mention_here' => NotificationType.mentionHere,
      'dm_message' => NotificationType.dmMessage,
      'reply' => NotificationType.reply,
      _ => throw ArgumentError.value(value, 'type', 'unknown notification type'),
    };
  }
}

class Notification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String? body;
  final String? communityId;
  final String? channelId;
  final String? messageId;
  final String? actorId;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final String createdAt;
  final User? actor;

  const Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.communityId,
    this.channelId,
    this.messageId,
    this.actorId,
    required this.metadata,
    required this.isRead,
    required this.createdAt,
    this.actor,
  });

  /// Direct messages carry the conversation in metadata rather than a channel.
  String? get conversationId => metadata['conversationId'] as String?;

  Notification copyWith({bool? isRead}) {
    return Notification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      communityId: communityId,
      channelId: channelId,
      messageId: messageId,
      actorId: actorId,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actor: actor,
    );
  }

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: NotificationTypeX.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      communityId: json['communityId'] as String?,
      channelId: json['channelId'] as String?,
      messageId: json['messageId'] as String?,
      actorId: json['actorId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      isRead: json['isRead'] as bool,
      createdAt: json['createdAt'] as String,
      actor: json['actor'] == null
          ? null
          : User.fromJson(json['actor'] as Map<String, dynamic>),
    );
  }
}