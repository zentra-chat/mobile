import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentra/data/models/index.dart';
import 'package:zentra/widgets/message_composer.dart';

const screenSize = Size(360, 640);
const gestureBar = 24.0;

void usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = screenSize;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: gestureBar);
  tester.view.viewPadding = const FakeViewPadding(bottom: gestureBar);
  addTearDown(tester.view.reset);
}

Widget host({ReplyTarget? reply, List<String> typing = const []}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const Expanded(child: SizedBox.shrink()),
          MessageComposer(
            typingNames: typing,
            replyTo: reply,
            onSend: (_, {replyToId, editing}) {},
          ),
        ],
      ),
    ),
  );
}

double composerHeight(WidgetTester tester) =>
    tester.getSize(find.byType(MessageComposer)).height;

void main() {
  testWidgets('lays out on a phone with no keyboard', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(host());
    expect(tester.takeException(), isNull);
    expect(composerHeight(tester), lessThan(200));
  });

  testWidgets('lays out with a reply banner and a typing user', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(
      host(
        typing: const ['ada'],
        reply: ReplyTarget(id: 'm0', authorName: 'grace', preview: 'hello'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grows with the input', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(host());
    final collapsed = composerHeight(tester);

    await tester.enterText(
      find.byType(TextField),
      List.generate(8, (i) => 'line$i').join('\n'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(composerHeight(tester), greaterThan(collapsed));
  });

  testWidgets('sits at the bottom and clears the gesture bar', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(host());

    expect(tester.getBottomLeft(find.byType(MessageComposer)).dy,
        screenSize.height);

    final gap =
        tester.getBottomLeft(find.byType(MessageComposer)).dy -
        tester.getBottomLeft(find.byType(TextField)).dy;
    // The gesture bar plus breathing room under the input.
    expect(gap, greaterThanOrEqualTo(gestureBar + 8));
  });

  testWidgets('typing does not paint outside the composer', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(host());

    final before = tester.getRect(find.byType(MessageComposer));
    await tester.pumpWidget(host(typing: const ['ada']));
    final after = tester.getRect(find.byType(MessageComposer));

    // The typing row lives inside the composer box, so the box grows upward
    // from the bottom of the screen instead of a band appearing above it.
    expect(after.bottom, before.bottom);
    expect(after.top, lessThan(before.top));
    expect(find.text('ada is typing...'), findsOneWidget);
  });
}