import 'package:flutter/material.dart';
import '../services/matrix_session.dart';
import 'matrix_chat_page.dart';

class MatrixNewChatPage extends StatefulWidget {
  const MatrixNewChatPage({super.key, required this.session});

  final MatrixSession session;

  @override
  State<MatrixNewChatPage> createState() => _MatrixNewChatPageState();
}

class _MatrixNewChatPageState extends State<MatrixNewChatPage> {
  final controller = TextEditingController();
  bool creating = false;
  String? error;

  Future<void> _create() async {
    final value = controller.text.trim();
    if (value.isEmpty || creating) return;
    setState(() {
      creating = true;
      error = null;
    });
    try {
      await widget.session.joinInvitedRooms();
      final roomId = await widget.session.startDirectChat(value);
      var room = widget.session.roomById(roomId);
      if (room == null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        room = widget.session.roomById(roomId);
      }
      if (!mounted || room == null) {
        if (mounted) {
          setState(() => error = '私聊房间正在同步，请稍后重试');
        }
        return;
      }
      final activeRoom = room;
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MatrixChatPage(session: widget.session, room: activeRoom),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建 Matrix 私聊')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('输入对方的 Matrix 用户 ID，例如：'),
          const SizedBox(height: 8),
          Text(
            '@friend_2:matrix.friend.outmcn.net',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Matrix 用户 ID',
              hintText: '@friend_2:matrix.friend.outmcn.net',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _create(),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: creating ? null : _create,
            icon: creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_outlined),
            label: const Text('创建私聊'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
