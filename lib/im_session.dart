import 'dart:async';

import 'im_socket.dart';

/// A text message retained until the authenticated socket can send it.
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
  String? _userId;
  ImConnectionState _state = ImConnectionState.disconnected;

  Stream<Map<String, dynamic>> get events => _events.stream;
  FriendImSocket? get socket => _socket;
  String? get userId => _userId;
  ImConnectionState get state => _state;
  bool get isConnected => _state == ImConnectionState.ready;

  Future<void> start(String token) async {
    if (token.isEmpty) return;
    if (_socket != null && _token == token) return;
    await stop(clearOutbox: false);
    _token = token;
    _setState(ImConnectionState.connecting);
    final socket = FriendImSocket(token: token);
    _socket = socket;
    socket.setOnReady((userId) {
      _userId = userId;
      _setState(ImConnectionState.ready);
      final callbacks = List<void Function()>.from(_readyCallbacks);
      _readyCallbacks.clear();
      for (final callback in callbacks) {
        callback();
      }
      _flushOutbox();
    });
    _socketEvents = socket.events.listen((event) {
      final type = event['type'];
      if (type == 'auth:invalid') {
        _setState(ImConnectionState.unauthorized);
      } else if (type == 'closed') {
        _setState(ImConnectionState.disconnected);
      } else if (type == 'error' || type == 'connect_failed') {
        _setState(ImConnectionState.error);
      }
      _events.add(event);
    });
    unawaited(socket.connect());
  }

  void _setState(ImConnectionState value) {
    _state = value;
    _events.add(<String, dynamic>{
      'type': 'im:state',
      'state': value.name,
      'userId': _userId,
    });
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
    if (socket == null || !isConnected || _outbox.isEmpty) return;
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
    if (isConnected) {
      callback();
    } else {
      _readyCallbacks.add(callback);
    }
  }

  Future<void> stop({bool clearOutbox = true}) async {
    _readyCallbacks.clear();
    if (clearOutbox) _outbox.clear();
    await _socketEvents?.cancel();
    _socketEvents = null;
    await _socket?.dispose();
    _socket = null;
    _token = null;
    _userId = null;
    _state = ImConnectionState.disconnected;
  }
}

enum ImConnectionState { disconnected, connecting, ready, unauthorized, error }
