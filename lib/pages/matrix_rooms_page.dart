import 'dart:async';

import 'package:flutter/material.dart';
import '../models/matrix_room_view.dart';
import '../services/matrix_session.dart';
import 'matrix_chat_page.dart';
import 'matrix_new_chat_page.dart';

class MatrixRoomsPage extends StatefulWidget {
  const MatrixRoomsPage({super.key, required this.session});

  final MatrixSession session;

  @override
  State<MatrixRoomsPage> createState() => _MatrixRoomsPageState();
}

class _MatrixRoomsPageState extends State<MatrixRoomsPage> {
  StreamSubscription<void>? _updates;

  @override
  void initState() {
    super.initState();
    _updates = widget.session.updates.listen((_) {
      if (mounted) setState(() {});
    });
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
          preview: event?.body ?? '暂无消息',
          unreadCount: room.notificationCount,
        );
      }).toList()..sort((a, b) => a.roomId.compareTo(b.roomId));

  Future<void> _joinInvites() async {
    await widget.session.joinInvitedRooms();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = rooms;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix 消息'),
        actions: [
          IconButton(
            tooltip: '新建私聊',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => MatrixNewChatPage(session: widget.session),
              ),
            ),
          ),
        ],
      ),
      body: data.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.session.isLoggedIn ? '暂无 Matrix 会话' : '请先登录 Matrix',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  if (widget.session.invitedRooms().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _joinInvites,
                      child: Text(
                        '加入 ${widget.session.invitedRooms().length} 个邀请',
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final room = data[index];
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
                  title: Text(room.title),
                  subtitle: Text(
                    room.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: room.unreadCount == 0
                      ? null
                      : Badge(label: Text('${room.unreadCount}')),
                  onTap: () {
                    final matrixRoom = widget.session.client.getRoomById(
                      room.roomId,
                    );
                    if (matrixRoom == null) return;
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatrixChatPage(
                          session: widget.session,
                          room: matrixRoom,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
