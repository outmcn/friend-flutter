import 'dart:async';

import 'im_socket.dart';

/// App-wide IM session. Pages subscribe to events but never own the socket.
class ImSession {
  ImSession._();
  static final ImSession instance = ImSession._();

  FriendImSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketEvents;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
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
    _socketEvents = socket.events.listen(_events.add);
    unawaited(socket.connect());
  }

  Future<void> stop() async {
    await _socketEvents?.cancel();
    _socketEvents = null;
    await _socket?.dispose();
    _socket = null;
    _token = null;
  }
}
