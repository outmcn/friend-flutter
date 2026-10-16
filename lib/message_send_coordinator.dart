import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'im_local_store.dart';
import 'post_service.dart';

typedef Message = Map<String, dynamic>;

/// Sole owner of outgoing messages, including recovery after process restart.
/// Server acceptance is terminal; cache persistence is a separate best effort.
class MessageSendCoordinator {
  MessageSendCoordinator({
    Future<String> Function()? token,
    Future<String?> Function()? account,
    DDPostService Function()? service,
    Future<void> Function(String, Message)? persist,
    this.timeout = const Duration(minutes: 1),
    this.requestTimeout = const Duration(seconds: 10),
    this.backoff = const Duration(seconds: 1),
  })  : _token = token ?? _storedToken,
        _account =
            account ?? (token == null ? _storedAccount : () async => null),
        _service = service ?? DDPostService.new,
        _persist = persist ?? _save;

  static final instance = MessageSendCoordinator();
  final Future<String> Function() _token;
  final Future<String?> Function() _account;
  final DDPostService Function() _service;
  final Future<void> Function(String, Message) _persist;
  final Duration timeout, requestTimeout, backoff;
  final _events = StreamController<Message>.broadcast();
  final _tasks = <String, Future<Message>>{};
  final _states = <String, Message>{};
  final _invalidTokens = <String>{};
  Stream<Message> get events => _events.stream;

  static Future<String?> _storedAccount() async =>
      (await SharedPreferences.getInstance()).getString('friend.auth.userId') ??
      '';

  List<Message> snapshot(String account, String conversation) => _states.entries
      .where((entry) => entry.key.startsWith('$account/$conversation/'))
      .map((entry) => Map<String, dynamic>.from(entry.value))
      .toList();

  static Future<String> _storedToken() async =>
      (await SharedPreferences.getInstance()).getString('friend.auth.token') ??
      '';
  static Future<void> _save(String account, Message message) =>
      ImLocalStore.saveMessages(
          accountId: account,
          conversationId: '${message['conversationId']}',
          messages: [message]);
  String _key(String account, Message message) =>
      '$account/${message['conversationId']}/${message['clientId']}';

  Future<void> _cache(String account, Message message) async {
    try {
      await _persist(account, message).timeout(requestTimeout);
    } catch (error) {
      _events.add({
        'type': 'message:persistence-error',
        'accountId': account,
        'clientId': message['clientId'],
        'error': '$error'
      });
    }
  }

  Message _publish(String account, Message message) {
    final key = _key(account, message);
    final previous = _states[key];
    if (previous?['status'] == 'sent' && message['status'] != 'sent') {
      return previous!;
    }
    _states[key] = message;
    _events.add({
      'type': message['status'] == 'sent'
          ? 'message:accepted'
          : message['status'] == 'failed'
              ? 'message:failed'
              : 'message:pending',
      'accountId': account,
      'conversationId': message['conversationId'],
      'clientId': message['clientId'],
      'code': message['lastError'],
      'message': message
    });
    return message;
  }

  void observeAccepted(String account, Message message) {
    if ('${message['clientId'] ?? ''}'.isEmpty) return;
    final accepted = _publish(account, {
      ...?_states[_key(account, message)],
      ...message,
      'status': 'sent',
      'lastError': null,
    });
    unawaited(_cache(account, accepted));
  }

  void invalidateToken(String token) => _invalidTokens.add(token);

  Future<Message> send(
      {required String accountId,
      required Message message,
      bool retry = false,
      bool recover = false}) {
    final key = _key(accountId, message);
    if (['sent', 'recalled', 'deleted'].contains(message['status'])) {
      observeAccepted(accountId, message);
      return Future.value(_states[key]);
    }
    final active = _tasks[key];
    if (active != null) return active;
    final previous = _states[key];
    if (previous?['status'] == 'sent' ||
        (previous?['status'] == 'failed' && !retry)) {
      return Future.value(previous);
    }
    final completion = Completer<Message>();
    _tasks[key] = completion.future;
    unawaited(() async {
      try {
        completion.complete(
            await _run(accountId, message, recover: recover, retry: retry));
      } catch (error) {
        final failed = _publish(
            accountId, {...message, 'status': 'failed', 'lastError': '$error'});
        await _cache(accountId, failed);
        completion.complete(failed);
      } finally {
        _tasks.remove(key);
      }
    }());
    return completion.future;
  }

  Future<Message> _run(String account, Message original,
      {required bool recover, required bool retry}) async {
    final key = _key(account, original);
    final now = DateTime.now();
    final deadline = recover
        ? DateTime.tryParse('${original['retryUntil']}') ?? now.add(timeout)
        : now.add(timeout);
    // An expired persisted attempt still gets one bounded lookup: a previous
    // process may have received acceptance but failed to persist it.
    final lookupOnly = recover && !now.isBefore(deadline);
    final operationDeadline = lookupOnly ? now.add(requestTimeout) : deadline;
    var message = _publish(account, {
      ...original,
      'status': 'pending',
      'retryStartedAt': now.toIso8601String(),
      'retryUntil': deadline.toIso8601String(),
      'lastError': null
    });
    await _cache(account, message);
    var attempt = 0;
    var reconcile = recover || retry;
    Object failure = TimeoutException('发送超时');
    while (_states[key]?['status'] != 'sent' &&
        DateTime.now().isBefore(operationDeadline)) {
      final activeAccount = await _account();
      if (activeAccount != null && activeAccount != account) {
        failure = const ImSendException(401, '账号已切换，请重新登录');
        break;
      }
      final token = await _token();
      if (token.trim().isEmpty || _invalidTokens.contains(token)) {
        failure = const ImSendException(401, '登录状态为空或已失效，请重新登录');
        break;
      }
      final service = _service();
      var requestActive = true;
      try {
        Future<Message> request() async {
          if (reconcile) {
            try {
              return await service.reconcilePending(token,
                  '${message['conversationId']}', '${message['clientId']}');
            } on ImSendException catch (error) {
              if (error.statusCode != 404 || lookupOnly) rethrow;
            }
          }
          final activeAccount = await _account();
          if (_states[key]?['status'] == 'sent') return _states[key]!;
          if (!requestActive) throw TimeoutException('请求已超时');
          if (!DateTime.now().isBefore(operationDeadline)) {
            throw TimeoutException('发送超时');
          }
          if (_invalidTokens.contains(token)) {
            throw const ImSendException(401, '登录状态已失效，请重新登录');
          }
          if (activeAccount != null && activeAccount != account) {
            throw const ImSendException(401, '账号已切换，请重新登录');
          }
          return service.sendImMessage(token, '${message['conversationId']}',
              text: '${message['text']}',
              clientId: '${message['clientId']}',
              kind: '${message['kind'] ?? 'text'}',
              durationMs: (message['durationMs'] as num?)?.toInt() ?? 0,
              metadata: message['metadata'] as Map<String, dynamic>?);
        }

        final remaining = operationDeadline.difference(DateTime.now());
        // Observe even a late HTTP success before the timeout handler runs.
        await request().then((server) {
          observeAccepted(account, {...message, ...server});
          return server;
        }).timeout(remaining < requestTimeout ? remaining : requestTimeout);
        return _states[key]!;
      } catch (error) {
        failure = error;
        if (_states[key]?['status'] == 'sent') return _states[key]!;
        if (error is ImSendException && !error.retryable) {
          if (error.statusCode == 401) _invalidTokens.add(token);
          break;
        }
      } finally {
        requestActive = false;
        service.dispose();
      }
      if (lookupOnly) break;
      reconcile = true;
      final delay = backoff * (1 << attempt.clamp(0, 4));
      attempt++;
      final remaining = operationDeadline.difference(DateTime.now());
      if (remaining <= Duration.zero || attempt >= 6) break;
      await Future<void>.delayed(delay < remaining ? delay : remaining);
    }
    message = _publish(account, {
      ...message,
      'status': 'failed',
      'lastError': '$failure',
      'retryCount': attempt
    });
    await _cache(account, message);
    return message;
  }

  Future<void> resume(String accountId) async {
    try {
      final pending = await ImLocalStore.pendingMessages(accountId);
      for (final message in pending) {
        unawaited(send(
            accountId: accountId,
            message: {
              ...message,
              'id': 'local:${message['clientId']}',
              'senderId': accountId,
            },
            recover: true));
      }
    } catch (error) {
      _events.add({'type': 'message:persistence-error', 'error': '$error'});
    }
  }
}
