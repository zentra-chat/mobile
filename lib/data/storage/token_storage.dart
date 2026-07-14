import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/index.dart';

// Persists the active session (tokens + user) securely on the device, scoped
// per instance so each backend keeps its own login.
abstract class TokenStorage {
  Future<void> saveSession(String instanceId, Session session);
  Future<Session?> loadSession(String instanceId);
  Future<void> clear(String instanceId);
}

class SecureTokenStorage implements TokenStorage {
  static String _sessionKey(String instanceId) => 'zentra_session_$instanceId';

  final FlutterSecureStorage _storage;

  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveSession(String instanceId, Session session) async {
    await _storage.write(
      key: _sessionKey(instanceId),
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<Session?> loadSession(String instanceId) async {
    final raw = await _storage.read(key: _sessionKey(instanceId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Session.fromJson(json);
    } catch (_) {
      // Corrupt or outdated session data; treat as logged out.
      await clear(instanceId);
      return null;
    }
  }

  @override
  Future<void> clear(String instanceId) async {
    await _storage.delete(key: _sessionKey(instanceId));
  }
}
