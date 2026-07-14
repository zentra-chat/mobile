import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    ref.read(selectedCommunityIdProvider.notifier).state = id;
    ref.read(selectedChannelIdProvider.notifier).state = null;
    setState(() => _showChannels = true);
  }

  void _showCommunityList() {
    setState(() => _showChannels = false);
  }

  Future<void> _selectChannel(String communityId, String channelId) async {
    ref.read(selectedChannelIdProvider.notifier).state = channelId;
    try {
      await ref.read(apiClientProvider).markChannelRead(channelId);
    } catch (_) {
      // Non-fatal: read receipts are best effort.
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final communityId = ref.watch(selectedCommunityIdProvider);
    final channelId = ref.watch(selectedChannelIdProvider);
    final user = ref.watch(authProvider).session?.user;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(user?.effectiveName ?? 'Zentra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sign out',
          ),
        ],
      ),
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
                    currentUserId: user?.id,
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
          error: (e, _) => [const ListTile(title: Text('Failed to load communities'))],
        ),
      ],
    );
  }
}

class ChannelList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider(communityId));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                tooltip: 'Communities',
              ),
              const Text(
                'Channels',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
          ...channels.when(
            data: (list) => list.map((channel) {
              return ListTile(
                leading: const Icon(Icons.tag),
                title: Text('# ${channel.name}'),
                selected: channel.id == selectedId,
                onTap: () {
                  onSelected(channel.id);
                  Navigator.of(context).pop();
                },
              );
            }),
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
