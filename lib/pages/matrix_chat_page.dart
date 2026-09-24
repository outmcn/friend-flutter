import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import '../services/matrix_session.dart';

class MatrixChatPage extends StatefulWidget {
  const MatrixChatPage({super.key, required this.session, required this.room});

  final MatrixSession session;
  final Room room;

  @override
  State<MatrixChatPage> createState() => _MatrixChatPageState();
}

class _MatrixChatPageState extends State<MatrixChatPage> {
  StreamSubscription<void>? _updates;
  Timeline? timeline;
  final composer = TextEditingController();
  final scrollController = ScrollController();
  Timer? typingTimer;
  String? error;
  bool loading = true;
  bool sending = false;
  bool loadingHistory = false;
  String? roomTitle;
  Event? replyingTo;

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
    } catch (_) {}
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

  Future<void> _send() async {
    final text = composer.text.trim();
    if (text.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      if (replyingTo != null) {
        await widget.session.sendReply(widget.room, replyingTo!, text);
      } else {
        await widget.session.sendText(widget.room, text);
      }
      composer.clear();
      typingTimer?.cancel();
      await widget.session.setTyping(widget.room, false);
      if (mounted) setState(() => replyingTo = null);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _showMessageActions(Event event) async {
    final mine = event.senderId == widget.session.client.userID;
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
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text('赞'),
              onTap: () => Navigator.pop(context, 'react'),
            ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('撤回'),
                onTap: () => Navigator.pop(context, 'redact'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'reply') {
        setState(() => replyingTo = event);
      } else if (action == 'react') {
        await widget.session.reactToMessage(widget.room, event, '👍');
      } else if (action == 'redact') {
        await widget.session.redactMessage(widget.room, event);
        if (mounted) setState(() {});
      } else if (action == 'edit') {
        final controller = TextEditingController(text: event.body);
        final value = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('编辑消息'),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('保存'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (value != null && value.trim().isNotEmpty) {
          await widget.session.editMessage(widget.room, event, value);
        }
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
    return event.body == 'Redacted' ? '已撤回一条消息' : event.body;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final events = messageEvents;
    return Scaffold(
      appBar: AppBar(
        title: Text(roomTitle ?? widget.room.getLocalizedDisplayname()),
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
          if (replyingTo != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.reply),
              title: Text('回复：${replyingTo!.body}'),
              trailing: IconButton(
                onPressed: () => setState(() => replyingTo = null),
                icon: const Icon(Icons.close),
              ),
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
                        return GestureDetector(
                          onLongPress: () => _showMessageActions(event),
                          child: Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
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
                                  Text(_messageBody(displayed)),
                                  if (mine &&
                                      widget.session.otherUserHasRead(
                                        widget.room,
                                        event,
                                      ))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        '已读',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '输入消息',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        typingTimer?.cancel();
                        unawaited(widget.session.setTyping(widget.room, true));
                        typingTimer = Timer(
                          const Duration(seconds: 3),
                          () => widget.session.setTyping(widget.room, false),
                        );
                      },
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
    typingTimer?.cancel();
    unawaited(widget.session.setTyping(widget.room, false));
    _updates?.cancel();
    composer.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
