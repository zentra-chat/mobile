import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Network image that falls back to [fallback] when the URL is missing, empty
/// or fails to load, so a dead image URL never renders an error box.
///
/// The image fills whatever size it is given and crops with [fit], matching
/// the web client's `object-cover`. The parent must therefore pass tight
/// constraints or the image will lay out at its own aspect ratio.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(url!, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}

/// Circular avatar showing a remote image cropped to the circle, or the first
/// letter of [label] over a tinted circle when there is no image. [child] is
/// passed straight through for callers that render their own content, and is
/// centered by [CircleAvatar].
class RemoteAvatar extends StatelessWidget {
  const RemoteAvatar({
    super.key,
    required this.url,
    required this.label,
    this.radius = 20,
    this.child,
    this.backgroundColor,
    this.foregroundColor = ZentraColors.primary,
  });

  final String? url;
  final String label;
  final double radius;
  final Widget? child;
  final Color? backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? ZentraColors.surface,
      foregroundColor: foregroundColor,
      child:
          child ??
          SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: ClipOval(
              child: RemoteImage(
                url: url,
                fallback: _Initials(label: label, radius: radius),
              ),
            ),
          ),
    );
  }
}

/// Letter over a light green wash, mirroring the web client's avatar
/// placeholder.
class _Initials extends StatelessWidget {
  const _Initials({required this.label, required this.radius});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZentraColors.primary.withValues(alpha: 0.2),
            ZentraColors.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w500,
            color: ZentraColors.primary,
          ),
        ),
      ),
    );
  }
}
