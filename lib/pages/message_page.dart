import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.token});

  final String token;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late final ChatController _chatController;

  late final Map<String, User> _users;

  static const _currentUserId = 'friend-current-user';
  static const _otherUserId = 'friend-demo-contact';

  @override
  void initState() {
    super.initState();

    _users = {
      _currentUserId: const User(id: _currentUserId, name: '我'),
      _otherUserId: const User(id: _otherUserId, name: 'Friend 用户'),
    };
    _chatController = InMemoryChatController(
      messages: [
        Message.text(
          id: 'demo-incoming-1',
          authorId: _otherUserId,
          text: '你好，欢迎使用 Friend。',
          createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
        ),
        Message.text(
          id: 'demo-outgoing-1',
          authorId: _currentUserId,
          text: '你好！这是 Flyer Chat UI 的消息页面演示。',
          createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
          sentAt: DateTime.now().subtract(const Duration(minutes: 6)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<User?> _resolveUser(String id) async {
    return _users[id] ?? User(id: id, name: 'Friend 用户');
  }

  void _sendMessage(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    _chatController.insertMessage(
      Message.text(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        authorId: _currentUserId,
        text: value,
        createdAt: DateTime.now(),
        sentAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          toolbarHeight: 40,
          automaticallyImplyLeading: false,
          title: const Text('消息'),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () {},
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Expanded(
          child: Chat(
            chatController: _chatController,
            currentUserId: _currentUserId,
            resolveUser: _resolveUser,
            onMessageSend: _sendMessage,
            backgroundColor: Theme.of(context).colorScheme.surface,
            theme: ChatTheme.fromThemeData(Theme.of(context)),
          ),
        ),
      ],
    );
  }
}
