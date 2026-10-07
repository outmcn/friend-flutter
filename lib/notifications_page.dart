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
      await service.markNotificationsRead(t);
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
      case 'favorite':
        return '收藏了你的动态';
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('通知'),
          actions: [
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
                                  onTap: item.postId == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => DynamicDetailPage(
                                                postId: item.postId!,
                                                focusComment:
                                                    item.commentId != null,
                                              ),
                                            ),
                                          ),
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
                                        if (item.postId != null)
                                          const Icon(Icons.chevron_right),
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
