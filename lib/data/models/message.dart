import 'user.dart';

class Reaction {
  final String emoji;
  final int count;
  final bool reacted;

  const Reaction({
    required this.emoji,
    required this.count,
    required this.reacted,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      emoji: json['emoji'] as String,
      count: json['count'] as int? ?? 0,
      reacted: json['reacted'] as bool? ?? false,
    );
  }
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
      size: json['size'] as int? ?? 0,
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
  final Message? replyTo;
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
      isEdited: json['isEdited'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      reactions: (json['reactions'] as List? ?? [])
          .map((reaction) => Reaction.fromJson(reaction as Map<String, dynamic>))
          .toList(),
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      attachments: (json['attachments'] as List? ?? [])
          .map((attachment) => Attachment.fromJson(attachment as Map<String, dynamic>))
          .toList(),
      linkPreviews: (json['linkPreviews'] as List? ?? [])
          .map((preview) => LinkPreview.fromJson(preview as Map<String, dynamic>))
          .toList(),
      replyTo: json['replyTo'] == null
          ? null
          : Message.fromJson(json['replyTo'] as Map<String, dynamic>),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
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
