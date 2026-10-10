import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'im_local_store.dart';
import 'im_socket.dart';
import 'post_service.dart';

/// A text message retained until the authenticated socket can send it.
class _PendingImMessage {
  const _PendingImMessage({
    required this.conversationId,
    required this.text,
    required this.clientId,
    this.kind = 'text',
  });

  final String conversationId;
  final String text;
  final String clientId;
  final String kind;
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
  final _retryUntil = <String, DateTime>{};
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
      if (_userId != null) {
        unawaited(restorePending(_userId!));
      }
      _flushOutbox();
      unawaited(reconcilePendingMessages(token));
    });
    _socketEvents = socket.events.listen((event) {
      var suppressEvent = false;
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
          final accepted = _inflight.remove(clientId);
          _ackTimers.remove(clientId)?.cancel();
          _retryUntil.remove(clientId);
          _retryCounts.remove(clientId);
          if (accepted != null) {
            _setRetryState(
              clientId,
              conversationId: accepted.conversationId,
              status: 'sent',
            );
          }
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
          final retryCount =
              _retryCounts[clientId] = (_retryCounts[clientId] ?? 0) + 1;
          final until = _retryUntil[clientId] ?? DateTime.now();
          if (DateTime.now().isBefore(until)) {
            _outbox.add(failed);
            _setRetryState(
              clientId,
              conversationId: failed.conversationId,
              status: 'pending',
              retryCount: retryCount,
              error: '${event['code'] ?? 'send_failed'}',
            );
            _flushOutbox();
            suppressEvent = true;
          } else {
            _retryUntil.remove(clientId);
            _retryCounts.remove(clientId);
            _setRetryState(
              clientId,
              conversationId: failed.conversationId,
              status: 'failed',
              error: 'retry_expired',
              retryCount: retryCount,
            );
            _events.add(<String, dynamic>{
              'type': 'message:failed',
              'code': 'retry_expired',
              'clientId': clientId,
            });
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
      if (!suppressEvent) _events.add(event);
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
    final kind = '${message['kind'] ?? 'text'}';
    final objectKey = '${message['text'] ?? ''}';
    if (kind == 'image' || kind == 'audio') {
      final service = DDPostService();
      try {
        final url = await service.mediaUrlForKey(token, objectKey);
        final response = await http.get(Uri.parse(url));
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            response.bodyBytes.isEmpty) {
          return;
        }
        await ImLocalStore.saveImage(objectKey, response.bodyBytes);
      } catch (_) {
        return;
      } finally {
        service.dispose();
      }
    }
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
      _retryUntil[message.clientId] ??=
          DateTime.now().add(const Duration(minutes: 1));
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

  Future<void> reconcilePendingMessages(String token) async {
    final accountId = _userId;
    if (accountId == null) return;
    final pending = await ImLocalStore.pendingMessages(accountId);
    for (final item in pending) {
      final conversationId = '${item['conversationId'] ?? ''}';
      final clientId = '${item['clientId'] ?? ''}';
      if (conversationId.isEmpty || clientId.isEmpty) continue;
      final service = DDPostService();
      try {
        final message =
            await service.reconcilePending(token, conversationId, clientId);
        await ImLocalStore.reconcileAccepted(
            accountId: accountId, message: message);
      } on StateError {
        // 未被服务器接受，保留 pending。
      } finally {
        service.dispose();
      }
    }
  }

  Future<void> restorePending(String accountId) async {
    try {
      final pending = await ImLocalStore.pendingMessages(accountId);
      for (final message in pending) {
        final conversationId = '${message['conversationId'] ?? ''}';
        final clientId = '${message['clientId'] ?? ''}';
        final text = '${message['text'] ?? ''}';
        final persistedUntil = DateTime.tryParse(
          '${message['retryUntil'] ?? ''}',
        );
        final retryUntil =
            persistedUntil ?? DateTime.now().add(const Duration(minutes: 1));
        if (clientId.isNotEmpty && !DateTime.now().isBefore(retryUntil)) {
          await ImLocalStore.updateRetryState(
            accountId: accountId,
            conversationId: conversationId,
            clientId: clientId,
            status: 'failed',
            lastError: 'retry_expired',
          );
          _events.add(<String, dynamic>{
            'type': 'message:failed',
            'code': 'retry_expired',
            'clientId': clientId,
          });
          continue;
        }
        _retryUntil[clientId] = retryUntil;
        if (conversationId.isNotEmpty &&
            clientId.isNotEmpty &&
            text.isNotEmpty &&
            !_outbox.any((item) => item.clientId == clientId) &&
            !_inflight.containsKey(clientId)) {
          _outbox.add(_PendingImMessage(
            conversationId: conversationId,
            text: text,
            clientId: clientId,
            kind: '${message['kind'] ?? 'text'}',
          ));
        }
      }
      _flushOutbox();
    } catch (_) {}
  }

  void _setRetryState(
    String clientId, {
    required String conversationId,
    required String status,
    String? error,
    int? retryCount,
  }) {
    final now = DateTime.now();
    final until = _retryUntil[clientId];
    unawaited(ImLocalStore.updateRetryState(
      accountId: _userId ?? '',
      conversationId: conversationId,
      clientId: clientId,
      status: status,
      retryStartedAt: status == 'pending' ? now.toIso8601String() : null,
      retryUntil: status == 'pending' ? until?.toIso8601String() : null,
      retryCount: retryCount,
      lastError: error,
    ));
  }

  void queueText({
    required String conversationId,
    required String text,
    required String clientId,
  }) {
    _retryUntil[clientId] = DateTime.now().add(const Duration(minutes: 1));
    _setRetryState(clientId, conversationId: conversationId, status: 'pending');
    _outbox.add(_PendingImMessage(
      conversationId: conversationId,
      text: text,
      clientId: clientId,
    ));
    _flushOutbox();
  }

  void queueMessage({
    required String conversationId,
    required String text,
    required String clientId,
    required String kind,
  }) {
    _retryUntil[clientId] = DateTime.now().add(const Duration(minutes: 1));
    _setRetryState(clientId, conversationId: conversationId, status: 'pending');
    _outbox.add(_PendingImMessage(
      conversationId: conversationId,
      text: text,
      clientId: clientId,
      kind: kind,
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
        kind: message.kind,
      );
      _ackTimers[message.clientId]?.cancel();
      _ackTimers[message.clientId] = Timer(const Duration(seconds: 15), () {
        final timedOut = _inflight.remove(message.clientId);
        if (timedOut != null) {
          final retryCount = _retryCounts[message.clientId] =
              (_retryCounts[message.clientId] ?? 0) + 1;
          final until = _retryUntil[message.clientId] ?? DateTime.now();
          if (DateTime.now().isBefore(until)) {
            _outbox.add(timedOut);
            _setRetryState(
              message.clientId,
              conversationId: timedOut.conversationId,
              status: 'pending',
              retryCount: retryCount,
              error: 'ack_timeout',
            );
            _flushOutbox();
          } else {
            _setRetryState(
              message.clientId,
              conversationId: timedOut.conversationId,
              status: 'failed',
              error: 'retry_expired',
              retryCount: retryCount,
            );
            _events.add(<String, dynamic>{
              'type': 'message:failed',
              'code': 'retry_expired',
              'clientId': message.clientId,
            });
          }
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
    _retryUntil[clientId] = DateTime.now().add(const Duration(minutes: 1));
    _setRetryState(clientId, conversationId: conversationId, status: 'pending');
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
    _retryUntil.clear();
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
