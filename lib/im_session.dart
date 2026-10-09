import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'im_local_store.dart';
import 'im_socket.dart';
import 'post_service.dart';

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
  final _ackTimers = <String, Timer>{};
  final _retryCounts = <String, int>{};
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
      } else if (type == 'closed' || type == 'connect_failed') {
        _readySnapshot = false;
        _setState(ImConnectionState.disconnected);
        _requeueInflight();
      } else if (type == 'error') {
        _setState(ImConnectionState.error);
      }
      if (type == 'message:accepted') {
        final clientId =
            '${event['clientId'] ?? event['message']?['clientId'] ?? ''}';
        final message = event['message'];
        if (clientId.isNotEmpty) {
          _inflight.remove(clientId);
          _ackTimers.remove(clientId)?.cancel();
          _retryCounts.remove(clientId);
          if (message is Map && _userId != null) {
            unawaited(ImLocalStore.reconcileAccepted(
              accountId: _userId!,
              message: message.cast<String, dynamic>(),
            ));
          }
        }
      } else if (type == 'message:failed') {
        final clientId =
            '${event['clientId'] ?? event['message']?['clientId'] ?? ''}';
        final failed = clientId.isNotEmpty ? _inflight.remove(clientId) : null;
        _ackTimers.remove(clientId)?.cancel();
        if (failed != null) {
          _retryCounts[clientId] = (_retryCounts[clientId] ?? 0) + 1;
          if ((_retryCounts[clientId] ?? 0) <= 3) {
            _outbox.add(failed);
            _flushOutbox();
          } else {
            _retryCounts.remove(clientId);
          }
        }
      }
      if (type == 'message:new') {
        final message = event['message'];
        if (message is Map && message['id'] != null && _userId != null) {
          unawaited(_persistIncoming(message.cast<String, dynamic>()));
        }
      }
      if (type == 'message:recalled') {
        final message = event['message'];
        if (message is Map && _userId != null) {
          unawaited(ImLocalStore.markRecalled(
            accountId: _userId!,
            message: message.cast<String, dynamic>(),
          ));
        }
      }
      _events.add(event);
    });
    unawaited(socket.connect());
  }

  Future<void> _persistIncoming(Map<String, dynamic> message) async {
    final accountId = _userId;
    final conversationId = '${message['conversationId'] ?? ''}';
    final messageId = '${message['id'] ?? ''}';
    if (accountId == null || conversationId.isEmpty || messageId.isEmpty) {
      return;
    }
    await ImLocalStore.saveIncomingMessage(
      accountId: accountId,
      message: message,
    );
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final durable = await ImLocalStore.durableMessages(
      accountId: accountId,
      conversationId: conversationId,
      messageIds: [messageId],
    );
    final ids = durable.map((row) => '${row['message_id']}').toList();
    if (ids.isEmpty) return;
    final service = DDPostService();
    try {
      await service.confirmImMessagesSynced(token, conversationId, ids);
    } finally {
      service.dispose();
    }
  }

  void _requeueInflight() {
    if (_inflight.isEmpty) return;
    for (final message in _inflight.values) {
      if (!_outbox.any((queued) => queued.clientId == message.clientId)) {
        _outbox.add(message);
      }
      _ackTimers.remove(message.clientId)?.cancel();
      _retryCounts.remove(message.clientId);
    }
    _inflight.clear();
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
            text.isNotEmpty &&
            !_outbox.any((item) => item.clientId == clientId) &&
            !_inflight.containsKey(clientId)) {
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
      _ackTimers[message.clientId]?.cancel();
      _ackTimers[message.clientId] = Timer(const Duration(seconds: 15), () {
        final timedOut = _inflight.remove(message.clientId);
        if (timedOut != null) {
          final retries = (_retryCounts[message.clientId] ?? 0) + 1;
          _retryCounts[message.clientId] = retries;
          if (retries <= 3) {
            _outbox.add(timedOut);
            _flushOutbox();
          } else {
            _retryCounts.remove(message.clientId);
          }
          _events.add(<String, dynamic>{
            'type': 'message:failed',
            'code': 'ack_timeout',
            'clientId': message.clientId,
          });
        }
        _ackTimers.remove(message.clientId);
      });
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
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
    _retryCounts.clear();
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
