import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's current lifecycle state. System notifications are only worth
/// posting while the app is not in the foreground.
class LifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void set(AppLifecycleState value) => state = value;
}

final lifecycleProvider =
    NotifierProvider<LifecycleNotifier, AppLifecycleState>(LifecycleNotifier.new);