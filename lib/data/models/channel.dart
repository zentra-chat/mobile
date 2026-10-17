class Channel {
  final String id;
  final String communityId;
  final String? categoryId;
  final String name;
  final String? topic;
  final String type;
  final int position;
  final bool isNsfw;
  final int slowmodeSeconds;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String updatedAt;

  const Channel({
    required this.id,
    required this.communityId,
    this.categoryId,
    required this.name,
    this.topic,
    required this.type,
    required this.position,
    required this.isNsfw,
    required this.slowmodeSeconds,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      communityId: json['communityId'] as String,
      categoryId: json['categoryId'] as String?,
      name: json['name'] as String,
      topic: json['topic'] as String?,
      type: json['type'] as String,
      position: json['position'] as int,
      isNsfw: json['isNsfw'] as bool,
      slowmodeSeconds: json['slowmodeSeconds'] as int,
      metadata: json['metadata'] as Map<String, dynamic>,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class UnreadCounts {
  final Map<String, int> unread;
  final Map<String, int> mentions;

  const UnreadCounts({required this.unread, required this.mentions});

  factory UnreadCounts.fromJson(Map<String, dynamic> json) {
    return UnreadCounts(
      unread: _intMap(json['unread']),
      mentions: _intMap(json['mentions']),
    );
  }

  static Map<String, int> _intMap(dynamic json) => {
    for (final entry in (json as Map<String, dynamic>).entries)
      entry.key: entry.value as int,
  };
}

extension UnreadCountsX on UnreadCounts {
  int get totalUnread => unread.values.fold(0, (a, b) => a + b);
  int unreadFor(String channelId) => unread[channelId] ?? 0;
  int mentionsFor(String channelId) => mentions[channelId] ?? 0;
}

class ChannelCategory {
  final String id;
  final String communityId;
  final String name;
  final int position;
  final String createdAt;

  const ChannelCategory({
    required this.id,
    required this.communityId,
    required this.name,
    required this.position,
    required this.createdAt,
  });

  factory ChannelCategory.fromJson(Map<String, dynamic> json) {
    return ChannelCategory(
      id: json['id'] as String,
      communityId: json['communityId'] as String,
      name: json['name'] as String,
      position: json['position'] as int,
      createdAt: json['createdAt'] as String,
    );
  }
}