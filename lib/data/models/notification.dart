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
  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => NotificationType.reply,
    );
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

  Notification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    String? communityId,
    String? channelId,
    String? messageId,
    String? actorId,
    Map<String, dynamic>? metadata,
    bool? isRead,
    String? createdAt,
    User? actor,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      communityId: communityId ?? this.communityId,
      channelId: channelId ?? this.channelId,
      messageId: messageId ?? this.messageId,
      actorId: actorId ?? this.actorId,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actor: actor ?? this.actor,
    );
  }

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: NotificationTypeX.fromString(json['type'] as String?),
      title: json['title'] as String,
      body: json['body'] as String?,
      communityId: json['communityId'] as String?,
      channelId: json['channelId'] as String?,
      messageId: json['messageId'] as String?,
      actorId: json['actorId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
      actor: json['actor'] == null
          ? null
          : User.fromJson(json['actor'] as Map<String, dynamic>),
    );
  }
}
