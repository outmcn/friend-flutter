import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'im_local_store.dart';
import 'im_socket.dart';
import 'post_service.dart';

enum ImConnectionState { disconnected, connecting, ready, unauthorized, error }

/// App-wide IM session. WebSocket is receive-only for realtime events;
/// user-originated state changes are performed by HTTP APIs.
class ImSession {
  ImSession._();
  static final ImSession instance = ImSession._();

  FriendImSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketEvents;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _readyCallbacks = <void Function()>[];
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
    await stop();
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
      unawaited(_reconcilePendingMessages(token));
    });
    _socketEvents = socket.events.listen((event) {
      final type = event['type'];
      if (type == 'auth:invalid') {
        _readySnapshot = false;
        _setState(ImConnectionState.unauthorized);
      } else if (type == 'closed' || type == 'connect_failed') {
        _readySnapshot = false;
        _setState(ImConnectionState.disconnected);
      } else if (type == 'error') {
        _setState(ImConnectionState.error);
      }
      if (type == 'message:new') {
        final message = event['message'];
        if (message is Map && message['id'] != null && _userId != null) {
          unawaited(_persistIncoming(message.cast<String, dynamic>()));
        }
      } else if (type == 'message:recalled') {
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
        accountId: accountId, message: message);
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

  /// Reconciles pending rows after login/socket readiness without depending on
  /// the currently visible chat page. Sending itself remains HTTP-only.
  Future<void> _reconcilePendingMessages(String token) async {
    final accountId = _userId;
    if (accountId == null) return;
    final pending = await ImLocalStore.pendingMessages(accountId);
    for (final item in pending) {
      final conversationId = '${item['conversationId'] ?? ''}';
      final clientId = '${item['clientId'] ?? ''}';
      final text = '${item['text'] ?? ''}';
      final kind = '${item['kind'] ?? 'text'}';
      if (conversationId.isEmpty || clientId.isEmpty || text.isEmpty) continue;
      final service = DDPostService();
      try {
        final message = await service.reconcilePending(
          token,
          conversationId,
          clientId,
        );
        await ImLocalStore.reconcileAccepted(
          accountId: accountId,
          message: message,
        );
      } on StateError {
        try {
          final message = await service.sendImMessage(
            token,
            conversationId,
            text: text,
            clientId: clientId,
            kind: kind,
          );
          await ImLocalStore.reconcileAccepted(
            accountId: accountId,
            message: message,
          );
        } catch (_) {
          // 保留 pending；下一次启动或用户手动重试继续使用同一 clientId。
        }
      } finally {
        service.dispose();
      }
    }
  }

  void _setState(ImConnectionState value) {
    _state = value;
    _events.add(<String, dynamic>{
      'type': 'im:state',
      'state': value.name,
      'userId': _userId,
    });
  }

  void whenReady(void Function() callback) {
    if (isConnected) {
      callback();
    } else {
      _readyCallbacks.add(callback);
    }
  }

  Future<void> stop() async {
    _readyCallbacks.clear();
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
