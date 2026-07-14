enum UserStatus { online, away, busy, invisible, offline }

extension UserStatusX on UserStatus {
  static UserStatus fromString(String? value) {
    return UserStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => UserStatus.offline,
    );
  }
}

class User {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final UserStatus status;
  final String? customStatus;
  final String createdAt;

  const User({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.status = UserStatus.offline,
    this.customStatus,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      bio: json['bio'] as String?,
      status: UserStatusX.fromString(json['status'] as String?),
      customStatus: json['customStatus'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }

  String get effectiveName => displayName?.isNotEmpty == true ? displayName! : username;
}

class FullUser extends User {
  final String email;
  final bool emailVerified;
  final bool twoFactorEnabled;
  final bool isAdmin;
  final String updatedAt;

  const FullUser({
    required super.id,
    required super.username,
    super.displayName,
    super.avatarUrl,
    super.bannerUrl,
    super.bio,
    super.status,
    super.customStatus,
    required super.createdAt,
    required this.email,
    required this.emailVerified,
    required this.twoFactorEnabled,
    required this.isAdmin,
    required this.updatedAt,
  });

  factory FullUser.fromJson(Map<String, dynamic> json) {
    return FullUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      bio: json['bio'] as String?,
      status: UserStatusX.fromString(json['status'] as String?),
      customStatus: json['customStatus'] as String?,
      createdAt: json['createdAt'] as String,
      email: json['email'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? false,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
