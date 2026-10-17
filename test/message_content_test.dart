import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentra/widgets/message_content.dart';

const userId = '11111111-2222-3333-4444-555555555555';
const roleId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

Widget wrap(String content, {String? Function(String)? userName}) {
  return MaterialApp(
    home: Scaffold(
      body: MentionScope(
        userName: userName ?? (id) => 'Ada',
        roleName: (id) => 'Mods',
        child: MessageContent(content: content),
      ),
    ),
  );
}

void main() {
  testWidgets('renders user mention as the resolved name', (tester) async {
    await tester.pumpWidget(wrap('hey <@$userId> look'));
    expect(find.textContaining('hey '), findsOneWidget);
    expect(find.textContaining('@Ada'), findsOneWidget);
    expect(find.textContaining(userId), findsNothing);
  });

  testWidgets('falls back to a short id when the mention is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap('hey <@$userId>', userName: (_) => null),
    );
    expect(find.textContaining('@11111111'), findsOneWidget);
  });

  testWidgets('renders role and broadcast mentions', (tester) async {
    await tester.pumpWidget(wrap('<@&$roleId> and @everyone and @here'));
    expect(find.textContaining('@Mods'), findsOneWidget);
    expect(find.textContaining('@everyone'), findsOneWidget);
    expect(find.textContaining('@here'), findsOneWidget);
  });

  testWidgets('leaves mentions inside code spans alone', (tester) async {
    await tester.pumpWidget(wrap('`<@$userId>`'));
    expect(find.textContaining('@Ada'), findsNothing);
    expect(find.textContaining('<@$userId>'), findsOneWidget);
  });

  testWidgets('renders markdown emphasis and breaks', (tester) async {
    await tester.pumpWidget(wrap('**bold** and *italic*\nsecond line'));
    expect(find.textContaining('bold'), findsOneWidget);
    expect(find.textContaining('second line'), findsOneWidget);
  });

  testWidgets('renders fenced code with the language class', (tester) async {
    await tester.pumpWidget(wrap('```dart\nfinal x = 1;\n```'));
    expect(find.textContaining('final x = 1;'), findsOneWidget);
  });

  testWidgets('tapping a mention calls back with the id', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MentionScope(
            userName: (_) => 'Ada',
            onMentionTap: tapped.add,
            child: MessageContent(content: 'hey <@$userId>'),
          ),
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('@Ada'));
    await tester.pumpAndSettle();
    expect(tapped, [userId]);
  });
}