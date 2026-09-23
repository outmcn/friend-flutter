import 'package:flutter/material.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('游戏')),
      body: const Center(child: Text('游戏入口已开放，游戏内容即将上线')),
    );
  }
}
