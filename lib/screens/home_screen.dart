import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart' show Channel, ChannelCategory;
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../widgets/message_item.dart' show MessageRow;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showChannels = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _selectCommunity(String id) async {
    ref.read(selectedCommunityIdProvider.notifier).set(id);
    ref.read(selectedChannelIdProvider.notifier).set(null);
    setState(() => _showChannels = true);
  }

  void _showCommunityList() {
    setState(() => _showChannels = false);
  }

  Future<void> _selectChannel(String communityId, String channelId) async {
    ref.read(selectedChannelIdProvider.notifier).set(channelId);
    try {
      await ref.read(apiClientProvider).markChannelRead(channelId);
    } catch (_) {
      // Non-fatal: read receipts are best effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityId = ref.watch(selectedCommunityIdProvider);
    final channelId = ref.watch(selectedChannelIdProvider);
    final userId = ref.watch(authProvider).session?.user.id;

    String? title;
    if (communityId != null && channelId != null) {
      title = ref.watch(channelsProvider(communityId)).maybeWhen(
        data: (list) {
          for (final channel in list) {
            if (channel.id == channelId) return '#${channel.name}';
          }
          return null;
        },
        orElse: () => null,
      );
    }
    title ??= ref.watch(communitiesProvider).maybeWhen(
      data: (list) {
        for (final community in list) {
          if (community.id == communityId) return community.name;
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text(title ?? 'Zentra')),
      drawer: Drawer(
        child: _showChannels && communityId != null
            ? ChannelList(
                communityId: communityId,
                selectedId: channelId,
                onBack: _showCommunityList,
                onSelected: (id) => _selectChannel(communityId, id),
              )
            : CommunityList(
                selectedId: communityId,
                onSelected: _selectCommunity,
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: channelId == null
                ? const Center(child: Text('Select a channel to start chatting'))
                : MessageList(
                    channelId: channelId,
                    currentUserId: userId,
                    scrollController: _scrollController,
                    onChanged: _scrollToBottom,
                  ),
          ),
          if (channelId != null)
            MessageComposer(
              channelId: channelId,
              controller: _messageController,
            ),
        ],
      ),
    );
  }
}

class CommunityList extends ConsumerWidget {
  const CommunityList({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(communitiesProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Communities', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...communities.when(
          data: (list) => list.map((community) {
            return ListTile(
              title: Text(community.name),
              selected: community.id == selectedId,
              onTap: () => onSelected(community.id),
            );
          }),
          loading: () => const [
            Center(child: CircularProgressIndicator()),
          ],
          error: (e, _) {
            debugPrint('Failed to load communities: $e');
            return [
              const ListTile(title: Text('Failed to load communities')),
            ];
          },
        ),
      ],
    );
  }
}

class ChannelList extends ConsumerStatefulWidget {
  const ChannelList({
    super.key,
    required this.communityId,
    required this.selectedId,
    required this.onBack,
    required this.onSelected,
  });

  final String communityId;
  final String? selectedId;
  final VoidCallback onBack;
  final void Function(String) onSelected;

  @override
  ConsumerState<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<ChannelList> {
  // Folder keys used to keep collapsed sections collapsed. An empty string
  // stands for the uncategorized section.
  final Set<String> _collapsed = {};

  String get _communityId => widget.communityId;

  /// Whether the active user can manage folders and channels. Limited to the
  /// community owner since the app does not yet fetch role permissions.
  bool get _canManage {
    final userId = ref.watch(authProvider).session?.user.id;
    final communities = ref.watch(communitiesProvider).value;
    if (userId == null || communities == null) return false;
    for (final community in communities) {
      if (community.id == _communityId) return community.ownerId == userId;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelsProvider(_communityId));
    final categories = ref.watch(categoriesProvider(_communityId));
    final canManage = _canManage;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Communities',
              ),
              const Expanded(
                child: Text(
                  'Channels',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () => _createFolder(context),
                  tooltip: 'Create Folder',
                ),
            ],
          ),
        ),
        ...channels.when(
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
              children.addAll(_foldSection(
                key: const ValueKey('uncategorized'),
                name: 'Channels',
                collapsedKey: '',
                canManage: canManage,
                items: uncategorized,
                onCreateChannel: () => _createChannel(context, null),
              ));
            }

            for (final category in categories.value ?? []) {
              final folderChannels = byFolder[category.id] ?? [];
              children.addAll(_foldSection(
                key: ValueKey('category-${category.id}'),
                name: category.name,
                collapsedKey: category.id,
                canManage: canManage,
                items: folderChannels,
                onCreateChannel: () => _createChannel(context, category.id),
                onSectionLongPress: canManage
                    ? () => _categoryActions(context, category)
                    : null,
              ));
            }

            return children;
          },
          loading: () => const [
            Center(child: CircularProgressIndicator()),
          ],
          error: (_, _) => const [
            ListTile(title: Text('Failed to load channels')),
          ],
        ),
      ],
    );
  }

  List<Widget> _foldSection({
    required Key key,
    required String name,
    required String collapsedKey,
    required bool canManage,
    required List<Channel> items,
    required VoidCallback? onCreateChannel,
    VoidCallback? onSectionLongPress,
  }) {
    final children = <Widget>[
      _SectionRow(
        key: key,
        name: name,
        collapsed: _collapsed.contains(collapsedKey),
        onToggle: () => _toggle(collapsedKey),
        trailingActions: [
          if (canManage && onCreateChannel != null)
            IconButton(
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: onCreateChannel,
              tooltip: 'Create Channel',
            ),
        ],
        onLongPress: onSectionLongPress,
      ),
    ];

    if (!_collapsed.contains(collapsedKey)) {
      children.addAll(items.map((channel) {
        return _ChannelRow(
          channel: channel,
          selected: channel.id == widget.selectedId,
          onTap: () {
            widget.onSelected(channel.id);
            Navigator.of(context).pop();
          },
          onLongPress:
              canManage && onSectionLongPress != null
                  ? () => _channelActions(context, channel)
                  : null,
        );
      }));
    }

    return children;
  }

  void _toggle(String key) {
    setState(() {
      if (!_collapsed.remove(key)) {
        _collapsed.add(key);
      }
    });
  }

  Future<void> _createFolder(BuildContext context) async {
    final name = await _promptForName(context, 'Create Folder', 'Name');
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).createCategory(_communityId, name.trim());
      ref.invalidate(categoriesProvider(_communityId));
    } catch (e) {
      debugPrint('Failed to create folder: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create folder')),
        );
      }
    }
  }

  Future<void> _categoryActions(
    BuildContext context,
    ChannelCategory category,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(category.name)),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Folder'),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Folder'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case 'rename':
        final name = await _promptForName(
          context,
          'Rename Folder',
          'Name',
          initial: category.name,
        );
        if (name == null || name.trim().isEmpty) return;
        try {
          await ref.read(apiClientProvider).updateCategory(
                category.id,
                name.trim(),
              );
          ref.invalidate(categoriesProvider(_communityId));
        } catch (e) {
          debugPrint('Failed to rename folder: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to rename folder')),
            );
          }
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Folder'),
              content: Text(
                'Delete "${category.name}"? Channels inside it will no longer be in a folder.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
        if (confirmed != true) return;
        try {
          await ref.read(apiClientProvider).deleteCategory(category.id);
          ref.invalidate(categoriesProvider(_communityId));
          ref.invalidate(channelsProvider(_communityId));
        } catch (e) {
          debugPrint('Failed to delete folder: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete folder')),
            );
          }
        }
    }
  }

  Future<void> _channelActions(
    BuildContext context,
    Channel channel,
  ) async {
    final targetFolderId = await _pickFolder(context, ref, channel);
    if (!context.mounted || targetFolderId == null) return;
    try {
      await ref.read(apiClientProvider).updateChannel(
            channel.id,
            categoryId: targetFolderId,
          );
      ref.invalidate(channelsProvider(_communityId));
    } catch (e) {
      debugPrint('Failed to move channel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to move channel')),
        );
      }
    }
  }

  Future<String?> _pickFolder(
    BuildContext context,
    WidgetRef ref,
    Channel channel,
  ) async {
    final categories = await ref.read(categoriesProvider(_communityId).future);
    if (!context.mounted) return null;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  'Move "#${channel.name}"',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...categories.map((category) {
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(category.name),
                  selected: channel.categoryId == category.id,
                  onTap: () => Navigator.of(sheetContext).pop(category.id),
                );
              }),
              if (_canManage && categories.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: const Text('New Folder'),
                  onTap: () => Navigator.of(sheetContext).pop('__new__'),
                ),
            ],
          ),
        );
      },
    );

    if (selected == '__new__') {
      if (!context.mounted) return null;
      final name = await _promptForName(context, 'New Folder', 'Name');
      if (name == null || name.trim().isEmpty) return null;
      try {
        final folder =
            await ref.read(apiClientProvider).createCategory(_communityId, name.trim());
        ref.invalidate(categoriesProvider(_communityId));
        return folder.id;
      } catch (e) {
        debugPrint('Failed to create folder: $e');
        return null;
      }
    }

    return selected;
  }

  Future<void> _createChannel(
    BuildContext context,
    String? folderId,
  ) async {
    final name = await _promptForName(context, 'New Channel', 'Name');
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).createChannel(
            _communityId,
            name: name.trim(),
            categoryId: folderId,
          );
      ref.invalidate(channelsProvider(_communityId));
    } catch (e) {
      debugPrint('Failed to create channel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create channel')),
        );
      }
    }
  }

  Future<String?> _promptForName(
    BuildContext context,
    String title,
    String label, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    return name;
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.name,
    required this.collapsed,
    required this.onToggle,
    required this.trailingActions,
    this.onLongPress,
  });

  final String name;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              name.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            ...trailingActions,
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
    required this.onTap,
    this.onLongPress,
  });

  final Channel channel;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.tag, size: 18),
      title: Text('# ${channel.name}'),
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class MessageList extends ConsumerWidget {
  const MessageList({
    super.key,
    required this.channelId,
    required this.currentUserId,
    required this.scrollController,
    required this.onChanged,
  });

  final String channelId;
  final String? currentUserId;
  final ScrollController scrollController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(channelMessagesProvider(channelId));
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageRow(
          message: message,
          previous: index > 0 ? messages[index - 1] : null,
          currentUserId: currentUserId,
        );
      },
    );
  }
}

class MessageComposer extends ConsumerWidget {
  const MessageComposer({
    super.key,
    required this.channelId,
    required this.controller,
  });

  final String channelId;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(ref),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _send(ref),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  void _send(WidgetRef ref) {
    final notifier = ref.read(channelMessagesProvider(channelId).notifier);
    notifier.send(controller.text);
    controller.clear();
  }
}
