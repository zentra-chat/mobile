import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/models/index.dart';
import '../providers/auth_provider.dart';
import '../providers/api_provider.dart';
import '../providers/instance_provider.dart';

// Manage and switch between backend instances, mirroring the web client's
// instance modal. Instances are persisted; selecting one swaps the active
// session (each instance keeps its own login).
class InstancesScreen extends ConsumerStatefulWidget {
  const InstancesScreen({super.key});

  @override
  ConsumerState<InstancesScreen> createState() => _InstancesScreenState();
}

class _InstancesScreenState extends ConsumerState<InstancesScreen> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _checking = false;
  bool? _checkOk;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _checking = true;
      _checkOk = null;
    });
    final instance = Instance.fromUrl(url, name: _nameController.text);
    final ok = await ref.read(apiClientProvider).checkHealth(instance.url);
    if (mounted) setState(() => _checking = false);
    if (mounted) setState(() => _checkOk = ok);
  }

  Future<void> _add() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _checkOk != true) return;
    final notifier = ref.read(instancesProvider.notifier);
    final existing = notifier.state.where((i) => i.url == Instance.fromUrl(url).url);
    if (existing.isNotEmpty) {
      await ref.read(authProvider.notifier).switchInstance(existing.first.id);
    } else {
      final instance = Instance.fromUrl(
        url,
        name: _nameController.text,
        id: 'inst_${DateTime.now().microsecondsSinceEpoch}',
      );
      notifier.add(instance);
      await ref.read(authProvider.notifier).switchInstance(instance.id);
    }
    _urlController.clear();
    _nameController.clear();
    if (mounted) setState(() => _checkOk = null);
  }

  Future<void> _select(String id) async {
    await ref.read(authProvider.notifier).switchInstance(id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove(Instance instance) async {
    final instances = ref.read(instancesProvider);
    final activeId = ref.read(activeInstanceIdProvider);
    final notifier = ref.read(instancesProvider.notifier);
    if (instance.id == activeId && instances.length > 1) {
      final next = instances.firstWhere((i) => i.id != instance.id);
      await ref.read(authProvider.notifier).switchInstance(next.id);
    } else if (instance.id == activeId) {
      // Removing the only instance drops us to the login screen.
      await ref.read(authProvider.notifier).switchInstance(instance.id);
    }
    await ref.read(tokenStorageProvider).clear(instance.id);
    notifier.remove(instance.id);
  }

  @override
  Widget build(BuildContext context) {
    final instances = ref.watch(instancesProvider);
    final activeId = ref.watch(activeInstanceIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Instances')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Add Instance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Display name (optional)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Instance URL',
              hintText: 'https://zentra.example.com',
            ),
            onChanged: (_) => setState(() => _checkOk = null),
            onSubmitted: (_) => _check(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: _checking ? null : _check,
                child: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _checkOk == true ? _add : null,
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              if (_checkOk == true)
                const Icon(Icons.check_circle, color: Colors.green)
              else if (_checkOk == false)
                const Icon(Icons.error, color: Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          Text('Your Instances', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...instances.map((instance) {
            final isActive = instance.id == activeId;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: instance.iconUrl != null
                    ? NetworkImage(instance.iconUrl!)
                    : null,
                child: instance.iconUrl == null
                    ? Text(
                        instance.name.isNotEmpty
                            ? instance.name[0].toUpperCase()
                            : '?',
                      )
                    : null,
              ),
              title: Text(instance.name),
              subtitle: Text(instance.url),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.circle : Icons.circle_outlined,
                    size: 12,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  if (isActive)
                    const Text('Active')
                  else
                    TextButton(
                      onPressed: () => _select(instance.id),
                      child: const Text('Connect'),
                    ),
                  IconButton(
                    onPressed: () => _remove(instance),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove',
                  ),
                ],
              ),
              onTap: isActive ? null : () => _select(instance.id),
            );
          }),
        ],
      ),
    );
  }
}
