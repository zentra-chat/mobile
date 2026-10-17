import 'package:flutter/material.dart';

import '../config/layout.dart';

/// Rail that slides away when [visible] goes false and is removed from the
/// tree once the collapse finishes, so its contents are not laid out (or kept
/// alive by their providers) while it is off screen.
class CollapsibleRail extends StatefulWidget {
  const CollapsibleRail({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<CollapsibleRail> createState() => _CollapsibleRailState();
}

class _CollapsibleRailState extends State<CollapsibleRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kNavDuration,
  )..addStatusListener(_onStatus);

  /// The rail has to stay in the tree while it animates out, otherwise it
  /// would vanish before it slides.
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _mounted = widget.visible;
    _controller.value = widget.visible ? 1 : 0;
  }

  @override
  void didUpdateWidget(CollapsibleRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    // A build always follows, so the field can be set directly.
    _mounted = true;
    if (widget.visible) {
      _controller.forward();
    } else {
      // Start from fully open so the collapse is a slide out, not a jump.
      _controller.value = 1;
      _controller.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    // Seeding the controller in initState reports a status too, so only a
    // collapse that is actually running may unmount the rail. A reverse ends
    // as "dismissed" rather than "completed".
    if (widget.visible) return;
    if (status != AnimationStatus.forward) setState(() => _mounted = false);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => SizedBox(
          width: kServerRailWidth * _controller.value,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: kServerRailWidth,
            maxWidth: kServerRailWidth,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}