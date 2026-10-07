part of 'main.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final service = DDPostService();
  late final List<DiscoverFeed> feeds;
  final pendingLikes = <int>{};
  int selectedTab = 0;

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) throw Exception('请先登录');
    return token;
  }

  @override
  void initState() {
    super.initState();
    feeds = List.generate(3, (tab) {
      final feed = DiscoverFeed((offset) async {
        final token = await _token();
        if (tab == 1 && offset == 0) await syncCachedLocation(service, token);
        final posts = tab == 0
            ? await service.fetchRecommendedPosts(token, offset: offset)
            : tab == 1
                ? await service.fetchNearbyPosts(token, offset: offset)
                : await service.fetchFollowingPosts(token, offset: offset);
        return Future.wait(
            posts.map((post) => service.resolvePostMedia(token, post)));
      });
      feed.scroll.addListener(() {
        if (feed.scroll.hasClients &&
            feed.scroll.position.extentAfter < 500 &&
            feed.initialized &&
            feed.error == null) {
          feed.load();
        }
      });
      return feed;
    });
    feeds.first.load();
  }

  Future<void> _like(DDPost post) async {
    if (!pendingLikes.add(post.id)) return;
    try {
      await service.toggleLike(await _token(), post.id);
      if (!mounted) return;
      final updated = post.copyWith(
          liked: !post.liked, likes: post.likes + (post.liked ? -1 : 1));
      for (final feed in feeds) {
        feed.updateLike(updated);
      }
      await DDPostService.clearProfileTabCaches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      pendingLikes.remove(post.id);
    }
  }

  Future<void> _open(DDPost post) async {
    final deleted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DynamicDetailPage(
            postId: post.id,
            initialPost: post,
          ),
        ));
    if (!mounted || deleted != true) return;
    for (final feed in feeds) {
      feed.posts.removeWhere((item) => item.id == post.id);
    }
    feeds[selectedTab].notifyListeners();
  }

  Widget _card(DiscoverFeed feed, int index, {bool fullWidth = false}) {
    final post = feed.posts[index];
    if (index + 1 < feed.posts.length) {
      final next = feed.posts[index + 1];
      if (next.imageUrl?.isNotEmpty == true) {
        unawaited(_PermanentImageCache.prefetch(next.imageUrl!));
      }
      if (next.thumbnailUrl?.isNotEmpty == true) {
        unawaited(_PermanentImageCache.prefetch(next.thumbnailUrl!));
      }
    }
    return _DiscoverFeedCard(
      key: ValueKey(post.id),
      feed: feed,
      post: post,
      fullWidth: fullWidth,
      onLike: _like,
      onOpen: _open,
    );
  }

  Widget _list(int tab) {
    final feed = feeds[tab];
    return AnimatedBuilder(
      animation: feed,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () => feed.load(refresh: true),
        child: CustomScrollView(
          key: PageStorageKey('discover.$tab'),
          controller: feed.scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (tab == 0)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _card(feed, index, fullWidth: true),
                  childCount: feed.posts.length,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<int>) return null;
                    final index =
                        feed.posts.indexWhere((post) => post.id == key.value);
                    return index < 0 ? null : index;
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    width: double.infinity,
                    child: MasonryGridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      itemCount: feed.posts.length,
                      itemBuilder: (context, index) => _card(feed, index),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: feed.error != null
                  ? _PageErrorState(
                      title: '动态加载失败',
                      subtitle: feed.error!,
                      onRetry: () => feed.load(refresh: !feed.hasMore))
                  : feed.busy
                      ? const Center(child: CircularProgressIndicator())
                      : feed.posts.isEmpty
                          ? const Center(child: Text('暂无动态'))
                          : feed.hasMore
                              ? TextButton(
                                  onPressed: () => feed.load(),
                                  child: const Text('加载更多'))
                              : const Center(child: Text('没有更多动态了')),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(
              children: List.generate(
                  3,
                  (tab) => TextButton(
                        onPressed: () {
                          setState(() => selectedTab = tab);
                          if (!feeds[tab].initialized) feeds[tab].load();
                        },
                        child: Text(['推荐', '本地', '关注'][tab],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: selectedTab == tab
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selectedTab == tab
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).hintColor,
                            )),
                      ))),
          actions: [
            IconButton(
                tooltip: '通知中心',
                icon: const Icon(TIcons.notification),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsPage()))),
            IconButton(
                tooltip: '创建动态',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreatePostPage()));
                  if (mounted) feeds[selectedTab].load(refresh: true);
                }),
          ],
        ),
        body:
            IndexedStack(index: selectedTab, children: List.generate(3, _list)),
      );

  @override
  void dispose() {
    for (final feed in feeds) {
      feed.dispose();
    }
    service.dispose();
    super.dispose();
  }
}

// 单条数据变化只刷新对应卡片，列表结构仍由 feed 的分页通知更新。
class _DiscoverFeedCard extends StatefulWidget {
  const _DiscoverFeedCard({
    super.key,
    required this.feed,
    required this.post,
    required this.fullWidth,
    required this.onLike,
    required this.onOpen,
  });

  final DiscoverFeed feed;
  final DDPost post;
  final bool fullWidth;
  final ValueChanged<DDPost> onLike;
  final ValueChanged<DDPost> onOpen;

  @override
  State<_DiscoverFeedCard> createState() => _DiscoverFeedCardState();
}

class _DiscoverFeedCardState extends State<_DiscoverFeedCard> {
  late DDPost post;

  @override
  void initState() {
    super.initState();
    post = widget.post;
    widget.feed.postChanges.addListener(_update);
  }

  void _update() {
    final updated = widget.feed.postChanges.value;
    if (updated != null && updated.id == post.id) {
      setState(() => post = updated);
    }
  }

  @override
  void didUpdateWidget(covariant _DiscoverFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed != widget.feed) {
      oldWidget.feed.postChanges.removeListener(_update);
      widget.feed.postChanges.addListener(_update);
    }
    post = widget.post;
  }

  @override
  Widget build(BuildContext context) {
    final card = _DiscoverProfileCard(
      post: post,
      onLike: () => widget.onLike(post),
      onOpen: () => widget.onOpen(post),
    );
    return widget.fullWidth
        ? Padding(padding: const EdgeInsets.only(bottom: 8), child: card)
        : card;
  }

  @override
  void dispose() {
    widget.feed.postChanges.removeListener(_update);
    super.dispose();
  }
}
