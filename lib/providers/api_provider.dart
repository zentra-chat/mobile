import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import '../data/api/api_client.dart';
import '../data/storage/token_storage.dart';
import '../data/ws/websocket_client.dart';
import 'auth_provider.dart';
import 'instance_provider.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    getBaseUrl: () => ref.read(instanceProvider).apiBaseUrl,
    getAccessToken: () => ref.read(authProvider).session?.accessToken,
    onUnauthorized: () => ref.read(authProvider.notifier).refreshSession(),
    onAuthFailure: () => ref.read(authProvider.notifier).forceLogout(),
  );
});

final websocketProvider = Provider<WebSocketClient>((ref) {
  return WebSocketClient(
    getWsUrl: () => ref.read(instanceProvider).wsUrl,
    getAccessToken: () => ref.read(authProvider).session?.accessToken,
    onAuthFailure: () => ref.read(authProvider.notifier).forceLogout(),
  );
});
