import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/matrix_bridge_session.dart';

class MatrixSession extends ChangeNotifier {
  MatrixSession._(this.client);

  final Client client;
  bool ready = false;
  String? error;
  StreamSubscription<SyncUpdate>? _syncSubscription;
  bool _joiningInvites = false;

  static Future<MatrixSession> create() async {
    final directory = await getApplicationSupportDirectory();
    final database = await sqflite.openDatabase(
      '${directory.path}/friend_matrix.sqlite',
    );
    final matrixDatabase = await MatrixSdkDatabase.init(
      'friend_matrix',
      database: database,
    );
    final client = Client('Friend Matrix', database: matrixDatabase);
    await client.checkHomeserver(Uri.parse('https://matrix.friend.outmcn.net'));
    final session = MatrixSession._(client);
    await session._restore();
    return session;
  }

  static Future<MatrixSession> fromBridgeSession(
    MatrixBridgeSession bridge,
  ) async {
    final session = await create();
    await session.client.init(
      newToken: bridge.accessToken,
      newHomeserver: Uri.parse('https://matrix.friend.outmcn.net'),
      newUserID: bridge.userId,
      newDeviceID: bridge.deviceId,
      newDeviceName: 'Friend Flutter',
      waitUntilLoadCompletedLoaded: false,
    );
    session.ready = true;
    session._startBackgroundSync();
    session.notifyListeners();
    return session;
  }

  static Future<MatrixSession> fromBridgeJson(Map<String, dynamic> json) =>
      fromBridgeSession(MatrixBridgeSession.fromJson(json));

  Future<void> _restore() async {
    try {
      if (client.isLogged()) {
        ready = true;
        _startBackgroundSync();
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void _startBackgroundSync() {
    if (_syncSubscription != null) return;
    client.backgroundSync = true;
    _syncSubscription = client.onSync.stream.listen((_) {
      unawaited(joinInvitedRooms());
      notifyListeners();
    });
    unawaited(joinInvitedRooms());
  }

  Future<void> joinInvitedRooms() async {
    if (_joiningInvites) return;
    _joiningInvites = true;
    try {
      final invites = client.rooms
          .where((room) => room.membership == Membership.invite)
          .toList();
      for (final room in invites) {
        try {
          await room.join();
        } catch (e) {
          error = '加入 Matrix 私聊失败：$e';
        }
      }
      if (invites.isNotEmpty) notifyListeners();
    } finally {
      _joiningInvites = false;
    }
  }

  Future<void> login({required String userId, required String password}) async {
    error = null;
    notifyListeners();
    try {
      await client.login(
        AuthenticationTypes.password,
        identifier: AuthenticationUserIdentifier(user: userId),
        password: password,
        initialDeviceDisplayName: 'Friend Flutter',
      );
      ready = true;
      _startBackgroundSync();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  List<Room> directRooms() => client.rooms
      .where((room) => room.isDirectChat && room.membership == Membership.join)
      .toList();

  List<Room> invitedRooms() => client.rooms
      .where((room) => room.membership == Membership.invite)
      .toList();

  Stream<void> get updates => client.onSync.stream.map((_) {});

  bool get isLoggedIn => ready;

  Future<void> sendText(Room room, String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await room.sendTextEvent(value);
  }

  Future<String> startDirectChat(String matrixUserId) {
    if (!ready || !client.isLogged()) {
      throw StateError('Matrix 会话尚未完成登录');
    }
    return client.startDirectChat(
      matrixUserId,
      enableEncryption: false,
      waitForSync: true,
    );
  }

  Room? roomById(String roomId) => client.getRoomById(roomId);

  Future<void> logout() async {
    await client.logout();
    ready = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    client.dispose();
    super.dispose();
  }
}
