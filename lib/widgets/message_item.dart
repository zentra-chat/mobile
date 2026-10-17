import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../data/models/index.dart';
import '../utils/links.dart';
import 'avatar.dart';
import 'emoji_picker.dart';
import 'message_content.dart';
import 'message_pieces.dart';
import 'reaction_bar.dart';

/// A single message row: reply preview, author, rendered content, attachments,
/// link previews and reactions. Everything interactive is handed in by the
/// caller so the same row serves both channel and direct message screens.
class MessageRow extends StatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    this.previous,
    this.currentUserId,
    this.userName,
    this.roleName,
    this.onMentionTap,
    this.onAuthorTap,
    this.onReply,
    this.onReact,
    this.onEdit,
    this.onDelete,
    this.onPin,
    this.onJumpToReply,
    this.showDateDivider = false,
    this.highlighted = false,
  });

  final Message message;
  final Message? previous;
  final String? currentUserId;

  /// Mention resolvers, supplied by whichever directory the stream uses.
  final String? Function(String userId)? userName;
  final String? Function(String roleId)? roleName;

  final void Function(String userId)? onMentionTap;
  final void Function(User author)? onAuthorTap;
  final VoidCallback? onReply;
  final void Function(String emoji, bool reacted)? onReact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onJumpToReply;
  final bool showDateDivider;
  final bool highlighted;

  @override
  State<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<MessageRow> {
  bool _showHoverTime = false;

  /// Same author within five minutes, the window the web client groups on.
  bool get _grouped {
    final previous = widget.previous;
    if (previous == null) return false;
    if (previous.authorId != widget.message.authorId) return false;
    final current = DateTime.tryParse(widget.message.createdAt);
    final before = DateTime.tryParse(previous.createdAt);
    if (current == null || before == null) return false;
    return current.difference(before).inMinutes < 5;
  }

  Message get _message => widget.message;

  bool get _isOwn => _message.authorId == widget.currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _grouped;
    final createdAt = DateTime.tryParse(_message.createdAt);
    final time = createdAt == null
        ? ''
        : TimeOfDay.fromDateTime(createdAt).format(context);
    final reply = _message.replyTo;
    final content = _message.content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showDateDivider)
          DateDivider(date: createdAt ?? DateTime.now()),
        GestureDetector(
          onTap: () {
            if (!grouped) return;
            setState(() => _showHoverTime = !_showHoverTime);
          },
          onLongPress: _showActions,
          child: Container(
            color: widget.highlighted
                ? ZentraColors.primary.withValues(alpha: 0.08)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: grouped
                        ? (_showHoverTime
                              ? Center(
                                  child: Text(
                                    time,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: ZentraColors.textMuted),
                                  ),
                                )
                              : const SizedBox.shrink())
                        : GestureDetector(
                            onTap: widget.onAuthorTap == null
                                ? null
                                : () => widget.onAuthorTap!(_message.author),
                            child: RemoteAvatar(
                              url: _message.author.avatarUrl,
                              label: _message.author.effectiveName,
                              radius: 18,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!grouped) _header(theme, time),
                      if (reply != null)
                        _ReplyPreview(
                          reply: reply,
                          onTap: widget.onJumpToReply,
                        ),
                      if (content != null)
                        MentionScope(
                          userName: widget.userName ?? (_) => null,
                          roleName: widget.roleName,
                          onMentionTap: widget.onMentionTap,
                          child: MessageContent(content: content),
                        ),
                      for (final attachment in _message.attachments)
                        AttachmentTile(attachment: attachment),
                      for (final preview in _message.linkPreviews)
                        LinkPreviewCard(
                          preview: preview,
                          onTap: () => openExternalLink(context, preview.url),
                        ),
                      if (_message.isEdited || widget.onReact != null)
                        _footer(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme, String time) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Flexible(
            child: GestureDetector(
              onTap: widget.onAuthorTap == null
                  ? null
                  : () => widget.onAuthorTap!(_message.author),
              child: Text(
                _message.author.effectiveName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: ZentraColors.textMuted,
            ),
          ),
          if (_message.isPinned) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.push_pin,
              size: 12,
              color: ZentraColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  /// Reactions wrap onto as many lines as they need, so this cannot be a Row:
/// that would hand the reaction Wrap an unbounded width and overflow.
Widget _footer(ThemeData theme) {
  final reactions = _message.reactions;
  return Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (_message.isEdited)
        Text(
          '(edited)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: ZentraColors.textMuted,
          ),
        ),
      if (reactions.isNotEmpty)
        ReactionBar(
          reactions: reactions,
          onToggle: (reaction) =>
              widget.onReact!(reaction.emoji, reaction.reacted),
        ),
    ],
  );
}

  Future<void> _showReactionPicker() async {
    final emoji = await pickEmoji(context);
    if (emoji == null) return;
    widget.onReact?.call(emoji, false);
  }

  Future<void> _showActions() async {
    final actions = <_MessageAction>[
      _MessageAction('Add Reaction', Icons.emoji_emotions_outlined, () {
        _showReactionPicker();
      }),
      if (widget.onReply != null)
        _MessageAction('Reply', Icons.reply, widget.onReply!),
      _MessageAction('Copy Text', Icons.copy, _copyContent),
      if (_isOwn && widget.onEdit != null)
        _MessageAction('Edit', Icons.edit_outlined, widget.onEdit!),
      if (widget.onPin != null)
        _MessageAction(
          _message.isPinned ? 'Unpin' : 'Pin',
          Icons.push_pin_outlined,
          widget.onPin!,
        ),
      if (_isOwn && widget.onDelete != null)
        _MessageAction('Delete', Icons.delete_outline, widget.onDelete!),
    ];

    final chosen = await showModalBottomSheet<_MessageAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () => Navigator.of(sheetContext).pop(action),
              ),
          ],
        ),
      ),
    );
    chosen?.onTap();
  }

  void _copyContent() {
    final content = _message.content;
    if (content == null) return;
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copied')));
  }
}

class _MessageAction {
  const _MessageAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class DateDivider extends StatelessWidget {
  const DateDivider({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              formatDateDivider(date),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ZentraColors.textMuted,
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

String formatDateDivider(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// True when the two messages fall on different calendar days, which is when
/// a date divider is drawn between them.
bool needsDateDivider(Message? previous, Message current) {
  if (previous == null) return true;
  final before = DateTime.tryParse(previous.createdAt);
  final now = DateTime.tryParse(current.createdAt);
  if (before == null || now == null) return true;
  return before.year != now.year ||
      before.month != now.month ||
      before.day != now.day;
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.reply, this.onTap});

  final MessageReply reply;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 14,
              margin: const EdgeInsets.only(top: 3, right: 6),
              decoration: BoxDecoration(
                color: ZentraColors.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            RemoteAvatar(
              url: reply.author.avatarUrl,
              label: reply.author.effectiveName,
              radius: 8,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${reply.author.effectiveName} ${reply.summaryText}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ZentraColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}