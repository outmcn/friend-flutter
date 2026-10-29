part of 'main.dart';

Future<List<DDPost>> _feedShellUnusedFetch(int _) async => const <DDPost>[];

class FeedShellTab {
  const FeedShellTab({
    required this.title,
    required this.cacheKey,
    required this.fetch,
    this.icon,
    this.selectedIcon,
  });

  final String title;
  final String cacheKey;
  final Future<List<DDPost>> Function(int offset) fetch;
  final IconData? icon;
  final IconData? selectedIcon;
}

class FeedShellController {
  FeedShellController({required this.feeds, required this.cardKeys});
  final List<DiscoverFeed> feeds;
  final Map<String, GlobalKey> cardKeys;
  final Map<int, List<Widget>> _sliverCache = <int, List<Widget>>{};
  final Map<int, String> _sliverSignatures = <int, String>{};

  List<Widget> slivers({
    required int index,
    required ValueChanged<DDPost> onLike,
    required ValueChanged<DDPost> onFavorite,
    required ValueChanged<DDPost> onShare,
    required ValueChanged<DDPost> onReport,
    required ValueChanged<DDPost> onOpen,
    Future<void> Function(String, DDPost)? onSendToFriend,
    ValueChanged<DDPost>? onDirectChat,
    ValueChanged<DDPost>? onFollow,
    ValueChanged<DDPost>? onGift,
    ValueChanged<DDPost>? onDelete,
    ValueChanged<DDPost>? onPinned,
    int? currentUserId,
    bool hideAuthorRow = false,
    bool showViews = false,
    bool showItemDivider = false,
  }) {
    final feed = feeds[index];
    final signature = feed.posts.map((post) => post.id).join(',');
    if (_sliverSignatures[index] == signature && _sliverCache[index] != null) {
      return _sliverCache[index]!;
    }
    final result = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, itemIndex) {
              final post = feed.posts[itemIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DiscoverFeedCard(
                    key: cardKeys.putIfAbsent('${post.id}', GlobalKey.new),
                    feed: feed,
                    post: post,
                    onLike: onLike,
                    onFavorite: onFavorite,
                    onShare: onShare,
                    onSendToFriend: onSendToFriend,
                    onDirectChat: onDirectChat,
                    onFollow: onFollow,
                    onGift: onGift,
                    onDelete:
                        currentUserId != null && post.userId == currentUserId
                            ? onDelete
                            : null,
                    onPinned: onPinned,
                    onReport: onReport,
                    onOpen: onOpen,
                    hideAuthorRow: hideAuthorRow,
                    showViews: showViews,
                  ),
                  if (showItemDivider)
                    Container(
                        height: 1,
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.28)),
                ],
              );
            },
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
                  onRetry: () => feed.load(refresh: true))
              : (feed.restoring || (feed.busy && feed.posts.isEmpty))
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()))
                  : feed.posts.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: Text('暂无动态')))
                      : feed.hasMore
                          ? TextButton(
                              onPressed: feed.busy ? null : () => feed.load(),
                              child: Text(feed.busy ? '加载中…' : '加载更多'))
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: Text('没有更多动态了'))),
        ),
      ),
    ];
    _sliverSignatures[index] = signature;
    _sliverCache[index] = result;
    return result;
  }
}

class FeedShell extends StatefulWidget {
  const FeedShell({
    super.key,
    required this.tabs,
    this.externalFeeds,
    this.showTabs = true,
    this.disposeFeeds = true,
    this.embedded = false,
    this.refreshAtTop = false,
    this.selectedTab,
    this.onTabChanged,
    required this.onLike,
    required this.onFavorite,
    required this.onShare,
    required this.onReport,
    required this.onOpen,
    this.onSendToFriend,
    this.onDirectChat,
    this.onFollow,
    this.onGift,
    this.onDelete,
    this.onPinned,
    this.currentUserId,
    this.hideAuthorRow = false,
    this.showViews = false,
    this.initialTab = 0,
  });

  final List<FeedShellTab> tabs;
  final List<DiscoverFeed>? externalFeeds;
  final bool showTabs;
  final bool disposeFeeds;
  final bool embedded;
  final bool refreshAtTop;
  final int? selectedTab;
  final ValueChanged<int>? onTabChanged;
  final ValueChanged<DDPost> onLike;
  final ValueChanged<DDPost> onFavorite;
  final ValueChanged<DDPost> onShare;
  final ValueChanged<DDPost> onReport;
  final ValueChanged<DDPost> onOpen;
  final Future<void> Function(String peerId, DDPost post)? onSendToFriend;
  final ValueChanged<DDPost>? onDirectChat;
  final ValueChanged<DDPost>? onFollow;
  final ValueChanged<DDPost>? onGift;
  final ValueChanged<DDPost>? onDelete;
  final ValueChanged<DDPost>? onPinned;
  final int? currentUserId;
  final bool hideAuthorRow;
  final bool showViews;
  final int initialTab;

  @override
  State<FeedShell> createState() => _FeedShellState();
}

class _FeedShellState extends State<FeedShell> {
  late int selectedTab;
  late final List<DiscoverFeed> feeds;
  final pendingLikes = <int>{};
  final pendingFavorites = <int>{};
  final cardKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    selectedTab = (widget.selectedTab ?? widget.initialTab)
        .clamp(0, widget.tabs.length - 1);
    feeds = (widget.externalFeeds ??
        widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final feed = DiscoverFeed(tab.fetch, cacheKey: tab.cacheKey);
          _GlobalScrollToTopRegistry.register(feed.scroll);
          feed.scroll.addListener(() {
            if (feed.scroll.hasClients &&
                feed.scroll.position.extentAfter < 500 &&
                feed.initialized &&
                feed.error == null) {
              feed.load();
            }
          });
          if (index == selectedTab) {
            unawaited(feed.restoreCache().then((_) {
              if (!feed.initialized) return feed.load();
              return Future<void>.value();
            }));
          }
          return feed;
        }).toList());
  }

  @override
  void dispose() {
    if (widget.disposeFeeds) {
      for (final feed in feeds) {
        _GlobalScrollToTopRegistry.unregister(feed.scroll);
        feed.dispose();
      }
    }
    super.dispose();
  }

  Widget _tab(int index) {
    final feed = feeds[index];
    return AnimatedBuilder(
      animation: feed,
      builder: (context, _) {
        final view = CustomScrollView(
          key: PageStorageKey('feed-shell.$index'),
          controller: feed.scroll,
          physics: widget.refreshAtTop
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const ClampingScrollPhysics(),
          slivers: [
            if (widget.refreshAtTop)
              CupertinoSliverRefreshControl(
                onRefresh: () => feed.load(refresh: true),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = feed.posts[index];
                    if (index + 1 < feed.posts.length) {
                      final next = feed.posts[index + 1];
                      if (next.imageUrl?.isNotEmpty == true) {
                        unawaited(
                            _PermanentImageCache.prefetch(next.imageUrl!));
                      }
                      if (next.thumbnailUrl?.isNotEmpty == true) {
                        unawaited(
                            _PermanentImageCache.prefetch(next.thumbnailUrl!));
                      }
                    }
                    return _DiscoverFeedCard(
                      key: cardKeys.putIfAbsent('${post.id}', GlobalKey.new),
                      feed: feed,
                      post: post,
                      onLike: widget.onLike,
                      onFavorite: widget.onFavorite,
                      onShare: widget.onShare,
                      onSendToFriend: widget.onSendToFriend,
                      onDirectChat: widget.onDirectChat,
                      onFollow: widget.onFollow,
                      onGift: widget.onGift,
                      onDelete: widget.currentUserId != null &&
                              post.userId == widget.currentUserId
                          ? widget.onDelete
                          : null,
                      onPinned: widget.onPinned,
                      onReport: widget.onReport,
                      onOpen: widget.onOpen,
                      hideAuthorRow: widget.hideAuthorRow,
                      showViews: widget.showViews,
                    );
                  },
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
                        onRetry: () => feed.load(refresh: true),
                      )
                    : (feed.restoring || (feed.busy && feed.posts.isEmpty))
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : feed.posts.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 48),
                                child: Center(child: Text('暂无动态')),
                              )
                            : feed.hasMore
                                ? TextButton(
                                    onPressed:
                                        feed.busy ? null : () => feed.load(),
                                    child: Text(feed.busy ? '加载中…' : '加载更多'),
                                  )
                                : const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: Text('没有更多动态了')),
                                  ),
              ),
            ),
          ],
        );
        return view;
      },
    );
  }

  Widget _content(BuildContext context) => Column(
        children: [
          if (widget.showTabs)
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  for (final entry in widget.tabs.asMap().entries)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          widget.onTabChanged?.call(entry.key);
                          if (widget.onTabChanged == null) {
                            setState(() => selectedTab = entry.key);
                          }
                        },
                        child: Center(
                          child: entry.value.icon == null
                              ? Text(
                                  entry.value.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: selectedTab == entry.key
                                        ? null
                                        : Theme.of(context).hintColor,
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      selectedTab == entry.key
                                          ? (entry.value.selectedIcon ??
                                              entry.value.icon!)
                                          : entry.value.icon!,
                                      size: 24,
                                      color: selectedTab == entry.key
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context).hintColor,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: widget.selectedTab ?? selectedTab,
              children: List.generate(widget.tabs.length, _tab),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) =>
      widget.embedded ? _content(context) : Scaffold(body: _content(context));
}
