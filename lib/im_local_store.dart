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
      version: 3,
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
          CREATE TABLE local_deleted_messages (
            account_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            deleted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (account_id, conversation_id, message_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'");
          await db.execute(
              "ALTER TABLE messages ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0");
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE local_deleted_messages (
              account_id TEXT NOT NULL,
              conversation_id TEXT NOT NULL,
              message_id TEXT NOT NULL,
              deleted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (account_id, conversation_id, message_id)
            )
          ''');
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
      final clientId = '${message['clientId'] ?? ''}';
      if (id.isEmpty) continue;
      if (clientId.isNotEmpty) {
        batch.delete(
          'messages',
          where:
              'account_id = ? AND conversation_id = ? AND client_id = ? AND message_id <> ?',
          whereArgs: [accountId, conversationId, clientId, id],
        );
      }
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

  static Future<void> saveIncomingMessage({
    required String accountId,
    required Map<String, dynamic> message,
  }) async {
    final conversationId = '${message['conversationId'] ?? ''}';
    final messageId = '${message['id'] ?? ''}';
    if (conversationId.isEmpty || messageId.isEmpty) return;
    final deleted = await localDeletedMessageIds(
      accountId: accountId,
      conversationId: conversationId,
    );
    if (deleted.contains(messageId)) return;
    await saveMessages(
      accountId: accountId,
      conversationId: conversationId,
      messages: [
        {...message, 'status': 'sent'}
      ],
    );
  }

  static Future<void> reconcileAccepted({
    required String accountId,
    required Map<String, dynamic> message,
  }) async {
    final conversationId = '${message['conversationId'] ?? ''}';
    final clientId = '${message['clientId'] ?? ''}';
    if (conversationId.isEmpty || clientId.isEmpty) return;
    final db = await _db();
    final rows = await db.query(
      'messages',
      columns: ['message_id'],
      where: 'account_id = ? AND conversation_id = ? AND client_id = ?',
      whereArgs: [accountId, conversationId, clientId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final oldId = '${rows.first['message_id'] ?? ''}';
    if (oldId != '${message['id'] ?? ''}') {
      await db.delete(
        'messages',
        where: 'account_id = ? AND conversation_id = ? AND message_id = ?',
        whereArgs: [accountId, conversationId, oldId],
      );
    }
    await saveMessages(
      accountId: accountId,
      conversationId: conversationId,
      messages: [
        {...message, 'status': 'sent'}
      ],
    );
  }

  static Future<void> markRecalled({
    required String accountId,
    required Map<String, dynamic> message,
  }) async {
    final conversationId = '${message['conversationId'] ?? ''}';
    final messageId = '${message['id'] ?? ''}';
    final clientId = '${message['clientId'] ?? ''}';
    if (conversationId.isEmpty || messageId.isEmpty) return;
    final db = await _db();
    final where = clientId.isEmpty
        ? 'account_id = ? AND conversation_id = ? AND message_id = ?'
        : 'account_id = ? AND conversation_id = ? AND (message_id = ? OR client_id = ?)';
    final args = clientId.isEmpty
        ? [accountId, conversationId, messageId]
        : [accountId, conversationId, messageId, clientId];
    final rows = await db.query('messages',
        columns: ['message_id'], where: where, whereArgs: args, limit: 1);
    if (rows.isEmpty) return;
    final oldId = '${rows.first['message_id'] ?? ''}';
    await db.update(
      'messages',
      {'status': 'recalled'},
      where: 'account_id = ? AND conversation_id = ? AND message_id = ?',
      whereArgs: [accountId, conversationId, oldId],
    );
  }

  static Future<void> deleteLocalMessage({
    required String accountId,
    required String conversationId,
    required String messageId,
  }) async {
    final db = await _db();
    await db.delete(
      'messages',
      where: 'account_id = ? AND conversation_id = ? AND message_id = ?',
      whereArgs: [accountId, conversationId, messageId],
    );
    await db.insert(
      'local_deleted_messages',
      {
        'account_id': accountId,
        'conversation_id': conversationId,
        'message_id': messageId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Set<String>> localDeletedMessageIds({
    required String accountId,
    required String conversationId,
  }) async {
    final rows = await (await _db()).query(
      'local_deleted_messages',
      columns: ['message_id'],
      where: 'account_id = ? AND conversation_id = ?',
      whereArgs: [accountId, conversationId],
    );
    return rows.map((row) => '${row['message_id']}').toSet();
  }

  static Future<List<Map<String, dynamic>>> pendingMessages(
      String accountId) async {
    final rows = await (await _db()).query(
      'messages',
      columns: ['conversation_id', 'client_id', 'text'],
      where: "account_id = ? AND status = 'pending' AND client_id IS NOT NULL",
      whereArgs: [accountId],
      orderBy: 'CAST(message_id AS INTEGER) ASC',
    );
    return rows
        .map((row) => <String, dynamic>{
              'conversationId': '${row['conversation_id'] ?? ''}',
              'clientId': '${row['client_id'] ?? ''}',
              'text': '${row['text'] ?? ''}',
            })
        .toList();
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
