import 'user.dart';

class Community {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? bannerUrl;
  final String ownerId;
  final bool isPublic;
  final bool isOpen;
  final int memberCount;
  final String createdAt;
  final String updatedAt;

  const Community({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.bannerUrl,
    required this.ownerId,
    required this.isPublic,
    required this.isOpen,
    required this.memberCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      ownerId: json['ownerId'] as String,
      isPublic: json['isPublic'] as bool,
      isOpen: json['isOpen'] as bool,
      memberCount: json['memberCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class CommunityMember {
  final String userId;
  final String communityId;
  final String? nickname;
  final String joinedAt;
  final List<Role> roles;
  final User? user;

  const CommunityMember({
    required this.userId,
    required this.communityId,
    this.nickname,
    required this.joinedAt,
    this.roles = const [],
    this.user,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    return CommunityMember(
      userId: json['userId'] as String,
      communityId: json['communityId'] as String,
      nickname: json['nickname'] as String?,
      joinedAt: json['joinedAt'] as String,
      roles: (json['roles'] as List? ?? [])
          .map((role) => Role.fromJson(role as Map<String, dynamic>))
          .toList(),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class Role {
  final String id;
  final String communityId;
  final String name;
  final String? color;
  final int position;
  final int permissions;
  final bool isDefault;
  final String createdAt;

  const Role({
    required this.id,
    required this.communityId,
    required this.name,
    this.color,
    required this.position,
    required this.permissions,
    required this.isDefault,
    required this.createdAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      communityId: json['communityId'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      position: json['position'] as int? ?? 0,
      permissions: json['permissions'] as int? ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
    );
  }
}
