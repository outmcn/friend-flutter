import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import '../models/matrix_room_view.dart';
import '../services/matrix_session.dart';
import '../widgets/post_card.dart';
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
  final Map<String, int> _avatars = {};
  bool _loadingTitles = false;

  Future<void> _refreshReadState() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.refreshRoomSummaries();
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
          final peer = room.directChatMatrixID;
          final friendId = peer == null
              ? null
              : int.tryParse(
                  peer.split(':').first.replaceFirst('@friend_', ''),
                );
          if (friendId != null) {
            await widget.session.loadFriendProfile(
              token: widget.token,
              friendId: friendId,
              roomId: room.id,
            );
            final avatar = widget.session.cachedRoomAvatarId(room.id);
            if (avatar != null) _avatars[room.id] = avatar;
          }
        } catch (_) {
          // Keep the SDK fallback title and default avatar on failure.
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

  List<MatrixRoomViewData> get rooms {
    final cached = widget.session.cachedRoomSummaries;
    if (cached.isNotEmpty) {
      return cached
          .map(
            (summary) => MatrixRoomViewData(
              roomId: summary.roomId,
              title: summary.title,
              preview: summary.preview,
              timestamp: summary.timestamp,
              unreadCount: summary.unreadCount,
              avatarId: summary.avatarId,
            ),
          )
          .toList();
    }
    return widget.session.directRooms().map((room) {
      final event = room.lastEvent;
      return MatrixRoomViewData(
        roomId: room.id,
        title: MatrixSession.sanitizeDisplayName(
          room.getLocalizedDisplayname(),
        ),
        preview: _previewFor(event),
        timestamp: event?.originServerTs,
        unreadCount: room.notificationCount,
      );
    }).toList()..sort((a, b) {
      final at = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
  }

  String _previewFor(Event? event) {
    if (event == null) return '暂无消息';
    if (event.messageType == MessageTypes.Image) return '[图片]';
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

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final local = value.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${local.month}/${local.day}';
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
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: data.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final item = data[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColors[_avatars[item.roomId] ?? 0],
                  child: Icon(
                    avatarIcons[_avatars[item.roomId] ?? 0],
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_titles[item.roomId] ?? item.title),
                          ),
                          if (item.timestamp != null)
                            Text(
                              _timeLabel(item.timestamp),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Badge(label: Text('${item.unreadCount}')),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
