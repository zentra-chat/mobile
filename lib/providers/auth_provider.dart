import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_client.dart';
import '../data/models/index.dart';
import '../data/storage/token_storage.dart';
import '../data/ws/websocket_client.dart';
import 'api_provider.dart';

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

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.ref) : super(const AuthState());

  final Ref ref;

  bool _refreshing = false;

  TokenStorage get _storage => ref.read(tokenStorageProvider);
  ApiClient get _api => ref.read(apiClientProvider);
  WebSocketClient get _ws => ref.read(websocketProvider);

  // Restore a persisted session on app start, if one exists.
  Future<void> init() async {
    final session = await _storage.loadSession();
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
      // Persistence is best-effort: if the secure store is unavailable the
      // session still lives in memory so the app stays usable.
      try {
        await _storage.saveSession(session);
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
      await _storage.saveSession(next);
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

  Future<void> _clearLocal() async {
    await _storage.clear();
    state = const AuthState();
  }

  FullUser? get currentUser => state.session?.user;
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
