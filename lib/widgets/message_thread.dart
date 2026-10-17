import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/index.dart';
import 'message_item.dart';

/// Scrolling list of messages, shared by the channel and direct message
/// views. The view owns paging and scrolling; every mutation is handed in by
/// the screen that owns the underlying provider.
class MessageThread extends StatefulWidget {
  const MessageThread({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.currentUserId,
    required this.loadOlder,
    this.userName,
    this.roleName,
    this.onAuthorTap,
    this.onMentionTap,
    this.onReply,
    this.onJumpToReply,
    this.onEdit,
    this.onDelete,
    this.onPin,
    this.onReact,
    this.emptyLabel = 'No messages yet',
  });

  final List<Message> messages;
  final ScrollController scrollController;
  final String? currentUserId;
  final Future<void> Function() loadOlder;

  /// Mention resolvers for the stream this thread belongs to.
  final String? Function(String userId)? userName;
  final String? Function(String roleId)? roleName;

  final void Function(User author)? onAuthorTap;
  final void Function(String userId)? onMentionTap;
  final void Function(Message message)? onReply;
  final void Function(MessageReply reply)? onJumpToReply;
  final void Function(Message message)? onEdit;
  final void Function(Message message)? onDelete;
  final void Function(Message message)? onPin;
  final void Function(String messageId, String emoji, bool reacted)? onReact;
  final String emptyLabel;

  @override
  State<MessageThread> createState() => MessageThreadState();
}

class MessageThreadState extends State<MessageThread> {
  String? _lastMessageId;
  String? _targetId;
  GlobalKey? _targetKey;

  /// Brings a message into view, paging in older history until it is loaded.
  /// Rows are variable height, so the position is estimated first and the
  /// real row refines it once built.
  Future<void> jumpToMessage(String messageId) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (widget.messages.any((message) => message.id == messageId)) break;
      await widget.loadOlder();
    }
    if (!mounted) return;
    final index = widget.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message could not be found')),
      );
      return;
    }

    setState(() {
      _targetId = messageId;
      _targetKey = GlobalKey();
    });

    if (widget.scrollController.hasClients) {
      final position = widget.scrollController.position;
      widget.scrollController.jumpTo(
        (position.maxScrollExtent * index / widget.messages.length)
            .clamp(0.0, position.maxScrollExtent),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(messageId));
  }

  void _ensureVisible(String messageId) {
    final target = _targetKey?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.4,
        duration: const Duration(milliseconds: 250),
      );
    }
    if (!mounted || _targetId != messageId) return;
    setState(() {
      _targetId = null;
      _targetKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          widget.emptyLabel,
          style: const TextStyle(color: ZentraColors.textMuted),
        ),
      );
    }

    // Follow the thread only when the newest message changes, so paging in
    // history does not yank the reader back to the bottom.
    final newestId = messages.last.id;
    if (_lastMessageId != newestId) {
      _lastMessageId = newestId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels <= 120) widget.loadOlder();
        return false;
      },
      child: ListView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final reply = message.replyTo;
          return MessageRow(
            key: message.id == _targetId ? _targetKey : null,
            message: message,
            previous: index > 0 ? messages[index - 1] : null,
            currentUserId: widget.currentUserId,
            userName: widget.userName,
            roleName: widget.roleName,
            showDateDivider: needsDateDivider(
              index > 0 ? messages[index - 1] : null,
              message,
            ),
            onAuthorTap: widget.onAuthorTap,
            onMentionTap: widget.onMentionTap,
            onReply: widget.onReply == null ? null : () => widget.onReply!(message),
            onJumpToReply: reply == null || widget.onJumpToReply == null
                ? null
                : () => widget.onJumpToReply!(reply),
            onEdit: widget.onEdit == null ? null : () => widget.onEdit!(message),
            onDelete: widget.onDelete == null ? null : () => widget.onDelete!(message),
            onPin: widget.onPin == null
                ? null
                : () => widget.onPin!(message),
            onReact: widget.onReact == null
                ? null
                : (emoji, reacted) => widget.onReact!(message.id, emoji, reacted),
          );
        },
      ),
    );
  }

  void _scrollToBottom() {
    if (!widget.scrollController.hasClients) return;
    widget.scrollController.jumpTo(
      widget.scrollController.position.maxScrollExtent,
    );
  }
}

/// Confirmation dialog used before destructive message actions.
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}