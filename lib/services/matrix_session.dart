import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../services/api_client.dart';

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
  final Map<int, Map<String, dynamic>> _friendProfiles = {};
  Map<String, dynamic>? _ownProfile;
  final Map<String, int> _roomAvatarIds = {};
  final Map<String, Uri> _attachmentUris = {};
  final Map<String, Future<Uri?>> _attachmentLoads = {};
  final Map<String, Uint8List> _attachmentBytes = {};
  final Map<String, Future<Uint8List>> _attachmentByteLoads = {};
  final Map<String, MatrixRoomSummary> _roomSummaries = {};
  final Map<String, Timeline> _timelines = {};
  sqflite.Database? _cacheDatabase;

  Future<void> _openSummaryCache() async {
    if (_cacheDatabase != null) return;
    final directory = await getApplicationSupportDirectory();
    _cacheDatabase = await sqflite.openDatabase(
      '${directory.path}/friend_matrix_cache.sqlite',
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE room_summary ('
          'room_id TEXT PRIMARY KEY, peer_id TEXT, title TEXT NOT NULL, '
          'preview TEXT NOT NULL, timestamp INTEGER NOT NULL, '
          'unread_count INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE friend_profile ('
          'friend_id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE media_cache ('
          'event_id TEXT PRIMARY KEY, uri TEXT NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE friend_profile ('
            'friend_id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE media_cache ('
            'event_id TEXT PRIMARY KEY, uri TEXT NOT NULL)',
          );
        }
      },
    );
  }

  Future<void> loadCachedRoomSummaries() async {
    await _openSummaryCache();
    final rows = await _cacheDatabase!.query('room_summary');
    for (final row in rows) {
      _roomSummaries[row['room_id'] as String] = MatrixRoomSummary(
        roomId: row['room_id'] as String,
        peerId: row['peer_id'] as String?,
        title: row['title'] as String,
        preview: row['preview'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        unreadCount: row['unread_count'] as int,
      );
    }
    final profiles = await _cacheDatabase!.query('friend_profile');
    for (final row in profiles) {
      final id = row['friend_id'] as int;
      final profile = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String),
      );
      if (id == -1) {
        _ownProfile = profile;
      } else {
        _friendProfiles[id] = profile;
      }
    }
    final media = await _cacheDatabase!.query('media_cache');
    for (final row in media) {
      _attachmentUris[row['event_id'] as String] = Uri.parse(
        row['uri'] as String,
      );
    }
    notifyListeners();
  }

  List<MatrixRoomSummary> get cachedRoomSummaries =>
      _roomSummaries.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  void refreshRoomSummaries() {
    for (final room in directRooms()) {
      final event = room.lastEvent;
      if (event == null) continue;
      _roomSummaries[room.id] = MatrixRoomSummary(
        roomId: room.id,
        peerId: room.directChatMatrixID,
        title: room.getLocalizedDisplayname(),
        preview: _summaryPreview(event),
        timestamp: event.originServerTs,
        unreadCount: room.notificationCount,
      );
      unawaited(_persistRoomSummary(_roomSummaries[room.id]!));
    }
    notifyListeners();
  }

  String _summaryPreview(Event event) {
    if (event.messageType == MessageTypes.Image) return '[图片]';
    if (event.redacted || event.body == 'Redacted') return '消息已撤回';
    return event.body.trim();
  }

  Future<void> _persistRoomSummary(MatrixRoomSummary summary) async {
    await _openSummaryCache();
    await _cacheDatabase!.insert(
      'room_summary',
      summary.toMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Timeline? cachedTimeline(String roomId) => _timelines[roomId];

  Future<Timeline> loadRoomTimeline(
    Room room, {
    int limit = 60,
    VoidCallback? onUpdate,
  }) async {
    final cached = _timelines[room.id];
    if (cached != null) return cached;
    final loaded = await room.getTimeline(limit: limit, onUpdate: onUpdate);
    _timelines[room.id] = loaded;
    return loaded;
  }

  Uri? cachedAttachmentUri(String eventId) => _attachmentUris[eventId];

  String? _mediaDirectoryPath;

  Future<void> _ensureMediaDirectory() async {
    if (_mediaDirectoryPath != null) return;
    final directory = await getApplicationSupportDirectory();
    final media = Directory('${directory.path}/friend_matrix_media');
    await media.create(recursive: true);
    _mediaDirectoryPath = media.path;
  }

  File _attachmentFile(Event event) {
    final name = base64Url
        .encode(utf8.encode(event.eventId))
        .replaceAll('=', '');
    return File('$_mediaDirectoryPath/$name.bin');
  }

  Future<File?> cachedAttachmentFile(Event event) async {
    await _ensureMediaDirectory();
    final file = _attachmentFile(event);
    return await file.exists() ? file : null;
  }

  Future<Uint8List> loadAttachmentBytes(Event event) {
    final cached = _attachmentBytes[event.eventId];
    if (cached != null) return Future.value(cached);
    final pending = _attachmentByteLoads[event.eventId];
    if (pending != null) return pending;
    final load = _loadAttachmentBytes(event).then((bytes) {
      _attachmentBytes[event.eventId] = bytes;
      _attachmentByteLoads.remove(event.eventId);
      return bytes;
    });
    _attachmentByteLoads[event.eventId] = load;
    return load;
  }

  Future<Uint8List> _loadAttachmentBytes(Event event) async {
    await _ensureMediaDirectory();
    final local = _attachmentFile(event);
    if (await local.exists()) return local.readAsBytes();
    final file = await event.downloadAndDecryptAttachment(getThumbnail: true);
    await local.writeAsBytes(file.bytes, flush: true);
    return file.bytes;
  }

  Future<Uri?> loadAttachmentUri(Event event) {
    final cached = _attachmentUris[event.eventId];
    if (cached != null) return Future.value(cached);
    final pending = _attachmentLoads[event.eventId];
    if (pending != null) return pending;
    final load = event.getAttachmentUri(getThumbnail: true).then((uri) {
      if (uri != null) {
        _attachmentUris[event.eventId] = uri;
        unawaited(_persistMedia(event.eventId, uri));
      }
      _attachmentLoads.remove(event.eventId);
      return uri;
    });
    _attachmentLoads[event.eventId] = load;
    return load;
  }

  Future<void> _persistMedia(String eventId, Uri uri) async {
    await _openSummaryCache();
    await _cacheDatabase!.insert('media_cache', {
      'event_id': eventId,
      'uri': uri.toString(),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  int? cachedRoomAvatarId(String roomId) => _roomAvatarIds[roomId];

  Map<String, dynamic>? cachedFriendProfile(int friendId) =>
      _friendProfiles[friendId];

  Map<String, dynamic>? get cachedOwnProfile => _ownProfile;

  void cacheOwnProfile(Map<String, dynamic> profile) {
    _ownProfile = profile;
    unawaited(_persistProfile(-1, profile));
  }

  Future<Map<String, dynamic>?> loadFriendProfile({
    required String token,
    required int friendId,
    String? roomId,
  }) async {
    final cached = _friendProfiles[friendId];
    if (cached != null) {
      if (roomId != null) {
        final avatar = (cached['avatarId'] as num?)?.toInt();
        if (avatar != null) _roomAvatarIds[roomId] = avatar.clamp(0, 9);
      }
      return cached;
    }
    final response = await ApiClient(token: token).get('/api/users/$friendId');
    final raw = response['data'];
    if (raw is! Map) return null;
    final profile = Map<String, dynamic>.from(raw);
    final nested = profile['profile'];
    if (nested is Map && profile['avatarId'] == null) {
      profile['avatarId'] = nested['avatarId'];
    }
    _friendProfiles[friendId] = profile;
    unawaited(_persistProfile(friendId, profile));
    final avatar = (profile['avatarId'] as num?)?.toInt();
    if (roomId != null && avatar != null) {
      _roomAvatarIds[roomId] = avatar.clamp(0, 9);
    }
    return profile;
  }

  Future<void> _persistProfile(
    int friendId,
    Map<String, dynamic> profile,
  ) async {
    await _openSummaryCache();
    await _cacheDatabase!.insert('friend_profile', {
      'friend_id': friendId,
      'payload': jsonEncode(profile),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

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
    final session = MatrixSession._(client);
    await session.loadCachedRoomSummaries();
    await client.init(
      newToken: bridge.accessToken,
      newHomeserver: homeserver,
      newDeviceName: 'Friend Flutter',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );
    if (client.userID == null || client.userID!.isEmpty) {
      throw StateError('Matrix SDK whoami 未返回当前用户 ID');
    }
    session._markReady();
    session._startSyncListener();
    unawaited(session._finishInitialSync());
    return session;
  }

  Future<void> _finishInitialSync() async {
    try {
      await client.onSync.stream.first;
      refreshRoomSummaries();
      await joinInvitedRooms();
    } catch (_) {}
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
      refreshRoomSummaries();
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

  List<Room> directRooms() {
    final byPeer = <String, Room>{};
    for (final room in client.rooms.where(
      (room) => room.isDirectChat && room.membership == Membership.join,
    )) {
      final peer = room.directChatMatrixID;
      if (peer == null) continue;
      final previous = byPeer[peer];
      if (previous == null ||
          room.latestEventReceivedTime.isAfter(
            previous.latestEventReceivedTime,
          )) {
        byPeer[peer] = room;
      }
    }
    return byPeer.values.toList();
  }

  Room? directRoomForUser(String matrixUserId) {
    final rooms = client.rooms.where(
      (room) =>
          room.membership == Membership.join &&
          room.directChatMatrixID == matrixUserId,
    );
    Room? selected;
    for (final room in rooms) {
      if (selected == null ||
          room.latestEventReceivedTime.isAfter(
            selected.latestEventReceivedTime,
          )) {
        selected = room;
      }
    }
    return selected;
  }

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

  Future<String> sendFile(
    Room room, {
    required Uint8List bytes,
    required String name,
    String? mimeType,
  }) async {
    final file = MatrixFile.fromMimeType(
      bytes: bytes,
      name: name,
      mimeType: mimeType,
    );
    return await room.sendFileEvent(file) ?? '';
  }

  Future<String> sendReply(Room room, Event event, String text) async {
    final value = text.trim();
    if (value.isEmpty) return '';
    final eventId = await room.sendTextEvent(value, inReplyTo: event);
    return eventId ?? '';
  }

  Future<void> redactMessage(Room room, Event event) async {
    await room.redactEvent(event.eventId);
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

class MatrixRoomSummary {
  const MatrixRoomSummary({
    required this.roomId,
    required this.peerId,
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.unreadCount,
  });

  final String roomId;
  final String? peerId;
  final String title;
  final String preview;
  final DateTime timestamp;
  final int unreadCount;

  Map<String, Object?> toMap() => {
    'room_id': roomId,
    'peer_id': peerId,
    'title': title,
    'preview': preview,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'unread_count': unreadCount,
  };
}
