import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models/index.dart';

/// Surfaces mentions, replies and direct messages as system notifications.
///
/// The gateway pushes these over the websocket while the app is connected.
/// True background delivery, where a killed app still gets notified, needs
/// push infrastructure on the server, which Zentra does not have yet.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelKey = 'zentra_messages';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    await _createAndroidChannel();
    _ready = true;
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

  /// Shows [notification] in the tray. Returns false when the platform has no
  /// notification support or permission was refused.
  Future<bool> show(Notification notification) async {
    if (kIsWeb) return false;
    if (!_ready) await init();
    try {
      await _plugin.show(
        // Each notification gets its own id so they stack in the tray instead
        // of replacing one another.
        id: notification.id.hashCode & 0x7fffffff,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelKey,
            'Messages',
            channelDescription: 'Mentions, replies and direct messages',
            importance: Importance.high,
            priority: Priority.high,
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