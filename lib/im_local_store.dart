import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Per-user SQLite cache for IM messages and delivery state.
class ImLocalStore {
  static Database? _database;

  static Future<Database> _db() async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'friend_im.sqlite'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            account_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            client_id TEXT,
            sender_id TEXT NOT NULL,
            text TEXT NOT NULL,
            kind TEXT NOT NULL DEFAULT 'text',
            duration_ms INTEGER NOT NULL DEFAULT 0,
            created_at TEXT,
            status TEXT NOT NULL DEFAULT 'sent',
            PRIMARY KEY (account_id, conversation_id, message_id)
          )
        ''');
        await db.execute('''
          CREATE INDEX messages_cursor_idx
          ON messages(account_id, conversation_id, message_id)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'");
          await db.execute(
              "ALTER TABLE messages ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0");
        }
      },
    );
    return _database!;
  }

  static Future<List<Map<String, dynamic>>> messages({
    required String accountId,
    required String conversationId,
  }) async {
    final rows = await (await _db()).query(
      'messages',
      where: 'account_id = ? AND conversation_id = ?',
      whereArgs: [accountId, conversationId],
      orderBy: 'CAST(message_id AS INTEGER) ASC',
    );
    return rows.map((row) {
      final item = Map<String, dynamic>.from(row);
      return <String, dynamic>{
        'id': '${item['message_id'] ?? ''}',
        'conversationId': '${item['conversation_id'] ?? ''}',
        'clientId': item['client_id'],
        'senderId': '${item['sender_id'] ?? ''}',
        'text': '${item['text'] ?? ''}',
        'kind': '${item['kind'] ?? 'text'}',
        'durationMs': (item['duration_ms'] as num?)?.toInt() ?? 0,
        'createdAt': item['created_at'],
        'status': '${item['status'] ?? 'sent'}',
      };
    }).toList();
  }

  static Future<void> saveMessages({
    required String accountId,
    required String conversationId,
    required List<Map<String, dynamic>> messages,
  }) async {
    final db = await _db();
    final batch = db.batch();
    for (final message in messages) {
      final id = '${message['id'] ?? ''}';
      if (id.isEmpty) continue;
      batch.insert(
        'messages',
        {
          'account_id': accountId,
          'conversation_id': conversationId,
          'message_id': id,
          'client_id': message['clientId'],
          'sender_id': '${message['senderId'] ?? ''}',
          'text': '${message['text'] ?? ''}',
          'kind': '${message['kind'] ?? 'text'}',
          'duration_ms': (message['durationMs'] as num?)?.toInt() ?? 0,
          'created_at': '${message['createdAt'] ?? ''}',
          'status': '${message['status'] ?? 'sent'}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> saveConversations({
    required String accountId,
    required List<Map<String, dynamic>> conversations,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(path.join(dir.path, 'im-conversations-$accountId.json'));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(conversations), flush: true);
    await temp.rename(file.path);
  }

  static Future<List<Map<String, dynamic>>> conversations(
      String accountId) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(path.join(dir.path, 'im-conversations-$accountId.json'));
    if (!await file.exists()) return <Map<String, dynamic>>[];
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is List) {
        return data
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> migrateLegacyAudioKeys() async {
    final db = await _db();
    final columns = await db.rawQuery('PRAGMA table_info(messages)');
    final names = columns.map((row) => '${row['name']}').toSet();
    if (!names.contains('kind')) {
      await db.execute(
          "ALTER TABLE messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'");
    }
    if (!names.contains('duration_ms')) {
      await db.execute(
          "ALTER TABLE messages ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0");
    }
    await db.rawUpdate(
      "UPDATE messages SET kind = 'audio' WHERE kind = 'text' AND text LIKE 'friend/%/voices/%.m4a'",
    );
  }

  static Future<String?> avatarPath(String key) => imagePath('avatar:$key');

  static Future<String> saveAvatar(String key, List<int> bytes) =>
      saveImage('avatar:$key', bytes);
  static Future<String?> imagePath(String key) async {
    final dir = await getApplicationSupportDirectory();
    final safe = base64Url.encode(utf8.encode(key));
    final file = File(path.join(dir.path, 'im-media-$safe'));
    return await file.exists() ? file.path : null;
  }

  static Future<String> saveImage(String key, List<int> bytes) async {
    final dir = await getApplicationSupportDirectory();
    final safe = base64Url.encode(utf8.encode(key));
    final file = File(path.join(dir.path, 'im-media-$safe'));
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    return file.path;
  }

  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
