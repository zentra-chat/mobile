import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/index.dart';

/// Row of reaction pills under a message. Adding a new reaction goes through
/// the message's long press menu, so this only ever shows what exists.
class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key, required this.reactions, required this.onToggle});

  final List<Reaction> reactions;
  final void Function(Reaction reaction) onToggle;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final reaction in reactions)
          _ReactionPill(reaction: reaction, onTap: () => onToggle(reaction)),
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.reaction, required this.onTap});

  final Reaction reaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: reaction.reacted
              ? ZentraColors.primary.withValues(alpha: 0.1)
              : ZentraColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: reaction.reacted ? ZentraColors.primary : ZentraColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              '${reaction.count}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: reaction.reacted
                    ? ZentraColors.primary
                    : ZentraColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}