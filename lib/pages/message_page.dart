import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as fc;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.token});
  final String token;
  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late final fc.InMemoryChatController _controller;
  final _user = const fc.User(id: 'friend-local-user', name: '我');
  @override
  void initState() {
    super.initState();
    _controller = fc.InMemoryChatController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<fc.User> _resolveUser(fc.UserID id) async =>
      id == _user.id ? _user : fc.User(id: id, name: '对方');
  void _send(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    _controller.insertMessage(
      fc.Message.text(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        authorId: _user.id,
        createdAt: DateTime.now(),
        text: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('消息')),
    body: Chat(
      currentUserId: _user.id,
      resolveUser: _resolveUser,
      chatController: _controller,
      onMessageSend: _send,
    ),
  );
}
