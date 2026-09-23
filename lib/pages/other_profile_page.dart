import 'package:flutter/material.dart';
import '../models/ui_post.dart';
import '../widgets/post_card.dart';
import '../widgets/empty_state.dart';

class OtherProfilePage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String dataToken;
  const OtherProfilePage({super.key, required this.data, this.dataToken = ''});
  @override
  Widget build(BuildContext context) {
    final p = data['profile'] as Map<String, dynamic>? ?? {};
    final raw = data['posts'];
    final posts = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(UiPost.fromJson).toList()
        : <UiPost>[];
    final name =
        (p['nickname']?.toString().trim().isNotEmpty == true
                ? p['nickname']
                : p['username'] ?? '')
            .toString();
    return Scaffold(
      appBar: AppBar(title: const Text('个人主页')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 40,
                child: Icon(Icons.public, size: 44),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '关注 ${p['following'] ?? 0}   粉丝 ${p['followers'] ?? 0}   获赞 ${p['likes'] ?? 0}',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (posts.isEmpty) const EmptyState(text: '还没有动态'),
          ...posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(post: post, token: dataToken),
            ),
          ),
        ],
      ),
    );
  }
}
