import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/layout.dart';
import '../providers/data_providers.dart';
import '../providers/nav_provider.dart';
import '../widgets/bottom_rail.dart';
import '../widgets/channel_sidebar.dart';
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

    // Hide the bottom rail while a channel is open, the way Discord drops it
    // once you are reading.
    final showBottomRail = nav.tabIndex != kServersTab || channelId == null;

    return Scaffold(
      body: Row(
        children: [
          ServerRail(
            selectedId: communityId,
            onSelected: navActions.selectCommunity,
            onHome: () => navActions.showTab(kDmsTab),
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
        child: showBottomRail
            ? BottomRail(index: nav.tabIndex, onSelected: navActions.showTab)
            : const SizedBox.shrink(),
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
