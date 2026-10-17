import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/lifecycle_provider.dart';
import '../providers/notifications_provider.dart';
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
      await service.init();
      await service.requestPermission();
    } catch (e) {
      debugPrint('System notifications are unavailable: $e');
    }
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