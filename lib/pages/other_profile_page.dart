import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/post_card.dart';
import '../widgets/empty_state.dart';
import '../models/ui_post.dart';

class OtherProfilePage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String dataToken;
  final Future<void> Function()? onFollowChanged;
  final bool isSelf;
  const OtherProfilePage({
    super.key,
    required this.data,
    this.dataToken = '',
    this.onFollowChanged,
    this.isSelf = false,
  });
  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  bool spaceExpanded = false;
  late Map<String, dynamic> profile;
  late List<UiPost> posts;
  bool following = false;
  bool followLoading = false;
  bool profileLiked = false;
  bool profileLikeLoading = false;

  int get userId => (profile['id'] as num?)?.toInt() ?? 0;
  String get displayName =>
      (profile['nickname']?.toString().trim().isNotEmpty == true)
      ? profile['nickname'].toString()
      : profile['username']?.toString() ?? '';
  int get avatarId => ((profile['avatarId'] as num?)?.toInt() ?? 0).clamp(0, 9);

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
    following = widget.data['following'] == true;
  }

  Future<void> _toggleFollow() async {
    if (followLoading || userId == 0 || widget.dataToken.isEmpty) return;
    setState(() => followLoading = true);
    try {
      final r = await http.post(
        Uri.parse('https://friend.outmcn.net/api/users/$userId/follow'),
        headers: {'Authorization': 'Bearer ${widget.dataToken}'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && mounted) {
        setState(() => following = b['data']['following'] == true);
        await widget.onFollowChanged?.call();
      }
    } finally {
      if (mounted) setState(() => followLoading = false);
    }
  }

  void _openChat() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChatPlaceholderPage(name: displayName)),
  );

  Future<void> _toggleProfileLike() async {
    if (profileLikeLoading || userId == 0 || widget.dataToken.isEmpty) return;
    setState(() => profileLikeLoading = true);
    try {
      final r = await http.post(
        Uri.parse('https://friend.outmcn.net/api/users/$userId/like'),
        headers: {'Authorization': 'Bearer ${widget.dataToken}'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && mounted) {
        setState(() {
          profileLiked = b['data']['liked'] == true;
          profile['likes'] = b['data']['likes'];
        });
      }
    } finally {
      if (mounted) setState(() => profileLikeLoading = false);
    }
  }

  Future<void> _blockUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('拉黑用户'),
        content: Text('确定要拉黑 $displayName 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('拉黑'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final response = await http.post(
        Uri.parse('https://friend.outmcn.net/api/users/$userId/block'),
        headers: {'Authorization': 'Bearer ${widget.dataToken}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已拉黑')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelf ? '我的主页' : 'Ta的主页'),
        actions: [
          if (!widget.isSelf)
            IconButton(
              onPressed: _blockUser,
              icon: const Icon(Icons.block_outlined),
              tooltip: '拉黑',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [c.surfaceContainer, c.primaryContainer],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: c.onSurface,
                              ),
                            ),
                          ),
                          if ((profile['city']?.toString() ?? '').isNotEmpty)
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: c.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'IP：${profile['city']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.onPrimaryContainer,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${profile['activeDays'] ?? 0}天',
                              style: TextStyle(
                                color: c.onSecondaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '关注 ${profile['following'] ?? 0}',
                            style: TextStyle(color: c.onSurfaceVariant),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '粉丝 ${profile['followers'] ?? 0}',
                            style: TextStyle(color: c.onSurfaceVariant),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '获赞 ${profile['likes'] ?? 0}',
                            style: TextStyle(color: c.onSurfaceVariant),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '动态 ${profile['posts'] ?? posts.length}',
                            style: TextStyle(color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 42,
                  backgroundColor: avatarColors[avatarId],
                  child: Icon(
                    avatarIcons[avatarId],
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.isSelf)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: followLoading ? null : _toggleFollow,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(following ? '已关注' : '关注'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openChat,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('私聊'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: profileLikeLoading ? null : _toggleProfileLike,
                    icon: Icon(
                      profileLiked ? Icons.favorite : Icons.favorite_border,
                      color: profileLiked ? Colors.red : c.onSurfaceVariant,
                    ),
                    tooltip: '主页点赞',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (posts.isEmpty) const EmptyState(text: '还没有动态'),
          ...posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: post,
                token: widget.dataToken,
                hideAuthor: true,
              ),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('与$name私聊')),
    body: const Center(child: Text('私聊功能尚未接入后端')),
  );
}
