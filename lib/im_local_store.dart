import 'dart:convert';
import 'dart:io';

import 'im_call.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Per-user SQLite cache for IM messages and delivery state.
class ImLocalStore {
  static Database? _database;

  static Map<String, dynamic>? _decodeMetadata(dynamic value) {
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static Future<Database> _db() async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'friend_im.sqlite'),
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            account_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            client_id TEXT,
            sender_id TEXT NOT NULL,
            caller_id TEXT,
            callee_id TEXT,
            text TEXT NOT NULL,
            kind TEXT NOT NULL DEFAULT 'text',
            metadata TEXT,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            created_at TEXT,
            status TEXT NOT NULL DEFAULT 'sent',
            recalled_at TEXT,
            deleted_at TEXT,
            ended_at TEXT,
            answered_at TEXT,
            local_duration_seconds INTEGER,
            local_answered INTEGER NOT NULL DEFAULT 0,
            retry_started_at TEXT,
            retry_until TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            mutation_id TEXT,
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
        await db.execute('''
          CREATE TABLE im_sync_state (
            account_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            mutation_id TEXT NOT NULL DEFAULT '0',
            PRIMARY KEY (account_id, conversation_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 10) {
          await db.execute('ALTER TABLE messages ADD COLUMN metadata TEXT');
        }
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
        if (oldVersion < 4) {
          await db
              .execute('ALTER TABLE messages ADD COLUMN retry_started_at TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN retry_until TEXT');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE messages ADD COLUMN mutation_id TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE messages ADD COLUMN recalled_at TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN deleted_at TEXT');
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE messages ADD COLUMN caller_id TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN callee_id TEXT');
        }
        if (oldVersion < 8) {
          await db.execute('ALTER TABLE messages ADD COLUMN ended_at TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN answered_at TEXT');
        }
        if (oldVersion < 9) {
          await db.execute(
              'ALTER TABLE messages ADD COLUMN local_duration_seconds INTEGER');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN local_answered INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              "UPDATE messages SET message_id = 'call:' || message_id WHERE kind = 'call'");
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
      orderBy: 'created_at ASC, CAST(message_id AS INTEGER) ASC',
    );
    return rows.map((row) {
      final item = Map<String, dynamic>.from(row);
      return <String, dynamic>{
        'id':
            '${item['kind'] == 'call' ? '${item['message_id']}'.replaceFirst('call:', '') : item['message_id'] ?? ''}',
        'conversationId': '${item['conversation_id'] ?? ''}',
        'clientId': item['client_id'],
        'senderId': '${item['sender_id'] ?? ''}',
        'callerId': item['caller_id']?.toString(),
        'calleeId': item['callee_id']?.toString(),
        'text': '${item['text'] ?? ''}',
        'kind': '${item['kind'] ?? 'text'}',
        'metadata': _decodeMetadata(item['metadata']),
        if ('${item['kind'] ?? ''}' == 'call') '_timelineKind': 'call',
        'durationMs': _parseInt(item['duration_ms']) ?? 0,
        'createdAt': item['created_at'],
        'recalledAt': item['recalled_at'],
        'deletedAt': item['deleted_at'],
        'endedAt': item['ended_at'],
        'answeredAt': item['answered_at'],
        'localDurationSeconds': ImCall.duration(item['local_duration_seconds']),
        'answered': _parseInt(item['local_answered']) == 1,
        'mutationId': item['mutation_id'],
        'status': item['recalled_at'] != null
            ? 'recalled'
            : item['deleted_at'] != null
                ? 'deleted'
                : '${item['status'] ?? 'sent'}',
      };
    }).toList();
  }

  static Future<Map<String, dynamic>?> latestMessage({
    required String accountId,
    required String conversationId,
  }) async {
    final rows = await (await _db()).query(
      'messages',
      where: 'account_id = ? AND conversation_id = ?',
      whereArgs: [accountId, conversationId],
      orderBy: 'created_at DESC, CAST(message_id AS INTEGER) DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  static Future<void> saveMessages({
    required String accountId,
    required String conversationId,
    required List<Map<String, dynamic>> messages,
  }) async {
    final db = await _db();
    final batch = db.batch();
    for (final message in messages) {
      if (ImCall.isCall(message)) {
        continue; // Calls are saved only by ImSession.
      }
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
          'caller_id': message['callerId'],
          'callee_id': message['calleeId'],
          'text': '${message['text'] ?? ''}',
          'kind':
              '${message['_timelineKind'] == 'call' ? 'call' : message['kind'] ?? 'text'}',
          'metadata': message['metadata'] == null
              ? null
              : jsonEncode(message['metadata']),
          'duration_ms': (message['durationMs'] as num?)?.toInt() ?? 0,
          'created_at': '${message['createdAt'] ?? ''}',
          'status': '${message['status'] ?? 'sent'}',
          'recalled_at': message['recalledAt'],
          'deleted_at': message['deletedAt'],
          'ended_at': message['endedAt'],
          'answered_at': message['answeredAt'],
          'retry_started_at': message['retryStartedAt'],
          'retry_until': message['retryUntil'],
          'retry_count': (message['retryCount'] as num?)?.toInt() ?? 0,
          'last_error': message['lastError'],
          'mutation_id': message['mutationId'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<Map<String, dynamic>> saveCall({
    required String accountId,
    required Map<String, dynamic> call,
  }) async {
    final conversationId =
        '${call['conversationId'] ?? call['conversation_id'] ?? ''}';
    final id = 'call:${call['id']}';
    return (await _db()).transaction((txn) async {
      final rows = await txn.query('messages',
          where: 'account_id = ? AND conversation_id = ? AND message_id = ?',
          whereArgs: [accountId, conversationId, id]);
      final row = rows.isEmpty ? <String, dynamic>{} : rows.first;
      final merged = ImCall.merge({
        if (row.isNotEmpty) ...{
          'id': call['id'],
          'conversationId': conversationId,
          'callerId': row['caller_id'],
          'calleeId': row['callee_id'],
          'status': row['status'],
          'createdAt': row['created_at'],
          'answeredAt': row['answered_at'],
          'endedAt': row['ended_at'],
          'answered': _parseInt(row['local_answered']) == 1,
          'localDurationSeconds': row['local_duration_seconds'],
        },
      }, call);
      final values = <String, dynamic>{
        'account_id': accountId,
        'conversation_id': conversationId,
        'message_id': id,
        'sender_id': '${merged['callerId'] ?? ''}',
        'caller_id': merged['callerId']?.toString(),
        'callee_id': merged['calleeId']?.toString(),
        'text': '',
        'kind': 'call',
        'status': merged['status'] ?? 'ringing',
        'created_at': merged['createdAt'],
        'answered_at': merged['answeredAt'],
        'ended_at': merged['endedAt'],
        'local_answered': merged['answered'] == true ? 1 : 0,
        'local_duration_seconds': merged['localDurationSeconds'],
      };
      if (rows.isEmpty) {
        await txn.insert('messages', values);
      } else if (values.entries.any((entry) => row[entry.key] != entry.value)) {
        await txn.update('messages', values,
            where: 'account_id = ? AND conversation_id = ? AND message_id = ?',
            whereArgs: [accountId, conversationId, id]);
      }
      return merged;
    });
  }

  static Future<Map<String, Map<String, dynamic>>> latestMessages(
      String accountId) async {
    final rows = await (await _db()).rawQuery(
        "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY conversation_id ORDER BY created_at DESC, CAST(message_id AS INTEGER) DESC) AS position FROM messages WHERE account_id = ?) WHERE position = 1",
        [accountId]);
    return {
      for (final row in rows)
        '${row['conversation_id']}': Map<String, dynamic>.from(row)
    };
  }

  static Future<void> updateRetryState({
    required String accountId,
    required String conversationId,
    required String clientId,
    required String status,
    String? retryStartedAt,
    String? retryUntil,
    int? retryCount,
    String? lastError,
  }) async {
    final values = <String, dynamic>{
      'status': status,
      'retry_started_at': retryStartedAt,
      'retry_until': retryUntil,
      'last_error': lastError,
    };
    if (retryCount != null) values['retry_count'] = retryCount;
    await (await _db()).update(
      'messages',
      values,
      where: 'account_id = ? AND conversation_id = ? AND client_id = ?',
      whereArgs: [accountId, conversationId, clientId],
    );
  }

  static Future<Map<String, dynamic>?> retryState({
    required String accountId,
    required String conversationId,
    required String clientId,
  }) async {
    final rows = await (await _db()).query(
      'messages',
      columns: [
        'status',
        'retry_started_at',
        'retry_until',
        'retry_count',
        'last_error',
      ],
      where: 'account_id = ? AND conversation_id = ? AND client_id = ?',
      whereArgs: [accountId, conversationId, clientId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return <String, dynamic>{
      'status': '${row['status'] ?? ''}',
      'retryStartedAt': row['retry_started_at'],
      'retryUntil': row['retry_until'],
      'retryCount': (row['retry_count'] as num?)?.toInt() ?? 0,
      'lastError': row['last_error'],
    };
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

  /// Returns durable local rows for server IDs after the SQLite commit completes.
  static Future<List<Map<String, dynamic>>> durableMessages({
    required String accountId,
    required String conversationId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return <Map<String, dynamic>>[];
    final placeholders = List.filled(messageIds.length, '?').join(',');
    final rows = await (await _db()).query(
      'messages',
      where:
          'account_id = ? AND conversation_id = ? AND message_id IN ($placeholders)',
      whereArgs: [accountId, conversationId, ...messageIds],
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
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
      {
        'status': 'recalled',
        'text': '',
        'recalled_at': message['recalledAt'] ?? DateTime.now().toIso8601String()
      },
      where: 'account_id = ? AND conversation_id = ? AND message_id = ?',
      whereArgs: [accountId, conversationId, oldId],
    );
  }

  static Future<void> clearConversation({
    required String accountId,
    required String conversationId,
  }) async {
    final db = await _db();
    await db.delete(
      'messages',
      where: 'account_id = ? AND conversation_id = ?',
      whereArgs: [accountId, conversationId],
    );
    await db.delete(
      'local_deleted_messages',
      where: 'account_id = ? AND conversation_id = ?',
      whereArgs: [accountId, conversationId],
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
      columns: [
        'conversation_id',
        'client_id',
        'text',
        'kind',
        'metadata',
        'duration_ms',
        'retry_started_at',
        'retry_until',
        'retry_count',
        'last_error'
      ],
      where: "account_id = ? AND status = 'pending' AND client_id IS NOT NULL",
      whereArgs: [accountId],
      orderBy: 'CAST(message_id AS INTEGER) ASC',
    );
    return rows
        .map((row) => <String, dynamic>{
              'conversationId': '${row['conversation_id'] ?? ''}',
              'clientId': '${row['client_id'] ?? ''}',
              'text': '${row['text'] ?? ''}',
              'kind': '${row['kind'] ?? 'text'}',
              'metadata': _decodeMetadata(row['metadata']),
              'durationMs': (row['duration_ms'] as num?)?.toInt() ?? 0,
              'retryStartedAt': row['retry_started_at'],
              'retryUntil': row['retry_until'],
              'retryCount': (row['retry_count'] as num?)?.toInt() ?? 0,
              'lastError': row['last_error'],
            })
        .toList();
  }

  static Future<String> mutationId({
    required String accountId,
    required String conversationId,
  }) async {
    final rows = await (await _db()).query(
      'im_sync_state',
      columns: ['mutation_id'],
      where: 'account_id = ? AND conversation_id = ?',
      whereArgs: [accountId, conversationId],
      limit: 1,
    );
    return rows.isEmpty ? '0' : '${rows.first['mutation_id'] ?? '0'}';
  }

  static Future<void> saveMutationId({
    required String accountId,
    required String conversationId,
    required String mutationId,
  }) async {
    await (await _db()).insert(
      'im_sync_state',
      {
        'account_id': accountId,
        'conversation_id': conversationId,
        'mutation_id': mutationId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
