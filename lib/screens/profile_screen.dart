import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).session?.user;
    final effectiveName = user?.effectiveName ?? 'Unknown';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null
                  ? Text(
                      effectiveName.isNotEmpty
                          ? effectiveName[0].toUpperCase()
                          : '?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(effectiveName, style: Theme.of(context).textTheme.titleLarge),
            if (user?.email.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(user!.email, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
