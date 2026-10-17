import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Emoji the reaction picker offers, with the words people search for. This is
/// a deliberately short list of the reactions people actually reach for; the
/// full emoji catalogue is not worth bundling for a picker that mostly gets
/// used with three or four faces.
const Map<String, List<String>> _categories = {
  'Smileys': [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
    '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '😘',
    '😋', '😛', '🤪', '🤗', '🤔', '🤨', '😐', '😑',
    '😴', '😪', '😷', '🤒', '🤕', '🥳', '😎', '🤓',
  ],
  'Gestures': [
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
    '👋', '🙌', '👏', '🤝', '🙏', '💪', '🫡', '✍️',
  ],
  'Hearts': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💔', '💖', '💕', '💯'],
  'Objects': [
    '🔥', '✨', '⭐', '🎉', '🎊', '💡', '✅', '❌',
    '⚠️', '❗', '❓', '💤', '🚀', '👀', '🧠', '☕',
  ],
};

const Map<String, List<String>> _keywords = {
  '😀': ['grinning', 'smile', 'happy'],
  '😂': ['joy', 'laughing', 'tears'],
  '🤣': ['rofl', 'rolling'],
  '🙂': ['slight', 'ok'],
  '😉': ['wink'],
  '😍': ['heart', 'love', 'crush'],
  '🥰': ['love', 'warm'],
  '😴': ['sleep', 'tired', 'zzz'],
  '🥳': ['party', 'celebrate'],
  '😎': ['cool', 'sunglasses'],
  '👍': ['thumbs', 'up', 'like', 'approve', '+1'],
  '👎': ['thumbs', 'down', 'dislike', '-1'],
  '👌': ['ok', 'perfect', 'nice'],
  '✌️': ['peace', 'victory'],
  '🙏': ['pray', 'thanks', 'please'],
  '💪': ['strong', 'muscle'],
  '👀': ['eyes', 'looking', 'watch'],
  '❤️': ['heart', 'love'],
  '💔': ['broken', 'heart'],
  '🔥': ['fire', 'lit', 'hot'],
  '✨': ['sparkles', 'shiny'],
  '⭐': ['star'],
  '🎉': ['party', 'tada', 'celebrate'],
  '✅': ['check', 'done', 'tick'],
  '❌': ['cross', 'no', 'wrong'],
  '🚀': ['rocket', 'ship', 'launch'],
  '💯': ['hundred', 'score'],
  '☕': ['coffee', 'tea'],
  '🤔': ['think'],
};

/// Searchable grid of emoji. Returns the chosen character to [onSelect].
class EmojiPicker extends StatefulWidget {
  const EmojiPicker({super.key, required this.onSelect, this.height = 280});

  final ValueChanged<String> onSelect;
  final double height;

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, List<String>>> get _visible {
    final query = _query.trim().toLowerCase();
    final entries = <MapEntry<String, List<String>>>[];
    for (final entry in _categories.entries) {
      if (query.isEmpty) {
        entries.add(entry);
        continue;
      }
      final matches = [
        for (final emoji in entry.value)
          if (_matches(emoji, query)) emoji,
      ];
      if (matches.isNotEmpty) entries.add(MapEntry(entry.key, matches));
    }
    return entries;
  }

  bool _matches(String emoji, String query) {
    if (_keywords[emoji]?.any((word) => word.contains(query)) ?? false) {
      return true;
    }
    return _categories.entries
        .any((entry) => entry.key.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final sections = _visible;
    return SizedBox(
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search emoji',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: sections.isEmpty
                ? const Center(
                    child: Text(
                      'No matches',
                      style: TextStyle(color: ZentraColors.textMuted),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final section in sections) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                          child: Text(
                            section.key,
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w700,
                              color: ZentraColors.textMuted,
                            ),
                          ),
                        ),
                        GridView.count(
                          crossAxisCount: 8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final emoji in section.value)
                              _EmojiCell(
                                emoji: emoji,
                                onTap: () => widget.onSelect(emoji),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 36,
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

/// Opens the picker as a bottom sheet and returns the chosen character, or
/// null when it was dismissed.
Future<String?> pickEmoji(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: EmojiPicker(
        onSelect: (emoji) => Navigator.of(sheetContext).pop(emoji),
      ),
    ),
  );
}