import 'user.dart';

class AuthResponse {
  final FullUser user;
  final String accessToken;
  final String refreshToken;
  final String expiresAt;
  final bool? requires2FA;

  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.requires2FA,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: FullUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
      requires2FA: json['requires2FA'] as bool?,
    );
  }
}

class LoginRequest {
  final String login;
  final String password;
  final String? totpCode;

  const LoginRequest({
    required this.login,
    required this.password,
    this.totpCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'login': login,
      'password': password,
      if (totpCode != null) 'totpCode': totpCode,
    };
  }
}

class RegisterRequest {
  final String username;
  final String email;
  final String password;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
    };
  }
}

class RegisterResponse {
  final bool requiresEmailVerification;
  final bool verificationSent;
  final String email;
  final String message;

  const RegisterResponse({
    required this.requiresEmailVerification,
    required this.verificationSent,
    required this.email,
    required this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return RegisterResponse(
      requiresEmailVerification: data['requiresEmailVerification'] as bool? ?? false,
      verificationSent: data['verificationSent'] as bool? ?? false,
      email: data['email'] as String? ?? '',
      message: data['message'] as String? ?? '',
    );
  }
}

// Persisted session data. This is the single source of truth for auth tokens
// and is written to secure storage on every change.
class Session {
  final FullUser user;
  final String accessToken;
  final String refreshToken;
  final String expiresAt;

  const Session({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory Session.fromAuth(AuthResponse auth) {
    return Session(
      user: auth.user,
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
      expiresAt: auth.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': {
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'avatarUrl': user.avatarUrl,
        'bannerUrl': user.bannerUrl,
        'bio': user.bio,
        'status': user.status.name,
        'customStatus': user.customStatus,
        'createdAt': user.createdAt,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'twoFactorEnabled': user.twoFactorEnabled,
        'isAdmin': user.isAdmin,
        'updatedAt': user.updatedAt,
      },
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt,
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      user: FullUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
    );
  }
}
