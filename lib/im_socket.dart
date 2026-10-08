import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Minimal Friend IM WebSocket client for the first transport slice.
class FriendImSocket {
  FriendImSocket({required this.token, WebSocketChannel? channel})
      : _channel = channel;

  final String token;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null;

  Future<void> connect() async {
    if (_channel != null) return;
    final uri = Uri.parse('wss://friend.outmcn.net/ws');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready;
    _subscription = channel.stream.listen(
      (event) {
        if (event is! String) return;
        try {
          final decoded = jsonDecode(event);
          if (decoded is Map) {
            _events.add(decoded.cast<String, dynamic>());
          }
        } catch (_) {
          _events.add(<String, dynamic>{
            'type': 'error',
            'code': 'invalid_json',
          });
        }
      },
      onError: (Object error, StackTrace stack) {
        _events.add(<String, dynamic>{
          'type': 'error',
          'code': 'socket_error',
          'message': '$error',
        });
      },
      onDone: () {
        _events.add(<String, dynamic>{'type': 'closed'});
        _channel = null;
      },
      cancelOnError: false,
    );
    send({'type': 'auth', 'token': token});
  }

  void send(Map<String, dynamic> event) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(event));
  }

  void ping() => send({'type': 'ping'});

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
