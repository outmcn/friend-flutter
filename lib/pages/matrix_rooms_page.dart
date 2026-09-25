import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import '../models/matrix_room_view.dart';
import '../services/matrix_session.dart';
import 'matrix_chat_page.dart';
import 'matrix_new_chat_page.dart';

class MatrixRoomsPage extends StatefulWidget {
  const MatrixRoomsPage({
    super.key,
    required this.session,
    required this.token,
    this.embedded = false,
  });

  final MatrixSession session;
  final bool embedded;
  final String token;

  @override
  State<MatrixRoomsPage> createState() => _MatrixRoomsPageState();
}

class _MatrixRoomsPageState extends State<MatrixRoomsPage> {
  StreamSubscription<void>? _updates;
  final Map<String, String> _titles = {};
  bool _loadingTitles = false;

  Future<void> _refreshReadState() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _updates = widget.session.updates.listen((_) {
      if (mounted) setState(() {});
    });
    _loadTitles();
  }

  Future<void> _loadTitles() async {
    if (_loadingTitles) return;
    _loadingTitles = true;
    try {
      for (final room in widget.session.directRooms()) {
        try {
          _titles[room.id] = await widget.session.roomDisplayName(room);
        } catch (_) {
          // Keep the SDK fallback title while member data is unavailable.
        }
      }
      if (mounted) setState(() {});
    } finally {
      _loadingTitles = false;
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }

  List<MatrixRoomViewData> get rooms =>
      widget.session.directRooms().map((room) {
        final event = room.lastEvent;
        return MatrixRoomViewData(
          roomId: room.id,
          title: room.getLocalizedDisplayname(),
          preview: _previewFor(event),
          unreadCount: room.notificationCount,
        );
      }).toList()..sort((a, b) => b.roomId.compareTo(a.roomId));

  String _previewFor(Event? event) {
    if (event == null) return '暂无消息';
    if (event.redacted || event.body == 'Redacted') {
      final mine = event.senderId == widget.session.client.userID;
      return mine ? '你已撤回一条消息' : '对方已撤回一条消息';
    }
    final replyId = event.inReplyToEventId();
    if (replyId != null) {
      final lines = event.body.split('\n');
      final contentIndex = lines.lastIndexWhere(
        (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
      );
      if (contentIndex >= 0) return lines[contentIndex].trim();
    }
    return event.body;
  }

  Future<void> _joinInvites() async {
    await widget.session.joinInvitedRooms();
    if (mounted) setState(() {});
  }

  Future<void> _openNewChat() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MatrixNewChatPage(session: widget.session, token: widget.token),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _body(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!_loadingTitles &&
        _titles.length < widget.session.directRooms().length) {
      unawaited(_loadTitles());
    }
    final data = rooms;
    if (data.isEmpty) {
      final invites = widget.session.invitedRooms();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.session.isLoggedIn ? '暂无 Matrix 会话' : '请先登录 Matrix',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (invites.isNotEmpty) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _joinInvites,
                child: Text('加入 ${invites.length} 个邀请'),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = data[index];
        return ListTile(
          tileColor: colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.chat_bubble_outline,
              color: colors.onPrimaryContainer,
            ),
          ),
          title: Text(_titles[item.roomId] ?? item.title),
          subtitle: Text(
            item.preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: item.unreadCount == 0
              ? null
              : Badge(label: Text('${item.unreadCount}')),
          onTap: () async {
            final room = widget.session.client.getRoomById(item.roomId);
            if (room == null) return;
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => MatrixChatPage(
                  session: widget.session,
                  room: room,
                  token: widget.token,
                ),
              ),
            );
            await _refreshReadState();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _body(context);
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix 消息'),
        actions: [
          IconButton(
            tooltip: '新建私聊',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _openNewChat,
          ),
        ],
      ),
      body: content,
    );
  }
}
