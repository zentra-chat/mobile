import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Handles a push that arrives while the app is not running.
///
/// Firebase spins up a separate isolate for this, so it cannot reach Riverpod,
/// the API client or any app state. Everything needed to display the
/// notification has to come from the message payload itself.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await NotificationService().showFromPush(message.data);
  } catch (e) {
    // Nothing useful can be done here, and crashing the isolate would stop
    // future messages being handled at all.
    debugPrint('Failed to display a background notification: $e');
  }
}

/// Registers the device for OS level push delivery.
///
/// Android receives through Firebase Cloud Messaging and iOS through APNs.
/// FCM wraps APNs on the device side, so one token covers both platforms.
class PushService {
  PushService({FirebaseMessaging? messaging, NotificationService? notifications})
      : _messagingOverride = messaging,
        _notifications = notifications ?? NotificationService();

  final FirebaseMessaging? _messagingOverride;
  final NotificationService _notifications;

  // FirebaseMessaging.instance throws until Firebase.initializeApp has run, so
  // the instance is only resolved once init has started Firebase. Resolving it
  // in the constructor would break every caller that builds the service before
  // init gets a chance to run.
  FirebaseMessaging? _messaging;

  FirebaseMessaging get _messagingInstance {
    final messaging = _messaging ?? _messagingOverride;
    if (messaging == null) {
      throw StateError('PushService.init must run before messaging is used');
    }
    return messaging;
  }

  String? _token;
  bool _initialised = false;
  StreamSubscription<String>? _registrationSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  // Completed with the first identifier Firebase issues, or with null if
  // registration is not possible on this device.
  final Completer<String?> _firstToken = Completer<String?>();

  /// The current device token, or null until registration completes.
  String? get token => _token;

  /// Completes with the first token Firebase issues, or null if it never does.
  ///
  /// Registration is asynchronous, so the identifier is not available the
  /// moment init returns. Waiting on this is what lets registration proceed
  /// whenever a session becomes available, rather than only if one happened to
  /// exist before Firebase finished starting.
  Future<String?> get firstToken => _firstToken.future;

  /// Called with a new token whenever Firebase rotates it, so the caller can
  /// register it against the gateway.
  void Function(String token)? onTokenRefresh;

  /// The platform identifier the gateway stores alongside the token.
  static String platformFor(TargetPlatform target) =>
      switch (target) {
        TargetPlatform.iOS => 'ios',
        _ => 'android',
      };

  static bool isSupported(TargetPlatform target) =>
      target == TargetPlatform.android || target == TargetPlatform.iOS;

  /// Starts Firebase and asks for permission.
  ///
  /// Returns false when push cannot run, which is the normal case on desktop
  /// and in tests. Callers treat that as websocket only delivery rather than
  /// an error, so the app stays fully usable without push.
  ///
  /// The token itself is not returned because it arrives asynchronously, see
  /// [firstToken].
  Future<bool> init({required TargetPlatform target}) async {
    if (_initialised) return true;
    if (!isSupported(target) || kIsWeb) {
      _settleFirstToken(null);
      return false;
    }

    try {
      await Firebase.initializeApp();
      _initialised = true;
    } catch (e) {
      // Usually a missing google-services.json or an iOS bundle with no
      // Firebase configuration.
      debugPrint('Push is unavailable, Firebase did not start: $e');
      _settleFirstToken(null);
      return false;
    }

    _messaging = _messagingOverride ?? FirebaseMessaging.instance;

    await _requestPermission();

    // Registration replaces the legacy getToken flow, and the identifier it
    // yields is what the gateway stores and sends to. The stream only reports a
    // genuinely new registration, so on its own it stays silent whenever
    // Firebase already holds a token from an earlier run and registration would
    // never complete.
    _registrationSubscription = _messagingInstance.onRegistered
        .listen(_handleTokenAvailable);

    try {
      await _messagingInstance.register();
    } catch (e) {
      debugPrint('Push is unavailable, registration failed: $e');
      _settleFirstToken(null);
      return false;
    }

    return true;
  }

  void _handleTokenAvailable(String token) {
    if (token.isEmpty) return;
    final isFirst = _token == null;
    _token = token;
    _settleFirstToken(token);

    // Only a replacement needs forwarding, the first one is collected through
    // firstToken.
    if (!isFirst) onTokenRefresh?.call(token);
  }

  void _settleFirstToken(String? token) {
    if (!_firstToken.isCompleted) _firstToken.complete(token);
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await _messagingInstance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permission was refused, push will not show');
      }
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
    }
  }

  /// Delivers taps on alerts the system displayed itself, which is iOS. The
  /// [onOpened] callback receives the routing fields the gateway attached.
  ///
  /// Android pushes are data only, so the notification is posted by this app
  /// and its tap arrives through [NotificationService.onOpened] instead.
  Future<void> listenForOpenedNotifications(
    void Function(RemoteMessage message) onOpened,
  ) async {
    try {
      final initial = await _messagingInstance.getInitialMessage();
      if (initial != null) onOpened(initial);

      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(onOpened);
    } catch (e) {
      debugPrint('Failed to listen for opened notifications: $e');
    }
  }

  /// Presents a push that arrived while the app was in the foreground.
  ///
  /// The gateway skips users with a live websocket, so this only fires during
  /// the gap while the socket is reconnecting. It is shown rather than
  /// suppressed because the websocket event may never arrive.
  Future<void> showInForeground(RemoteMessage message) async {
    if (message.data['notificationId'] == null) return;
    try {
      await _notifications.showFromPush(message.data);
    } catch (e) {
      debugPrint('Failed to show a foreground push notification: $e');
    }
  }

  Future<void> dispose() async {
    await _registrationSubscription?.cancel();
    await _openedSubscription?.cancel();
    _registrationSubscription = null;
    _openedSubscription = null;
    _messaging = null;
    _initialised = false;
  }
}