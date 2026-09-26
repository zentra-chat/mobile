import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/nav_provider.dart';
import '../widgets/message_item.dart' show MessageRow;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final communityId = ref.watch(selectedCommunityIdProvider);
    final channelId = ref.watch(selectedChannelIdProvider);
    final userId = ref.watch(authProvider).session?.user.id;

    String? title;
    if (communityId != null && channelId != null) {
      title = ref
          .watch(channelsProvider(communityId))
          .maybeWhen(
            data: (list) {
              for (final channel in list) {
                if (channel.id == channelId) return '#${channel.name}';
              }
              return null;
            },
            orElse: () => null,
          );
    }
    title ??= ref
        .watch(communitiesProvider)
        .maybeWhen(
          data: (list) {
            for (final community in list) {
              if (community.id == communityId) return community.name;
            }
            return null;
          },
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(
        leading: communityId == null
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => ref.read(navProvider.notifier).openSidebar(),
                tooltip: 'Channels',
              ),
        title: Text(title ?? 'Zentra'),
      ),
      body: Column(
        children: [
          Expanded(
            child: channelId == null
                ? _EmptyState(hasCommunity: communityId != null)
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasCommunity});

  final bool hasCommunity;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasCommunity ? Icons.tag : Icons.forum_outlined,
            size: 40,
            color: ZentraColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            hasCommunity
                ? 'Select a channel to start chatting'
                : 'No community selected',
            style: const TextStyle(color: ZentraColors.textMuted),
          ),
          if (!hasCommunity)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Pick one from the rail on the left',
                style: TextStyle(fontSize: 12, color: ZentraColors.textMuted),
              ),
            ),
        ],
      ),
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
