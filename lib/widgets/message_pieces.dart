import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/index.dart';
import 'avatar.dart';

/// The card the web client shows for a URL found in a message. Tapping it
/// opens the link.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    required this.preview,
    required this.onTap,
  });

  final LinkPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = preview.imageUrl;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: ZentraColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZentraColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                RemoteImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  fallback: const SizedBox(height: 120),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preview.siteName case final site? when site.isNotEmpty)
                      Text(
                        site,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ZentraColors.textMuted,
                        ),
                      ),
                    if (preview.title case final title? when title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (preview.description case final text?
                        when text.isNotEmpty)
                      Text(
                        text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      preview.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ZentraColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// File and image attachments on a message.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentType = attachment.contentType ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: contentType.startsWith('image/')
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
                child: Image.network(
                  attachment.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fileChip(theme),
                ),
              ),
            )
          : _fileChip(theme),
    );
  }

  Widget _fileChip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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