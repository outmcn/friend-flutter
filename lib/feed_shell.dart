part of 'main.dart';

Future<List<DDPost>> _feedShellUnusedFetch(int _) async => const <DDPost>[];

class FeedShellTab {
  const FeedShellTab({
    required this.title,
    required this.cacheKey,
    required this.fetch,
  });

  final String title;
  final String cacheKey;
  final Future<List<DDPost>> Function(int offset) fetch;
}


class FeedShellController {
  FeedShellController({required this.feeds, required this.cardKeys});
  final List<DiscoverFeed> feeds;
  final Map<String, GlobalKey> cardKeys;

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
  }) {
    final feed = feeds[index];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, itemIndex) {
              final post = feed.posts[itemIndex];
              return _DiscoverFeedCard(
                key: cardKeys.putIfAbsent('$index:${post.id}', GlobalKey.new),
                feed: feed,
                post: post,
                onLike: onLike,
                onFavorite: onFavorite,
                onShare: onShare,
                onSendToFriend: onSendToFriend,
                onDirectChat: onDirectChat,
                onFollow: onFollow,
                onGift: onGift,
                onDelete: onDelete,
                onReport: onReport,
                onOpen: onOpen,
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
              ? _PageErrorState(title: '动态加载失败', subtitle: feed.error!, onRetry: () => feed.load(refresh: true))
              : (feed.restoring || (feed.busy && feed.posts.isEmpty))
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()))
                  : feed.posts.isEmpty
                      ? const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('暂无动态')))
                      : feed.hasMore
                          ? TextButton(onPressed: feed.busy ? null : () => feed.load(), child: Text(feed.busy ? '加载中…' : '加载更多'))
                          : const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('没有更多动态了'))),
        ),
      ),
    ];
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
    this.initialTab = 0,
  });

  final List<FeedShellTab> tabs;
  final List<DiscoverFeed>? externalFeeds;
  final bool showTabs;
  final bool disposeFeeds;
  final bool embedded;
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
    selectedTab = (widget.selectedTab ?? widget.initialTab).clamp(0, widget.tabs.length - 1);
    feeds = (widget.externalFeeds ?? widget.tabs.asMap().entries.map((entry) {
      final index = entry.key;
      final tab = entry.value;
      final feed = DiscoverFeed(tab.fetch, cacheKey: tab.cacheKey);
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
      for (final feed in feeds) feed.dispose();
    }
    super.dispose();
  }


  Widget _tab(int index) {
    final feed = feeds[index];
    return AnimatedBuilder(
      animation: feed,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () => feed.load(refresh: true),
        child: CustomScrollView(
          key: PageStorageKey('feed-shell.$index'),
          controller: feed.scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                      key: cardKeys.putIfAbsent('$index:${post.id}', GlobalKey.new),
                      feed: feed,
                      post: post,
                      onLike: widget.onLike,
                      onFavorite: widget.onFavorite,
                      onShare: widget.onShare,
                      onSendToFriend: widget.onSendToFriend,
                      onDirectChat: widget.onDirectChat,
                      onFollow: widget.onFollow,
                      onGift: widget.onGift,
                      onDelete: widget.onDelete,
                      onReport: widget.onReport,
                      onOpen: widget.onOpen,
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
                                    onPressed: feed.busy ? null : () => feed.load(),
                                    child: Text(feed.busy ? '加载中…' : '加载更多'),
                                  )
                                : const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: Text('没有更多动态了')),
                                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) => Column(
          children: [
            if (widget.showTabs) SizedBox(
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
                          child: Text(
                            entry.value.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selectedTab == entry.key
                                  ? null
                                  : Theme.of(context).hintColor,
                            ),
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
        ),
      );

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _content(context)
      : Scaffold(body: _content(context));
}
