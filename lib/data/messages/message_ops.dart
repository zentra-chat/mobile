import '../models/message.dart';

/// How many messages the REST history endpoints are asked for per page.
const int kMessagePageSize = 50;

/// Accepts a history page newest first from the API and yields the combined
/// list oldest first, which is the order the message list renders in.
List<Message> appendOlder(
  List<Message> current,
  List<Message> page, {
  required int limit,
}) => normaliseOrder([...page.reversed, ...current], limit: limit);

/// Applies a reaction event to a message and returns the updated copy.
///
/// The gateway only reports that a user added or removed an emoji, so the
/// count and the "did I react" flag are derived here. Reactions that fall back
/// to zero are dropped rather than shown as an empty pill.
Message applyReaction(
  Message message, {
  required String emoji,
  required String userId,
  required bool added,
  required String currentUserId,
}) {
  final reactions = [...message.reactions];
  final index = reactions.indexWhere((reaction) => reaction.emoji == emoji);
  final isSelf = userId == currentUserId;

  if (index == -1) {
    if (!added) return message;
    reactions.add(
      Reaction(emoji: emoji, count: 1, reacted: isSelf),
    );
    return message.copyWith(reactions: reactions);
  }

  final existing = reactions[index];

  // Channel payloads list who reacted, direct message payloads only carry a
  // count. Without a list the count is the only thing to move, so the list is
  // left empty rather than seeded with a partial answer.
  if (existing.users.isEmpty) {
    final count = added ? existing.count + 1 : existing.count - 1;
    if (count <= 0) {
      reactions.removeAt(index);
    } else {
      reactions[index] = Reaction(
        emoji: emoji,
        count: count,
        reacted: added
            ? existing.reacted || isSelf
            : existing.reacted && !isSelf,
      );
    }
    return message.copyWith(reactions: reactions);
  }

  final users = existing.users.where((id) => id != userId).toList();
  if (added && !users.contains(userId)) users.add(userId);
  if (users.isEmpty) {
    reactions.removeAt(index);
  } else {
    reactions[index] = Reaction(
      emoji: emoji,
      count: users.length,
      reacted: users.contains(currentUserId),
      users: users,
    );
  }

  return message.copyWith(reactions: reactions);
}

/// Applies a reaction event to the matching message, or returns the list
/// unchanged when nothing moved.
List<Message> updateReaction(
  List<Message> messages, {
  required String messageId,
  required String emoji,
  required String userId,
  required bool added,
  required String currentUserId,
}) {
  final index = messages.indexWhere((message) => message.id == messageId);
  if (index == -1) return messages;
  final updated = applyReaction(
    messages[index],
    emoji: emoji,
    userId: userId,
    added: added,
    currentUserId: currentUserId,
  );
  final next = [...messages];
  next[index] = updated;
  return next;
}

/// Flips a reaction immediately on tap. The gateway confirms shortly after and
/// overwrites this with the authoritative list.
List<Message> toggleReactionLocally(
  List<Message> messages, {
  required String messageId,
  required String emoji,
  required String currentUserId,
}) {
  final index = messages.indexWhere((message) => message.id == messageId);
  if (index == -1) return messages;
  final message = messages[index];
  final existing = message.reactions
      .where((reaction) => reaction.emoji == emoji)
      .firstOrNull;
  final adding = existing == null || !existing.reacted;
  final reactions = [...message.reactions];
  if (existing == null) {
    reactions.add(Reaction(emoji: emoji, count: 1, reacted: true));
  } else if (adding) {
    reactions[reactions.indexOf(existing)] = Reaction(
      emoji: emoji,
      count: existing.count + 1,
      reacted: true,
      users: existing.users.contains(currentUserId)
          ? existing.users
          : [...existing.users, currentUserId],
    );
  } else {
    reactions.removeWhere((reaction) => reaction.emoji == emoji);
  }
  final next = [...messages];
  next[index] = message.copyWith(reactions: reactions);
  return next;
}

/// Replaces a message in place, used by edit, pin and update events.
List<Message> replaceMessage(List<Message> messages, Message message) {
  return [
    for (final existing in messages)
      if (existing.id == message.id) message else existing,
  ];
}

/// Sorts oldest first and drops duplicates, then trims to the newest
/// [limit] entries. A message that appears twice keeps the later copy, which
/// is the one carrying any edits or reactions applied since it was loaded.
List<Message> normaliseOrder(List<Message> messages, {int limit = 100}) {
  final byId = <String, Message>{};
  for (final message in messages) {
    byId[message.id] = message;
  }
  final unique = byId.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (unique.length <= limit) return unique;
  return unique.sublist(unique.length - limit);
}