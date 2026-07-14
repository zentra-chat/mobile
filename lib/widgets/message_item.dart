import 'package:flutter/material.dart';

import '../data/models/index.dart';

class MessageRow extends StatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    this.previous,
    this.currentUserId,
  });

  final Message message;
  final Message? previous;
  final String? currentUserId;

  @override
  State<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<MessageRow> {
  bool _showTime = false;

  bool get _grouped {
    final prev = widget.previous;
    if (prev == null) return false;
    if (prev.authorId != widget.message.authorId) return false;
    final current = DateTime.parse(widget.message.createdAt);
    final before = DateTime.parse(prev.createdAt);
    return current.difference(before).inMinutes < 5;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = TimeOfDay.fromDateTime(
      DateTime.parse(widget.message.createdAt),
    );
    final author = widget.message.author;
    final grouped = _grouped;

    final avatar = CircleAvatar(
      radius: 18,
      backgroundImage: author.avatarUrl != null
          ? NetworkImage(author.avatarUrl!)
          : null,
      child: author.avatarUrl == null
          ? Text(
              author.effectiveName.isNotEmpty
                  ? author.effectiveName[0].toUpperCase()
                  : '?',
              style: theme.textTheme.labelSmall,
            )
          : null,
    );

    return InkWell(
      onTap: grouped ? () => setState(() => _showTime = !_showTime) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: grouped
                    ? (_showTime
                          ? Center(
                              child: Text(
                                time.format(context),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : null)
                    : avatar,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!grouped) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        children: [
                          Text(
                            author.effectiveName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time.format(context),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (widget.message.content != null)
                    Text(
                      widget.message.content!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ...widget.message.attachments.map(
                    (attachment) => _AttachmentTile(attachment: attachment),
                  ),
                  if (widget.message.isEdited)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '(edited)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = (attachment.contentType ?? '').startsWith('image/');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                attachment.url,
                width: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fileChip(theme),
              ),
            )
          : _fileChip(theme),
    );
  }

  Widget _fileChip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachment.filename,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
