import 'dart:async';

import 'im_socket.dart';

/// App-wide IM session. Pages subscribe to events but never own the socket.
class ImSession {
  ImSession._();
  static final ImSession instance = ImSession._();

  FriendImSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketEvents;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _readyCallbacks = <void Function()>[];
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
    });
    _socketEvents = socket.events.listen(_events.add);
    unawaited(socket.connect());
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
    await _socketEvents?.cancel();
    _socketEvents = null;
    await _socket?.dispose();
    _socket = null;
    _token = null;
  }
}
