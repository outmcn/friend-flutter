part of 'main.dart';

class _CharmSourcesPage extends StatefulWidget {
  const _CharmSourcesPage();

  @override
  State<_CharmSourcesPage> createState() => _CharmSourcesPageState();
}

String _formatCharmSourceTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final beijing = parsed.toUtc().add(const Duration(hours: 8));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${beijing.year}-${two(beijing.month)}-${two(beijing.day)} '
      '${two(beijing.hour)}:${two(beijing.minute)}:${two(beijing.second)}';
}

class _CharmSourcesPageState extends State<_CharmSourcesPage> {
  final service = DDPostService();
  List<Map<String, dynamic>> sources = const [];
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
      final loaded = await service.fetchCharmSources(token);
      if (mounted) setState(() => sources = loaded);
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
        appBar: AppBar(title: const Text('魅力值来源')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _PageErrorState(
                    title: '加载失败', subtitle: error!, onRetry: _load)
                : sources.isEmpty
                    ? const Center(child: Text('暂无礼物来源'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sources.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final source = sources[index];
                          final sender = '${source['senderNickname'] ?? '用户'}';
                          final gift = '${source['giftName'] ?? '礼物'}';
                          final quantity = source['quantity'] ?? 0;
                          final coins = source['coinAmount'] ?? 0;
                          final created = _formatCharmSourceTime(
                              '${source['createdAt'] ?? ''}');
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                  gift.isEmpty ? '礼' : gift.characters.first),
                            ),
                            title: Text('$sender送出$gift × $quantity'),
                            subtitle: Text('动态  ·  $created'),
                            trailing: Text('+$coins'),
                          );
                        },
                      ),
      );
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, this.showCoinBalance = true});

  final bool showCoinBalance;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final DDPostService service = DDPostService();
  String diamondBalance = '0.00';
  String diamondFrozenBalance = '0.00';
  String coinBalance = '0';
  String charmCoins = '0';
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
          coinBalance = _integerAmount(user['coinBalance']);
          charmCoins = _integerAmount(user['charmCoins']);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _integerAmount(dynamic value) {
    final parsed = num.tryParse('$value');
    return parsed == null ? '0' : parsed.truncate().toString();
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
            _WalletAssetCard(
              title: '金币钱包',
              subtitle: '',
              amount: loading ? '加载中…' : '$coinBalance 金币',
              detail: '',
              colors: const [Color(0xffe07a22), Color(0xfff0b44d)],
            ),
            const SizedBox(height: 16),
            _WalletAssetCard(
              title: '钻石钱包',
              subtitle: '',
              amount: loading ? '加载中…' : '$diamondBalance 钻石',
              detail: '冻结：$diamondFrozenBalance 钻石',
              colors: const [Color(0xff6d5dfc), Color(0xffa66cff)],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('充值暂未开放')),
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

class GiftExhibitionPage extends StatefulWidget {
  const GiftExhibitionPage(
      {super.key, this.userId, this.userName, this.onSendGift});

  final int? userId;
  final String? userName;
  final VoidCallback? onSendGift;

  @override
  State<GiftExhibitionPage> createState() => _GiftExhibitionPageState();
}

class _GiftExhibitionPageState extends State<GiftExhibitionPage> {
  final DDPostService service = DDPostService();
  List<Map<String, dynamic>> gifts = const [];
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
      final value = widget.userId == null
          ? await service.fetchMyUserGifts(token)
          : await service.fetchUserGifts(token, widget.userId!);
      if (mounted) setState(() => gifts = value);
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
        appBar: AppBar(
          title: Text(
              widget.userName == null ? '礼物展馆' : '${widget.userName}的礼物展馆'),
          actions: [
            if (widget.userId != null && widget.onSendGift != null)
              TextButton.icon(
                onPressed: widget.onSendGift,
                icon: const Icon(Icons.card_giftcard_outlined),
                label: const Text('送礼物'),
              ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: gifts.length,
                    itemBuilder: (_, index) {
                      final gift = gifts[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${gift['icon'] ?? '🎁'}',
                                  style: const TextStyle(fontSize: 34)),
                              const SizedBox(height: 8),
                              Text('${gift['name'] ?? '礼物'}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('收到 ${gift['received_quantity'] ?? 0} 个'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      );
}

class _WalletAssetCard extends StatelessWidget {
  const _WalletAssetCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.detail,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String detail;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            if (subtitle.isNotEmpty) ...[
              Text(subtitle, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 10),
            ],
            Text(amount,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800)),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(detail, style: const TextStyle(color: Colors.white70)),
            ],
          ],
        ),
      );
}

class _ProfileFeaturePage extends StatelessWidget {
  const _ProfileFeaturePage(
      {required this.title, required this.icon, required this.description});
  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 18),
                const Text('暂无内容', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
}

class ProfileCollectionPage extends StatelessWidget {
  const ProfileCollectionPage({super.key});
  @override
  Widget build(BuildContext context) => const _ProfileFeaturePage(
      title: '典藏', icon: TIcons.collection, description: '收藏的内容和作品将在这里展示。');
}

class ProfileSpacePage extends StatelessWidget {
  const ProfileSpacePage({super.key});
  @override
  Widget build(BuildContext context) => const _ProfileFeaturePage(
      title: '空间', icon: TIcons.space, description: '个人空间内容将在这里展示。');
}

class ProfileChannelPage extends StatelessWidget {
  const ProfileChannelPage({super.key});
  @override
  Widget build(BuildContext context) => const _ProfileFeaturePage(
      title: '频道', icon: TIcons.browse_gallery, description: '关注和创建的频道将在这里展示。');
}

class DDProfilePage extends StatefulWidget {
  const DDProfilePage({super.key});
  @override
  State<DDProfilePage> createState() => _DDProfilePageState();
}

class _DDProfilePageState extends State<DDProfilePage>
    with WidgetsBindingObserver {
  final DDPostService service = DDPostService();
  Map<String, dynamic>? profile;
  int coinBalance = 0;
  int charmCoins = 0;
  int selectedTab = 0;
  int? _currentUserId;
  bool loading = true;
  late final List<FeedShellTab> profileFeedTabs;
  late final List<DiscoverFeed> feeds;
  final pendingLikes = <int>{};
  final pendingFavorites = <int>{};
  final _profileCardKeys = <String, GlobalKey>{};
  String? _cachedAllProfileSignature;
  List<Widget>? _cachedAllProfileSlivers;
  final List<VoidCallback> _profileFeedListeners = <VoidCallback>[];
  final Map<int, double> _profileTabOffsets = <int, double>{};
  final AudioPlayer _sonicPlayer = AudioPlayer();
  final ScrollController _profileHeaderScroll = ScrollController();
  bool _showStickyNickname = false;
  String? _sonicUrl;
  String? _avatarUrl;
  String? _avatarLocalPath;
  bool _avatarReviewRejected = false;
  String? error;
  bool _stealth = false;
  bool _antiHarassment = false;
  bool _smartBlock = false;
  bool _matching = false;
  bool _profileRefreshing = false;
  Timer? _presenceTimer;
  bool _appActive = true;
  bool _presenceUpdating = false;
  bool _heartbeatRunning = false;
  Future<Map<String, dynamic>?>? _profileRequest;
  static const _profileCacheKey = 'dd.profile.self.cache.v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileHeaderScroll.addListener(_handleProfileScroll);
    _presenceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_appActive) _sendPresenceHeartbeat();
    });
    _sonicPlayer.onPlayerComplete.listen((_) {});
    profileFeedTabs = List.generate(
      4,
      (tab) => FeedShellTab(
        title: tab == 0
            ? '我的动态'
            : tab == 1
                ? '收藏'
                : tab == 2
                    ? '点赞'
                    : '私密动态',
        icon: tab == 0
            ? TIcons.highlight_1
            : tab == 1
                ? TIcons.bookmark
                : tab == 2
                    ? TIcons.heart
                    : TIcons.lock_on,
        selectedIcon: tab == 0
            ? TIcons.highlight_1_filled
            : tab == 1
                ? TIcons.bookmark_filled
                : tab == 2
                    ? TIcons.heart_filled
                    : TIcons.lock_on,
        cacheKey: 'dd.profile.my.v2.tab.$tab',
        fetch: (offset) async {
          final token = await _token();
          final loaded = tab == 0
              ? await service.fetchMyPosts(token, offset: offset)
              : tab == 1
                  ? await service.fetchFavoritedPosts(token, offset: offset)
                  : tab == 2
                      ? await service.fetchLikedPosts(token, offset: offset)
                      : await service.fetchPrivatePosts(token, offset: offset);
          return Future.wait(
              loaded.map((post) => service.resolvePostMedia(token, post)));
        },
      ),
    );
    feeds = profileFeedTabs
        .map((tab) => DiscoverFeed(tab.fetch, cacheKey: tab.cacheKey))
        .toList();
    for (final feed in feeds) {
      void invalidate() {
        _cachedAllProfileSignature = null;
        _cachedAllProfileSlivers = null;
        if (mounted) setState(() {});
      }

      _profileFeedListeners.add(invalidate);
      feed.addListener(invalidate);
      _GlobalScrollToTopRegistry.register(feed.scroll);
      feed.scroll.addListener(_handleProfileScroll);
      feed.scroll.addListener(() {
        if (feed.scroll.hasClients) {
          _profileTabOffsets[feeds.indexOf(feed)] = feed.scroll.offset;
        }
      });
      feed.scroll.addListener(() {
        if (feed.scroll.hasClients &&
            feed.scroll.position.extentAfter < 500 &&
            feed.initialized &&
            feed.error == null) {
          feed.load().then((_) {
            if (!mounted || feed.error == null) return;
            _showTopNotice(context, Text('动态加载失败：${feed.error}'));
          });
        }
      });
    }
    unawaited(_restoreProfileCache());
    unawaited(load());
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  void _handleProfileScroll() {
    final shouldShow =
        _profileHeaderScroll.hasClients && _profileHeaderScroll.offset >= 58;
    if (shouldShow != _showStickyNickname && mounted) {
      setState(() => _showStickyNickname = shouldShow);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    final wasActive = _appActive;
    if (active != wasActive && mounted) {
      setState(() => _appActive = active);
    }
    if (active && !wasActive) {
      unawaited(_sendPresenceHeartbeat());
      unawaited(_refreshProfileOnly());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = ModalRoute.of(context)?.isCurrent ?? true;
    if (active != _appActive && mounted) {
      setState(() => _appActive = active);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    _profileHeaderScroll.removeListener(_handleProfileScroll);
    _profileHeaderScroll.dispose();
    for (final feed in feeds) {
      feed.scroll.removeListener(_handleProfileScroll);
      final listenerIndex = feeds.indexOf(feed);
      if (listenerIndex >= 0 && listenerIndex < _profileFeedListeners.length) {
        feed.removeListener(_profileFeedListeners[listenerIndex]);
      }
      _GlobalScrollToTopRegistry.unregister(feed.scroll);
      feed.dispose();
    }
    _sonicPlayer.dispose();
    service.dispose();
    super.dispose();
  }

  String _formatCount(dynamic value) {
    final number = int.tryParse('$value') ?? 0;
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (mounted) await _refreshProfileOnly();
  }

  Future<void> _editSonic() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VoiceRecordPage(currentUrl: _sonicUrl),
      ),
    );
    if (mounted) await _refreshProfileOnly();
  }

  Future<void> _setPresenceMode(
    String mode,
    void Function(void Function())? setSheetState,
  ) async {
    if (_presenceUpdating) return;
    final previous = _stealth;
    final nextStealth = mode == 'stealth';
    if (mounted) {
      setState(() {
        _presenceUpdating = true;
        _stealth = nextStealth;
      });
      setSheetState?.call(() {});
    }
    try {
      final token = await _token();
      await service.setPresence(token, mode);
    } catch (e) {
      if (mounted) {
        setState(() => _stealth = previous);
        setSheetState?.call(() {});
        _showTopNotice(context, const Text('在线状态更新失败'));
      }
    } finally {
      if (mounted) {
        setState(() => _presenceUpdating = false);
        setSheetState?.call(() {});
      }
    }
  }

  Future<void> _sendPresenceHeartbeat() async {
    if (!_appActive || !mounted || _heartbeatRunning) return;
    _heartbeatRunning = true;
    try {
      final token = await _token();
      await service.presenceHeartbeat(token);
    } catch (_) {
    } finally {
      _heartbeatRunning = false;
    }
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
                subtitle: Text('${_stealth ? '当前：隐身' : '当前：在线'} · 已同步'),
                trailing: Switch(
                  value: !_stealth,
                  onChanged: _presenceUpdating
                      ? null
                      : (value) {
                          unawaited(_setPresenceMode(
                            value ? 'online' : 'stealth',
                            setSheetState,
                          ));
                        },
                ),
              ),
              SwitchListTile(
                title: const Text('全站防骚扰'),
                subtitle: const Text('服务端同步'),
                value: _antiHarassment,
                onChanged: (value) {
                  final before = _antiHarassment;
                  setSheetState(() => _antiHarassment = value);
                  unawaited(_savePreferences(
                    antiHarassment: value,
                    onFailure: () =>
                        setSheetState(() => _antiHarassment = before),
                  ));
                },
              ),
              SwitchListTile(
                title: const Text('智能屏蔽'),
                subtitle: const Text('服务端同步'),
                value: _smartBlock,
                onChanged: (value) {
                  final before = _smartBlock;
                  setSheetState(() => _smartBlock = value);
                  unawaited(_savePreferences(
                    smartBlock: value,
                    onFailure: () => setSheetState(() => _smartBlock = before),
                  ));
                },
              ),
              ListTile(
                title: const Text('开启匹配'),
                subtitle: const Text('服务端同步'),
                trailing: Switch(
                  value: _matching,
                  onChanged: (value) {
                    final before = _matching;
                    setSheetState(() => _matching = value);
                    unawaited(_savePreferences(
                      matchingEnabled: value,
                      onFailure: () => setSheetState(() => _matching = before),
                    ));
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

  Future<void> _savePreferences({
    bool? antiHarassment,
    bool? smartBlock,
    bool? matchingEnabled,
    VoidCallback? onFailure,
  }) async {
    try {
      final token = await _token();
      await service.updatePreferences(
        token,
        antiHarassment: antiHarassment,
        smartBlock: smartBlock,
        matchingEnabled: matchingEnabled,
      );
    } catch (e) {
      onFailure?.call();
      if (mounted) _showTopNotice(context, const Text('设置保存失败'));
    }
  }

  Future<void> _selectProfileTab(int tab) async {
    if (tab == selectedTab) return;
    final feed = feeds[tab];
    if (!feed.initialized) {
      await feed.restoreCache();
      if (!feed.initialized) await feed.load();
    }
    if (!mounted) return;
    _cachedAllProfileSignature = null;
    _cachedAllProfileSlivers = null;
    setState(() => selectedTab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !feed.scroll.hasClients) return;
      final target = _profileTabOffsets[tab] ?? 0.0;
      feed.scroll.jumpTo(target.clamp(
        feed.scroll.position.minScrollExtent,
        feed.scroll.position.maxScrollExtent,
      ));
    });
  }

  Future<void> _restoreProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileCacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final cachedAt = decoded['_cachedAt'] as num?;
        final age = cachedAt == null
            ? null
            : DateTime.now().millisecondsSinceEpoch - cachedAt.toInt();
        if (age == null || age <= const Duration(minutes: 5).inMilliseconds) {
          await _applyProfileData(
              Map<String, dynamic>.from(decoded)..remove('_cachedAt'));
        }
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _fetchProfileOnce(String token) async {
    if (_profileRequest != null) {
      return _profileRequest!.then((value) => value ?? <String, dynamic>{});
    }
    final future = service.fetchMe(token);
    _profileRequest = future.then<Map<String, dynamic>?>((value) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _profileCacheKey,
          jsonEncode(
              {...value, '_cachedAt': DateTime.now().millisecondsSinceEpoch}));
      return value;
    });
    return _profileRequest!
        .then((value) => value ?? <String, dynamic>{})
        .whenComplete(() => _profileRequest = null);
  }

  Future<void> _applyProfileData(Map<String, dynamic> loaded,
      {String? token}) async {
    final avatarKey = '${loaded['avatarKey'] ?? ''}'.trim();
    String? localAvatar;
    if (avatarKey.isNotEmpty) {
      localAvatar = await ImLocalStore.avatarPath(avatarKey);
    }
    String? signedAvatar;
    if (localAvatar == null && token != null && avatarKey.isNotEmpty) {
      signedAvatar = await service.resolveAvatarUrl(token, avatarKey);
    }
    if (!mounted) return;
    setState(() {
      profile = loaded;
      _currentUserId =
          int.tryParse('${loaded['id'] ?? loaded['userId'] ?? ''}');
      coinBalance = int.tryParse('${loaded['coinBalance'] ?? 0}') ?? 0;
      charmCoins = int.tryParse('${loaded['charmCoins'] ?? 0}') ?? 0;
      final nextSonicUrl =
          DDPostService.mediaUrl(loaded['voiceUrl']?.toString());
      if (_sonicUrl != null && _sonicUrl != nextSonicUrl) {
        unawaited(_sonicPlayer.stop());
      }
      _sonicUrl = nextSonicUrl;
      _avatarLocalPath = localAvatar;
      _avatarUrl = signedAvatar;
      _avatarReviewRejected = loaded['avatarReviewStatus'] == 'rejected' ||
          loaded['avatar_review_status'] == 'rejected';
      _stealth = '${loaded['presenceMode'] ?? 'online'}' == 'stealth';
      _antiHarassment = loaded['antiHarassment'] == true;
      _smartBlock = loaded['smartBlock'] == true;
      _matching = loaded['matchingEnabled'] == true;
    });
  }

  Future<void> _refreshProfileOnly() async {
    if (_profileRefreshing) return;
    setState(() => _profileRefreshing = true);
    try {
      final token = await _token();
      final loaded = await _fetchProfileOnce(token);
      await _applyProfileData(loaded, token: token);
    } catch (_) {
      if (mounted) _showTopNotice(context, const Text('资料刷新失败'));
    } finally {
      if (mounted) setState(() => _profileRefreshing = false);
    }
  }

  Future<void> _invalidateProfileCacheAndReload() async {
    await DDPostService.clearProfileTabCaches();
    for (final feed in feeds) {
      feed.posts.clear();
      feed.initialized = false;
      feed.offset = 0;
      feed.hasMore = true;
    }
    await feeds[selectedTab].load(refresh: true);
  }

  Future<void> load({int? tab, bool forceRefresh = false}) async {
    final targetTab = tab ?? selectedTab;
    if (mounted) {
      setState(() {
        error = null;
        if (tab != null) selectedTab = targetTab;
        loading = true;
      });
    }
    try {
      final t = await _token();
      if (profile == null || tab == null || forceRefresh) {
        final loadedProfile = await _fetchProfileOnce(t);
        await _applyProfileData(loadedProfile, token: t);
        final avatarKey = '${loadedProfile['avatarKey'] ?? ''}'.trim();
        final avatar = _avatarUrl;
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
      }
      final feed = feeds[targetTab];
      if (forceRefresh || !feed.initialized) {
        await feed.load(refresh: forceRefresh);
      }
      if (!mounted) return;
      setState(() {
        selectedTab = targetTab;
        error = null;
      });
      if (feed.error != null && mounted) {
        _showTopNotice(context, Text('动态加载失败：${feed.error}'));
        feed.clearError();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = null);
        _showTopNotice(context, Text('动态加载失败：$e'));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _deleteMyPost(DDPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除动态'),
        content: const Text('删除后无法恢复，确定继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await service.deletePost(await _token(), post.id);
      await _invalidateProfileCacheAndReload();
    } catch (e) {
      if (mounted) _showTopNotice(context, const Text('删除失败'));
    }
  }

  Future<void> _profileLike(DDPost post) async {
    if (!pendingLikes.add(post.id)) return;
    try {
      await service.toggleLike(await _token(), post.id);
      if (!mounted) return;
      final updated = post.copyWith(
        liked: !post.liked,
        likes: post.likes + (post.liked ? -1 : 1),
      );
      for (final feed in feeds) {
        feed.updateLike(updated);
      }
      await DDPostService.clearProfileTabCaches();
    } catch (e) {
      if (mounted) _showTopNotice(context, SnackBar(content: Text('$e')));
    } finally {
      pendingLikes.remove(post.id);
    }
  }

  Future<void> _profileFavorite(DDPost post) async {
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

  Future<void> _profileShare(DDPost post) async {
    await Share.share('动态 ${post.id}：${post.content}');
    if (mounted) _showTopNotice(context, const Text('已打开系统分享面板'));
  }

  Future<void> _profileSendToFriend(String peerId, DDPost post) async {
    try {
      final conversationId =
          await service.createDirectConversation(await _token(), peerId);
      await _sendSharedPostMessage(
        conversationId: conversationId,
        postId: post.id,
        text: post.content,
        author: post.nickname,
        content: post.content,
        thumbnailUrl: post.thumbnailUrl ?? post.imageUrl ?? '',
      );
      if (mounted) _showTopNotice(context, const Text('已发送给好友'));
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  Future<void> _profileDirectChat(DDPost post) async {
    if (post.userId == null) return;
    try {
      final conversationId = await service.createDirectConversation(
          await _token(), '${post.userId}');
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _ChatDetailPage(
                    chat: _ChatPreview(
                        post.nickname,
                        '开始聊天',
                        post.avatar,
                        null,
                        '${post.userId}',
                        conversationId,
                        0,
                        null,
                        null,
                        'dm',
                        false,
                        false),
                  )));
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  Future<void> _profileFollow(DDPost post) async {
    if (post.userId == null) return;
    try {
      final followed = await service.toggleFollow(await _token(), post.userId!);
      final updated = post.copyWith(following: followed);
      for (final feed in feeds) {
        feed.updateFollowing(updated);
      }
      if (mounted) _showTopNotice(context, Text(followed ? '已关注' : '已取消关注'));
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  void _profileGift(DDPost post) {
    if (!mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                DynamicDetailPage(postId: post.id, initialPost: post)));
  }

  Future<void> _profileReport(DDPost post) async {
    if (post.userId == profile?['id']) return;
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ReportPostPage(postId: post.id, service: service, token: _token)),
    );
    if (submitted == true && mounted) {
      _showTopNotice(context, const Text('举报已提交'));
    }
  }

  List<Widget> _allProfileFeedSlivers() {
    final signature = feeds
        .map((feed) => feed.posts.map((post) => post.id).join(','))
        .join('|');
    if (_cachedAllProfileSignature == signature &&
        _cachedAllProfileSlivers != null) {
      return _cachedAllProfileSlivers!;
    }
    final shell = FeedShellController(feeds: feeds, cardKeys: _profileCardKeys);
    final result = <Widget>[];
    for (var index = 0; index < feeds.length; index++) {
      final slivers = shell.slivers(
        index: index,
        currentUserId: _currentUserId,
        onLike: _profileLike,
        onFavorite: _profileFavorite,
        onShare: _profileShare,
        onSendToFriend: _profileSendToFriend,
        onDirectChat: _profileDirectChat,
        onFollow: _profileFollow,
        onGift: _profileGift,
        onDelete: index == 0 ? _deleteMyPost : null,
        onReport: _profileReport,
        hideAuthorRow: index == 0,
        showViews: index == 0,
        showItemDivider: index == 0,
        onOpen: (post) async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => DynamicDetailPage(
                postId: post.id,
                initialPost: post,
                cardKey: _profileCardKeys['${post.id}'],
              ),
            ),
          );
          if (changed == true) await _invalidateProfileCacheAndReload();
        },
      );
      for (final sliver in slivers) {
        result.add(SliverVisibility(
          visible: selectedTab == index,
          maintainState: true,
          maintainAnimation: true,
          sliver: sliver,
        ));
      }
    }
    _cachedAllProfileSignature = signature;
    _cachedAllProfileSlivers = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: '在线状态',
          onPressed: _openPresenceControls,
          icon: const Icon(TIcons.sensors),
        ),
        title: _showStickyNickname
            ? Text(
                '${p?['nickname'] ?? 'Friend 用户'}',
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
            icon: const Icon(TIcons.location),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(TIcons.format_vertical_align_right),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  notificationPredicate: (notification) =>
                      notification.depth == 0,
                  onRefresh: () => load(forceRefresh: true),
                  child: CustomScrollView(
                    controller: _profileHeaderScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '地区：${'${p?['city'] ?? ''}'.trim().isEmpty ? '未知' : '${p?['city']}'.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    '${p?['nickname'] ?? 'Friend 用户'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 30,
                                                        height: 1.2,
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: '编辑资料',
                                                  onPressed: _openEditProfile,
                                                  icon: const Icon(TIcons
                                                      .textformat_shorter),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints
                                                          .tightFor(
                                                          width: 32,
                                                          height: 32),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              'ID：${p?['id'] ?? p?['userId'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: .65),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.only(
                                                  top: 7, bottom: 14),
                                              decoration: const BoxDecoration(),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                      child: _InlineProfileStat(
                                                          label: '关注',
                                                          value: _formatCount(
                                                              p?['following']),
                                                          onTap: () => Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder: (_) => const _UserRelationListPage(
                                                                      relation:
                                                                          'following',
                                                                      title:
                                                                          '关注'))))),
                                                  Expanded(
                                                      child: _InlineProfileStat(
                                                          label: '粉丝',
                                                          value: _formatCount(
                                                              p?['followers']),
                                                          onTap: () => Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder: (_) => const _UserRelationListPage(
                                                                      relation:
                                                                          'followers',
                                                                      title:
                                                                          '粉丝'))))),
                                                  Expanded(
                                                      child: _InlineProfileStat(
                                                          label: '获赞',
                                                          value: _formatCount(
                                                              p?['receivedLikes'] ??
                                                                  p?['likes']),
                                                          onTap: () => Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder: (_) => const _UserRelationListPage(
                                                                      relation:
                                                                          'likers',
                                                                      title:
                                                                          '获赞'))))),
                                                  Expanded(
                                                      child: _InlineProfileStat(
                                                    label: '魅力',
                                                    value: _formatCount(
                                                        charmCoins),
                                                    onTap: () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const _CharmSourcesPage(),
                                                      ),
                                                    ),
                                                  )),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 23),
                                        child: Column(
                                          children: [
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Container(
                                                  width: 108,
                                                  height: 108,
                                                  padding:
                                                      const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: p?['gender'] ==
                                                            '男'
                                                        ? const LinearGradient(
                                                            colors: [
                                                              Color(0xFF69B7FF),
                                                              Color(0xFF1677FF),
                                                              Color(0xFF0B3D91)
                                                            ],
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                          )
                                                        : p?['gender'] == '女'
                                                            ? const LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                      0xFFFFB6D5),
                                                                  Color(
                                                                      0xFFFF6FAE),
                                                                  Color(
                                                                      0xFFC2185B)
                                                                ],
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomRight,
                                                              )
                                                            : null,
                                                    color: p?['gender'] ==
                                                                '男' ||
                                                            p?['gender'] == '女'
                                                        ? null
                                                        : Theme.of(context)
                                                            .dividerColor,
                                                  ),
                                                  child: ClipOval(
                                                    child: SizedBox(
                                                      width: 102,
                                                      height: 102,
                                                      child:
                                                          _avatarReviewRejected
                                                              ? const ColoredBox(
                                                                  color: Colors
                                                                      .black12,
                                                                  child: Center(
                                                                    child: Text(
                                                                        '图片涉嫌违规',
                                                                        textAlign:
                                                                            TextAlign
                                                                                .center,
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            color:
                                                                                Colors.black54)),
                                                                  ),
                                                                )
                                                              : _avatarLocalPath !=
                                                                      null
                                                                  ? Image.file(
                                                                      File(
                                                                          _avatarLocalPath!),
                                                                      width:
                                                                          102,
                                                                      height:
                                                                          102,
                                                                      fit: BoxFit
                                                                          .cover)
                                                                  : _avatarUrl ==
                                                                              null ||
                                                                          _avatarUrl!
                                                                              .isEmpty
                                                                      ? const ColoredBox(
                                                                          color: Colors
                                                                              .black12,
                                                                          child: Icon(
                                                                              Icons.person,
                                                                              size: 40))
                                                                      : _PermanentCachedImage(
                                                                          url:
                                                                              _avatarUrl!,
                                                                          width:
                                                                              102,
                                                                          height:
                                                                              102,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                          placeholder: const ColoredBox(
                                                                              color: Colors.black12,
                                                                              child: Icon(Icons.person, size: 40)),
                                                                        ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: _ExpandableProfileSignature(
                                            value:
                                                '${p?['signature'] ?? p?['bio'] ?? ''}',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 36),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: _ProfileActionButton(
                                              icon: TIcons.sonic,
                                              label: '声音',
                                              onTap: _editSonic)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: _ProfileActionButton(
                                              icon: Icons.auto_awesome_outlined,
                                              label: '展馆',
                                              onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const GiftExhibitionPage())))),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: _ProfileActionButton(
                                              icon: TIcons.space,
                                              label: '空间',
                                              onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ProfileSpacePage())))),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: _ProfileActionButton(
                                              icon: TIcons.browse_gallery,
                                              label: '频道',
                                              onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ProfileChannelPage())))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 0),
                            const SizedBox(height: 0),
                          ]),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _ProfileTabsHeaderDelegate(
                          child: _MyProfileIconTabs(
                            selectedTab: selectedTab,
                            onSelect: _selectProfileTab,
                          ),
                        ),
                      ),
                      ..._allProfileFeedSlivers(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: subtitle == null ? 40 : 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: scheme.primary),
              const SizedBox(width: 7),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
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
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
            child: child,
          ),
        ),
      );

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}
