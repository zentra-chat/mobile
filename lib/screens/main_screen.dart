import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/layout.dart';
import '../providers/data_providers.dart';
import '../providers/dm_providers.dart';
import '../providers/nav_provider.dart';
import '../widgets/bottom_rail.dart';
import '../widgets/channel_sidebar.dart';
import '../widgets/collapsible_rail.dart';
import '../widgets/server_rail.dart';
import 'dm_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  // Order must match the bottom rail tabs: Servers, DMs, Notifications,
  // Settings.
  static const List<Widget> _screens = [
    HomeScreen(),
    DmScreen(),
    NotificationsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navProvider);
    final navActions = ref.read(navProvider.notifier);
    final communityId = ref.watch(selectedCommunityIdProvider);
    final channelId = ref.watch(selectedChannelIdProvider);
    final conversationId = ref.watch(selectedConversationIdProvider);

    // Reading gets the whole width: both rails slide away the way the web
    // client drops its server list once a thread is open, and the header's
    // back button returns to the picker. The rail only belongs to the servers
    // tab; direct messages, notifications and settings have nothing to switch
    // between servers for.
    final reading = channelId != null || conversationId != null;
    final showServerRail = !reading && nav.tabIndex == kServersTab;

    return Scaffold(
      body: Row(
        children: [
          // The rail keeps its own width while the slot collapses, so the
          // list views inside it are never laid out at zero width.
          CollapsibleRail(
            visible: showServerRail,
            child: ServerRail(
              selectedId: communityId,
              onSelected: navActions.selectCommunity,
              onHome: () => navActions.showTab(kDmsTab),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < -400) {
                        navActions.closeSidebar();
                      } else if (velocity > 400 &&
                          nav.tabIndex == kServersTab) {
                        navActions.openSidebar();
                      }
                    },
                    child: IndexedStack(
                      index: nav.tabIndex,
                      children: _screens,
                    ),
                  ),
                ),
                if (communityId != null) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !nav.sidebarOpen,
                      child: AnimatedOpacity(
                        opacity: nav.sidebarOpen ? 1 : 0,
                        duration: kNavDuration,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: navActions.closeSidebar,
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: kChannelSidebarWidth,
                    // The sidebar slides out with a paint transform, which a
                    // Stack does not clip, so clip it to its own box to keep
                    // it off screen while closed.
                    child: ClipRect(
                      child: IgnorePointer(
                        ignoring: !nav.sidebarOpen,
                        child: AnimatedSlide(
                          offset: nav.sidebarOpen
                              ? Offset.zero
                              : const Offset(-1, 0),
                          duration: kNavDuration,
                          curve: Curves.easeOutCubic,
                          child: ChannelSidebar(
                            communityId: communityId,
                            communityName: _communityName(ref, communityId),
                            selectedChannelId: channelId,
                            onChannelSelected: (id) =>
                                navActions.selectChannel(communityId, id),
                            onDismiss: navActions.closeSidebar,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedSize(
        duration: kNavDuration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: reading
            ? const SizedBox.shrink()
            : BottomRail(index: nav.tabIndex, onSelected: navActions.showTab),
      ),
    );
  }

  String _communityName(WidgetRef ref, String communityId) {
    final communities = ref.watch(communitiesProvider).value;
    if (communities == null) return '';
    for (final community in communities) {
      if (community.id == communityId) return community.name;
    }
    return '';
  }
}