part of 'main.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DDPostService service = DDPostService();
  List<DDNotification> notifications = const [];
  bool loading = true;
  String? error;
  bool get hasUnread => notifications.any((item) => !item.read);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<String> token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final t = await token();
      final items = await service.fetchNotifications(t);
      if (mounted) setState(() => notifications = items);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String titleFor(DDNotification item) {
    switch (item.type) {
      case 'like':
        return '点赞了你的动态';
      case 'post_like':
        return '';
      case 'favorite':
        return '收藏了你的动态';
      case 'post_favorite':
        return '';
      case 'post_gift':
        return '';
      case 'post_comment':
        return '';
      case 'comment':
        return '评论了你的动态';
      case 'comment_reply':
        return '回复了你的评论';
      case 'comment_deleted':
        return '你的评论被系统删除';
      case 'post_deleted':
        return '你的动态被系统删除';
      case 'follow':
        return '关注了你';
      default:
        return item.content;
    }
  }

  Future<void> _markAllRead() async {
    try {
      await service.markNotificationsRead(await token());
      if (mounted) setState(() {
        notifications = notifications.map((n) => DDNotification(id: n.id, type: n.type, content: n.content, createdAt: n.createdAt, nickname: n.nickname, avatar: n.avatar, postId: n.postId, commentId: n.commentId, postContent: n.postContent, commentContent: n.commentContent, read: true)).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('通知'),
          actions: [
            TextButton(onPressed: hasUnread ? _markAllRead : null, child: const Text('一键已读')),
            IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _PageErrorState(
                    title: '通知加载失败', subtitle: error!, onRetry: load)
                : RefreshIndicator(
                    onRefresh: load,
                    child: notifications.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(child: Text('暂无通知')),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, index) {
                              final item = notifications[index];
                              final actor =
                                  item.nickname?.trim().isNotEmpty == true
                                      ? item.nickname!
                                      : '系统';
                              return Card(
                                margin: EdgeInsets.zero,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    final t = await token();
                                    await service.markNotificationRead(t, item.id);
                                    if (mounted) setState(() {
                                      notifications = notifications.map((n) => n.id == item.id
                                          ? DDNotification(id: n.id, type: n.type, content: n.content, createdAt: n.createdAt, nickname: n.nickname, avatar: n.avatar, postId: n.postId, commentId: n.commentId, postContent: n.postContent, commentContent: n.commentContent, read: true)
                                          : n).toList();
                                    });
                                    if (!mounted || item.postId == null) return;
                                    await Navigator.push(context, MaterialPageRoute(builder: (_) => item.type == 'post_rejected'
                                        ? ViolationNotificationPage(postId: item.postId!)
                                        : DynamicDetailPage(postId: item.postId!, focusComment: item.commentId != null)));
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          child: item.avatar?.isNotEmpty == true
                                              ? ClipOval(
                                                  child: _PermanentCachedImage(
                                                    url: item.avatar!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Icon(item.nickname == null
                                                  ? Icons.shield_outlined
                                                  : Icons.person_outline),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('$actor ${titleFor(item)}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              if (item.postContent
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 5),
                                                  child: Text(
                                                    '动态：${item.postContent}',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (item.commentContent
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 3),
                                                  child: Text(
                                                    '评论：${item.commentContent}',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 5),
                                                child: Text(
                                                  '${item.content} · ${item.createdAt}',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!item.read)
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      );
}


class ViolationNotificationPage extends StatefulWidget {
  const ViolationNotificationPage({super.key, required this.postId});
  final int postId;
  @override State<ViolationNotificationPage> createState() => _ViolationNotificationPageState();
}

class _ViolationNotificationPageState extends State<ViolationNotificationPage> {
  final DDPostService service = DDPostService();
  DDPost? post; String? error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = await service.fetchPost(prefs.getString('friend.auth.token') ?? '', widget.postId);
      if (mounted) setState(() => post = value);
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
  }
  @override void dispose() { service.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('违规内容')),
    body: error != null ? Center(child: Text(error!)) : post == null ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(children: [Icon(TIcons.error_triangle_filled, color: Colors.red), SizedBox(width: 8), Text('该动态正在确认违规', style: TextStyle(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 18),
        if (post!.content.trim().isNotEmpty) Text(post!.content.characters.map((_) => '*').join(), style: const TextStyle(fontSize: 16, height: 1.5)),
        if (post!.imageUrl?.isNotEmpty == true || post!.videoUrl?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          Container(height: 220, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(TIcons.error_triangle_filled, color: Colors.red, size: 42), SizedBox(height: 8), Text('图片涉嫌违规')]))
        ],
      ],
    ),
  );
}
