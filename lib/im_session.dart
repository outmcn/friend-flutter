import 'dart:async';

import 'im_socket.dart';

/// A text message retained in memory until the authenticated socket is ready.
class _PendingImMessage {
  const _PendingImMessage({
    required this.conversationId,
    required this.text,
    required this.clientId,
  });

  final String conversationId;
  final String text;
  final String clientId;
}

/// App-wide IM session. Pages subscribe to events but never own the socket.
class ImSession {
  ImSession._();
  static final ImSession instance = ImSession._();

  FriendImSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketEvents;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _readyCallbacks = <void Function()>[];
  final _outbox = <_PendingImMessage>[];
  String? _token;

  Stream<Map<String, dynamic>> get events => _events.stream;
  FriendImSocket? get socket => _socket;
  bool get isConnected => _socket?.isConnected == true;

  Future<void> start(String token) async {
    if (token.isEmpty) return;
    if (_socket != null && _token == token) return;
    await stop();
    _token = token;
    final socket = FriendImSocket(token: token);
    _socket = socket;
    socket.setOnReady(() {
      final callbacks = List<void Function()>.from(_readyCallbacks);
      _readyCallbacks.clear();
      for (final callback in callbacks) {
        callback();
      }
      _flushOutbox();
    });
    _socketEvents = socket.events.listen(_events.add);
    unawaited(socket.connect());
  }

  void queueText({
    required String conversationId,
    required String text,
    required String clientId,
  }) {
    _outbox.add(_PendingImMessage(
      conversationId: conversationId,
      text: text,
      clientId: clientId,
    ));
    _flushOutbox();
  }

  void _flushOutbox() {
    final socket = _socket;
    if (socket == null || !socket.isConnected || _outbox.isEmpty) return;
    final pending = List<_PendingImMessage>.from(_outbox);
    _outbox.clear();
    for (final message in pending) {
      socket.sendText(
        conversationId: message.conversationId,
        text: message.text,
        clientId: message.clientId,
      );
    }
  }

  void whenReady(void Function() callback) {
    final socket = _socket;
    if (socket == null) return;
    if (socket.isConnected) {
      callback();
    } else {
      _readyCallbacks.add(callback);
    }
  }

  Future<void> stop() async {
    _readyCallbacks.clear();
    _outbox.clear();
    await _socketEvents?.cancel();
    _socketEvents = null;
    await _socket?.dispose();
    _socket = null;
    _token = null;
  }
}
