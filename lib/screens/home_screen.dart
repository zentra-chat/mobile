import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../data/models/index.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/directory_providers.dart';
import '../providers/nav_provider.dart';
import '../providers/typing_provider.dart';
import '../widgets/message_composer.dart';
import '../widgets/message_thread.dart';
import '../widgets/user_card.dart';

/// The channel view: thread, composer and channel header.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  final _threadKey = GlobalKey<MessageThreadState>();

  ReplyTarget? _replyTo;
  Message? _editing;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Consumes a pending jump request, once, after the thread has a target.
  void _consumePendingJump(String channelId) {
    final pending = ref.read(pendingMessageIdProvider);
    if (pending == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(selectedChannelIdProvider) != channelId) return;
      ref.read(pendingMessageIdProvider.notifier).set(null);
      _threadKey.currentState?.jumpToMessage(pending);
    });
  }

  void _startReply(Message message) {
    setState(() {
      _editing = null;
      _replyTo = ReplyTarget(
        id: message.id,
        authorName: message.author.effectiveName,
        preview: message.summaryText,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final communityId = ref.watch(selectedCommunityIdProvider);
    final channelId = ref.watch(selectedChannelIdProvider);
    final userId = ref.watch(authProvider).session?.user.id;
    final directory = communityId == null
        ? null
        : ref.watch(communityDirectoryProvider(communityId));
    if (channelId != null) _consumePendingJump(channelId);

    return Scaffold(
      appBar: AppBar(
        leading: communityId == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: ref.read(navProvider.notifier).closeChannel,
                tooltip: 'Back to channels',
              ),
        title: Text(_title(ref, communityId, channelId)),
        actions: [
          if (channelId != null)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: ref.read(navProvider.notifier).openSidebar,
              tooltip: 'Channels',
            ),
        ],
      ),
      body: channelId == null
          ? const _EmptyState()
          : Column(
              children: [
                Expanded(
                  child: MessageThread(
                    key: _threadKey,
                    messages: ref.watch(channelMessagesProvider(channelId)),
                    scrollController: _scrollController,
                    currentUserId: userId,
                    loadOlder: () =>
                        ref
                            .read(channelMessagesProvider(channelId).notifier)
                            .loadOlder(),
                    userName: directory?.userName,
                    roleName: directory?.roleName,
                    onAuthorTap: (author) => showUserCard(
                      context,
                      user: author,
                      onMessage: () => openDirectMessage(context, ref, author),
                    ),
                    onMentionTap: (userId) => _showMentionedUser(
                      context,
                      directory?.user(userId),
                    ),
                    onReply: _startReply,
                    onJumpToReply: (reply) =>
                        _threadKey.currentState?.jumpToMessage(reply.id),
                    onEdit: (message) => setState(() {
                      _replyTo = null;
                      _editing = message;
                    }),
                    onDelete: (message) =>
                        _delete(channelId, message),
                    onPin: (message) => _setPinned(channelId, message),
                    onReact: (messageId, emoji, reacted) =>
                        _toggleReaction(channelId, messageId, emoji, reacted),
                  ),
                ),
                _Composer(
                  channelId: channelId,
                  replyTo: _replyTo,
                  editing: _editing,
                  onSent: () => setState(() {
                    _replyTo = null;
                    _editing = null;
                  }),
                  onCancelReply: () => setState(() => _replyTo = null),
                  onCancelEdit: () => setState(() => _editing = null),
                ),
              ],
            ),
    );
  }

  void _showMentionedUser(BuildContext context, User? user) {
    if (user == null) return;
    showUserCard(
      context,
      user: user,
      onMessage: () => openDirectMessage(context, ref, user),
    );
  }

  String _title(WidgetRef ref, String? communityId, String? channelId) {
    if (communityId != null && channelId != null) {
      final channels = ref.watch(channelsProvider(communityId)).value;
      for (final channel in channels ?? const <Channel>[]) {
        if (channel.id == channelId) return '#${channel.name}';
      }
    }
    if (communityId != null) {
      final communities = ref.watch(communitiesProvider).value;
      for (final community in communities ?? const <Community>[]) {
        if (community.id == communityId) return community.name;
      }
    }
    return 'Zentra';
  }

  Future<void> _delete(String channelId, Message message) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete Message',
      message: 'This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(channelMessagesProvider(channelId).notifier)
          .delete(message.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Future<void> _toggleReaction(
    String channelId,
    String messageId,
    String emoji,
    bool reacted,
  ) async {
    try {
      await ref
          .read(channelMessagesProvider(channelId).notifier)
          .toggleReaction(messageId, emoji, reacted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not react: $e')));
    }
  }

  Future<void> _setPinned(String channelId, Message message) async {
    try {
      await ref
          .read(channelMessagesProvider(channelId).notifier)
          .setPinned(message.id, !message.isPinned);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pin: $e')));
    }
  }
}

class _Composer extends ConsumerWidget {
  const _Composer({
    required this.channelId,
    required this.replyTo,
    required this.editing,
    required this.onSent,
    required this.onCancelReply,
    required this.onCancelEdit,
  });

  final String channelId;
  final ReplyTarget? replyTo;
  final Message? editing;
  final VoidCallback onSent;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(channelMessagesProvider(channelId).notifier);
    final typing = ref.watch(typingNamesProvider(channelId));

    return MessageComposer(
      typingNames: typing,
      replyTo: replyTo,
      editing: editing,
      onCancelReply: onCancelReply,
      onCancelEdit: onCancelEdit,
      onTyping: () => ref.read(websocketProvider).sendTyping(channelId),
      onSend: (content, {replyToId, editing}) async {
        try {
          if (editing != null) {
            await notifier.edit(editing.id, content);
          } else {
            await notifier.send(content, replyToId: replyToId);
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not send: $e')));
          return;
        }
        onSent();
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tag, size: 40, color: ZentraColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Select a channel to start chatting',
            style: TextStyle(color: ZentraColors.textMuted),
          ),
        ],
      ),
    );
  }
}