import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'im_local_store.dart';
import 'message_send_coordinator.dart';
import 'im_socket.dart';
import 'post_service.dart';

enum ImConnectionState { disconnected, connecting, ready, unauthorized, error }

/// App-wide IM session. WebSocket is receive-only for realtime events;
/// user-originated state changes are performed by HTTP APIs.
class ImSession {
  ImSession._() {
    MessageSendCoordinator.instance.events.listen((event) {
      if (event['accountId'] == _userId) _events.add(event);
    });
  }
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
    unawaited(_resumeMessages(token));
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
      unawaited(MessageSendCoordinator.instance.resume(userId));
    });
    _socketEvents = socket.events.listen((event) {
      final type = event['type'];
      if (type == 'auth:invalid') {
        MessageSendCoordinator.instance.invalidateToken(token);
        _readySnapshot = false;
        _setState(ImConnectionState.unauthorized);
      } else if (type == 'closed' || type == 'connect_failed') {
        _readySnapshot = false;
        _setState(ImConnectionState.disconnected);
      } else if (type == 'error') {
        _setState(ImConnectionState.error);
      }
      if (type == 'call:incoming' || type == 'call:update') {
        final call = event['call'];
        if (call is Map) {
          unawaited(saveCall(call.cast<String, dynamic>(), eventType: '$type')
              .catchError((Object _) => <String, dynamic>{}));
        }
        return;
      }
      if (type == 'message:new') {
        final message = event['message'];
        if (message is Map && message['id'] != null && _userId != null) {
          if ('${message['senderId']}' == _userId) {
            MessageSendCoordinator.instance
                .observeAccepted(_userId!, message.cast<String, dynamic>());
          }
          unawaited(_persistIncoming(message.cast<String, dynamic>())
              .catchError((Object _) {}));
        }
      } else if (type == 'notification:new') {
        final notification = event['notification'];
        if (notification is Map) {
          _events.add({'type': 'notification:new', 'notification': notification.cast<String, dynamic>()});
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

  Future<Map<String, dynamic>> startCall(
      String token, String conversationId) async {
    final service = DDPostService();
    try {
      final result = await service.startImCall(token, conversationId);
      result['call'] =
          await saveCall(Map<String, dynamic>.from(result['call'] as Map));
      return result;
    } finally {
      service.dispose();
    }
  }

  Future<Map<String, dynamic>> updateCall(
      String token, String callId, String action) async {
    final service = DDPostService();
    try {
      final result = await service.updateImCall(token, callId, action);
      result['call'] =
          await saveCall(Map<String, dynamic>.from(result['call'] as Map));
      return result;
    } finally {
      service.dispose();
    }
  }

  Future<void> _callQueue = Future<void>.value();

  Future<Map<String, dynamic>> saveCall(Map<String, dynamic> call,
      {String eventType = 'call:update', bool notify = true}) {
    final sessionAccountId = _userId;
    final operation = _callQueue.then((_) async {
      final accountId = sessionAccountId ??
          (await SharedPreferences.getInstance())
              .getString('friend.auth.userId');
      if (accountId == null ||
          accountId.isEmpty ||
          '${call['id'] ?? ''}'.isEmpty ||
          '${call['conversationId'] ?? call['conversation_id'] ?? ''}'
              .isEmpty) {
        throw StateError('Missing call identity');
      }
      final merged =
          await ImLocalStore.saveCall(accountId: accountId, call: call);
      if (notify && (_userId == null || _userId == accountId)) {
        _events.add({'type': eventType, 'call': merged});
      }
      return merged;
    });
    _callQueue =
        operation.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      _events
          .add({'type': 'call:persistence-error', 'error': error.toString()});
    });
    return operation;
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

  Future<void> _resumeMessages(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != token) return;
    final accountId = prefs.getString('friend.auth.userId');
    if (accountId == null || accountId.isEmpty) return;
    _userId ??= accountId;
    await MessageSendCoordinator.instance.resume(accountId);
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
    await _callQueue;
    _socketEvents = null;
    await _socket?.dispose();
    _socket = null;
    _token = null;
    _userId = null;
    _readySnapshot = false;
    _state = ImConnectionState.disconnected;
  }
}
