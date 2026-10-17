import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/layout.dart';
import '../config/theme.dart';
import '../data/models/index.dart' show UnreadCountsX;
import '../providers/data_providers.dart';
import '../providers/dm_providers.dart';
import '../providers/nav_provider.dart';
import '../providers/notifications_provider.dart';

class BottomRail extends ConsumerWidget {
  const BottomRail({super.key, required this.index, required this.onSelected});

  final int index;
  final void Function(int index) onSelected;

  static const List<_RailItem> _items = [
    _RailItem(
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum,
      label: 'Servers',
    ),
    _RailItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Direct Messages',
    ),
    _RailItem(
      icon: Icons.notifications_none,
      activeIcon: Icons.notifications,
      label: 'Notifications',
    ),
    _RailItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadNotifications = notifications.where((n) => !n.isRead).length;
    final unreadDms = ref
        .watch(dmConversationsProvider)
        .fold<int>(0, (total, c) => total + c.unreadCount);
    final communityId = ref.watch(selectedCommunityIdProvider);
    final unreadChannels = communityId == null
        ? 0
        : (ref.watch(channelUnreadProvider(communityId)).value?.totalUnread ?? 0);

    final badges = <int, int>{
      kServersTab: unreadChannels,
      kDmsTab: unreadDms,
      kNotificationsTab: unreadNotifications,
    };

    return Container(
      decoration: const BoxDecoration(
        color: ZentraColors.backgroundSecondary,
        border: Border(top: BorderSide(color: ZentraColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomRailHeight,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _RailButton(
                    item: _items[i],
                    active: i == index,
                    badge: badges[i] ?? 0,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final _RailItem item;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? ZentraColors.primary : ZentraColors.textSecondary;

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: active ? ZentraColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 7),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  active ? item.activeIcon : item.icon,
                  size: 24,
                  color: color,
                ),
                if (badge > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: ZentraColors.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
