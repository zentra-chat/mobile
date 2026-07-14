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
    this.metadata = const {},
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
      type: json['type'] as String? ?? 'text',
      position: json['position'] as int? ?? 0,
      isNsfw: json['isNsfw'] as bool? ?? false,
      slowmodeSeconds: json['slowmodeSeconds'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
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
    Map<String, int> toMap(dynamic value) => value == null
        ? {}
        : Map<String, int>.from(
            (value as Map).map((k, v) => MapEntry(k as String, v as int)),
          );
    return UnreadCounts(
      unread: toMap(json['unread']),
      mentions: toMap(json['mentions']),
    );
  }
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
      position: json['position'] as int? ?? 0,
      createdAt: json['createdAt'] as String,
    );
  }
}

class ChannelTypeDefinition {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int capabilities;
  final Map<String, dynamic> defaultMetadata;
  final bool builtIn;
  final String? pluginId;
  final String createdAt;

  const ChannelTypeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.capabilities,
    required this.defaultMetadata,
    required this.builtIn,
    this.pluginId,
    required this.createdAt,
  });

  factory ChannelTypeDefinition.fromJson(Map<String, dynamic> json) {
    return ChannelTypeDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      capabilities: json['capabilities'] as int? ?? 0,
      defaultMetadata: json['defaultMetadata'] as Map<String, dynamic>? ?? {},
      builtIn: json['builtIn'] as bool? ?? false,
      pluginId: json['pluginId'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}
