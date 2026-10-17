import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/index.dart';
import 'avatar.dart';

/// Profile sheet shown when a mention, avatar or author name is tapped.
/// Matches the web client's profile card, minus the friend actions which have
/// no mobile equivalent yet.
Future<void> showUserCard(
  BuildContext context, {
  required User user,
  Color? nameColor,
  List<Role> roles = const [],
  VoidCallback? onMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _UserCard(
      user: user,
      nameColor: nameColor,
      roles: roles,
      onMessage: onMessage,
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    this.nameColor,
    this.roles = const [],
    this.onMessage,
  });

  final User user;
  final Color? nameColor;
  final List<Role> roles;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberSince = DateTime.tryParse(user.createdAt);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                width: double.infinity,
                child: RemoteImage(
                  url: user.bannerUrl,
                  fit: BoxFit.cover,
                  fallback: ColoredBox(
                    color: ZentraColors.accent,
                    child: Center(
                      child: Icon(
                        Icons.person_outline,
                        size: 32,
                        color: ZentraColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: RemoteAvatar(
                        url: user.avatarUrl,
                        label: user.effectiveName,
                        radius: 32,
                      ),
                    ),
                    Text(
                      user.effectiveName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: nameColor ?? theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZentraColors.textMuted,
                      ),
                    ),
                    if (roles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final role in roles)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: parseRoleColor(role.color) ??
                                      ZentraColors.border,
                                ),
                              ),
                              child: Text(
                                role.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: parseRoleColor(role.color) ??
                                      ZentraColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (user.customStatus != null &&
                        user.customStatus!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.customStatus!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        user.bio!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (onMessage != null) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onMessage!();
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Message'),
                        ),
                      ),
                    ],
                    if (memberSince != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Member since ${_formatDate(memberSince)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ZentraColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
