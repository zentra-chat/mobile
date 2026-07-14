import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/storage/instance_storage.dart';

// Persistent store for the user's backend instances and which one is active.
// Seeded from AppConfig.defaultInstance on first launch; the auth notifier
// loads/persists on startup so there is a single source of truth for storage.

final instanceStorageProvider =
    Provider<InstanceStorage>((ref) => SecureInstanceStorage());

final instancesProvider =
    StateNotifierProvider<InstancesNotifier, List<Instance>>(
  (ref) => InstancesNotifier(ref),
);

class InstancesNotifier extends StateNotifier<List<Instance>> {
  InstancesNotifier(this.ref) : super(const []);

  final Ref ref;

  void setAll(List<Instance> instances) {
    state = instances;
    _persist();
  }

  void add(Instance instance) {
    if (state.any((existing) => existing.url == instance.url)) return;
    state = [...state, instance];
    _persist();
  }

  void update(String id, Instance instance) {
    state = state.map((existing) => existing.id == id ? instance : existing).toList();
    _persist();
  }

  void remove(String id) {
    state = state.where((existing) => existing.id != id).toList();
    _persist();
  }

  void setOnline(String id, bool online) {
    state = state
        .map((existing) => existing.id == id
            ? existing.copyWith(
                isOnline: online,
                lastChecked: DateTime.now().toIso8601String(),
              )
            : existing)
        .toList();
    _persist();
  }

  void _persist() => ref.read(instanceStorageProvider).saveInstances(state);
}

final activeInstanceIdProvider =
    StateNotifierProvider<ActiveInstanceNotifier, String?>(
  (ref) => ActiveInstanceNotifier(ref),
);

class ActiveInstanceNotifier extends StateNotifier<String?> {
  ActiveInstanceNotifier(this.ref) : super(null);

  final Ref ref;

  void set(String? id) {
    state = id;
    ref.read(instanceStorageProvider).saveActiveId(id);
  }
}

// The instance the app currently talks to. Derived from the saved list and the
// active id, falling back to the configured default when nothing is selected.
final instanceProvider = Provider<Instance>((ref) {
  final instances = ref.watch(instancesProvider);
  final activeId = ref.watch(activeInstanceIdProvider);
  if (activeId != null) {
    final matches = instances.where((instance) => instance.id == activeId);
    if (matches.isNotEmpty) return matches.first;
  }
  return instances.isNotEmpty ? instances.first : AppConfig.defaultInstance;
});
