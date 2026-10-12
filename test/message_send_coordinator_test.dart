import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dd/im_local_store.dart';
import 'package:dd/message_send_coordinator.dart';
import 'package:dd/post_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const location = {
  'latitude': 31.23,
  'longitude': 121.47,
  'title': '广场',
  'address': '上海'
};
Map<String, dynamic> draft({String kind = 'location'}) => {
      'id': 'local:c1',
      'clientId': 'c1',
      'conversationId': '1',
      'senderId': 'a',
      'text': '广场',
      'kind': kind,
      'metadata': kind == 'location' ? location : null,
      'createdAt': '2026-10-12T00:00:00Z',
      'status': 'pending',
    };
http.Response accepted([int code = 201]) => http.Response(
    jsonEncode({
      'message': {...draft(), 'id': '42'},
    }),
    code,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MessageSendCoordinator coordinator(
          Future<http.Response> Function(http.Request) handle,
          {Future<void> Function(String, Message)? persist,
          String token = 'token',
          Duration timeout = const Duration(seconds: 1),
          Duration requestTimeout = const Duration(milliseconds: 100),
          Duration backoff = const Duration(milliseconds: 1)}) =>
      MessageSendCoordinator(
        token: () async => token,
        service: () => DDPostService(client: MockClient(handle)),
        persist: persist ?? (_, __) async {},
        timeout: timeout,
        requestTimeout: requestTimeout,
        backoff: backoff,
      );

  for (final kind in ['text', 'location']) {
    test('$kind uses one POST and accepts despite SQLite failure', () async {
      var posts = 0;
      final sender = coordinator((request) async {
        posts++;
        expect(request.url.origin, 'https://friend.outmcn.net');
        final body = jsonDecode(request.body) as Map;
        expect(body['kind'], kind);
        if (kind == 'location') expect(body['metadata'], location);
        return http.Response(
            jsonEncode({
              'message': {...body, 'id': '42'}
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }, persist: (_, __) async => throw StateError('disk full'));
      final result =
          await sender.send(accountId: 'a', message: draft(kind: kind));
      expect(result['status'], 'sent');
      expect(
          (await sender.send(
              accountId: 'a',
              message: draft(kind: kind),
              retry: true))['status'],
          'sent');
      expect(posts, 1);
    });
  }

  test('concurrent send, recovery and manual retry share one task', () async {
    final response = Completer<http.Response>();
    var posts = 0;
    final sender = coordinator((_) {
      posts++;
      return response.future;
    });
    final one = sender.send(accountId: 'a', message: draft());
    final two = sender.send(accountId: 'a', message: draft(), recover: true);
    final three = sender.send(accountId: 'a', message: draft(), retry: true);
    expect(identical(one, two), isTrue);
    expect(identical(one, three), isTrue);
    await Future<void>.delayed(Duration.zero);
    response.complete(accepted());
    expect((await one)['status'], 'sent');
    expect(posts, 1);
  });

  test('persisted sent message cannot start a new send task', () async {
    final sender = coordinator((_) async => throw StateError('must not send'));
    expect(
        (await sender.send(
            accountId: 'a',
            message: {
              ...draft(),
              'id': '42',
              'status': 'sent',
            },
            retry: true))['status'],
        'sent');
  });

  test('acceptance during reconcile prevents a subsequent POST', () async {
    final response = Completer<http.Response>();
    final methods = <String>[];
    final sender = coordinator((request) {
      methods.add(request.method);
      return response.future;
    });
    final operation =
        sender.send(accountId: 'a', message: draft(), recover: true);
    await Future<void>.delayed(Duration.zero);
    sender.observeAccepted('a', {...draft(), 'id': '42'});
    response.complete(http.Response('', 404));
    expect((await operation)['status'], 'sent');
    expect(methods, ['GET']);
  });

  test('late 404 after lookup timeout never starts a detached POST', () async {
    final response = Completer<http.Response>();
    final methods = <String>[];
    final sender = coordinator((request) {
      methods.add(request.method);
      return response.future;
    },
        timeout: const Duration(milliseconds: 25),
        requestTimeout: const Duration(milliseconds: 25));
    expect(
        (await sender.send(
            accountId: 'a', message: draft(), recover: true))['status'],
        'failed');
    response.complete(http.Response('', 404));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(methods, ['GET']);
  });

  test('500 followed by reconcile 200 accepts without another POST', () async {
    final methods = <String>[];
    final sender = coordinator((request) async {
      methods.add(request.method);
      return request.method == 'POST'
          ? http.Response('<html>error</html>', 500)
          : accepted(200);
    });
    final result = await sender.send(accountId: 'a', message: draft());
    expect(result['status'], 'sent');
    expect(result['metadata'], location);
    expect(methods, ['POST', 'GET']);
  });

  test('reconcile 404 permits resend with unchanged clientId and metadata',
      () async {
    final methods = <String>[];
    final sender = coordinator((request) async {
      methods.add(request.method);
      if (request.method == 'GET') return http.Response('', 404);
      expect((jsonDecode(request.body) as Map)['clientId'], 'c1');
      expect((jsonDecode(request.body) as Map)['metadata'], location);
      return accepted();
    });
    expect(
        (await sender.send(
            accountId: 'a', message: draft(), retry: true))['status'],
        'sent');
    expect(methods, ['GET', 'POST']);
  });

  for (final status in [400, 401, 403, 409]) {
    test('HTTP $status terminates explicitly without automatic retry',
        () async {
      var count = 0;
      final sender = coordinator((_) async {
        count++;
        return http.Response('not json', status);
      });
      final result = await sender.send(accountId: 'a', message: draft());
      expect(result['status'], 'failed');
      expect(result['lastError'], contains('$status'));
      expect(count, 1);
    });
  }

  test('empty and invalidated tokens fail without HTTP', () async {
    for (final token in ['', 'invalid']) {
      final sender = coordinator(
          (_) async => throw StateError('must not request'),
          token: token);
      if (token.isNotEmpty) sender.invalidateToken(token);
      final result = await sender.send(accountId: 'a', message: draft());
      expect(result['status'], 'failed');
      expect(result['lastError'], contains('401'));
    }
  });

  test('account switch cannot send using another account token', () async {
    final sender = MessageSendCoordinator(
        token: () async => 'new token',
        account: () async => 'b',
        persist: (_, __) async {},
        service: () => throw StateError('must not send'));
    expect((await sender.send(accountId: 'a', message: draft()))['lastError'],
        contains('账号已切换'));
  });

  test('accepted event wins over a late HTTP failure', () async {
    final response = Completer<http.Response>();
    final events = <Message>[];
    final sender = coordinator((_) => response.future);
    final subscription = sender.events.listen(events.add);
    addTearDown(subscription.cancel);
    final operation = sender.send(accountId: 'a', message: draft());
    await Future<void>.delayed(Duration.zero);
    sender.observeAccepted('a', {...draft(), 'id': '42'});
    response.complete(http.Response('', 403));
    expect((await operation)['status'], 'sent');
    await Future<void>.delayed(Duration.zero);
    expect(events.where((event) => event['type'] == 'message:failed'), isEmpty);
  });

  test('late 201 upgrades timeout failure and cannot be retried', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final sender = coordinator((_) {
      requests++;
      return response.future;
    },
        timeout: const Duration(milliseconds: 25),
        requestTimeout: const Duration(milliseconds: 25));
    expect((await sender.send(accountId: 'a', message: draft()))['status'],
        'failed');
    response.complete(accepted());
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(
        (await sender.send(
            accountId: 'a', message: draft(), retry: true))['status'],
        'sent');
    expect(requests, 1);
  });

  test('persistent 503 backs off exponentially and reaches a finite deadline',
      () async {
    final times = <DateTime>[];
    final sender = coordinator((_) async {
      times.add(DateTime.now());
      return http.Response('', 503);
    },
        timeout: const Duration(milliseconds: 150),
        backoff: const Duration(milliseconds: 20));
    final result = await sender.send(accountId: 'a', message: draft());
    expect(result['status'], 'failed');
    expect(times.length, inInclusiveRange(3, 4));
    expect(
        times[1].difference(times[0]).inMilliseconds, greaterThanOrEqualTo(18));
    expect(
        times[2].difference(times[1]).inMilliseconds, greaterThanOrEqualTo(38));
  });

  test('expired recovery reconciles acceptance but never resends', () async {
    for (final code in [200, 404, 503]) {
      var count = 0;
      final sender = coordinator((request) async {
        count++;
        expect(request.method, 'GET');
        return code == 200 ? accepted(200) : http.Response('', code);
      });
      final result = await sender.send(
          accountId: 'a',
          message: {
            ...draft(),
            'retryUntil': '2000-01-01T00:00:00Z',
          },
          recover: true);
      expect(result['status'], code == 200 ? 'sent' : 'failed');
      expect(count, 1);
    }
  });

  test('201 or reconcile 200 with broken body is still accepted', () async {
    for (final recover in [false, true]) {
      final sender = coordinator(
          (_) async => http.Response('broken json', recover ? 200 : 201));
      final result =
          await sender.send(accountId: 'a', message: draft(), recover: recover);
      expect(result['status'], 'sent');
      expect(result['kind'], 'location');
      expect(result['metadata'], location);
    }
  });

  test('pagination, sync and by-client retain location metadata', () async {
    final service = DDPostService(
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'messages': [
                {...draft(), 'id': '42'}
              ],
              'message': {...draft(), 'id': '42'},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    addTearDown(service.dispose);
    expect(
        (await service.fetchImMessages('token', '1', beforeId: '43'))
            .single
            .metadata,
        location);
    final sync = await service.syncImMessages('token', '1', '0');
    expect((sync['messages'] as List<DDImMessage>).single.metadata, location);
    expect((await service.reconcilePending('token', '1', 'c1'))['metadata'],
        location);
  });

  group('SQLite monotonic acceptance', () {
    late Directory directory;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      directory = await Directory.systemTemp.createTemp('im-send-');
      await databaseFactory.setDatabasesPath(directory.path);
    });
    tearDown(() async {
      await ImLocalStore.close();
      await directory.delete(recursive: true);
    });
    Future<void> save(Message message) => ImLocalStore.saveMessages(
        accountId: 'a', conversationId: '1', messages: [message]);
    test('stale page saves and retry state cannot overwrite accepted row',
        () async {
      await save(draft());
      await ImLocalStore.reconcileAccepted(
          accountId: 'a', message: {...draft(), 'id': '42'});
      await Future.wait([
        save(draft()),
        save({...draft(), 'status': 'failed'}),
        ImLocalStore.updateRetryState(
            accountId: 'a',
            conversationId: '1',
            clientId: 'c1',
            status: 'failed'),
      ]);
      await ImLocalStore.close();
      final rows =
          await ImLocalStore.messages(accountId: 'a', conversationId: '1');
      expect(rows, hasLength(1));
      expect(rows.single['id'], '42');
      expect(rows.single['status'], 'sent');
      expect(rows.single['metadata'], location);
      expect(await ImLocalStore.pendingMessages('a'), isEmpty);
    });
    test('reconcile inserts even if original pending write failed', () async {
      await ImLocalStore.reconcileAccepted(
          accountId: 'a', message: {...draft(), 'id': '42'});
      expect(
          (await ImLocalStore.messages(accountId: 'a', conversationId: '1'))
              .single['status'],
          'sent');
    });
  });
}
