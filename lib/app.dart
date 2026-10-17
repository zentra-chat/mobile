import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/lifecycle_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/push_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final AppLifecycleListener _lifecycleListener;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) =>
          ref.read(lifecycleProvider.notifier).set(state),
    );
    // Registered here rather than in the provider so the callbacks stay tied to
    // a mounted widget.
    _listenForPushes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    // Restore a persisted session (and reconnect the gateway) if present.
    ref.read(authProvider.notifier).init();
    _prepareNotifications();
  }

  Future<void> _prepareNotifications() async {
    final service = ref.read(notificationServiceProvider);
    try {
      // Set before init, since a launch from the tray is reported during it.
      service.onOpened = (data) =>
          ref.read(pushNavigationProvider.notifier).open(data);
      await service.init();
      await service.requestPermission();
    } catch (e) {
      debugPrint('System notifications are unavailable: $e');
    }
  }

  /// Starts push and wires taps back into the app.
  ///
  /// Failures here are never fatal. Push needs Firebase configured and
  /// permission granted, and without either the app still works over the
  /// websocket.
  Future<void> _listenForPushes() async {
    try {
      final service = ref.read(pushServiceProvider);
      final started = await service.init(target: defaultTargetPlatform);
      if (!started) return;

      // A rotated token has to reach the gateway or the old one keeps being
      // used until it is rejected.
      service.onTokenRefresh = (_) {
        ref.read(pushRegistrationProvider.notifier).register();
      };

      // Registers the device with the gateway. The notifier waits for a
      // session and a token, then registers, and rebuilds itself on a later
      // login or instance switch. Nothing else builds it, so without this read
      // a fresh install never registers and the gateway has no token to push
      // to.
      ref.read(pushRegistrationProvider.notifier);

      // Taps on notifications the app posted itself arrive through the
      // notification plugin. This covers the rest, which is iOS, where the
      // system displays the alert and hands the tap back itself.
      await service.listenForOpenedNotifications((message) {
        ref.read(pushNavigationProvider.notifier).open(message.data);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      debugPrint('Push notifications are unavailable: $e');
    }
  }

  /// Shows a push that arrived while the app was in the foreground.
  ///
  /// Dropped when the user caused it or when it belongs to the conversation
  /// already on screen.
  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    if (data['notificationId'] == null) return;

    // The gateway only pushes to users it cannot reach over the websocket, so
    // the app being open does not mean the message is already on screen.
    final redundant = isRedundantNotification(
      selfId: ref.read(authProvider).session?.user.id,
      activeStreamId: ref.read(activeStreamIdProvider),
      actorId: data['actorId'] as String?,
      streamId:
          data['conversationId'] as String? ?? data['channelId'] as String?,
    );
    if (redundant) return;

    ref.read(pushServiceProvider).showInForeground(message);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed =
        ref.watch(authProvider).status == AuthStatus.authenticated;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: zentraTheme,
      home: isAuthed ? const MainScreen() : const LoginScreen(),
    );
  }
}