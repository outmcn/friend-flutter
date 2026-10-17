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
  final pendingFavorites = <int>{};
  final _cardKeys = <String, GlobalKey>{};
  int selectedTab = 0;
  String _discoverLocalTabLabel = '本地';

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) throw Exception('请先登录');
    return token;
  }

  Future<void> _restoreDiscoverCityLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = (prefs.getString('dd.location.city') ?? '').trim();
    if (!mounted || cached.isEmpty) return;
    setState(() => _discoverLocalTabLabel = cached);
  }

  Future<void> _loadDiscoverCity() async {
    try {
      final token = await _token();
      final city = await cachedCityLabel(service, token);
      if (!mounted || city == '城市') return;
      setState(() => _discoverLocalTabLabel = city);
    } catch (_) {
      // 城市获取失败时保留“本地”，不影响推荐和关注列表。
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreDiscoverCityLabel();
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
      }, cacheKey: 'dd.discover.feed.$tab');
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
    final firstFeed = feeds.first;
    unawaited(firstFeed.restoreCache().then((_) {
      if (!firstFeed.initialized) return firstFeed.load();
      return Future<void>.value();
    }));
    // 城市标签首次切换时再获取，避免首屏额外请求。
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
        _showTopNotice(context, SnackBar(content: Text('$e')));
      }
    } finally {
      pendingLikes.remove(post.id);
    }
  }

  Future<void> _favorite(DDPost post) async {
    if (!pendingFavorites.add(post.id)) return;
    try {
      await service.toggleFavorite(await _token(), post.id);
      if (!mounted) return;
      final updated = post.copyWith(
        favorited: !post.favorited,
        favorites: post.favorites + (post.favorited ? -1 : 1),
      );
      for (final feed in feeds) {
        feed.updateFavorite(updated);
      }
      await DDPostService.clearProfileTabCaches();
    } catch (e) {
      if (mounted) _showTopNotice(context, SnackBar(content: Text('$e')));
    } finally {
      pendingFavorites.remove(post.id);
    }
  }

  Future<void> _share(DDPost post) async {
    await Clipboard.setData(
      ClipboardData(text: '动态 ${post.id}：${post.content}'),
    );
    if (mounted) _showTopNotice(context, const SnackBar(content: Text('动态内容已复制，可粘贴分享')));
  }

  Future<void> _report(DDPost post) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPostPage(
          postId: post.id,
          service: service,
          token: _token,
        ),
      ),
    );
    if (submitted == true && mounted) {
      _showTopNotice(context, const Text('举报已提交'));
    }
  }

  Future<void> _open(DDPost post) async {
    final feed = feeds[selectedTab];
    final key = _cardKeys.putIfAbsent(
      '$selectedTab:${post.id}',
      GlobalKey.new,
    );
    if (!mounted) return;
    final routeFuture = Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => DynamicDetailPage(
          postId: post.id,
          initialPost: post,
          cardKey: key,
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealCardEdgesOnly(key, feed.scroll);
    });
    final deleted = await routeFuture;
    if (!mounted) return;
    if (deleted != true) return;
    feed.posts.removeWhere((item) => item.id == post.id);
    feed.markChanged();
  }

  void _revealCardEdgesOnly(GlobalKey key, ScrollController scroll) {
    final cardContext = key.currentContext;
    final cardBox = cardContext?.findRenderObject() as RenderBox?;
    if (cardBox == null || !scroll.hasClients) return;
    final viewport =
        scroll.position.context.storageContext.findRenderObject() as RenderBox?;
    if (viewport == null) return;
    final cardTop = cardBox.localToGlobal(Offset.zero).dy;
    final cardBottom = cardTop + cardBox.size.height;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    var delta = 0.0;
    if (cardTop < viewportTop) delta = cardTop - viewportTop;
    if (cardBottom > viewportBottom) delta = cardBottom - viewportBottom;
    if (delta == 0) return;
    const cardGap = 8.0;
    final position = scroll.position;
    position.jumpTo(
      (position.pixels + delta + (delta > 0 ? cardGap : -cardGap)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  Widget _card(DiscoverFeed feed, int index) {
    final post = feed.posts[index];
    final feedIndex = feeds.indexOf(feed);
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
      key: _cardKeys.putIfAbsent(
        '$feedIndex:${post.id}',
        GlobalKey.new,
      ),
      feed: feed,
      post: post,
      onLike: _like,
      onFavorite: _favorite,
      onShare: _share,
      onReport: _report,
      onOpen: _open,
    );
  }

  void _scrollCurrentTabToTop() {
    final scroll = feeds[selectedTab].scroll;
    if (!scroll.hasClients || scroll.offset <= 0) return;
    unawaited(scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    ));
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _card(feed, index),
                  childCount: feed.posts.length,
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
                  : (feed.restoring || (feed.busy && feed.posts.isEmpty))
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : feed.posts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: Text('暂无动态')),
                            )
                          : feed.hasMore
                              ? TextButton(
                                  onPressed: feed.busy ? null : () => feed.load(),
                                  child: Text(feed.busy ? '加载中…' : '加载更多'))
                              : const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: Text('没有更多动态了')),
                                ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 48,
          titleSpacing: 16,
          title: Row(
            children: ['推荐', _discoverLocalTabLabel, '关注']
                .asMap()
                .entries
                .map((entry) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (selectedTab == entry.key) {
                          _scrollCurrentTabToTop();
                          return;
                        }
                        setState(() => selectedTab = entry.key);
                        final feed = feeds[entry.key];
                        if (entry.key == 1 && _discoverLocalTabLabel == '本地') {
                          unawaited(_loadDiscoverCity());
                        }
                        if (!feed.initialized) {
                          unawaited(feed.restoreCache().then((_) {
                            if (!feed.initialized) return feed.load();
                            return Future<void>.value();
                          }));
                        }
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 20, top: 1, bottom: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: selectedTab == entry.key
                                    ? null
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              width: selectedTab == entry.key ? 24 : 0,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          actions: [
            IconButton(
                tooltip: '创建动态',
                icon: const Icon(TIcons.logo_instagram),
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
    required this.onLike,
    required this.onFavorite,
    required this.onShare,
    required this.onReport,
    required this.onOpen,
  });

  final DiscoverFeed feed;
  final DDPost post;
  final ValueChanged<DDPost> onLike;
  final ValueChanged<DDPost> onFavorite;
  final ValueChanged<DDPost> onShare;
  final ValueChanged<DDPost> onReport;
  final ValueChanged<DDPost> onOpen;

  @override
  State<_DiscoverFeedCard> createState() => _DiscoverFeedCardState();
}

class _DiscoverFeedCardState extends State<_DiscoverFeedCard>
    with AutomaticKeepAliveClientMixin<_DiscoverFeedCard> {
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final card = _DiscoverProfileCard(
      post: post,
      onLike: () => widget.onLike(post),
      onFavorite: () => widget.onFavorite(post),
      onShare: () => widget.onShare(post),
      onReport: () => widget.onReport(post),
      onOpen: () => widget.onOpen(post),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: card,
    );
  }

  @override
  void dispose() {
    widget.feed.postChanges.removeListener(_update);
    super.dispose();
  }
}
