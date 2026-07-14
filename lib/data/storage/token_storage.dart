import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/index.dart';

// Persists the active session (tokens + user) securely on the device.
abstract class TokenStorage {
  Future<void> saveSession(Session session);
  Future<Session?> loadSession();
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  static const _sessionKey = 'zentra_session';

  final FlutterSecureStorage _storage;

  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveSession(Session session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<Session?> loadSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Session.fromJson(json);
    } catch (e) {
      // Corrupt or outdated session data; treat as logged out.
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}
