part of 'main.dart';

class DDProfilePage extends StatefulWidget {
  const DDProfilePage({super.key});
  @override
  State<DDProfilePage> createState() => _DDProfilePageState();
}

class _DDProfilePageState extends State<DDProfilePage> {
  final DDPostService service = DDPostService();
  Map<String, dynamic>? profile;
  List<DDPost> posts = [];
  int selectedTab = 0;
  bool loading = true;
  bool tabLoading = false;
  final Map<int, List<DDPost>> tabPosts = {};
  final AudioPlayer _sonicPlayer = AudioPlayer();
  final ScrollController _profileScrollController = ScrollController();
  bool _showStickyNickname = false;

  bool _sonicPlaying = false;
  String? _sonicUrl;
  String? _avatarUrl;
  String? error;
  List<String> _tags = <String>[];

  @override
  void initState() {
    super.initState();
    _profileScrollController.addListener(_handleProfileScroll);
    load();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  void _handleProfileScroll() {
    final shouldShow = _profileScrollController.hasClients &&
        _profileScrollController.offset >= 58;
    if (shouldShow != _showStickyNickname && mounted) {
      setState(() => _showStickyNickname = shouldShow);
    }
  }

  @override
  void dispose() {
    _profileScrollController.removeListener(_handleProfileScroll);
    _profileScrollController.dispose();
    _sonicPlayer.dispose();
    service.dispose();
    super.dispose();
  }

  Future<void> _toggleSonic() async {
    final url = _sonicUrl;
    if (url == null || url.isEmpty) return;
    if (_sonicPlaying) {
      await _sonicPlayer.pause();
    } else {
      await _sonicPlayer.play(UrlSource(url));
    }
    if (mounted) setState(() => _sonicPlaying = !_sonicPlaying);
  }

  static const _profileTabCachePrefix = 'dd.profile.tab.cache.v2.';
  static const _profileTabCacheAtPrefix = 'dd.profile.tab.cache.at.';

  Future<void> _saveTabCache(int tab, List<DDPost> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_profileTabCachePrefix$tab',
      jsonEncode(value.map((post) => post.toJson()).toList()),
    );
    await prefs.setInt(
      '$_profileTabCacheAtPrefix$tab',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<DDPost>?> _readTabCache(int tab) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_profileTabCachePrefix$tab';
    final expiry = prefs.getInt('$key.urlExpiresAt');
    if (expiry != null && DateTime.now().millisecondsSinceEpoch >= expiry) {
      return null;
    }
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as List;
      return data
          .whereType<Map>()
          .map((item) => DDPost.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      await prefs.remove('$_profileTabCachePrefix$tab');
      return null;
    }
  }

  Future<void> _invalidateProfileCacheAndReload() async {
    await DDPostService.clearProfileTabCaches();
    tabPosts.clear();
    await load(tab: selectedTab, forceRefresh: true);
  }

  Future<void> load({int? tab, bool forceRefresh = false}) async {
    final targetTab = tab ?? selectedTab;
    final isTabSwitch = tab != null && !loading && !forceRefresh;
    if (mounted) {
      setState(() {
        error = null;
        if (isTabSwitch) {
          selectedTab = targetTab;
          tabLoading = false;
          final cached = tabPosts[targetTab];
          if (cached != null) posts = cached;
        } else {
          loading = true;
        }
      });
    }
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('friend.auth.token') ?? '';
      if (t.isEmpty) throw Exception('请先登录');
      final needProfile = profile == null || !isTabSwitch;
      Map<String, dynamic> loadedProfile = profile ?? {};
      if (needProfile) {
        loadedProfile = await service.fetchMe(t);
        _sonicUrl =
            DDPostService.mediaUrl(loadedProfile['voiceUrl']?.toString());
        final avatarKey = '${loadedProfile['avatarKey'] ?? ''}'.trim();
        _avatarUrl = avatarKey.isEmpty
            ? null
            : await service.resolveAvatarUrl(t, avatarKey);
        final profileTags = loadedProfile['tags'];
        _tags = profileTags is List
            ? profileTags
                .map((value) => '$value')
                .where((value) => value.trim().isNotEmpty)
                .toList()
            : <String>[];
      }
      final cached = forceRefresh ? null : await _readTabCache(targetTab);
      if (cached != null && !forceRefresh) {
        tabPosts[targetTab] = cached;
        if (mounted) {
          setState(() {
            profile = loadedProfile;
            posts = cached;
            selectedTab = targetTab;
          });
        }
        return;
      }
      final loadedPosts = targetTab == 0
          ? await service.fetchMyPosts(t)
          : targetTab == 1
              ? await service.fetchFavoritedPosts(t)
              : await service.fetchLikedPosts(t);
      final resolvedPosts = await Future.wait(
          loadedPosts.map((post) => service.resolvePostMedia(t, post)));
      tabPosts[targetTab] = resolvedPosts;
      await _saveTabCache(targetTab, resolvedPosts);
      if (!mounted) return;
      setState(() {
        profile = loadedProfile;
        posts = loadedPosts;
        selectedTab = targetTab;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          tabLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: _showStickyNickname
            ? Text(
                '${p?['nickname'] ?? 'DD 用户'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : const SizedBox.shrink(),
        actions: [
          IconButton(
            tooltip: '浏览记录',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _HistoryRecordsPage()),
            ),
            icon: const Icon(Icons.crop_free),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('分享主页'),
                    ),
                    ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('设置'),
                    ),
                  ],
                ),
              ),
            ),
            icon: const Icon(Icons.hexagon_outlined),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => load(forceRefresh: true),
              child: CustomScrollView(
                controller: _profileScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (error != null)
                          _PageErrorState(
                            title: '资料加载失败',
                            subtitle: error!,
                            onRetry: load,
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 84,
                                      height: 84,
                                      child: _avatarUrl == null ||
                                              _avatarUrl!.isEmpty
                                          ? const ColoredBox(
                                              color: Colors.black12,
                                              child:
                                                  Icon(Icons.person, size: 42),
                                            )
                                          : _PermanentCachedImage(
                                              url: _avatarUrl!,
                                              width: 84,
                                              height: 84,
                                              fit: BoxFit.cover,
                                              placeholder: const ColoredBox(
                                                color: Colors.black12,
                                                child: Icon(Icons.person,
                                                    size: 42),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _ProfileTag(
                                              text: '${p?['city'] ?? '未知'}'),
                                          const SizedBox(width: 8),
                                          _SonicProfileButton(
                                            playing: _sonicPlaying,
                                            enabled:
                                                _sonicUrl?.isNotEmpty == true,
                                            onTap: _toggleSonic,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${p?['nickname'] ?? 'DD 用户'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            tooltip: '编辑资料',
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 30, height: 30),
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const EditProfilePage()),
                                              );
                                              if (mounted) load();
                                            },
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _InlineProfileStat(
                                            label: '粉丝',
                                            value: '${p?['followers'] ?? 0}',
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const _UserRelationListPage(
                                                  relation: 'followers',
                                                  title: '粉丝',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          _InlineProfileStat(
                                            label: '关注',
                                            value: '${p?['following'] ?? 0}',
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const _UserRelationListPage(
                                                  relation: 'following',
                                                  title: '关注',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          _InlineProfileStat(
                                            label: '获赞',
                                            value:
                                                '${p?['receivedLikes'] ?? p?['likes'] ?? 0}',
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const _UserRelationListPage(
                                                  relation: 'likers',
                                                  title: '获赞',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 32,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ..._tags.map((tag) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6),
                                            child: _ProfileTag(text: tag),
                                          )),
                                      GestureDetector(
                                        onTap: () async {
                                          final selected = await Navigator.push<
                                              List<String>>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _ProfileTagEditorPage(
                                                      selectedTags: _tags),
                                            ),
                                          );
                                          if (selected != null && mounted) {
                                            final t = await _token();
                                            final updated =
                                                await service.updateMe(
                                                    token: t, tags: selected);
                                            setState(() {
                                              _tags = selected;
                                              profile = {
                                                ...(profile ??
                                                    <String, dynamic>{}),
                                                ...updated,
                                                'tags': selected,
                                              };
                                            });
                                          }
                                        },
                                        child: const _ProfileTag(text: '+'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          margin: EdgeInsets.zero,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : Colors.white.withValues(alpha: .72),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                            leading: const Icon(Icons.groups_rounded,
                                color: Color(0xffe6a51a)),
                            title: Text(
                              '${p?['clubName'] ?? p?['club'] ?? 'Free-Out地下说唱成员'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${p?['clubMemberCount'] ?? p?['clubCount'] ?? '28/30'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabsHeaderDelegate(
                      child: _MyProfileIconTabs(
                        selectedTab: selectedTab,
                        onSelect: (tab) => load(tab: tab),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _MyProfileGrid(
                          posts: posts,
                          onChanged: _invalidateProfileCacheAndReload,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabsHeaderDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).scaffoldBackgroundColor,
        elevation: overlapsContent ? 2 : 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: child,
        ),
      );

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}
