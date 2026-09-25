import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter/services.dart';
import '../pages/other_profile_page.dart';
import '../services/api_client.dart';
import '../services/matrix_session.dart';
import '../widgets/post_card.dart';

class MatrixChatPage extends StatefulWidget {
  const MatrixChatPage({
    super.key,
    required this.session,
    required this.room,
    required this.token,
  });

  final MatrixSession session;
  final Room room;
  final String token;

  @override
  State<MatrixChatPage> createState() => _MatrixChatPageState();
}

class _MatrixChatPageState extends State<MatrixChatPage> {
  StreamSubscription<void>? _updates;
  Timeline? timeline;
  final composer = TextEditingController();
  final scrollController = ScrollController();

  String? error;
  bool loading = true;
  bool sending = false;
  bool loadingHistory = false;
  String? roomTitle;
  Event? replyingTo;
  final Map<String, String> replyLabels = {};
  Map<String, dynamic>? peerProfile;
  Map<String, dynamic>? ownProfile;
  bool followLoading = false;

  @override
  void initState() {
    super.initState();
    _updates = widget.session.updates.listen((_) {
      if (mounted) setState(() {});
    });
    _loadRoomTitle();
    _loadTimeline();
  }

  Future<void> _loadRoomTitle() async {
    try {
      await widget.room.loadHeroUsers();
      final title = widget.room.getLocalizedDisplayname();
      if (mounted) setState(() => roomTitle = title);
      await _loadPeerProfile();
    } catch (_) {}
  }

  int? get _peerFriendId {
    final peer = widget.room.directChatMatrixID;
    if (peer == null) return null;
    return int.tryParse(peer.split(':').first.replaceFirst('@friend_', ''));
  }

  Future<void> _loadPeerProfile() async {
    final id = _peerFriendId;
    if (id == null || widget.token.isEmpty) return;
    try {
      final response = await ApiClient(
        token: widget.token,
      ).get('/api/users/$id');
      final own = await ApiClient(token: widget.token).get('/api/me');
      if (mounted) {
        setState(() {
          peerProfile = Map<String, dynamic>.from(response['data'] as Map);
          ownProfile = Map<String, dynamic>.from(own['data'] as Map);
        });
      }
    } catch (_) {}
  }

  Future<void> _openPeerProfile() async {
    final data = peerProfile;
    if (data == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OtherProfilePage(data: data, dataToken: widget.token),
      ),
    );
    await _loadPeerProfile();
  }

  Future<void> _toggleFollow() async {
    final id = _peerFriendId;
    if (id == null || followLoading || widget.token.isEmpty) return;
    setState(() => followLoading = true);
    try {
      final response = await ApiClient(
        token: widget.token,
      ).post('/api/users/$id/follow');
      if (mounted && peerProfile != null) {
        setState(
          () => peerProfile = {
            ...peerProfile!,
            'following': response['data']['following'] == true,
          },
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => followLoading = false);
    }
  }

  Widget _avatarFor(Event event) {
    final mine = event.senderId == widget.session.client.userID;
    final rawProfile = mine
        ? ownProfile
        : (peerProfile?['profile'] is Map
              ? Map<String, dynamic>.from(peerProfile!['profile'] as Map)
              : peerProfile);
    final id = ((rawProfile?['avatarId'] as num?)?.toInt() ?? 0).clamp(0, 9);
    return CircleAvatar(
      radius: 18,
      backgroundColor: avatarColors[id],
      child: Icon(avatarIcons[id], size: 20, color: Colors.white),
    );
  }

  Future<void> _loadTimeline() async {
    try {
      final loaded = await widget.room.getTimeline(
        limit: 60,
        onUpdate: () {
          if (mounted) setState(() {});
        },
      );
      if (mounted) {
        setState(() {
          timeline = loaded;
          loading = false;
        });
      }
      await _markRoomRead();
      await _loadReplyLabels();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final current = timeline;
    if (current == null || loadingHistory || !current.canRequestHistory) return;
    setState(() => loadingHistory = true);
    try {
      await current.requestHistory(historyCount: 60);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loadingHistory = false);
    }
  }

  Future<void> _markRoomRead() async {
    final latest = timeline?.events
        .where((event) => event.type == EventTypes.Message)
        .lastOrNull;
    if (latest == null) return;
    try {
      await widget.session.clearRoomUnread(widget.room);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadReplyLabels() async {
    final pending = messageEvents
        .where(
          (event) =>
              event.inReplyToEventId() != null &&
              !replyLabels.containsKey(event.eventId),
        )
        .toList();
    final labels = await Future.wait(
      pending.map(
        (event) async => MapEntry(event.eventId, await _replyLabel(event)),
      ),
    );
    replyLabels.addEntries(labels);
    if (mounted) setState(() {});
  }

  void _setImmediateReplyLabel(Event event, String text) {
    final id = event.inReplyToEventId();
    if (id == null) return;
    final lines = event.body.split('\n');
    final contentIndex = lines.lastIndexWhere(
      (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
    );
    final content = contentIndex >= 0 ? lines[contentIndex].trim() : text;
    replyLabels[event.eventId] = '对方: $content';
  }

  Future<void> _send() async {
    final text = composer.text.trim();
    if (text.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final sentEventId = replyingTo == null
          ? null
          : await widget.session.sendReply(widget.room, replyingTo!, text);
      if (replyingTo == null) {
        await widget.session.sendText(widget.room, text);
      }
      if (sentEventId != null && sentEventId.isNotEmpty) {
        final event = timeline?.events
            .where((item) => item.eventId == sentEventId)
            .firstOrNull;
        if (event != null) _setImmediateReplyLabel(event, text);
      }
      final latestReply = timeline?.events
          .where(
            (event) =>
                event.senderId == widget.session.client.userID &&
                event.inReplyToEventId() == replyingTo?.eventId,
          )
          .lastOrNull;
      if (latestReply != null) _setImmediateReplyLabel(latestReply, text);
      if (mounted) setState(() {});
      composer.clear();
      if (mounted) setState(() => replyingTo = null);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _showMessageActions(Event event) async {
    final mine = event.senderId == widget.session.client.userID;
    final canRedact =
        mine && DateTime.now().difference(event.originServerTs).inSeconds <= 60;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('回复'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),

            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),

            if (canRedact)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('撤回'),
                onTap: () => Navigator.pop(context, 'redact'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('举报'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'reply') {
        setState(() => replyingTo = event);
      } else if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: _messageBody(event)));
      } else if (action == 'report') {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('举报消息'),
              content: const Text('举报功能暂未连接后端'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
      } else if (action == 'redact') {
        await widget.session.redactMessage(widget.room, event);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  List<Event> get messageEvents =>
      timeline?.events
          .where((event) => event.type == EventTypes.Message)
          .toList() ??
      const [];

  Event _displayEvent(Event event) =>
      timeline == null ? event : event.getDisplayEvent(timeline!);

  String _messageBody(Event event) {
    if (event.redacted) return '已撤回一条消息';
    final replyId = event.inReplyToEventId();
    if (replyId != null) {
      final fallback = event.body;
      final lines = fallback.split('\n');
      final contentIndex = lines.lastIndexWhere(
        (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
      );
      if (contentIndex >= 0) return lines[contentIndex].trim();
    }
    return event.body == 'Redacted' ? '已撤回一条消息' : event.body;
  }

  bool _isRedaction(Event event) => event.redacted || event.body == 'Redacted';

  Future<String> _replyLabel(Event event) async {
    final id = event.inReplyToEventId();
    if (id == null) return event.body;
    final original = await widget.room.getEventById(id);
    if (original == null) return event.body;
    final sender = await original.fetchSenderUser();
    final name = sender?.displayName?.trim();
    return '${name?.isNotEmpty == true ? name : '对方'}: ${original.body}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final events = messageEvents;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openPeerProfile,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(roomTitle ?? widget.room.getLocalizedDisplayname()),
          ),
        ),
        actions: [
          if (peerProfile != null)
            TextButton(
              onPressed: followLoading ? null : _toggleFollow,
              child: Text(peerProfile!['following'] == true ? '已关注' : '关注'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: const Text('关闭'),
                ),
              ],
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : events.isEmpty
                ? Center(
                    child: Text(
                      '暂无消息',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 80) {
                        unawaited(_loadOlderMessages());
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final displayed = _displayEvent(event);
                        final mine =
                            event.senderId == widget.session.client.userID;
                        if (_isRedaction(displayed)) {
                          final redactedByMe =
                              event.senderId == widget.session.client.userID;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                redactedByMe
                                    ? '—— 你已撤回一条消息 ——'
                                    : '—— 对方已撤回一条消息 ——',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }
                        return GestureDetector(
                          onLongPress: () => _showMessageActions(event),
                          child: Row(
                            mainAxisAlignment: mine
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!mine) _avatarFor(event),
                              const SizedBox(width: 6),
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? colors.primaryContainer
                                      : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (replyLabels.containsKey(event.eventId))
                                      Text(
                                        '回复：${replyLabels[event.eventId]}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    Text(_messageBody(displayed)),
                                  ],
                                ),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 6),
                                _avatarFor(event),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (replyingTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 2),
              color: colors.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '回复：${replyingTo!.body}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => replyingTo = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: composer,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: '输入消息',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _updates?.cancel();
    composer.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
