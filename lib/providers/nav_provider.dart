import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_provider.dart';
import 'data_providers.dart';
import 'dm_providers.dart';

// Tab order of the bottom rail, also used by the rest of the shell to jump to
// a section. The shell orders its screens with these, so the rail and the
// visible screen cannot drift apart.
const int kServersTab = 0;
const int kDmsTab = 1;
const int kNotificationsTab = 2;
const int kSettingsTab = 3;

class NavState {
  final int tabIndex;
  final bool sidebarOpen;

  const NavState({this.tabIndex = kServersTab, this.sidebarOpen = false});

  NavState copyWith({int? tabIndex, bool? sidebarOpen}) {
    return NavState(
      tabIndex: tabIndex ?? this.tabIndex,
      sidebarOpen: sidebarOpen ?? this.sidebarOpen,
    );
  }
}

class NavNotifier extends Notifier<NavState> {
  @override
  NavState build() => const NavState();

  void showTab(int index) {
    if (index == state.tabIndex) {
      closeSidebar();
      return;
    }
    // Leaving the servers tab means leaving whatever channel was open there.
    _closeStreams();
    state = state.copyWith(tabIndex: index, sidebarOpen: false);
  }

  void openSidebar() => state = state.copyWith(sidebarOpen: true);

  void closeSidebar() => state = state.copyWith(sidebarOpen: false);

  void toggleSidebar() =>
      state = state.copyWith(sidebarOpen: !state.sidebarOpen);

  /// Switching communities clears the open channel, since channels belong to
  /// a single community. The sidebar opens so the new community's channels
  /// are one tap away.
  void selectCommunity(String id) {
    final community = ref.read(selectedCommunityIdProvider.notifier);
    if (community.state == id) {
      openSidebar();
      return;
    }
    community.set(id);
    _closeStreams();
    state = state.copyWith(tabIndex: kServersTab, sidebarOpen: true);
  }

  /// Picking a channel means reading it, so the shell shows the servers tab
  /// even when the pick was made from another one, and the rails get out of
  /// the way to give the thread the full width.
  Future<void> selectChannel(String communityId, String channelId) async {
    ref.read(selectedChannelIdProvider.notifier).set(channelId);
    state = state.copyWith(tabIndex: kServersTab, sidebarOpen: false);
    try {
      await ref.read(apiClientProvider).markChannelRead(channelId);
    } catch (e) {
      debugPrint('Failed to mark channel $channelId as read: $e');
    }
    ref.invalidate(channelUnreadProvider(communityId));
  }

  /// Leaves the channel and returns to the community's channel list with the
  /// sidebar already open, which is where the pick came from.
  void closeChannel() {
    ref.read(selectedChannelIdProvider.notifier).set(null);
    state = state.copyWith(sidebarOpen: true);
  }

  Future<void> selectConversation(String conversationId) async {
    ref.read(selectedConversationIdProvider.notifier).set(conversationId);
    ref.read(dmConversationsProvider.notifier).markRead(conversationId);
    state = state.copyWith(tabIndex: kDmsTab, sidebarOpen: false);
    try {
      await ref.read(apiClientProvider).markDmRead(conversationId);
    } catch (e) {
      debugPrint('Failed to mark conversation $conversationId as read: $e');
    }
  }

  void closeConversation() {
    ref.read(selectedConversationIdProvider.notifier).set(null);
    state = state.copyWith(tabIndex: kDmsTab, sidebarOpen: false);
  }

  void _closeStreams() {
    ref.read(selectedChannelIdProvider.notifier).set(null);
    ref.read(selectedConversationIdProvider.notifier).set(null);
  }
}

final navProvider = NotifierProvider<NavNotifier, NavState>(NavNotifier.new);