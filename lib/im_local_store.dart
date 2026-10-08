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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            account_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            client_id TEXT,
            sender_id TEXT NOT NULL,
            text TEXT NOT NULL,
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
    return rows.map(Map<String, dynamic>.from).toList();
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
          'created_at': '${message['createdAt'] ?? ''}',
          'status': '${message['status'] ?? 'sent'}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

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
