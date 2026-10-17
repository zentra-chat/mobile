import 'dart:convert';

/// The fields a tap needs in order to land on the right conversation.
///
/// Android pushes are data only, so the client posts the notification itself
/// and the routing has to ride along on it. A tap comes back with nothing but
/// the payload string that was stored with it.
const List<String> _pushTargetFields = [
  'notificationId',
  'channelId',
  'conversationId',
  'communityId',
  'messageId',
];

/// Serialises the routing fields of [data] for storage on a notification.
String encodePushTarget(Map<String, dynamic> data) {
  return jsonEncode({
    for (final field in _pushTargetFields)
      if (data[field] is String) field: data[field],
  });
}

/// Reads back what [encodePushTarget] wrote, or null when there is nothing to
/// route.
Map<String, dynamic>? decodePushTarget(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  } on FormatException {
    return null;
  }
}