import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../data/models/index.dart';
import '../providers/auth_provider.dart';
import '../providers/dm_providers.dart';
import '../providers/nav_provider.dart';
import '../providers/api_provider.dart';
import '../providers/typing_provider.dart';
import '../widgets/avatar.dart';
import '../widgets/message_composer.dart';
import '../widgets/message_thread.dart';
import '../widgets/user_card.dart';

/// Direct messages: the conversation list, or the open conversation when one
/// is selected.
class DmScreen extends ConsumerWidget {
  const DmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationId = ref.watch(selectedConversationIdProvider);
    if (conversationId != null) {
      return _ConversationView(key: ValueKey(conversationId), id: conversationId);
    }
    return const _ConversationList();
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(dmConversationsProvider);
    final selfId = ref.watch(authProvider).session?.user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Direct Messages')),
      body: RefreshIndicator(
        onRefresh: ref.read(dmConversationsProvider.notifier).refresh,
        child: conversations.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No conversations yet. Open one from a profile card.',
                      style: TextStyle(color: ZentraColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: _ConversationAvatar(
                      participants: conversation.others(selfId),
                    ),
                    title: Text(
                      conversation.title(selfId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: conversation.lastMessage == null
                        ? null
                        : Text(
                            conversation.lastMessage!.summaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: conversation.unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            decoration: BoxDecoration(
                              color: ZentraColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ZentraColors.onBright,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => ref
                        .read(navProvider.notifier)
                        .selectConversation(conversation.id),
                  );
                },
              ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.participants});

  final List<User> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const RemoteAvatar(url: null, label: '?', radius: 20);
    }
    if (participants.length == 1) {
      final user = participants.first;
      return RemoteAvatar(
        url: user.avatarUrl,
        label: user.effectiveName,
        radius: 20,
      );
    }
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < participants.length && i < 2; i++)
            Positioned(
              left: i * 12,
              top: i * 12,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ZentraColors.background, width: 2),
                ),
                child: RemoteAvatar(
                  url: participants[i].avatarUrl,
                  label: participants[i].effectiveName,
                  radius: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationView extends ConsumerStatefulWidget {
  const _ConversationView({super.key, required this.id});

  final String id;

  @override
  ConsumerState<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<_ConversationView> {
  final _scrollController = ScrollController();
  final _threadKey = GlobalKey<MessageThreadState>();
  ReplyTarget? _replyTo;
  Message? _editing;

  static DMConversation? _find(
    List<DMConversation> conversations,
    String id,
  ) {
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _find(ref.watch(dmConversationsProvider), widget.id);
    final selfId = ref.watch(authProvider).session?.user.id;
    final participants = conversation == null
        ? const <User>[]
        : conversation.others(selfId);
    final title = conversation?.title(selfId) ?? 'Direct Message';

    String? userName(String userId) {
      for (final user in participants) {
        if (user.id == userId) return user.effectiveName;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: ref.read(navProvider.notifier).closeConversation,
          tooltip: 'Back to conversations',
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: MessageThread(
              key: _threadKey,
              messages: ref.watch(dmMessagesProvider(widget.id)),
              scrollController: _scrollController,
              currentUserId: selfId,
              loadOlder: () =>
                  ref.read(dmMessagesProvider(widget.id).notifier).loadOlder(),
              userName: userName,
              onAuthorTap: (author) => showUserCard(context, user: author),
              onMentionTap: (userId) {
                final user = participants.where((p) => p.id == userId);
                if (user.isEmpty) return;
                showUserCard(context, user: user.first);
              },
              onReply: (message) => setState(() {
                _editing = null;
                _replyTo = ReplyTarget(
                  id: message.id,
                  authorName: message.author.effectiveName,
                  preview: message.summaryText,
                );
              }),
              onJumpToReply: (reply) =>
                  _threadKey.currentState?.jumpToMessage(reply.id),
              onEdit: (message) => setState(() {
                _replyTo = null;
                _editing = message;
              }),
              onDelete: (message) => _delete(message),
              onReact: (messageId, emoji, reacted) =>
                  _toggleReaction(messageId, emoji, reacted),
              emptyLabel: 'No messages yet',
            ),
          ),
          _Composer(
            conversationId: widget.id,
            replyTo: _replyTo,
            editing: _editing,
            onCancelReply: () => setState(() => _replyTo = null),
            onCancelEdit: () => setState(() => _editing = null),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReaction(
    String messageId,
    String emoji,
    bool reacted,
  ) async {
    try {
      await ref
          .read(dmMessagesProvider(widget.id).notifier)
          .toggleReaction(messageId, emoji, reacted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not react: $e')),
      );
    }
  }

  Future<void> _delete(Message message) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete Message',
      message: 'This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(dmMessagesProvider(widget.id).notifier)
          .delete(message.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the message: $e')),
      );
    }
  }
}

class _Composer extends ConsumerWidget {
  const _Composer({
    required this.conversationId,
    required this.replyTo,
    required this.editing,
    required this.onCancelReply,
    required this.onCancelEdit,
  });

  final String conversationId;
  final ReplyTarget? replyTo;
  final Message? editing;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dmMessagesProvider(conversationId).notifier);
    final typing = ref.watch(typingNamesProvider(conversationId));

    return MessageComposer(
      typingNames: typing,
      replyTo: replyTo,
      editing: editing,
      onCancelReply: onCancelReply,
      onCancelEdit: onCancelEdit,
      onTyping: () => ref.read(websocketProvider).sendTyping(conversationId),
      onSend: (content, {replyToId, editing}) async {
        try {
          if (editing != null) {
            await notifier.edit(editing.id, content);
          } else {
            await notifier.send(content, replyToId: replyToId);
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send the message: $e')),
          );
          return;
        }
        onCancelReply();
        onCancelEdit();
      },
    );
  }
}