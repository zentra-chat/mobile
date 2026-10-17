import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentra/data/models/index.dart';
import 'package:zentra/widgets/message_item.dart';

Message buildMessage({
  String id = 'm1',
  String authorId = 'u1',
  String content = 'hello',
  String createdAt = '2026-01-01T00:00:00Z',
  bool isEdited = false,
  List<Reaction> reactions = const [],
}) {
  return Message(
    id: id,
    channelId: 'c1',
    authorId: authorId,
    content: content,
    isEdited: isEdited,
    isPinned: false,
    reactions: reactions,
    author: User(
      id: authorId,
      username: 'ada',
      status: UserStatus.online,
      createdAt: '2025-01-01T00:00:00Z',
    ),
    attachments: const [],
    linkPreviews: const [],
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Widget host(Message message, {double width = 320, void Function()? onReply}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: MessageRow(
            message: message,
            currentUserId: 'u1',
            onReply: onReply ?? () {},
            onReact: (_, _) {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    ),
  );
}

double rowHeight(WidgetTester tester) =>
    tester.getSize(find.byType(MessageRow)).height;

/// Two messages from the same author, one minute apart, so the second one
/// groups under the first.
Widget thread() {
  final messages = [
    buildMessage(),
    buildMessage(id: 'm2', createdAt: '2026-01-01T00:01:00Z'),
  ];
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < messages.length; i++)
                MessageRow(
                  message: messages[i],
                  previous: i > 0 ? messages[i - 1] : null,
                  currentUserId: 'u1',
                  onReply: () {},
                  onReact: (_, _) {},
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a plain message hugs its content', (tester) async {
    await tester.pumpWidget(host(buildMessage()));
    expect(rowHeight(tester), lessThan(60));
  });

  testWidgets('a reply preview does not blow up the row', (tester) async {
    await tester.pumpWidget(host(buildMessage(content: 'a\nb\nc')));
    // Three lines of body plus one header line.
    expect(rowHeight(tester), lessThan(100));
  });

  testWidgets('many reactions wrap instead of overflowing', (tester) async {
    await tester.pumpWidget(
      host(
        buildMessage(
          isEdited: true,
          reactions: const [
            Reaction(emoji: '👍', count: 12, reacted: true),
            Reaction(emoji: '🎉', count: 3, reacted: false),
            Reaction(emoji: '❤️', count: 99, reacted: true),
            Reaction(emoji: '🔥', count: 4, reacted: false),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a grouped message is shorter than one with a header', (
    tester,
  ) async {
    await tester.pumpWidget(thread());
    final rows = find.byType(MessageRow);
    final withHeader = tester.getSize(rows.at(0)).height;
    final grouped = tester.getSize(rows.at(1)).height;
    expect(grouped, lessThan(withHeader));
  });

  testWidgets('long press opens the message actions', (tester) async {
    var replied = false;
    await tester.pumpWidget(host(buildMessage(), onReply: () => replied = true));

    final origin = tester.getTopLeft(find.byType(MessageRow));
    await tester.longPressAt(origin + const Offset(100, 20));
    await tester.pumpAndSettle();

    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Add Reaction'), findsOneWidget);
    expect(find.text('Copy Text'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(replied, isTrue);
  });
}
