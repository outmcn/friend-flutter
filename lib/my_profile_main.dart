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
  const GiftExhibitionPage({super.key});

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
      final value = await service.fetchMyUserGifts(token);
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
        appBar: AppBar(title: const Text('礼物展馆')),
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
  List<DDPost> posts = [];
  int selectedTab = 0;
  bool loading = true;
  bool tabLoading = false;
  late final List<DiscoverFeed> feeds;
  final AudioPlayer _sonicPlayer = AudioPlayer();
  final ScrollController _profileScrollController = ScrollController();
  bool _showStickyNickname = false;
  bool _sonicPlaying = false;
  bool _tagSaving = false;
  String? _sonicUrl;
  String? _avatarUrl;
  String? error;
  List<String> _tags = <String>[];
  bool _stealth = false;
  bool _antiHarassment = false;
  bool _smartBlock = false;
  bool _matching = false;
  bool _profileRefreshing = false;
  bool _locationRefreshing = false;
  bool _tabSwitching = false;
  Timer? _presenceTimer;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileScrollController.addListener(_handleProfileScroll);
    _presenceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_appActive) _sendPresenceHeartbeat();
    });
    _sonicPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _sonicPlaying = false);
    });
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive && mounted) {
      setState(() => _appActive = active);
    }
    if (active) unawaited(_sendPresenceHeartbeat());
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
    _profileScrollController.removeListener(_handleProfileScroll);
    _profileScrollController.dispose();
    for (final feed in feeds) {
      feed.dispose();
    }
    _sonicPlayer.dispose();
    service.dispose();
    super.dispose();
  }


  Future<void> _refreshCityFromLocation() async {
    if (_locationRefreshing) return;
    setState(() => _locationRefreshing = true);
    try {
      final token = await _token();
      await syncCachedLocation(service, token);
      await _refreshProfileOnly();
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('定位更新失败：$e'));
    } finally {
      if (mounted) setState(() => _locationRefreshing = false);
    }
  }

  String _formatCount(dynamic value) {
    final number = int.tryParse('$value') ?? 0;
    if (number >= 100000000) {
      return '${(number / 100000000).toStringAsFixed(1)}亿';
    }
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
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

  Future<void> _toggleSonic() async {
    final url = _sonicUrl;
    if (url == null || url.isEmpty) {
      _showTopNotice(context, const Text('暂未设置语音'));
      return;
    }
    try {
      if (_sonicPlaying) {
        await _sonicPlayer.pause();
        if (mounted) setState(() => _sonicPlaying = false);
      } else {
        await _sonicPlayer.play(UrlSource(url));
        if (mounted) setState(() => _sonicPlaying = true);
      }
    } catch (_) {
      if (mounted) _showTopNotice(context, const Text('声音播放失败'));
    }
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
    final previous = _stealth;
    final nextStealth = mode == 'stealth';
    if (mounted) {
      setState(() => _stealth = nextStealth);
      setSheetState?.call(() {});
    }
    try {
      final token = await _token();
      await service.setPresence(token, mode);
    } catch (e) {
      if (mounted) {
        setState(() => _stealth = previous);
        setSheetState?.call(() {});
        _showTopNotice(context, Text('在线状态更新失败：$e'));
      }
    }
  }

  Future<void> _sendPresenceHeartbeat() async {
    try {
      final token = await _token();
      await service.presenceHeartbeat(token);
    } catch (_) {}
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
                subtitle: Text(
                    '${_stealth ? '当前：隐身' : '当前：在线'} · 仅本机显示'),
                trailing: Switch(
                  value: !_stealth,
                  onChanged: (value) {
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
                    onFailure: () => setSheetState(() => _antiHarassment = before),
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
      if (mounted) _showTopNotice(context, Text('设置保存失败：$e'));
    }
  }

  Future<void> _selectProfileTab(int tab) async {
    if (_tabSwitching || tab == selectedTab) return;
    setState(() => _tabSwitching = true);
    try {
      await load(tab: tab);
    } finally {
      if (mounted) setState(() => _tabSwitching = false);
    }
  }
  Future<void> _refreshProfileOnly() async {
    if (_profileRefreshing) return;
    setState(() => _profileRefreshing = true);
    try {
      final token = await _token();
      final loaded = await service.fetchMe(token);
      final avatarKey = '${loaded['avatarKey'] ?? ''}'.trim();
      final avatar = avatarKey.isEmpty
          ? null
          : await service.resolveAvatarUrl(token, avatarKey);
      final rawTags = loaded['tags'];
      final tags = rawTags is List
          ? rawTags
              .map((value) => '$value')
              .where((value) => value.trim().isNotEmpty)
              .toList()
          : <String>[];
      if (mounted) {
        setState(() {
          profile = loaded;
          coinBalance = int.tryParse('${loaded['coinBalance'] ?? 0}') ?? 0;
          charmCoins = int.tryParse('${loaded['charmCoins'] ?? 0}') ?? 0;
          _sonicUrl = DDPostService.mediaUrl(loaded['voiceUrl']?.toString());
          _avatarUrl = avatar;
          _tags = tags;
        });
      }
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('资料刷新失败：$e'));
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
            charmCoins =
                int.tryParse('${loadedProfile['charmCoins'] ?? 0}') ?? 0;
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
            icon: const Icon(Icons.history_outlined),
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
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => load(forceRefresh: true),
                  child: CustomScrollView(
                    controller: _profileScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (error != null && profile != null)
                              _PageErrorState(
                                title: profile == null ? '资料加载失败' : '动态加载失败',
                                subtitle: error!,
                                onRetry: profile == null
                                    ? load
                                    : () => load(
                                        tab: selectedTab, forceRefresh: true),
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
                                            child: Text(
                                              '${p?['city'] ?? ''}'.trim().isEmpty
                                                  ? '添加城市'
                                                  : '${p?['city']}',
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
                                                '${p?['nickname'] ?? 'Friend 用户'}  ${p?['gender'] == '男' ? '♂' : p?['gender'] == '女' ? '♀' : ''}',
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
                                              onPressed: _openEditProfile,
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 22),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _SonicProfileButton(
                                              playing: _sonicPlaying,
                                              enabled: _sonicUrl != null &&
                                                  _sonicUrl!.isNotEmpty,
                                              onTap: _toggleSonic,
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: '编辑语音',
                                              onPressed: _editSonic,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 18),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _openPresenceControls,
                                    child: Semantics(
                                      button: true,
                                      label: _appActive
                                          ? (_stealth ? '隐身状态设置' : '在线状态设置')
                                          : '离线状态设置',
                                      child: InkWell(
                                        onTap: _refreshCityFromLocation,
                                        borderRadius: BorderRadius.circular(999),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: !_appActive
                                                ? const Color(0xfff3f4f6)
                                                : _stealth
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
                                                color: !_appActive
                                                    ? const Color(0xff9ca3af)
                                                    : _stealth
                                                        ? const Color(0xff9ca3af)
                                                        : const Color(0xff22c55e),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _appActive
                                                  ? (_stealth ? '隐身' : '在线')
                                                  : '离线',
                                              style: TextStyle(
                                                color: !_appActive
                                                    ? const Color(0xff9ca3af)
                                                    : _stealth
                                                        ? const Color(0xff6b7280)
                                                        : const Color(0xff16a34a),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ],
                              ),
                              const SizedBox(height: 18),
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
                                            value: _formatCount(p?['followers']),
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
                                            value: _formatCount(p?['following']),
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
                                            value: _formatCount(
                                                p?['receivedLikes'] ?? p?['likes']),
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const _UserRelationListPage(
                                                            relation: 'likers',
                                                            title: '获赞'))))),
                                    Expanded(
                                        child: _InlineProfileStat(
                                      label: '魅力',
                                      value: _formatCount(charmCoins),
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
                                        onTap: _tagSaving
                                            ? null
                                            : () async {
                                                final selected =
                                                    await Navigator.push<List<String>>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        _ProfileTagEditorPage(
                                                            selectedTags: _tags),
                                                  ),
                                                );
                                                if (selected != null && mounted) {
                                                  final previousTags =
                                                      List<String>.of(_tags);
                                                  setState(() => _tagSaving = true);
                                                  try {
                                                    final t = await _token();
                                                    final updated =
                                                        await service.updateMe(
                                                            token: t,
                                                            tags: selected);
                                                    if (!mounted) return;
                                                    setState(() {
                                                      _tags = selected;
                                                      profile = {
                                                        ...(profile ??
                                                            <String, dynamic>{}),
                                                        ...updated,
                                                        'tags': selected,
                                                      };
                                                    });
                                                  } catch (e) {
                                                    if (mounted) {
                                                      setState(() =>
                                                          _tags = previousTags);
                                                      _showTopNotice(context,
                                                          Text('标签保存失败：$e'));
                                                    }
                                                  } finally {
                                                    if (mounted) {
                                                      setState(() =>
                                                          _tagSaving = false);
                                                    }
                                                  }
                                                }
                                              },
                                        child: _tagSaving
                                            ? const SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: Padding(
                                                  padding: EdgeInsets.all(6),
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                ),
                                              )
                                            : const _ProfileTag(text: '+'),
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
                                subtitle: coinBalance > 0
                                    ? '$coinBalance 金币'
                                    : null,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const WalletPage())),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ProfileActionButton(
                                icon: Icons.auto_awesome_outlined,
                                label: '展馆',
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const GiftExhibitionPage())),
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
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _MyProfileIconTabs(
                            selectedTab: selectedTab,
                            onSelect: _selectProfileTab,
                          ),
                          if (tabLoading || _tabSwitching)
                            const Positioned(
                              bottom: 0,
                              left: 24,
                              right: 24,
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _MyProfileGrid(
                          posts: posts,
                          emptyLabel: selectedTab == 0
                              ? '还没有发布动态'
                              : selectedTab == 1
                                  ? '还没有收藏内容'
                                  : '还没有点赞内容',
                          emptyActionLabel: selectedTab == 0
                              ? '去发布动态'
                              : '去发现内容',
                          onEmptyAction: selectedTab == 0
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CreatePostPage(),
                                    ),
                                  );
                                  if (mounted) await load(forceRefresh: true);
                                }
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DiscoverPage(),
                                  ),
                                ),
                          onChanged: _invalidateProfileCacheAndReload,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
              ),
              if (_profileRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
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
