import 'dart:io';

import 'package:dd/im_call.dart';
import 'package:dd/im_local_store.dart';
import 'package:dd/im_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  if (Platform.isLinux) {
    databaseFactoryFfi.setDatabasesPath('/tmp');
  }
  late Directory directory;
  const call = <String, dynamic>{
    'id': '7',
    'conversationId': '1',
    'callerId': 'a',
    'calleeId': 'b',
    'status': 'ringing',
    'startedAt': '2026-10-12T10:00:00Z',
  };
  Future<List<Map<String, dynamic>>> rows() =>
      ImLocalStore.messages(accountId: 'b', conversationId: '1');
  Future<Map<String, dynamic>> save(Map<String, dynamic> update) =>
      ImSession.instance.saveCall({...call, ...update});

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('im-call-test-');
    await databaseFactory.setDatabasesPath(directory.path);
    SharedPreferences.setMockInitialValues({'friend.auth.userId': 'b'});
  });
  tearDown(() async {
    await ImLocalStore.close();
    await directory.delete(recursive: true);
  });

  test(
      'shared status reducer distinguishes terminal reasons and local duration',
      () {
    for (final entry in {
      'cancelled': '已取消',
      'rejected': '已拒绝',
      'missed': '未接听',
      'unanswered': '未接听',
      'answered': '已接听',
      'ended': '已结束',
      'ringing': '等待接听'
    }.entries) {
      expect(ImCall.statusText({'status': entry.key, 'durationSeconds': 123}),
          entry.value);
    }
    for (final value in [65, 65.0, '65', '65.0']) {
      expect(
          ImCall.statusText({'status': 'ended', 'localDurationSeconds': value}),
          '01:05');
    }
    expect(ImCall.statusText({'status': 'ended', 'local_duration_seconds': 0}),
        '00:00');
    for (final value in [-1, 'bad', double.nan, double.infinity]) {
      expect(
          ImCall.statusText({'status': 'ended', 'localDurationSeconds': value}),
          '已结束');
    }
  });

  test('incoming event is emitted only after SQLite commit and survives reopen',
      () async {
    final event = ImSession.instance.events
        .firstWhere((event) => event['type'] == 'call:incoming');
    await ImSession.instance.saveCall(call, eventType: 'call:incoming');
    await event;
    expect((await rows()).single['status'], 'ringing');
    await ImLocalStore.close();
    expect((await rows()).single['calleeId'], 'b');
  });

  test(
      'same message/call ID coexists and message deletion does not delete call',
      () async {
    await save({});
    await ImLocalStore.saveMessages(
        accountId: 'b',
        conversationId: '1',
        messages: [
          {
            'id': '7',
            'senderId': 'a',
            'text': 'hello',
            'createdAt': '2026-10-12T11:00:00Z'
          },
          {...call, 'kind': 'call', 'status': 'rejected'},
        ]);
    expect((await rows()).length, 2);
    expect((await rows()).where(ImCall.isCall).single['status'], 'ringing');
    await ImLocalStore.deleteLocalMessage(
        accountId: 'b', conversationId: '1', messageId: '7');
    expect((await rows()).single['kind'], 'call');
  });

  test('concurrent partial updates preserve answered and local duration',
      () async {
    await save({
      'status': 'answered',
      'answeredAt': '2026-10-12T10:00:01Z',
      'localDurationSeconds': '65'
    });
    await Future.wait([
      save({
        'status': 'ended',
        'answeredAt': null,
        'localDurationSeconds': null
      }),
      save({'status': 'ringing', 'answered': false, 'localDurationSeconds': 2}),
    ]);
    await ImLocalStore.close();
    final stored = (await rows()).single;
    expect(stored['status'], 'ended');
    expect(stored['answered'], true);
    expect(stored['answeredAt'], '2026-10-12T10:00:01Z');
    expect(stored['localDurationSeconds'], 65);
    final latest = await ImLocalStore.latestMessages('b');
    expect(ImCall.statusText(latest['1']!), '01:05');
    expect(ImCall.statusText(stored), ImCall.statusText(latest['1']!));
  });

  test(
      'v8 migration preserves old call and separates subsequent same-ID message',
      () async {
    final old =
        await databaseFactory.openDatabase('${directory.path}/friend_im.sqlite',
            options: OpenDatabaseOptions(
                version: 8,
                onCreate: (db, _) async {
                  await db.execute('''CREATE TABLE messages (
        account_id TEXT NOT NULL, conversation_id TEXT NOT NULL, message_id TEXT NOT NULL,
        client_id TEXT, sender_id TEXT NOT NULL, caller_id TEXT, callee_id TEXT,
        text TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'text', duration_ms INTEGER NOT NULL DEFAULT 0,
        created_at TEXT, status TEXT NOT NULL DEFAULT 'sent', recalled_at TEXT, deleted_at TEXT,
        ended_at TEXT, answered_at TEXT, retry_started_at TEXT, retry_until TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0, last_error TEXT, mutation_id TEXT,
        PRIMARY KEY(account_id, conversation_id, message_id))''');
                  await db.insert('messages', {
                    'account_id': 'b',
                    'conversation_id': '1',
                    'message_id': '7',
                    'sender_id': 'a',
                    'text': '',
                    'kind': 'call',
                    'status': 'ended',
                    'answered_at': '2026-10-12T10:00:01Z'
                  });
                }));
    await old.close();
    final migrated = (await rows()).single;
    expect(migrated['id'], '7');
    expect(migrated['localDurationSeconds'], isNull);
    expect(ImCall.statusText(migrated), '已结束');
    await save({'status': 'ended', 'localDurationSeconds': '90.0'});
    await ImLocalStore.saveMessages(
        accountId: 'b',
        conversationId: '1',
        messages: [
          {'id': '7', 'text': 'hello'}
        ]);
    await ImLocalStore.close();
    expect((await rows()).length, 2);
    expect(
        (await rows()).where(ImCall.isCall).single['localDurationSeconds'], 90);
  });
}
