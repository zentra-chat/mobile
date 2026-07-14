import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      // Restore a persisted session (and reconnect the gateway) if present.
      ref.read(authProvider.notifier).init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed =
        ref.watch(authProvider).status == AuthStatus.authenticated;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: zentraTheme,
      home: isAuthed ? const HomeScreen() : const LoginScreen(),
    );
  }
}
