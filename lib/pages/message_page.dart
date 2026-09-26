import 'package:flutter/material.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('消息')),
    body: const Center(child: Text('聊天服务暂未接入')),
  );
}
