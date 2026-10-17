import 'user.dart';

/// A reaction summary on a message. Channel messages list the reactors in
/// `users`, direct messages only send the count.
class Reaction {
  final String emoji;
  final int count;
  final bool reacted;
  final List<String> users;

  const Reaction({
    required this.emoji,
    required this.count,
    required this.reacted,
    this.users = const [],
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      emoji: json['emoji'] as String,
      count: json['count'] as int,
      reacted: json['reacted'] as bool,
      users: [
        for (final user in json['users'] as List<dynamic>? ?? const [])
          user as String,
      ],
    );
  }
}

/// Shallow preview of the message a reply points at. The server sends only
/// these four fields, so this is deliberately not a [Message].
class MessageReply {
  final String id;
  final String content;
  final String authorId;
  final User author;

  const MessageReply({
    required this.id,
    required this.content,
    required this.authorId,
    required this.author,
  });

  factory MessageReply.fromJson(Map<String, dynamic> json) {
    return MessageReply(
      id: json['id'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      author: User.fromJson(json['author'] as Map<String, dynamic>),
    );
  }

  /// Direct message replies name the author field `sender`.
  factory MessageReply.fromDmJson(Map<String, dynamic> json) {
    return MessageReply(
      id: json['id'] as String,
      content: json['content'] as String,
      authorId: json['senderId'] as String,
      author: User.fromJson(json['sender'] as Map<String, dynamic>),
    );
  }

  /// The preview is blank when the original message could not be decrypted.
  String get summaryText =>
      content.isEmpty ? '[Message unavailable]' : content;
}

class Attachment {
  final String id;
  final String filename;
  final String? contentType;
  final int size;
  final String url;
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  const Attachment({
    required this.id,
    required this.filename,
    this.contentType,
    required this.size,
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      filename: json['filename'] as String,
      contentType: json['contentType'] as String?,
      size: json['size'] as int,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? siteName;
  final String? imageUrl;
  final String? faviconUrl;

  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.siteName,
    this.imageUrl,
    this.faviconUrl,
  });

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      siteName: json['siteName'] as String?,
      imageUrl: json['imageUrl'] as String?,
      faviconUrl: json['faviconUrl'] as String?,
    );
  }
}

class Message {
  final String id;
  final String channelId;
  final String authorId;
  final String? content;
  final String? replyToId;
  final bool isEdited;
  final bool isPinned;
  final List<Reaction> reactions;
  final User author;
  final List<Attachment> attachments;
  final List<LinkPreview> linkPreviews;
  final MessageReply? replyTo;
  final String createdAt;
  final String updatedAt;

  const Message({
    required this.id,
    required this.channelId,
    required this.authorId,
    this.content,
    this.replyToId,
    required this.isEdited,
    required this.isPinned,
    required this.reactions,
    required this.author,
    required this.attachments,
    required this.linkPreviews,
    this.replyTo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      channelId: json['channelId'] as String,
      authorId: json['authorId'] as String,
      content: json['content'] as String?,
      replyToId: json['replyToId'] as String?,
      isEdited: json['isEdited'] as bool,
      isPinned: json['isPinned'] as bool,
      reactions: [
        for (final reaction in json['reactions'] as List<dynamic>? ?? const [])
          Reaction.fromJson(reaction as Map<String, dynamic>),
      ],
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      attachments: [
        for (final item in json['attachments'] as List<dynamic>? ?? const [])
          Attachment.fromJson(item as Map<String, dynamic>),
      ],
      linkPreviews: [
        for (final item in json['linkPreviews'] as List<dynamic>? ?? const [])
          LinkPreview.fromJson(item as Map<String, dynamic>),
      ],
      replyTo: json['replyTo'] == null
          ? null
          : MessageReply.fromJson(json['replyTo'] as Map<String, dynamic>),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Message copyWith({
    String? content,
    bool? isEdited,
    bool? isPinned,
    List<Reaction>? reactions,
    List<Attachment>? attachments,
    List<LinkPreview>? linkPreviews,
  }) {
    return Message(
      id: id,
      channelId: channelId,
      authorId: authorId,
      content: content ?? this.content,
      replyToId: replyToId,
      isEdited: isEdited ?? this.isEdited,
      isPinned: isPinned ?? this.isPinned,
      reactions: reactions ?? this.reactions,
      author: author,
      attachments: attachments ?? this.attachments,
      linkPreviews: linkPreviews ?? this.linkPreviews,
      replyTo: replyTo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Single line summary used in the conversation list.
  String get summaryText {
    final text = content?.trim();
    if (text != null && text.isNotEmpty) return text;
    if (attachments.isNotEmpty) return '[Attachment message]';
    if (linkPreviews.isNotEmpty) return '[Link preview]';
    return '[Message unavailable]';
  }
}

/// What the composer is replying to. Kept separate from [MessageReply] because
/// the banner is built from a full message when the reply is being started.
class ReplyTarget {
  final String id;
  final String authorName;
  final String preview;

  const ReplyTarget({
    required this.id,
    required this.authorName,
    required this.preview,
  });
}

class SendMessageRequest {
  final String content;
  final String? replyToId;
  final List<String>? attachments;

  const SendMessageRequest({
    required this.content,
    this.replyToId,
    this.attachments,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      if (replyToId != null) 'replyToId': replyToId,
      if (attachments != null) 'attachments': attachments,
    };
  }
}