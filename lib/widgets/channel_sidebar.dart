import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../data/models/index.dart' show Channel, UnreadCounts, UnreadCountsX;
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import 'channel_admin.dart' as channel_admin;

class ChannelSidebar extends ConsumerStatefulWidget {
  const ChannelSidebar({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.selectedChannelId,
    required this.onChannelSelected,
    required this.onDismiss,
  });

  final String communityId;
  final String communityName;
  final String? selectedChannelId;
  final void Function(String channelId) onChannelSelected;
  final VoidCallback onDismiss;

  @override
  ConsumerState<ChannelSidebar> createState() => _ChannelSidebarState();
}

class _ChannelSidebarState extends ConsumerState<ChannelSidebar> {
  // Category keys used to keep collapsed sections collapsed. An empty string
  // stands for the uncategorized section.
  final Set<String> _collapsed = {};

  /// Whether the active user can manage folders and channels. Limited to the
  /// community owner since the app does not yet fetch role permissions.
  bool get _canManage {
    final userId = ref.watch(authProvider).session?.user.id;
    final communities = ref.watch(communitiesProvider).value;
    if (userId == null || communities == null) return false;
    for (final community in communities) {
      if (community.id == widget.communityId) {
        return community.ownerId == userId;
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(ChannelSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.communityId != widget.communityId) {
      _collapsed.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManage;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ZentraColors.surface,
        border: Border(right: BorderSide(color: ZentraColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _SidebarHeader(
              name: widget.communityName,
              onTap: widget.onDismiss,
              trailing: canManage
                  ? IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => channel_admin.showCreateMenu(
                        context,
                        ref,
                        widget.communityId,
                      ),
                      tooltip: 'Create Channel or Folder',
                    )
                  : null,
            ),
            Expanded(child: _buildChannelList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelList(BuildContext context) {
    final theme = Theme.of(context);
    final channels = ref.watch(channelsProvider(widget.communityId));
    final categories = ref.watch(categoriesProvider(widget.communityId));
    final counts = ref.watch(channelUnreadProvider(widget.communityId)).value;
    final canManage = _canManage;

    return channels.when(
      data: (list) {
        final byFolder = <String, List<Channel>>{};
        for (final channel in list) {
          final folderId = channel.categoryId ?? '';
          byFolder.putIfAbsent(folderId, () => []).add(channel);
        }
        for (final group in byFolder.values) {
          group.sort((a, b) => a.position.compareTo(b.position));
        }

        final children = <Widget>[];

        final uncategorized = byFolder[''];
        if (uncategorized != null && uncategorized.isNotEmpty) {
          children.addAll(
            _foldSection(
              key: const ValueKey('uncategorized'),
              name: 'Channels',
              collapsedKey: '',
              canManage: canManage,
              items: uncategorized,
              counts: counts,
              onCreateChannel: () =>
                  channel_admin.createChannel(context, ref, widget.communityId),
            ),
          );
        }

        for (final category in categories.value ?? []) {
          children.addAll(
            _foldSection(
              key: ValueKey('category-${category.id}'),
              name: category.name,
              collapsedKey: category.id,
              canManage: canManage,
              items: byFolder[category.id] ?? [],
              counts: counts,
              onCreateChannel: () => channel_admin.createChannel(
                context,
                ref,
                widget.communityId,
                folderId: category.id,
              ),
              onSectionLongPress: canManage
                  ? () => channel_admin.showFolderActions(
                      context,
                      ref,
                      widget.communityId,
                      category,
                    )
                  : null,
            ),
          );
        }

        if (children.isEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 32, 16, 0),
              child: Text(
                'No channels yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ZentraColors.textMuted,
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
          children: children,
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) {
        debugPrint('Failed to load channels: $e');
        return const Center(
          child: Text(
            'Failed to load channels',
            style: TextStyle(color: ZentraColors.textMuted),
          ),
        );
      },
    );
  }

  List<Widget> _foldSection({
    required Key key,
    required String name,
    required String collapsedKey,
    required bool canManage,
    required List<Channel> items,
    required UnreadCounts? counts,
    required VoidCallback onCreateChannel,
    VoidCallback? onSectionLongPress,
  }) {
    final children = <Widget>[
      _SectionHeader(
        key: key,
        name: name,
        collapsed: _collapsed.contains(collapsedKey),
        onToggle: () => _toggle(collapsedKey),
        onLongPress: onSectionLongPress,
        trailing: canManage
            ? IconButton(
                icon: const Icon(Icons.add, size: 16),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: onCreateChannel,
                tooltip: 'Create Channel',
              )
            : null,
      ),
    ];

    if (_collapsed.contains(collapsedKey)) return children;

    children.addAll(
      items.map((channel) {
        return _ChannelRow(
          channel: channel,
          selected: channel.id == widget.selectedChannelId,
          unreadCount: counts?.unreadFor(channel.id) ?? 0,
          mentionCount: counts?.mentionsFor(channel.id) ?? 0,
          onTap: () => widget.onChannelSelected(channel.id),
          onLongPress: canManage && onSectionLongPress != null
              ? () => channel_admin.moveChannel(
                  context,
                  ref,
                  widget.communityId,
                  channel,
                )
              : null,
        );
      }),
    );

    return children;
  }

  void _toggle(String key) {
    setState(() {
      if (!_collapsed.remove(key)) {
        _collapsed.add(key);
      }
    });
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.name,
    required this.onTap,
    this.trailing,
  });

  final String name;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 8, right: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ZentraColors.border)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.expand_more,
                size: 18,
                color: ZentraColors.textSecondary,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ZentraColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.name,
    required this.collapsed,
    required this.onToggle,
    required this.trailing,
    this.onLongPress,
  });

  final String name;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget? trailing;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      onLongPress: onLongPress,
      child: Container(
        height: 28,
        padding: const EdgeInsets.only(left: 8, right: 6),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 14,
              color: ZentraColors.textMuted,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700,
                  color: ZentraColors.textMuted,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.selected,
    required this.unreadCount,
    required this.mentionCount,
    required this.onTap,
    this.onLongPress,
  });

  final Channel channel;
  final bool selected;
  final int unreadCount;
  final int mentionCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final unread = !selected && unreadCount > 0;
    final color = selected || unread
        ? ZentraColors.textPrimary
        : ZentraColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? ZentraColors.surfaceActive : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  child: unread
                      ? Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: ZentraColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                Text(
                  '#',
                  style: TextStyle(
                    fontSize: 16,
                    color: selected
                        ? ZentraColors.textSecondary
                        : ZentraColors.textMuted,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: color,
                      fontWeight: selected || unread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (mentionCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: ZentraColors.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mentionCount > 99 ? '99+' : '$mentionCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
