import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Authenticated IM WebSocket client with explicit state and diagnostics.
class FriendImSocket {
  FriendImSocket({required this.token});

  final String token;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _closedByOwner = false;
  bool _ready = false;
  bool _sessionReplaced = false;
  int _reconnectAttempt = 0;
  void Function(String userId)? _onReady;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null && _ready;

  void setOnReady(void Function(String userId)? callback) =>
      _onReady = callback;

  Future<void> connect() async {
    if (_closedByOwner || _channel != null) return;
    _emitState('connecting');
    try {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('wss://chat.outmcn.com/ws'),
        pingInterval: const Duration(seconds: 25),
      );
      _channel = channel;
      _ready = false;
      _sessionReplaced = false;
      await channel.ready;
      _reconnectAttempt = 0;
      _subscription = channel.stream.listen(
        _handleEvent,
        onError: (Object error, StackTrace stack) {
          _emitError('socket_error', '$error');
        },
        onDone: _handleClosed,
        cancelOnError: false,
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) => ping());
      send({'type': 'auth', 'token': token});
      _emitState('auth_sent');
    } catch (error) {
      _channel = null;
      _ready = false;
      _emitError('connect_failed', '$error');
      _scheduleReconnect();
    }
  }

  void _handleEvent(dynamic raw) {
    try {
      final payload = raw is String ? raw : utf8.decode(raw as List<int>);
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        _emitError('invalid_frame', 'WebSocket 返回的不是 JSON 对象');
        return;
      }
      final event = decoded.cast<String, dynamic>();
      _events.add(event);
      if (event['type'] == 'ready') {
        _ready = true;
        _onReady?.call('${event['userId'] ?? ''}');
        _emitState('ready', userId: event['userId']);
      } else if (event['type'] == 'auth:invalid') {
        _ready = false;
        _emitState('unauthorized');
      }
    } catch (error) {
      _emitError('invalid_frame', '$error');
    }
  }

  void _handleClosed() {
    _subscription = null;
    _channel = null;
    _ready = false;
    _pingTimer?.cancel();
    _emitState('closed');
    if (!_sessionReplaced) _scheduleReconnect();
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

  void _emitState(String state, {dynamic userId}) {
    _events.add(<String, dynamic>{
      'type': 'im:socket',
      'state': state,
      if (userId != null) 'userId': userId,
    });
  }

  void _emitError(String code, String message) {
    _events.add(<String, dynamic>{
      'type': 'im:socket',
      'state': 'error',
      'code': code,
      'message': message,
    });
  }

  void send(Map<String, dynamic> event) {
    final channel = _channel;
    if (channel == null) {
      _emitError('not_open', 'WebSocket 尚未打开');
      return;
    }
    try {
      channel.sink.add(jsonEncode(event));
    } catch (error) {
      _emitError('send_failed', '$error');
    }
  }

  void ping() => send({'type': 'ping'});

  void sendTyping({required String conversationId, required bool typing}) {
    send({
      'type': typing ? 'typing:start' : 'typing:stop',
      'conversationId': conversationId,
    });
  }

  void markDelivered(
      {required String conversationId, required String messageId}) {
    send({
      'type': 'message:delivered',
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void markRead({required String conversationId, required String messageId}) {
    send({
      'type': 'read:mark',
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void recallMessage(
      {required String conversationId, required String messageId}) {
    send({
      'type': 'message:recall',
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void deleteMessage(
      {required String conversationId, required String messageId}) {
    send({
      'type': 'message:delete',
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void sendText({
    required String conversationId,
    required String text,
    String? clientId,
    String kind = 'text',
  }) {
    send({
      'type': 'message:send',
      'conversationId': conversationId,
      'kind': kind,
      'text': text,
      if (clientId != null) 'clientId': clientId,
    });
  }

  Future<void> dispose() async {
    _closedByOwner = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _events.close();
    _channel = null;
    _ready = false;
  }
}
