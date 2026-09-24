import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ui_post.dart';
import '../widgets/empty_state.dart';
import 'other_profile_page.dart';
import '../widgets/post_card.dart';
import '../widgets/comment_tile.dart';

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
  final commentFocusNode = FocusNode();
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
  bool showExactPostTime = false;
  bool followAuthorLoading = false;
  final expandedReplies = <int>{};

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

  String _exactTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  String _commentTime(Map<String, dynamic> comment) {
    return _relativeTime(comment['createdAt']?.toString() ?? '');
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

  Future<void> _openTopbarAuthorProfile() async {
    if (openingAuthor || widget.post.authorId == 0 || token == null) return;
    openingAuthor = true;
    try {
      final response = await http.get(
        Uri.parse(
          'https://friend.outmcn.net/api/users/${widget.post.authorId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted || body['ok'] != true) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtherProfilePage(
            data: body['data'] as Map<String, dynamic>,
            dataToken: token!,
            onFollowChanged: widget.onActionChanged,
            isSelf: false,
          ),
        ),
      );
    } finally {
      openingAuthor = false;
    }
  }

  Future<void> _showCommentActions(Map<String, dynamic> comment) async {
    final canDelete = _canDeleteComment(comment);
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
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('删除'),
                  onTap: () async {
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    await _deleteComment(comment);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('举报'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showReportReasons();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReportReasons() async {
    const reasons = [
      '涉嫌欺诈',
      '涉政不当言论',
      '违法信息',
      '色情低俗',
      '涉嫌广告',
      '危害人身安全',
      '谣言',
      '涉及未成年',
      '攻击辱骂',
      '违反公共道德',
      '搬运/盗图',
      '侵权行为',
      '其他违规',
    ];
    String? selectedReason;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '选择举报原因',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setSheetState(() => selectedReason = value),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: reasons.length,
                      itemBuilder: (_, index) => RadioListTile<String>(
                        value: reasons[index],
                        title: Text(reasons[index]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedReason == null
                        ? null
                        : () => Navigator.pop(sheetContext),
                    child: const Text('提交举报'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    liked = widget.post.liked;
    favorited = widget.post.favorited;
    followingAuthor = widget.post.following;
    _loadSession();
  }

  @override
  void dispose() {
    commentController.dispose();
    commentFocusNode.dispose();
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

  List<Widget> _buildCommentWidgets(BuildContext context, ColorScheme colors) {
    final roots = comments.where((c) => c['parentId'] == null).toList();
    final children = <int, List<Map<String, dynamic>>>{};
    for (final comment in comments) {
      final parentId = (comment['parentId'] as num?)?.toInt();
      if (parentId != null) {
        children.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    final widgets = <Widget>[];
    for (final root in roots) {
      widgets.add(_commentWidget(context, colors, root, false));
      final replies = children[(root['id'] as num?)?.toInt()] ?? const [];
      final expanded = expandedReplies.contains((root['id'] as num?)?.toInt());
      final visibleReplies = expanded ? replies : replies.take(2).toList();
      widgets.addAll(
        visibleReplies.map(
          (reply) => _commentWidget(context, colors, reply, true),
        ),
      );
      final remaining = replies.length - visibleReplies.length;
      if (remaining > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 50, bottom: 12),
            child: TextButton(
              onPressed: () {
                setState(() {
                  final id = (root['id'] as num?)?.toInt();
                  if (id != null) expandedReplies.add(id);
                });
              },
              child: Text('展开$remaining条回复'),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _commentWidget(
    BuildContext context,
    ColorScheme colors,
    Map<String, dynamic> comment,
    bool isReply,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => replyingTo = comment);
        FocusScope.of(context).requestFocus(commentFocusNode);
      },
      onLongPress: () => _showCommentActions(comment),
      child: CommentTile(
        comment: comment,
        colors: colors,
        isReply: isReply,
        isSelf: (comment['userId'] as num?)?.toInt() == currentUserId,
        publishedLabel: _commentTime(comment),
        padding: EdgeInsets.only(left: isReply ? 50 : 0, bottom: 12),
        onAvatarTap: () => _openCommentProfile(comment),
        onLongPress: () => _showCommentActions(comment),
      ),
    );
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

  Future<void> _confirmDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除动态'),
        content: const Text('确定要删除这条动态吗？'),
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
    if (confirmed != true || token == null) return;
    final response = await http.delete(
      Uri.parse('https://friend.outmcn.net/api/posts/${widget.post.id}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] == true && mounted) {
      await widget.onActionChanged?.call();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _showShareSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '分享动态',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 88,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _shareTarget(
                      context: sheetContext,
                      icon: Icons.person,
                      label: '最近聊天',
                      onTap: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              SizedBox(
                height: 88,
                child: Row(
                  children: [
                    _shareTarget(
                      context: sheetContext,
                      icon: Icons.wechat,
                      label: '微信',
                      onTap: () => Navigator.pop(sheetContext),
                    ),
                    _shareTarget(
                      context: sheetContext,
                      icon: Icons.chat,
                      label: 'QQ',
                      onTap: () => Navigator.pop(sheetContext),
                    ),
                    _shareTarget(
                      context: sheetContext,
                      icon: Icons.more_horiz,
                      label: '更多',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await Share.share(widget.post.text, subject: '分享动态');
                      },
                    ),
                    if (sessionLoaded && widget.post.authorId != currentUserId)
                      _shareTarget(
                        context: sheetContext,
                        icon: Icons.flag_outlined,
                        label: '举报',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _reportPost();
                        },
                      ),
                    if (sessionLoaded && widget.post.authorId == currentUserId)
                      _shareTarget(
                        context: sheetContext,
                        icon: Icons.delete_outline,
                        label: '删除动态',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _confirmDeletePost();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareTarget({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 82,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final post = widget.post;
    final isOwnPost = post.authorId != 0 && post.authorId == currentUserId;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: isOwnPost ? null : _openTopbarAuthorProfile,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor:
                        avatarColors[post.authorAvatarId.clamp(0, 9)],
                    child: Icon(
                      avatarIcons[post.authorAvatarId.clamp(0, 9)],
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      post.author,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (sessionLoaded && !isOwnPost)
            FilledButton(
              onPressed: followAuthorLoading ? null : _toggleAuthorFollow,
              style: FilledButton.styleFrom(
                minimumSize: const Size(58, 34),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(followingAuthor ? '已关注' : '关注'),
            ),
          IconButton(
            onPressed: _showShareSheet,
            padding: const EdgeInsets.only(left: 2, right: 16),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: const Icon(Icons.ios_share),
            tooltip: '分享',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  if (post.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        post.imageUrl!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  if (post.imageUrl != null) const SizedBox(height: 18),
                  if (post.text.isNotEmpty)
                    Text(
                      post.text,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.45,
                        color: c.onSurface,
                      ),
                    ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () =>
                        setState(() => showExactPostTime = !showExactPostTime),
                    child: Row(
                      children: [
                        Text(
                          showExactPostTime
                              ? _exactTime(post.time)
                              : _relativeTime(post.time),
                          style: TextStyle(
                            fontSize: 12,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                        if (post.city.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            post.city,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: c.outlineVariant),
                  const SizedBox(height: 8),
                  Text(
                    '共${comments.length}条评论',
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
                    ..._buildCommentWidgets(context, c),
                ],
              ),
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
                      focusNode: commentFocusNode,
                      minLines: 1,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendComment(),
                      decoration: InputDecoration(
                        hintText: replyingTo == null
                            ? '写评论…'
                            : '回复：${replyingTo!['nickname']}…',
                        fillColor: c.surfaceContainerHighest,
                        constraints: const BoxConstraints(minHeight: 28),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _toggleAction('like'),
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.red : c.primary,
                    ),
                  ),
                  Text(
                    '${widget.post.likes}',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                  IconButton(
                    onPressed: () => _toggleAction('favorite'),
                    icon: Icon(
                      favorited ? Icons.bookmark : Icons.bookmark_outline,
                      color: favorited ? Colors.amber : c.primary,
                    ),
                  ),
                  Text(
                    '${widget.post.favorites}',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                  IconButton(
                    onPressed: () => commentFocusNode.requestFocus(),
                    icon: Icon(Icons.chat_bubble_outline, color: c.primary),
                  ),
                  Text(
                    '${comments.length}',
                    style: TextStyle(color: c.onSurfaceVariant),
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
