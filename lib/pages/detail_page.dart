import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../models/ui_post.dart';
import '../widgets/empty_state.dart';
import 'other_profile_page.dart';
import '../widgets/post_card.dart';

class DetailPage extends StatefulWidget {
  final UiPost post;
  final Future<void> Function()? onActionChanged;
  final String token;
  const DetailPage({
    super.key,
    required this.post,
    this.token = '',
    this.onActionChanged,
  });
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final commentController = TextEditingController();
  final comments = <Map<String, dynamic>>[];
  String? token;
  bool liked = false;
  bool favorited = false;
  bool sending = false;
  bool openingAuthor = false;
  bool reporting = false;
  int currentUserId = 0;
  bool sessionLoaded = false;
  bool followingAuthor = false;
  bool followAuthorLoading = false;

  String _relativeTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleAuthorFollow() async {
    if (followAuthorLoading || token == null || widget.post.authorId == 0) {
      return;
    }
    setState(() => followAuthorLoading = true);
    try {
      final r = await http.post(
        Uri.parse(
          'https://friend.outmcn.net/api/users/${widget.post.authorId}/follow',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && mounted) {
        setState(() => followingAuthor = b['data']['following'] == true);
      }
    } finally {
      if (mounted) setState(() => followAuthorLoading = false);
    }
  }

  Map<String, dynamic>? replyingTo;

  String _commentRelativeTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openCommentProfile(Map<String, dynamic> comment) async {
    final id = (comment['userId'] as num?)?.toInt() ?? 0;
    if (id == 0 || token == null || token!.isEmpty) return;
    final r = await http.get(
      Uri.parse('https://friend.outmcn.net/api/users/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (!mounted || body['ok'] != true) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherProfilePage(
          data: body['data'] as Map<String, dynamic>,
          dataToken: token!,
          onFollowChanged: widget.onActionChanged,
          isSelf: id == currentUserId,
        ),
      ),
    );
  }

  Future<void> _showCommentActions(Map<String, dynamic> comment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          snap: true,
          snapSizes: const [0.28, 0.52],
          minChildSize: 0.22,
          initialChildSize: 0.28,
          maxChildSize: 0.52,
          builder: (_, controller) => ListView(
            controller: controller,
            physics: const BouncingScrollPhysics(),
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制'),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: comment['content']?.toString() ?? ''),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('举报'),
                onTap: () async {
                  final r = await http.post(
                    Uri.parse(
                      'https://friend.outmcn.net/api/comments/${comment['id']}/report',
                    ),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({'reason': '违规评论'}),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted && r.statusCode >= 200 && r.statusCode < 300) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('举报已提交')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAuthorProfile() async {
    if (openingAuthor) return;
    openingAuthor = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = widget.token.isEmpty
          ? (prefs.getString('friend.auth.token') ?? '')
          : widget.token;
      if (widget.post.authorId == 0 || authToken.isEmpty) return;
      final r = await http.get(
        Uri.parse(
          'https://friend.outmcn.net/api/users/${widget.post.authorId}',
        ),
        headers: {'Authorization': 'Bearer $authToken'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && mounted) {
        final meResponse = await http.get(
          Uri.parse('https://friend.outmcn.net/api/me'),
          headers: {'Authorization': 'Bearer $authToken'},
        );
        final meBody = jsonDecode(meResponse.body) as Map<String, dynamic>;
        final me = meBody['data'] as Map<String, dynamic>?;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherProfilePage(
              data: b['data'] as Map<String, dynamic>,
              dataToken: authToken,
              onFollowChanged: widget.onActionChanged,
              isSelf: (me?['id'] as num?)?.toInt() == widget.post.authorId,
            ),
          ),
        );
      }
    } finally {
      openingAuthor = false;
    }
  }

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
    if (token != null) {
      final response = await http.get(
        Uri.parse('https://friend.outmcn.net/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (body['ok'] == true && data != null) {
        currentUserId = (data['id'] as num?)?.toInt() ?? 0;
      }
    }
    if (mounted) setState(() => sessionLoaded = true);
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
      if (b['ok'] == true && b['data'] is List && mounted) {
        setState(() {
          comments
            ..clear()
            ..addAll((b['data'] as List).whereType<Map<String, dynamic>>());
        });
      }
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
          if (action == 'like') {
            liked = b['data']['liked'] == true;
          } else {
            favorited = b['data']['favorited'] == true;
          }
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
        body: jsonEncode({
          'content': value,
          if (replyingTo != null) 'parentId': replyingTo!['id'],
        }),
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true) {
        commentController.clear();
        if (mounted) setState(() => replyingTo = null);
        await _loadComments();
        await widget.onActionChanged?.call();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  bool _canDeleteComment(Map<String, dynamic> comment) {
    final authorId = (comment['userId'] as num?)?.toInt() ?? 0;
    return authorId == currentUserId || widget.post.authorId == currentUserId;
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    if (token == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('确定要删除这条评论吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await http.delete(
      Uri.parse('https://friend.outmcn.net/api/comments/${comment['id']}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] == true) {
      await _loadComments();
      await widget.onActionChanged?.call();
    }
  }

  Future<void> _reportPost() async {
    if (token == null || reporting) return;
    final reasonController = TextEditingController(text: '违规内容');
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('举报动态'),
        content: TextField(
          controller: reasonController,
          maxLength: 200,
          decoration: const InputDecoration(labelText: '举报原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('提交举报'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => reporting = true);
    try {
      final response = await http.post(
        Uri.parse(
          'https://friend.outmcn.net/api/posts/${widget.post.id}/report',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason.trim()}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('举报已提交')));
      }
    } finally {
      if (mounted) setState(() => reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final post = widget.post;
    final isOwnPost = post.authorId != 0 && post.authorId == currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('动态详情'),
        actions: [
          if (sessionLoaded && !isOwnPost)
            IconButton(
              onPressed: reporting ? null : _reportPost,
              icon: const Icon(Icons.flag_outlined),
              tooltip: '举报',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _openAuthorProfile,
                      child: CircleAvatar(
                        backgroundColor:
                            avatarColors[post.authorAvatarId.clamp(0, 9)],
                        child: Icon(
                          avatarIcons[post.authorAvatarId.clamp(0, 9)],
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('发布时间'),
                            content: Text(post.time),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.author,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: c.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'IP：${post.city}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _relativeTime(post.time),
                              style: TextStyle(
                                fontSize: 12,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isOwnPost)
                      OutlinedButton(
                        onPressed: followAuthorLoading
                            ? null
                            : _toggleAuthorFollow,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(followingAuthor ? '已关注' : '关注'),
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
                  ...comments.map((comment) {
                    final avatarId =
                        ((comment['avatarId'] as num?)?.toInt() ?? 0).clamp(
                          0,
                          9,
                        );
                    final parentId = (comment['parentId'] as num?)?.toInt();
                    return GestureDetector(
                      onTap: () {
                        setState(() => replyingTo = comment);
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                      onLongPress: () => _showCommentActions(comment),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: parentId == null ? 0 : 28,
                          bottom: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _openCommentProfile(comment),
                              child: CircleAvatar(
                                backgroundColor: avatarColors[avatarId],
                                child: Icon(
                                  avatarIcons[avatarId],
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          comment['nickname']?.toString() ??
                                              '评论',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if ((comment['city']?.toString() ?? '')
                                          .isNotEmpty)
                                        Text(
                                          '  ${comment['city']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: c.onSurfaceVariant,
                                          ),
                                        ),
                                      const Spacer(),
                                      Text(
                                        _commentRelativeTime(
                                          comment['createdAt']?.toString() ??
                                              '',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: c.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(comment['content']?.toString() ?? ''),
                                  if (_canDeleteComment(comment))
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        onPressed: () =>
                                            _deleteComment(comment),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: '删除评论',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
                      minLines: 1,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendComment(),
                      decoration: InputDecoration(
                        hintText: replyingTo == null
                            ? '写评论…'
                            : '回复 ${replyingTo!['nickname']}…',
                        fillColor: c.surfaceContainerHighest,
                        constraints: const BoxConstraints(minHeight: 38),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: sending ? null : sendComment,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
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
