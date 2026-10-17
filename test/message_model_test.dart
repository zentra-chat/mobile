import 'package:flutter_test/flutter_test.dart';
import 'package:zentra/data/messages/message_ops.dart';
import 'package:zentra/data/models/index.dart';

Map<String, dynamic> messageJson({
  String id = 'm1',
  String channelId = 'c1',
  String authorId = 'u1',
  String createdAt = '2026-01-01T00:00:00Z',
  Map<String, dynamic>? replyTo,
  List<dynamic>? reactions,
}) {
  return {
    'id': id,
    'channelId': channelId,
    'authorId': authorId,
    'content': 'hello',
    'isEdited': false,
    'isPinned': false,
    'createdAt': createdAt,
    'updatedAt': createdAt,
    'author': {
      'id': authorId,
      'username': 'ada',
      'status': 'online',
      'createdAt': '2025-01-01T00:00:00Z',
    },
    'reactions': ?reactions,
    'replyTo': ?replyTo,
  };
}

// The reply preview the backend sends only carries these four fields.
const replyPreview = {
  'id': 'm0',
  'content': 'the original',
  'authorId': 'u0',
  'author': {
    'id': 'u0',
    'username': 'grace',
    'status': 'online',
    'createdAt': '2025-01-01T00:00:00Z',
  },
};

void main() {
  test('parses a reply preview that has no channel or timestamps', () {
    final message = Message.fromJson(messageJson(replyTo: replyPreview));
    expect(message.replyTo, isNotNull);
    expect(message.replyTo!.id, 'm0');
    expect(message.replyTo!.author.username, 'grace');
    expect(message.replyTo!.summaryText, 'the original');
  });

  test('an empty reply preview reads as unavailable', () {
    final message = Message.fromJson(
      messageJson(
        replyTo: {...replyPreview, 'content': ''},
      ),
    );
    expect(message.replyTo!.summaryText, '[Message unavailable]');
  });

  test('omitted optional collections default to empty', () {
    final message = Message.fromJson(messageJson());
    expect(message.reactions, isEmpty);
    expect(message.attachments, isEmpty);
    expect(message.linkPreviews, isEmpty);
    expect(message.replyTo, isNull);
    expect(message.content, 'hello');
  });

  test('reaction events adjust the count and the reacted flag', () {
    var message = Message.fromJson(messageJson());
    message = applyReaction(
      message,
      emoji: '👍',
      userId: 'me',
      added: true,
      currentUserId: 'me',
    );
    expect(message.reactions.single.count, 1);
    expect(message.reactions.single.reacted, isTrue);

    message = applyReaction(
      message,
      emoji: '👍',
      userId: 'other',
      added: true,
      currentUserId: 'me',
    );
    expect(message.reactions.single.count, 2);
    expect(message.reactions.single.reacted, isTrue);

    message = applyReaction(
      message,
      emoji: '👍',
      userId: 'me',
      added: false,
      currentUserId: 'me',
    );
    expect(message.reactions.single.count, 1);
    expect(message.reactions.single.reacted, isFalse);

    message = applyReaction(
      message,
      emoji: '👍',
      userId: 'other',
      added: false,
      currentUserId: 'me',
    );
    expect(message.reactions, isEmpty);
  });

  test('a direct message reaction payload without reactor ids', () {
    // DM reaction summaries carry a count but no users array.
    final message = Message.fromJson(
      messageJson(
        reactions: [
          {
            'emoji': '🎉',
            'count': 3,
            'reacted': false,
            'users': null,
          },
        ],
      ),
    );
    expect(message.reactions.single.users, isEmpty);

    final added = applyReaction(
      message,
      emoji: '🎉',
      userId: 'someone',
      added: true,
      currentUserId: 'me',
    );
    expect(added.reactions.single.count, 4);

    final removed = applyReaction(
      added,
      emoji: '🎉',
      userId: 'someone',
      added: false,
      currentUserId: 'me',
    );
    expect(removed.reactions.single.count, 3);
  });

  test('toggling locally adds then removes the emoji', () {
    final messages = [Message.fromJson(messageJson())];
    final added = toggleReactionLocally(
      messages,
      messageId: 'm1',
      emoji: '👍',
      currentUserId: 'me',
    );
    expect(added.single.reactions.single.reacted, isTrue);

    final removed = toggleReactionLocally(
      added,
      messageId: 'm1',
      emoji: '👍',
      currentUserId: 'me',
    );
    expect(removed.single.reactions, isEmpty);
  });

  test('history pages are merged oldest first without duplicates', () {
    final older = [
      Message.fromJson(
        messageJson(id: 'm1', createdAt: '2026-01-01T00:00:00Z'),
      ),
      Message.fromJson(
        messageJson(id: 'm2', createdAt: '2026-01-01T00:01:00Z'),
      ),
    ];
    final current = [
      Message.fromJson(
        messageJson(id: 'm2', createdAt: '2026-01-01T00:01:00Z'),
      ),
      Message.fromJson(
        messageJson(id: 'm3', createdAt: '2026-01-01T00:02:00Z'),
      ),
    ];
    final merged = appendOlder(current, older, limit: 100);
    expect(merged.map((m) => m.id), ['m1', 'm2', 'm3']);
  });
}