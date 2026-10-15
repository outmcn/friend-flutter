part of 'main.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final DDPostService service = DDPostService();
  String diamondBalance = '0.00';
  String diamondFrozenBalance = '0.00';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      final user = await service.fetchMe(token);
      if (mounted) {
        setState(() {
          diamondBalance = '${user['diamondBalance'] ?? '0.00'}';
          diamondFrozenBalance = '${user['diamondFrozenBalance'] ?? '0.00'}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('钱包')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xff6d5dfc), Color(0xffa66cff)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('钻石资产', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Text(loading ? '加载中…' : '$diamondBalance 钻石',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('冻结：$diamondFrozenBalance 钻石',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('充值')),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 12),
            const Card(
                child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('金币充值功能暂未接入支付'),
                    subtitle: Text('当前仅展示钱包页面，暂不产生真实订单。'))),
          ],
        ),
      );
}

class DDProfilePage extends StatefulWidget {
  const DDProfilePage({super.key});
  @override
  State<DDProfilePage> createState() => _DDProfilePageState();
}

class _DDProfilePageState extends State<DDProfilePage> {
  final DDPostService service = DDPostService();
  Map<String, dynamic>? profile;
  int coinBalance = 0;
  bool walletLoading = false;
  List<DDPost> posts = [];
  int selectedTab = 0;
  bool loading = true;
  bool tabLoading = false;
  late final List<DiscoverFeed> feeds;
  final AudioPlayer _sonicPlayer = AudioPlayer();
  final ScrollController _profileScrollController = ScrollController();
  bool _showStickyNickname = false;

  final bool _sonicPlaying = false;
  String? _sonicUrl;
  String? _avatarUrl;
  String? error;
  List<String> _tags = <String>[];
  bool _stealth = false;
  bool _antiHarassment = false;
  bool _smartBlock = false;
  bool _matching = false;

  @override
  void initState() {
    super.initState();
    _profileScrollController.addListener(_handleProfileScroll);
    feeds = List.generate(
        3,
        (tab) => DiscoverFeed((_) async {
              final token = await _token();
              final loaded = tab == 0
                  ? await service.fetchMyPosts(token)
                  : tab == 1
                      ? await service.fetchFavoritedPosts(token)
                      : await service.fetchLikedPosts(token);
              return Future.wait(
                  loaded.map((post) => service.resolvePostMedia(token, post)));
            }));
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
    for (final feed in feeds) {
      feed.dispose();
    }
    _sonicPlayer.dispose();
    service.dispose();
    super.dispose();
  }

  Future<void> _openPresenceControls() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('在线 / 隐身'),
                subtitle: Text(_stealth ? '当前：隐身' : '当前：在线'),
                trailing: Switch(
                  value: !_stealth,
                  onChanged: (value) {
                    setSheetState(() => _stealth = !value);
                    setState(() {});
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('全站防骚扰'),
                value: _antiHarassment,
                onChanged: (value) {
                  setSheetState(() => _antiHarassment = value);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('智能屏蔽'),
                value: _smartBlock,
                onChanged: (value) {
                  setSheetState(() => _smartBlock = value);
                  setState(() {});
                },
              ),
              ListTile(
                title: const Text('开启匹配'),
                trailing: Switch(
                  value: _matching,
                  onChanged: (value) {
                    setSheetState(() => _matching = value);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _invalidateProfileCacheAndReload() async {
    await DDPostService.clearProfileTabCaches();
    for (final feed in feeds) {
      feed.posts.clear();
      feed.initialized = false;
      feed.offset = 0;
      feed.hasMore = true;
    }
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
          tabLoading = true;
          posts = feeds[targetTab].posts;
        } else {
          loading = true;
        }
      });
    }
    try {
      final t = await _token();
      if (profile == null || !isTabSwitch) {
        final loadedProfile = await service.fetchMe(t);
        _sonicUrl =
            DDPostService.mediaUrl(loadedProfile['voiceUrl']?.toString());
        final avatarKey = '${loadedProfile['avatarKey'] ?? ''}'.trim();
        final avatar = avatarKey.isEmpty
            ? null
            : await service.resolveAvatarUrl(t, avatarKey);
        if (avatarKey.isNotEmpty && avatar != null && avatar.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(avatar));
            if (response.statusCode >= 200 &&
                response.statusCode < 300 &&
                response.bodyBytes.isNotEmpty) {
              await ImLocalStore.saveAvatar(avatarKey, response.bodyBytes);
            }
          } catch (_) {
            // 头像写入失败不影响我的页继续显示已获取的签名头像。
          }
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('friend.profile.avatarKey', avatarKey);
        await prefs.setString('friend.profile.avatarUrl', avatar ?? '');
        final profileTags = loadedProfile['tags'];
        final tags = profileTags is List
            ? profileTags
                .map((value) => '$value')
                .where((value) => value.trim().isNotEmpty)
                .toList()
            : <String>[];
        if (mounted) {
          setState(() {
            profile = loadedProfile;
            coinBalance =
                int.tryParse('${loadedProfile['coinBalance'] ?? 0}') ?? 0;
            _avatarUrl = avatar;
            _tags = tags;
          });
        }
      }
      final feed = feeds[targetTab];
      if (forceRefresh || !feed.initialized) {
        await feed.load(refresh: forceRefresh);
      }
      if (!mounted) return;
      setState(() {
        selectedTab = targetTab;
        posts = feed.posts;
        error = feed.error;
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
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
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
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipOval(
                                        child: SizedBox(
                                          width: 78,
                                          height: 78,
                                          child: _avatarUrl == null ||
                                                  _avatarUrl!.isEmpty
                                              ? const ColoredBox(
                                                  color: Colors.black12,
                                                  child: Icon(Icons.person,
                                                      size: 40),
                                                )
                                              : _PermanentCachedImage(
                                                  url: _avatarUrl!,
                                                  width: 78,
                                                  height: 78,
                                                  fit: BoxFit.cover,
                                                  placeholder: const ColoredBox(
                                                    color: Colors.black12,
                                                    child: Icon(Icons.person,
                                                        size: 40),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: -9,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .dividerColor),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              boxShadow: const [
                                                BoxShadow(
                                                    color: Color(0x19000000),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2)),
                                              ],
                                            ),
                                            child: Text('${p?['city'] ?? '未知'}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${p?['nickname'] ?? 'DD 用户'}  ${p?['gender'] == '男' ? '♂' : p?['gender'] == '女' ? '♀' : ''}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 20,
                                                    height: 1.2,
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: '编辑资料',
                                              onPressed: () async {
                                                await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            const EditProfilePage()));
                                                if (mounted) load();
                                              },
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 22),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        _SonicProfileButton(
                                          playing: _sonicPlaying,
                                          enabled: true,
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    _VoiceRecordPage(
                                                        currentUrl: _sonicUrl),
                                              ),
                                            );
                                            if (mounted) {
                                              await load(forceRefresh: true);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _openPresenceControls,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _stealth
                                            ? const Color(0xfff3f4f6)
                                            : const Color(0xfff0fdf4),
                                        border: Border.all(
                                            color: _stealth
                                                ? const Color(0xffd1d5db)
                                                : const Color(0xffbbf7d0)),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: _stealth
                                                  ? const Color(0xff9ca3af)
                                                  : const Color(0xff22c55e),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _stealth ? '隐身' : '在线',
                                            style: TextStyle(
                                              color: _stealth
                                                  ? const Color(0xff6b7280)
                                                  : const Color(0xff16a34a),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.symmetric(
                                      horizontal: BorderSide(
                                          color:
                                              Theme.of(context).dividerColor)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: _InlineProfileStat(
                                            label: '粉丝',
                                            value: '${p?['followers'] ?? 0}',
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const _UserRelationListPage(
                                                            relation:
                                                                'followers',
                                                            title: '粉丝'))))),
                                    Expanded(
                                        child: _InlineProfileStat(
                                            label: '关注',
                                            value: '${p?['following'] ?? 0}',
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const _UserRelationListPage(
                                                            relation:
                                                                'following',
                                                            title: '关注'))))),
                                    Expanded(
                                        child: _InlineProfileStat(
                                            label: '获赞',
                                            value:
                                                '${p?['receivedLikes'] ?? p?['likes'] ?? 0}',
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const _UserRelationListPage(
                                                            relation: 'likers',
                                                            title: '获赞'))))),
                                  ],
                                ),
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
                        Row(
                          children: [
                            Expanded(
                              child: _ProfileActionButton(
                                icon: Icons.account_balance_wallet_outlined,
                                label: '钱包',
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const WalletPage())),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ProfileActionButton(
                                icon: Icons.backpack_outlined,
                                label: '背包',
                                onTap: () {},
                              ),
                            ),
                          ],
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

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 19, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 7),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
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
