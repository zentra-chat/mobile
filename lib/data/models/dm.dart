import 'message.dart';
import 'user.dart';

// Direct message payloads use different field names than channel messages, so
// they are mapped onto the shared Message model once here.

class RawDmMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageReply? replyTo;
  final bool isEdited;
  final List<Reaction> reactions;
  final List<Attachment> attachments;
  final List<LinkPreview> linkPreviews;
  final String createdAt;
  final String updatedAt;
  final User sender;

  const RawDmMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.replyTo,
    required this.isEdited,
    required this.reactions,
    required this.attachments,
    required this.linkPreviews,
    required this.createdAt,
    required this.updatedAt,
    required this.sender,
  });

  factory RawDmMessage.fromJson(Map<String, dynamic> json) {
    return RawDmMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      replyTo: json['replyTo'] == null
          ? null
          : MessageReply.fromDmJson(json['replyTo'] as Map<String, dynamic>),
      isEdited: json['isEdited'] as bool,
      reactions: [
        for (final reaction in json['reactions'] as List<dynamic>? ?? const [])
          Reaction.fromJson(reaction as Map<String, dynamic>),
      ],
      attachments: [
        for (final item in json['attachments'] as List<dynamic>? ?? const [])
          Attachment.fromJson(item as Map<String, dynamic>),
      ],
      linkPreviews: [
        for (final item in json['linkPreviews'] as List<dynamic>? ?? const [])
          LinkPreview.fromJson(item as Map<String, dynamic>),
      ],
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      sender: User.fromJson(json['sender'] as Map<String, dynamic>),
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
      participants: [
        for (final user in json['participants'] as List<dynamic>)
          User.fromJson(user as Map<String, dynamic>),
      ],
      lastMessage: json['lastMessage'] == null
          ? null
          : RawDmMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
      unreadCount: json['unreadCount'] as int,
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

  DMConversation copyWith({
    Message? lastMessage,
    int? unreadCount,
  }) {
    return DMConversation(
      id: id,
      participants: participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Everyone but the reader. Conversations are between two users, but the
  /// payload lists every participant including the reader. Null means the
  /// reader is unknown, so nobody is excluded.
  List<User> others(String? currentUserId) => [
    for (final user in participants)
      if (user.id != currentUserId) user,
  ];

  String title(String? currentUserId) {
    final names = others(currentUserId).map((user) => user.effectiveName);
    return names.isEmpty ? 'Direct Message' : names.join(', ');
  }
}

Message mapDmMessage(RawDmMessage message) {
  return Message(
    id: message.id,
    channelId: message.conversationId,
    authorId: message.senderId,
    content: message.content,
    isEdited: message.isEdited,
    isPinned: false,
    reactions: message.reactions,
    author: message.sender,
    attachments: message.attachments,
    linkPreviews: message.linkPreviews,
    replyTo: message.replyTo,
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