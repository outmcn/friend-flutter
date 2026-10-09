import 'dart:async';

import 'im_local_store.dart';
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

enum ImConnectionState { disconnected, connecting, ready, unauthorized, error }

/// App-wide IM store. It owns the only socket and the authoritative connection state.
class ImSession {
  ImSession._();
  static final ImSession instance = ImSession._();

  FriendImSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketEvents;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _readyCallbacks = <void Function()>[];
  final _outbox = <_PendingImMessage>[];
  final _inflight = <String, _PendingImMessage>{};
  String? _token;
  String? _userId;
  ImConnectionState _state = ImConnectionState.disconnected;
  bool _readySnapshot = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  FriendImSocket? get socket => _socket;
  String? get userId => _userId;
  ImConnectionState get state => _state;
  bool get isConnected => _state == ImConnectionState.ready;
  bool get hasReadySnapshot => _readySnapshot;

  Future<void> start(String token) async {
    if (token.isEmpty) return;
    if (_socket != null && _token == token) return;
    await stop(clearOutbox: false);
    _token = token;
    _userId = null;
    _readySnapshot = false;
    _setState(ImConnectionState.connecting);
    final socket = FriendImSocket(token: token);
    _socket = socket;
    socket.setOnReady((userId) {
      _userId = userId;
      _readySnapshot = true;
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
        _readySnapshot = false;
        _setState(ImConnectionState.unauthorized);
      } else if (type == 'closed') {
        _readySnapshot = false;
        _setState(ImConnectionState.disconnected);
      } else if (type == 'error' || type == 'connect_failed') {
        _setState(ImConnectionState.error);
      }
      if (type == 'message:accepted') {
        final clientId =
            '${event['clientId'] ?? event['message']?['clientId'] ?? ''}';
        if (clientId.isNotEmpty) _inflight.remove(clientId);
      } else if (type == 'message:failed') {
        final clientId =
            '${event['clientId'] ?? event['message']?['clientId'] ?? ''}';
        final failed = clientId.isNotEmpty ? _inflight.remove(clientId) : null;
        if (failed != null) _outbox.add(failed);
      }
      if (type == 'message:new') {
        final message = event['message'];
        if (message is Map && message['id'] != null) {
          final conversationId = '${message['conversationId'] ?? ''}';
          final messageId = '${message['id'] ?? ''}';
          if (conversationId.isNotEmpty && messageId.isNotEmpty) {
            _socket?.markDelivered(
              conversationId: conversationId,
              messageId: messageId,
            );
          }
        }
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

  Future<void> restorePending(String accountId) async {
    try {
      final pending = await ImLocalStore.pendingMessages(accountId);
      for (final message in pending) {
        final conversationId = '${message['conversationId'] ?? ''}';
        final clientId = '${message['clientId'] ?? ''}';
        final text = '${message['text'] ?? ''}';
        if (conversationId.isNotEmpty &&
            clientId.isNotEmpty &&
            text.isNotEmpty) {
          _outbox.add(_PendingImMessage(
            conversationId: conversationId,
            text: text,
            clientId: clientId,
          ));
        }
      }
      _flushOutbox();
    } catch (_) {}
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
    for (final message in pending) {
      _inflight[message.clientId] = message;
      socket.sendText(
        conversationId: message.conversationId,
        text: message.text,
        clientId: message.clientId,
      );
    }
    _outbox.removeWhere(
        (queued) => pending.any((sent) => sent.clientId == queued.clientId));
  }

  void requeueText({
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

  void whenReady(void Function() callback) {
    if (isConnected) {
      callback();
    } else {
      _readyCallbacks.add(callback);
    }
  }

  Future<void> stop({bool clearOutbox = true}) async {
    _readyCallbacks.clear();
    _inflight.clear();
    if (clearOutbox) _outbox.clear();
    await _socketEvents?.cancel();
    _socketEvents = null;
    await _socket?.dispose();
    _socket = null;
    _token = null;
    _userId = null;
    _readySnapshot = false;
    _state = ImConnectionState.disconnected;
  }
}
