import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models/index.dart';
import 'push_payload.dart';

/// Surfaces mentions, replies and direct messages as system notifications.
///
/// The gateway pushes these over the websocket while the app is connected, and
/// through FCM or APNs once it is not.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelKey = 'zentra_messages';

/// Drawable used as the status bar icon, which has to be a white silhouette
/// rather than the full colour launcher icon.
static const String notificationIcon = 'ic_notification';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Called with the routing fields of a notification the user tapped, whether
  /// it arrived by push or over the websocket.
  void Function(Map<String, dynamic> data)? onOpened;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(notificationIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final data = decodePushTarget(response.payload);
        if (data != null) onOpened?.call(data);
      },
    );
    await _createAndroidChannel();
    _ready = true;

    // A cold start from the tray skips the response callback, so the tap that
    // launched the app has to be read back here instead.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final data = decodePushTarget(launch?.notificationResponse?.payload);
      if (data != null) onOpened?.call(data);
    }
  }

  Future<void> _createAndroidChannel() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelKey,
        'Messages',
        description: 'Mentions, replies and direct messages',
        importance: Importance.high,
      ),
    );
  }

  /// Asks the platform for permission to post notifications. Safe to call on
  /// every launch; the system only prompts once.
  Future<void> requestPermission() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Shows a notification delivered by the push service.
  ///
  /// Used from the background isolate, so it takes the raw payload rather than
  /// a [Notification] and performs no network or state access.
  Future<bool> showFromPush(Map<String, dynamic> data) async {
    if (kIsWeb) return false;
    final id = data['notificationId'];
    final title = data['title'];
    if (id is! String || id.isEmpty) return false;
    if (title is! String || title.isEmpty) return false;
    if (!_ready) await init();

    return _show(
      // The id doubles as the de-duplication key, since it matches the id the
      // websocket path would have used for the same notification.
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: data['body'] is String ? data['body'] as String : null,
      payload: encodePushTarget(data),
    );
  }

  /// Shows [notification] in the tray. Returns false when the platform has no
  /// notification support or permission was refused.
  Future<bool> show(Notification notification) async {
    if (kIsWeb) return false;
    if (!_ready) await init();
    return _show(
      // Each notification gets its own id so they stack in the tray instead
      // of replacing one another.
      id: notification.id.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      payload: encodePushTarget({
        'notificationId': notification.id,
        'channelId': notification.channelId,
        'conversationId': notification.conversationId,
        'communityId': notification.communityId,
        'messageId': notification.messageId,
      }),
    );
  }

  Future<bool> _show({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        // Carried through so a tap can be routed to the right conversation.
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelKey,
            'Messages',
            channelDescription: 'Mentions, replies and direct messages',
            importance: Importance.high,
            priority: Priority.high,
            icon: notificationIcon,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Failed to show a system notification: $e');
      return false;
    }
  }
}