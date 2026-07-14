import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/api/api_client.dart';
import '../data/models/index.dart';
import '../data/storage/token_storage.dart';
import '../data/ws/websocket_client.dart';
import 'api_provider.dart';
import 'instance_provider.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }

class AuthState {
  final AuthStatus status;
  final Session? session;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.session,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    Session? session,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  bool _refreshing = false;

  TokenStorage get _storage => ref.read(tokenStorageProvider);
  ApiClient get _api => ref.read(apiClientProvider);
  WebSocketClient get _ws => ref.read(websocketProvider);

  String? get _activeId => ref.read(activeInstanceIdProvider);

  // Restore persisted instances + the session for the active instance on
  // startup. Seeds the default instance (from env) when storage is empty so
  // the app is usable on first launch.
  Future<void> init() async {
    final storage = ref.read(instanceStorageProvider);
    var instances = await storage.loadInstances();
    if (instances.isEmpty) {
      instances = [AppConfig.defaultInstance];
      await storage.saveInstances(instances);
    }
    var activeId = await storage.loadActiveId();
    if (activeId == null || !instances.any((instance) => instance.id == activeId)) {
      activeId = instances.first.id;
      await storage.saveActiveId(activeId);
    }
    // Bring the providers in sync so the UI reflects persisted state.
    ref.read(instancesProvider.notifier).setAll(instances);
    ref.read(activeInstanceIdProvider.notifier).set(activeId);

    final session = await _storage.loadSession(activeId);
    if (session == null) return;
    state = state.copyWith(status: AuthStatus.authenticated, session: session);
    _ws.connect();
  }

  Future<void> login(String login, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, error: null);
    try {
      final response = await _api.login(LoginRequest(
        login: login,
        password: password,
      ));
      final session = Session.fromAuth(response);
      final activeId = _activeId ?? AppConfig.defaultInstance.id;
      // Persistence is best-effort: if the secure store is unavailable the
      // session still lives in memory so the app stays usable.
      try {
        await _storage.saveSession(activeId, session);
      } catch (e) {
        debugPrint('Failed to persist session, continuing in-memory: $e');
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
      );
      _ws.connect();
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.message,
      );
      rethrow;
    }
  }

  // Attempt to refresh the access token. Returns false (and logs out) on failure.
  // Guarded so concurrent 401s don't trigger multiple simultaneous refreshes.
  Future<bool> refreshSession() async {
    final session = state.session;
    if (session == null) {
      forceLogout();
      return false;
    }
    if (_refreshing) {
      // Wait briefly for the in-flight refresh to settle, then report outcome.
      for (var i = 0; i < 50 && _refreshing; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return state.session != null;
    }
    _refreshing = true;
    try {
      final response = await _api.refreshToken(session.refreshToken);
      final next = Session.fromAuth(response);
      final activeId = _activeId ?? AppConfig.defaultInstance.id;
      await _storage.saveSession(activeId, next);
      state = state.copyWith(session: next);
      return true;
    } catch (_) {
      forceLogout();
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Best effort; we still clear the local session below.
    }
    await _clearLocal();
  }

  // Called when the API layer determines the session is no longer valid.
  void forceLogout() {
    _ws.disconnect();
    _clearLocal();
  }

  // Switches the active instance, carrying over that instance's own session.
  // If the target instance has no stored session the user is taken to login.
  Future<void> switchInstance(String id) async {
    if (id == _activeId) return;
    _ws.disconnect();
    ref.read(activeInstanceIdProvider.notifier).set(id);
    final session = await _storage.loadSession(id);
    if (session == null) {
      state = const AuthState();
      return;
    }
    state = state.copyWith(
      status: AuthStatus.authenticated,
      session: session,
    );
    _ws.connect();
  }

  Future<void> _clearLocal() async {
    final activeId = _activeId;
    if (activeId != null) await _storage.clear(activeId);
    state = const AuthState();
  }

  FullUser? get currentUser => state.session?.user;
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
