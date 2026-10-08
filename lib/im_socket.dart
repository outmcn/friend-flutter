import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Authenticated IM WebSocket client with heartbeat and bounded reconnect.
class FriendImSocket {
  FriendImSocket({required this.token, WebSocketChannel? channel})
      : _channel = channel;

  final String token;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _closedByOwner = false;
  int _reconnectAttempt = 0;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null;

  Future<void> connect() async {
    if (_closedByOwner || _channel != null) return;
    final channel = _channel ??
        WebSocketChannel.connect(Uri.parse('wss://chat.outmcn.com/ws'));
    _channel = channel;
    try {
      await channel.ready;
      _reconnectAttempt = 0;
      _subscription = channel.stream.listen(
        _handleEvent,
        onError: (Object error, StackTrace stack) {
          _events.add(<String, dynamic>{
            'type': 'error',
            'code': 'socket_error',
            'message': '$error',
          });
        },
        onDone: _handleClosed,
        cancelOnError: false,
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) => ping());
      send({'type': 'auth', 'token': token});
    } catch (error) {
      _channel = null;
      _events.add(<String, dynamic>{
        'type': 'error',
        'code': 'connect_failed',
        'message': '$error',
      });
      _scheduleReconnect();
    }
  }

  void _handleEvent(dynamic event) {
    if (event is! String) return;
    try {
      final decoded = jsonDecode(event);
      if (decoded is Map) _events.add(decoded.cast<String, dynamic>());
    } catch (_) {
      _events.add(<String, dynamic>{'type': 'error', 'code': 'invalid_json'});
    }
  }

  void _handleClosed() {
    _subscription = null;
    _channel = null;
    _pingTimer?.cancel();
    _events.add(<String, dynamic>{'type': 'closed'});
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closedByOwner || _reconnectTimer?.isActive == true) return;
    final seconds = (1 << _reconnectAttempt.clamp(0, 4)).clamp(1, 16);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(connect());
    });
  }

  void send(Map<String, dynamic> event) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(event));
  }

  void ping() => send({'type': 'ping'});

  void markRead({required String conversationId, required String messageId}) {
    send({
      'type': 'read:mark',
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void sendText({
    required String conversationId,
    required String text,
    String? clientId,
  }) {
    send({
      'type': 'message:send',
      'conversationId': conversationId,
      'text': text,
      if (clientId != null) 'clientId': clientId,
    });
  }

  Future<void> close() async {
    _closedByOwner = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }
}
