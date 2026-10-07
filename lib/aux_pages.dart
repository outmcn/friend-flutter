part of 'main.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleListPage(
        title: '活动中心',
        items: const ['周末线下见面会', '城市摄影活动', '兴趣交友派对', '创作者交流会'],
      );
}

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleListPage(
        title: '趋势榜单',
        items: const ['本周热门动态', '最受欢迎用户', '热门兴趣圈', '城市热度排行'],
      );
}

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});
  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final service = DDPostService();
  List<DDPost> posts = const [];
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

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      posts = const [];
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deletePost(DDPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确认删除这条动态？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('friend.auth.token') ??
          '';
      if (token.isEmpty) throw Exception('请先登录');
      await service.deletePost(token, post.id);
      await DDPostService.clearProfileTabCaches();
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('动态已删除')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('我的动态')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    24 + MediaQuery.of(context).padding.bottom + 88,
                  ),
                  children: [
                    if (error != null)
                      _PageErrorState(
                        title: '动态为空',
                        subtitle: '新后端暂未提供动态接口',
                        onRetry: load,
                      )
                    else if (posts.isEmpty)
                      const _EmptyStateCard(
                        icon: Icons.article_outlined,
                        title: '暂无动态',
                        subtitle: '发布你的第一条动态吧',
                      )
                    else
                      ...posts.map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DynamicPostCard(
                            post: post,
                            authorNavigation: false,
                            onDelete: () => _deletePost(post),
                            onLike: () async {
                              final token =
                                  (await SharedPreferences.getInstance())
                                          .getString('friend.auth.token') ??
                                      '';
                              if (token.isNotEmpty) {
                                await service.toggleLike(token, post.id);
                                await load();
                              }
                            },
                            onFavorite: () async {
                              final token =
                                  (await SharedPreferences.getInstance())
                                          .getString('friend.auth.token') ??
                                      '';
                              if (token.isNotEmpty) {
                                await service.toggleFavorite(token, post.id);
                                await load();
                              }
                            },
                            onOpen: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DynamicDetailPage(postId: post.id),
                              ),
                            ),
                            onComment: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DynamicDetailPage(
                                  postId: post.id,
                                  focusComment: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
}
