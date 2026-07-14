import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

// The active Zentra instance the app is talking to. Starts with the configured
// default; later this can be backed by saved instances once that UI exists.
final instanceProvider = StateProvider<Instance>((ref) => AppConfig.defaultInstance);
