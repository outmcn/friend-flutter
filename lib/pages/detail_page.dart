import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ui_post.dart';
import '../widgets/empty_state.dart';

class DetailPage extends StatefulWidget {
  final UiPost post;
  final Future<void> Function()? onActionChanged;
  const DetailPage({super.key, required this.post, this.onActionChanged});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final commentController = TextEditingController();
  final comments = <String>[];
  String? token;
  bool liked = false;
  bool favorited = false;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    liked = widget.post.likes > 0;
    favorited = widget.post.favorites > 0;
    _loadSession();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('friend.auth.token');
    await _loadComments();
  }

  Future<void> _loadComments() async {
    if (token == null || widget.post.id == 0) return;
    try {
      final r = await http.get(
        Uri.parse(
          'https://friend.outmcn.net/api/posts/${widget.post.id}/comments',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && b['data'] is List && mounted)
        setState(() {
          comments
            ..clear()
            ..addAll(
              (b['data'] as List).whereType<Map<String, dynamic>>().map(
                (x) => x['content'].toString(),
              ),
            );
        });
    } catch (_) {}
  }

  Future<void> _toggleAction(String action) async {
    if (token == null || widget.post.id == 0) return;
    try {
      final r = await http.post(
        Uri.parse(
          'https://friend.outmcn.net/api/posts/${widget.post.id}/$action',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && mounted) {
        setState(() {
          if (action == 'like')
            liked = b['data']['liked'] == true;
          else
            favorited = b['data']['favorited'] == true;
        });
        await widget.onActionChanged?.call();
      }
    } catch (_) {}
  }

  Future<void> sendComment() async {
    final value = commentController.text.trim();
    if (value.isEmpty || token == null || widget.post.id == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => sending = true);
    try {
      final r = await http.post(
        Uri.parse(
          'https://friend.outmcn.net/api/posts/${widget.post.id}/comments',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': value}),
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true) {
        commentController.clear();
        await _loadComments();
        await widget.onActionChanged?.call();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final post = widget.post;
    return Scaffold(
      appBar: AppBar(title: const Text('动态详情')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: c.primary,
                      child: Icon(Icons.public, color: c.onPrimary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: c.onSurface,
                          ),
                        ),
                        Text(
                          post.time,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (post.text.isNotEmpty)
                  Text(
                    post.text,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.45,
                      color: c.onSurface,
                    ),
                  ),
                const SizedBox(height: 18),
                if (post.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      post.imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                const SizedBox(height: 22),
                Divider(color: c.outlineVariant),
                const SizedBox(height: 8),
                Text(
                  '评论',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (comments.isEmpty)
                  EmptyState(text: '还没有评论')
                else
                  ...comments.map(
                    (text) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: c.primary,
                        child: Icon(Icons.public, color: c.onPrimary),
                      ),
                      title: const Text('评论'),
                      subtitle: Text(text),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendComment(),
                      decoration: InputDecoration(
                        hintText: '写评论…',
                        fillColor: c.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: sending ? null : sendComment,
                    child: Text(sending ? '发送中…' : '发送'),
                  ),
                  IconButton(
                    onPressed: () => _toggleAction('like'),
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.red : c.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleAction('favorite'),
                    icon: Icon(
                      favorited ? Icons.star : Icons.star_border,
                      color: favorited ? Colors.amber : c.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
