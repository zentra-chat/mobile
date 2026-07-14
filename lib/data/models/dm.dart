import 'message.dart';
import 'user.dart';

// Direct message payloads arrive from the backend in a slightly different shape
// than channel messages. These raw types are mapped into the shared Message
// model so the rest of the app can treat DMs and channel messages uniformly.

class RawDmMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final RawDmMessageReply? replyTo;
  final bool isEdited;
  final List<Reaction> reactions;
  final List<LinkPreview> linkPreviews;
  final String createdAt;
  final String updatedAt;
  final User? sender;
  final List<Attachment> attachments;

  const RawDmMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.replyTo,
    required this.isEdited,
    required this.reactions,
    required this.linkPreviews,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    required this.attachments,
  });

  factory RawDmMessage.fromJson(Map<String, dynamic> json) {
    return RawDmMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      replyTo: json['replyTo'] == null
          ? null
          : RawDmMessageReply.fromJson(json['replyTo'] as Map<String, dynamic>),
      isEdited: json['isEdited'] as bool? ?? false,
      reactions: (json['reactions'] as List? ?? [])
          .map((reaction) => Reaction.fromJson(reaction as Map<String, dynamic>))
          .toList(),
      linkPreviews: (json['linkPreviews'] as List? ?? [])
          .map((preview) => LinkPreview.fromJson(preview as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      sender: json['sender'] == null
          ? null
          : User.fromJson(json['sender'] as Map<String, dynamic>),
      attachments: (json['attachments'] as List? ?? [])
          .map((attachment) => Attachment.fromJson(attachment as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RawDmMessageReply {
  final String id;
  final String content;
  final String senderId;
  final User? sender;

  const RawDmMessageReply({
    required this.id,
    required this.content,
    required this.senderId,
    this.sender,
  });

  factory RawDmMessageReply.fromJson(Map<String, dynamic> json) {
    return RawDmMessageReply(
      id: json['id'] as String,
      content: json['content'] as String,
      senderId: json['senderId'] as String,
      sender: json['sender'] == null
          ? null
          : User.fromJson(json['sender'] as Map<String, dynamic>),
    );
  }
}

class RawDmConversation {
  final String id;
  final List<User> participants;
  final RawDmMessage? lastMessage;
  final int unreadCount;
  final String createdAt;
  final String updatedAt;

  const RawDmConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RawDmConversation.fromJson(Map<String, dynamic> json) {
    return RawDmConversation(
      id: json['id'] as String,
      participants: (json['participants'] as List? ?? [])
          .map((user) => User.fromJson(user as Map<String, dynamic>))
          .toList(),
      lastMessage: json['lastMessage'] == null
          ? null
          : RawDmMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
      unreadCount: json['unreadCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class DMConversation {
  final String id;
  final List<User> participants;
  final Message? lastMessage;
  final int unreadCount;
  final String createdAt;
  final String updatedAt;

  const DMConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });
}

Message mapDmMessage(RawDmMessage message) {
  return Message(
    id: message.id,
    channelId: message.conversationId,
    authorId: message.senderId,
    content: message.content,
    replyToId: null,
    isEdited: message.isEdited,
    isPinned: false,
    reactions: message.reactions,
    author: message.sender ?? User(id: message.senderId, username: 'Unknown', createdAt: message.createdAt),
    attachments: message.attachments,
    linkPreviews: message.linkPreviews,
    replyTo: message.replyTo == null
        ? null
        : Message(
            id: message.replyTo!.id,
            channelId: message.conversationId,
            authorId: message.replyTo!.senderId,
            content: message.replyTo!.content,
            author: message.replyTo!.sender ??
                User(id: message.replyTo!.senderId, username: 'Unknown', createdAt: message.createdAt),
            isEdited: false,
            isPinned: false,
            reactions: const [],
            attachments: const [],
            linkPreviews: const [],
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
          ),
    createdAt: message.createdAt,
    updatedAt: message.updatedAt,
  );
}

DMConversation mapDmConversation(RawDmConversation conversation) {
  return DMConversation(
    id: conversation.id,
    participants: conversation.participants,
    lastMessage: conversation.lastMessage == null
        ? null
        : mapDmMessage(conversation.lastMessage!),
    unreadCount: conversation.unreadCount,
    createdAt: conversation.createdAt,
    updatedAt: conversation.updatedAt,
  );
}
