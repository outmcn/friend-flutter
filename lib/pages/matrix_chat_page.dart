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
  String? error;
  bool loading = true;
  bool sending = false;
  String? roomTitle;

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
    } catch (_) {
      // The room remains usable even when member profile loading is delayed.
    }
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

  Future<void> _markRoomRead() async {
    final latest = timeline?.events
        .where((event) => event.type == EventTypes.Message)
        .lastOrNull;
    if (latest == null) return;
    try {
      await widget.room.setReadMarker(latest.eventId, mRead: latest.eventId);
    } catch (_) {
      // Keep the chat usable if the receipt request fails.
    }
  }

  Future<void> _send() async {
    final text = composer.text.trim();
    if (text.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.session.sendText(widget.room, text);
      composer.clear();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  List<Event> get messageEvents =>
      timeline?.events
          .where((event) => event.type == EventTypes.Message)
          .toList() ??
      const [];

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
                : ListView.builder(
                    controller: scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final mine =
                          event.senderId == widget.session.client.userID;
                      return Align(
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
                          child: Text(event.body),
                        ),
                      );
                    },
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
