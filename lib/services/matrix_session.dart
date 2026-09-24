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

  static Future<MatrixSdkDatabase> _openDatabase() async {
    final directory = await getApplicationSupportDirectory();
    final database = await sqflite.openDatabase(
      '${directory.path}/friend_matrix.sqlite',
    );
    return MatrixSdkDatabase.init('friend_matrix', database: database);
  }

  static Future<MatrixSession> create() async {
    final client = Client('Friend Matrix', database: await _openDatabase());
    await client.checkHomeserver(Uri.parse('https://matrix.friend.outmcn.net'));
    final session = MatrixSession._(client);
    await session._restoreStoredSession();
    return session;
  }

  static Future<MatrixSession> fromBridgeSession(
    MatrixBridgeSession bridge,
  ) async {
    final client = Client('Friend Matrix', database: await _openDatabase());
    final homeserver = Uri.parse('https://matrix.friend.outmcn.net');
    await client.checkHomeserver(homeserver);
    await client.init(
      newToken: bridge.accessToken,
      newHomeserver: homeserver,
      newDeviceName: 'Friend Flutter',
      waitForFirstSync: true,
      waitUntilLoadCompletedLoaded: true,
    );
    if (client.userID == null || client.userID!.isEmpty) {
      throw StateError('Matrix SDK whoami 未返回当前用户 ID');
    }
    final session = MatrixSession._(client);
    session._markReady();
    session._startSyncListener();
    await session.joinInvitedRooms();
    return session;
  }

  static Future<MatrixSession> fromBridgeJson(Map<String, dynamic> json) =>
      fromBridgeSession(MatrixBridgeSession.fromJson(json));

  Future<void> _restoreStoredSession() async {
    try {
      await client.init(
        waitForFirstSync: true,
        waitUntilLoadCompletedLoaded: true,
      );
      if (client.userID != null && client.accessToken != null) {
        _markReady();
        _startSyncListener();
        await joinInvitedRooms();
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void _markReady() {
    if (client.userID == null || client.userID!.isEmpty) {
      throw StateError('Matrix SDK 未返回当前用户 ID');
    }
    if (client.accessToken == null || client.accessToken!.isEmpty) {
      throw StateError('Matrix SDK 未返回 Access Token');
    }
    ready = true;
    notifyListeners();
  }

  void _startSyncListener() {
    if (_syncSubscription != null) return;
    _syncSubscription = client.onSync.stream.listen((_) {
      unawaited(joinInvitedRooms());
      notifyListeners();
    });
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
      _markReady();
      _startSyncListener();
      await joinInvitedRooms();
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

  Future<void> sendReply(Room room, Event event, String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await room.sendTextEvent(value, inReplyTo: event);
  }

  Future<void> editMessage(Room room, Event event, String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await room.sendTextEvent(value, editEventId: event.eventId);
  }

  Future<void> redactMessage(Room room, Event event) async {
    await room.redactEvent(event.eventId);
  }

  bool otherUserHasRead(Room room, Event event) {
    final otherUsers = room.receiptState.global.otherUsers;
    return otherUsers.values.any((receipt) => receipt.eventId == event.eventId);
  }

  String get currentUserId {
    final value = client.userID;
    if (value == null || value.isEmpty) {
      throw StateError('Matrix SDK 当前用户未初始化');
    }
    return value;
  }

  Future<void> setDisplayName(String displayName) async {
    final value = displayName.trim();
    if (value.isEmpty) throw ArgumentError('昵称不能为空');
    await client.setProfileField(currentUserId, 'displayname', {
      'displayname': value,
    });
  }

  Future<String> startDirectChat(String matrixUserId) {
    if (!ready) {
      throw StateError('Matrix SDK 会话尚未初始化完成');
    }
    return client.startDirectChat(matrixUserId);
  }

  Room? roomById(String roomId) => client.getRoomById(roomId);

  Future<void> clearRoomUnread(Room room) async {
    final latest = room.lastEvent;
    if (latest?.eventId == null) return;
    await room.setReadMarker(latest!.eventId, mRead: latest.eventId);
    await room.markUnread(false);
  }

  Future<String> roomDisplayName(Room room) async {
    await room.loadHeroUsers();
    return room.getLocalizedDisplayname();
  }

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
