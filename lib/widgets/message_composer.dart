import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/index.dart';

/// The message input, shared by channel and direct message screens. Owns the
/// reply and edit banners so the caller only deals with sending.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    this.onTyping,
    this.typingNames = const [],
    this.replyTo,
    this.onCancelReply,
    this.editing,
    this.onCancelEdit,
    this.hintText = 'Message',
    this.autofocus = false,
  });

  /// Called with the trimmed text plus whichever of reply or edit applies.
  final void Function(String content, {String? replyToId, Message? editing})
  onSend;
  final VoidCallback? onTyping;

  /// Names of people typing in this stream. Rendered inside the composer's own
  /// background so it cannot read as a separate box above the input.
  final List<String> typingNames;

  final ReplyTarget? replyTo;
  final VoidCallback? onCancelReply;

  /// Content being edited, when the composer is in edit mode.
  final Message? editing;
  final VoidCallback? onCancelEdit;

  final String hintText;
  final bool autofocus;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _controller.text = widget.editing?.content ?? '';
    }
  }

  @override
  void didUpdateWidget(MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editing = widget.editing;
    if (editing == null) {
      if (oldWidget.editing != null) _controller.clear();
      return;
    }
    if (oldWidget.editing?.id != editing.id) {
      _controller
        ..text = editing.content ?? ''
        ..selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final editing = widget.editing;
    widget.onSend(
      text,
      replyToId: editing == null ? widget.replyTo?.id : null,
      editing: editing,
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: ZentraColors.backgroundSecondary,
        border: Border(top: BorderSide(color: ZentraColors.border)),
      ),
      // With the keyboard closed the bottom of the screen is the gesture
      // bar or the system buttons, so the input has to clear it. Once the
      // keyboard is up it already sits above it.
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        keyboardHeight > 0 ? 8 : safeBottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.typingNames.isNotEmpty) ...[
            _TypingLine(names: widget.typingNames),
            const SizedBox(height: 4),
          ],
          if (widget.editing != null)
            _Banner(
              label: 'Editing message',
              detail: widget.editing!.author.effectiveName,
              onClose: widget.onCancelEdit,
            )
          else if (widget.replyTo != null)
            _Banner(
              label: 'Replying to',
              detail: widget.replyTo!.authorName,
              preview: widget.replyTo!.preview,
              onClose: widget.onCancelReply,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  minLines: 1,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    hintText: widget.editing != null
                        ? 'Edit message'
                        : widget.hintText,
                  ),
                  onChanged: (_) => widget.onTyping?.call(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _submit,
                style: IconButton.styleFrom(
                  backgroundColor: ZentraColors.primary,
                  foregroundColor: ZentraColors.onBright,
                ),
                icon: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.label,
    required this.detail,
    this.preview,
    this.onClose,
  });

  final String label;
  final String detail;
  final String? preview;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 32,
            margin: const EdgeInsets.only(right: 10),
            color: ZentraColors.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ZentraColors.textMuted,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ZentraColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (preview != null)
                  Text(
                    preview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ZentraColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Typing row inside the composer. Only rendered while somebody is typing, so
/// it costs no space the rest of the time.
class _TypingLine extends StatelessWidget {
  const _TypingLine({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _label(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: ZentraColors.textMuted),
        ),
      ),
    );
  }

  String _label() {
    if (names.length == 1) return '${names.first} is typing...';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing...';
    return 'Several people are typing...';
  }
}
