import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link from message content in the system browser, falling back to
/// showing the raw URL when no handler is installed.
Future<void> openExternalLink(BuildContext context, String? href) async {
  if (href == null || href.isEmpty) return;
  final uri = Uri.tryParse(href);
  if (uri == null || !uri.hasScheme) return;
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $href')),
    );
  }
}