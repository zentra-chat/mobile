import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/index.dart';

// Real-time gateway client for the websocket.
class WebSocketClient {
  WebSocketClient({
    required this._getWsUrl,
    required this._getAccessToken,
    required this._onAuthFailure,
  });

  final String Function() _getWsUrl;
  final String? Function() _getAccessToken;
  final void Function() _onAuthFailure;

  WebSocketChannel? _channel;
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();

  Stream<WebSocketEvent> get events => _eventController.stream;

  static const int _maxReconnectAttempts = 10;
  static const int _reconnectDelayMs = 1000;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  int _reconnectAttempts = 0;
  bool _isConnecting = false;
  bool _intentionalClose = false;
  bool _connected = false;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  final Set<String> _activeSubscriptions = {};
  final Map<String, int> _subRefCounts = {};
  final List<String> _messageQueue = [];

  void connect() {
    final token = _getAccessToken();
    final url = _getWsUrl();
    if (_channel != null || _isConnecting || token == null || token.isEmpty) {
      return;
    }

    _isConnecting = true;
    _intentionalClose = false;

    final uri = Uri.parse('$url?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      _onData,
      onError: (_) => _scheduleReconnect(),
      onDone: _onDone,
      cancelOnError: false,
    );

    _channel!.ready.then((_) {
      _isConnecting = false;
      _connected = true;
      _reconnectAttempts = 0;
      _startHeartbeat();
      _flushQueue();
      for (final channelId in _activeSubscriptions) {
        _sendRaw({
          'type': 'SUBSCRIBE',
          'data': {'channelId': channelId},
        });
      }
    }).catchError((_) {
      _isConnecting = false;
      _scheduleReconnect();
    });
  }

  void _onData(dynamic message) {
    final text = message.toString();
    for (final part in text.split('\n')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        _eventController.add(WebSocketEvent.fromJson(json));
      } catch (_) {
        // Ignore frames that are not valid JSON.
      }
    }
  }

  void _onDone() {
    _connected = false;
    _stopHeartbeat();
    // Clear the channel handle so a later connect() can open a fresh socket
    // instead of bailing out on the stale (now-closed) one.
    _channel = null;
    _isConnecting = false;
    if (!_intentionalClose && _channel?.closeCode != 1000) {
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      send({'type': 'HEARTBEAT', 'data': {}});
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void _scheduleReconnect() {
    if (_intentionalClose) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _onAuthFailure();
      return;
    }

    final delay = (_reconnectDelayMs * (1 << _reconnectAttempts))
        .clamp(0, 30000);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _reconnectAttempts++;
      connect();
    });
  }

  void _flushQueue() {
    while (_messageQueue.isNotEmpty) {
      final frame = _messageQueue.removeAt(0);
      if (_connected) _channel?.sink.add(frame);
    }
  }

  void _sendRaw(Map<String, dynamic> message) {
    final frame = jsonEncode(message);
    if (_connected) {
      _channel?.sink.add(frame);
    } else {
      _messageQueue.add(frame);
    }
  }

  void send(Map<String, dynamic> message) => _sendRaw(message);

  void subscribe(String channelId) {
    final current = _subRefCounts[channelId] ?? 0;
    _subRefCounts[channelId] = current + 1;
    if (current == 0) {
      _activeSubscriptions.add(channelId);
      _sendRaw({'type': 'SUBSCRIBE', 'data': {'channelId': channelId}});
    }
  }

  void unsubscribe(String channelId) {
    final current = _subRefCounts[channelId] ?? 0;
    if (current <= 1) {
      _subRefCounts.remove(channelId);
      _activeSubscriptions.remove(channelId);
      _sendRaw({'type': 'UNSUBSCRIBE', 'data': {'channelId': channelId}});
      return;
    }
    _subRefCounts[channelId] = current - 1;
  }

  void sendTyping(String channelId) {
    _sendRaw({'type': 'TYPING_START', 'data': {'channelId': channelId}});
  }

  void updatePresence(String status) {
    if (!_connected) return;
    _channel?.sink.add(jsonEncode({
      'type': 'PRESENCE_UPDATE',
      'data': {'status': status},
    }));
  }

  void disconnect() {
    _intentionalClose = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    if (_connected) {
      updatePresence('offline');
      _channel?.sink.close(1000, 'User disconnected');
    }
    _channel = null;
    _connected = false;
    _messageQueue.clear();
    _activeSubscriptions.clear();
    _subRefCounts.clear();
  }

  bool get isConnected => _connected;
}
