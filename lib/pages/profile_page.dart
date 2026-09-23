import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/ui_post.dart';
import '../widgets/post_card.dart';
import '../widgets/empty_state.dart';

class ProfilePage extends StatefulWidget {
  final String token;
  const ProfilePage({super.key, required this.token});
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String nickname = '';
  bool loading = true;
  int section = 0;
  List<UiPost> ownPosts = [];
  List<UiPost> favoritePosts = [];
  List<UiPost> likedPosts = [];

  @override
  void initState() {
    super.initState();
    refreshFromServer();
  }

  Future<void> refreshFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('https://friend.outmcn.net/api/me/summary'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      if (body['ok'] == true && data is Map<String, dynamic> && mounted) {
        final profile = data['profile'] as Map<String, dynamic>;
        setState(() {
          nickname =
              (profile['nickname']?.toString().trim().isNotEmpty == true
                      ? profile['nickname']
                      : profile['username'])
                  .toString();
          ownPosts = _posts(data['posts']);
          favoritePosts = _posts(data['favorited']);
          likedPosts = _posts(data['liked']);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  List<UiPost> _posts(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().map(UiPost.fromJson).toList()
      : <UiPost>[];

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: nickname);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改名字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: '输入新的名字'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    final response = await http.put(
      Uri.parse('https://friend.outmcn.net/api/me'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'nickname': value}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] == true && mounted) setState(() => nickname = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visiblePosts = section == 0
        ? ownPosts
        : (section == 1 ? favoritePosts : likedPosts);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [colors.surfaceContainer, colors.primaryContainer],
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
                            loading ? '加载中…' : nickname,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _editNickname,
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          tooltip: '修改名字',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '关注  0     粉丝  0     获赞  0',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 42,
                backgroundColor: colors.primary,
                child: Icon(Icons.public, size: 48, color: colors.onPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ProfileTab(
                text: '动态',
                selected: section == 0,
                onTap: () => setState(() => section = 0),
              ),
            ),
            Expanded(
              child: _ProfileTab(
                text: '收藏',
                selected: section == 1,
                onTap: () => setState(() => section = 1),
              ),
            ),
            Expanded(
              child: _ProfileTab(
                text: '点赞',
                selected: section == 2,
                onTap: () => setState(() => section = 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visiblePosts.isEmpty)
          EmptyState(
            text: section == 0 ? '还没有动态' : (section == 1 ? '还没有收藏' : '还没有点赞'),
          ),
        ...visiblePosts.map(
          (post) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(post: post, onActionChanged: refreshFromServer),
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  const _ProfileTab({required this.text, this.selected = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? c.onPrimary : c.onSurface,
          ),
        ),
      ),
    );
  }
}
