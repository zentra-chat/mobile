import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/layout.dart';
import '../config/theme.dart';
import '../data/models/community.dart';
import '../data/models/index.dart' show UnreadCountsX;
import '../providers/data_providers.dart';
import 'avatar.dart';

class ServerRail extends ConsumerWidget {
  const ServerRail({
    super.key,
    required this.selectedId,
    required this.onSelected,
    required this.onHome,
  });

  final String? selectedId;
  final void Function(String id) onSelected;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(communitiesProvider);

    return Container(
      width: kServerRailWidth,
      decoration: const BoxDecoration(
        color: ZentraColors.backgroundSecondary,
        border: Border(right: BorderSide(color: ZentraColors.border)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            _RailButton(
              active: selectedId == null,
              onTap: onHome,
              semanticLabel: 'Direct Messages',
              fallback: const Icon(
                Icons.home_outlined,
                size: 24,
                color: ZentraColors.textSecondary,
              ),
            ),
            ...communities.when(
              data: (list) => [
                for (final community in list)
                  _CommunityButton(
                    community: community,
                    active: community.id == selectedId,
                    onTap: () => onSelected(community.id),
                  ),
              ],
              loading: () => const [
                _RailSkeleton(),
                _RailSkeleton(),
                _RailSkeleton(),
              ],
              error: (e, _) {
                debugPrint('Failed to load communities: $e');
                return const [];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityButton extends ConsumerWidget {
  const _CommunityButton({
    required this.community,
    required this.active,
    required this.onTap,
  });

  final Community community;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(channelUnreadProvider(community.id)).value;
    final hasUnread = counts != null && counts.totalUnread > 0;

    return _RailButton(
      active: active,
      onTap: onTap,
      semanticLabel: community.name,
      badge: hasUnread,
      iconUrl: community.iconUrl,
      fallback: Text(
        community.name.isEmpty ? '?' : community.name[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ZentraColors.textSecondary,
        ),
      ),
    );
  }
}

/// One icon in the rail, plus the selection bar that sits to its left.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.active,
    required this.onTap,
    required this.semanticLabel,
    required this.fallback,
    this.iconUrl,
    this.badge = false,
  });

  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget fallback;
  final String? iconUrl;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: kServerIconSize,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: kNavDuration,
                    width: 4,
                    height: active ? 30 : 4,
                    decoration: BoxDecoration(
                      color: active
                          ? ZentraColors.textPrimary
                          : ZentraColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(kServerIconRadius),
                      child: Container(
                        width: kServerIconSize,
                        height: kServerIconSize,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: active
                              ? ZentraColors.surfaceActive
                              : ZentraColors.surface,
                          borderRadius: BorderRadius.circular(
                            kServerIconRadius,
                          ),
                          border: Border.all(
                            color: active
                                ? ZentraColors.borderLight
                                : Colors.transparent,
                          ),
                        ),
                        child: RemoteImage(
                          url: iconUrl,
                          fallback: Center(child: fallback),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (badge)
                Positioned(
                  right: 10,
                  bottom: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: ZentraColors.textPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ZentraColors.backgroundSecondary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: kServerIconSize,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 12),
            child: SizedBox(
              width: kServerIconSize,
              height: kServerIconSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ZentraColors.surface,
                  borderRadius: BorderRadius.all(
                    Radius.circular(kServerIconRadius),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
