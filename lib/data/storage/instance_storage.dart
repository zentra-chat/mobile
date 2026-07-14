import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart' as app;

// Persists the list of configured backend instances and which one is active.
// Stored in the device keychain/keystore so the user's instance list survives
// restarts; instance URLs are not secrets.
// The `app` prefix avoids clashing with the `Instance` class exported by the
// transitive vm_service dependency.
abstract class InstanceStorage {
  Future<List<app.Instance>> loadInstances();
  Future<void> saveInstances(List<app.Instance> instances);
  Future<String?> loadActiveId();
  Future<void> saveActiveId(String? id);
}

class SecureInstanceStorage implements InstanceStorage {
  static const _instancesKey = 'zentra_instances';
  static const _activeKey = 'zentra_active_instance';

  final FlutterSecureStorage _storage;

  SecureInstanceStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<List<app.Instance>> loadInstances() async {
    final raw = await _storage.read(key: _instancesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => app.Instance.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveInstances(List<app.Instance> instances) async {
    await _storage.write(
      key: _instancesKey,
      value: jsonEncode(
        instances.map((instance) => instance.toJson()).toList(),
      ),
    );
  }

  @override
  Future<String?> loadActiveId() async {
    final raw = await _storage.read(key: _activeKey);
    return raw == null || raw.isEmpty ? null : raw;
  }

  @override
  Future<void> saveActiveId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _activeKey);
    } else {
      await _storage.write(key: _activeKey, value: id);
    }
  }
}
