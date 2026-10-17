import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentra/data/models/index.dart';
import 'package:zentra/providers/data_providers.dart';
import 'package:zentra/providers/dm_providers.dart';
import 'package:zentra/providers/nav_provider.dart';
import 'package:zentra/providers/notifications_provider.dart';
import 'package:zentra/config/layout.dart';
import 'package:zentra/screens/main_screen.dart';
import 'package:zentra/widgets/server_rail.dart';

const communityId = 'c1';

class _EmptyNotifications extends NotificationsNotifier {
  @override
  List<Notification> build() => const [];
}

class _EmptyConversations extends DmConversationsNotifier {
  @override
  List<DMConversation> build() => const [];
}

ProviderContainer buildContainer() {
  return ProviderContainer(
    overrides: [
      communitiesProvider.overrideWith((ref) async => const [
        Community(
          id: communityId,
          name: 'Test',
          ownerId: 'u1',
          isPublic: true,
          isOpen: false,
          memberCount: 1,
          createdAt: '2025-01-01T00:00:00Z',
          updatedAt: '2025-01-01T00:00:00Z',
        ),
      ]),
      channelUnreadProvider.overrideWith(
        (ref, id) async => const UnreadCounts(unread: {}, mentions: {}),
      ),
      notificationsProvider.overrideWith(_EmptyNotifications.new),
      dmConversationsProvider.overrideWith(_EmptyConversations.new),
    ],
  );
}

void main() {
  testWidgets('the server rail only shows on the servers tab', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(ServerRail), findsOneWidget);

    for (final tab in [kDmsTab, kNotificationsTab, kSettingsTab]) {
      container.read(navProvider.notifier).showTab(tab);
      // One pump to finish the collapse animation, one more to rebuild after
      // the rail has unmounted itself.
      await tester.pump(kNavDuration);
      await tester.pump();
      expect(
        find.byType(ServerRail),
        findsNothing,
        reason: 'the rail must be hidden on tab $tab',
      );
    }

    container.read(navProvider.notifier).showTab(kServersTab);
    await tester.pump();
    await tester.pump(kNavDuration);
    expect(find.byType(ServerRail), findsOneWidget);
  });
}