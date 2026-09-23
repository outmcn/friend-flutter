import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/ui_post.dart';
import '../widgets/post_card.dart';
import '../widgets/empty_state.dart';

class OtherProfilePage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String dataToken;
  const OtherProfilePage({super.key, required this.data, this.dataToken = ''});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  static const baseUrl = 'https://friend.outmcn.net';
  late Map<String, dynamic> profile;
  late List<UiPost> posts;
  bool following = false;
  bool followLoading = false;

  @override
  void initState() {
    super.initState();
    profile = Map<String, dynamic>.from(
      widget.data['profile'] as Map<String, dynamic>? ?? const {},
    );
    final raw = widget.data['posts'];
    posts = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(UiPost.fromJson).toList()
        : <UiPost>[];
    _loadFollowState();
  }

  int get userId => (profile['id'] as num?)?.toInt() ?? 0;

  String get displayName {
    final nickname = profile['nickname']?.toString().trim() ?? '';
    return nickname.isNotEmpty
        ? nickname
        : profile['username']?.toString() ?? '';
  }

  Future<void> _loadFollowState() async {
    if (userId == 0 || widget.dataToken.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {'Authorization': 'Bearer ${widget.dataToken}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (body['ok'] == true && data != null && mounted) {
        setState(() {
          profile = Map<String, dynamic>.from(
            data['profile'] as Map<String, dynamic>? ?? profile,
          );
          following = data['following'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (followLoading || userId == 0 || widget.dataToken.isEmpty) return;
    setState(() => followLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/$userId/follow'),
        headers: {'Authorization': 'Bearer ${widget.dataToken}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (body['ok'] == true && data != null && mounted) {
        setState(() {
          final wasFollowing = following;
          following = data['following'] == true;
          profile['followers'] =
              ((profile['followers'] as num?)?.toInt() ?? 0) +
              (following == wasFollowing
                  ? 0
                  : following
                  ? 1
                  : -1);
        });
      }
    } finally {
      if (mounted) setState(() => followLoading = false);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPlaceholderPage(name: displayName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人主页')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 40,
                child: Icon(Icons.public, size: 44),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '关注 ${profile['following'] ?? 0}   粉丝 ${profile['followers'] ?? 0}   获赞 ${profile['likes'] ?? 0}',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: followLoading ? null : _toggleFollow,
                            child: Text(following ? '已关注' : '关注'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openChat,
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('私聊'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (posts.isEmpty) const EmptyState(text: '还没有动态'),
          ...posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(post: post, token: widget.dataToken),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPlaceholderPage extends StatelessWidget {
  final String name;
  const ChatPlaceholderPage({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('与$name私聊')),
      body: const Center(child: Text('私聊功能尚未接入后端')),
    );
  }
}
