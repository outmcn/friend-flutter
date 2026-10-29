part of 'main.dart';

class OtherProfilePage extends StatefulWidget {
  const OtherProfilePage({
    super.key,
    this.name = '推荐用户',
    this.avatarAsset = 'assets/figma/profile-portrait-2.jpg',
    this.userId,
  });
  final String name;
  final String? avatarAsset;
  final int? userId;
  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  final DDPostService service = DDPostService();
  final ScrollController _profileScrollController = ScrollController();
  final AudioPlayer _sonicPlayer = AudioPlayer();
  Map<String, dynamic>? profile;
  List<DDPost> posts = const [];
  bool loading = true;
  bool actionLoading = false;
  bool isFollowing = false;
  bool isSelfProfile = false;
  bool blocked = false;
  int charmCoins = 0;
  int selectedContentTab = 0;
  bool _showStickyNickname = false;
  bool _sonicPlaying = false;
  String? _sonicUrl;
  String? _avatarUrl;
  bool _avatarReviewRejected = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _profileScrollController.addListener(_handleProfileScroll);
    load();
  }

  void _handleProfileScroll() {
    final show = _profileScrollController.hasClients &&
        _profileScrollController.offset >= 58;
    if (show != _showStickyNickname && mounted) {
      setState(() => _showStickyNickname = show);
    }
  }

  Future<void> _openPrivateChat() async {
    final peerId = widget.userId;
    if (peerId == null || isSelfProfile) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final conversationId =
          await service.createDirectConversation(token, '$peerId');
      if (!mounted) return;
      final chat = _ChatPreview(
        widget.name,
        '开始一段新的聊天',
        _avatarUrl,
        null,
        '$peerId',
        conversationId,
        0,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ChatDetailPage(chat: chat)),
      );
    } catch (error) {
      if (!mounted) return;
      _showTopNotice(context, Text('$error'));
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

  bool _giftSubmitting = false;
  int _giftPage = 0;

  Future<void> _confirmAndSendGift(
      BuildContext sheetContext, Map<String, dynamic> gift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认送礼'),
        content: Text(
            '送出「${gift['name'] ?? '礼物'}」需要 ${gift['coinPrice'] ?? gift['coin_price'] ?? 0} 金币，确认送出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认送出')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(sheetContext);
      unawaited(_sendUserGift(gift));
    }
  }

  Future<void> _openGiftMenu() async {
    if (widget.userId == null || _giftSubmitting || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final gifts = await service.fetchGiftItems(token, scope: 'user');
      _giftPage = 0;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        enableDrag: false,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                gifts.isEmpty
                    ? const SizedBox(
                        height: 120,
                        child: Center(child: Text('暂无可送礼物')),
                      )
                    : StatefulBuilder(builder: (context, setSheetState) {
                        final pageCount = (gifts.length / 10).ceil();
                        return SizedBox(
                          height: 215,
                          child: Column(
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  itemCount: pageCount,
                                  onPageChanged: (page) => setSheetState(() {}),
                                  itemBuilder: (_, page) {
                                    final pageGifts =
                                        gifts.skip(page * 10).take(10).toList();
                                    return GridView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: pageGifts.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 5,
                                              crossAxisSpacing: 6,
                                              mainAxisSpacing: 6,
                                              childAspectRatio: .72),
                                      itemBuilder: (_, index) {
                                        final gift = pageGifts[index];
                                        final assetIndex = page * 10 + index;
                                        return InkWell(
                                          onTap: () => _confirmAndSendGift(
                                              sheetContext, gift),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Image.asset(
                                                      'assets/profile_gifts/gift_${assetIndex + 1}.png',
                                                      width: 42,
                                                      height: 42,
                                                      fit: BoxFit.contain),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                      '${gift['name'] ?? '礼物'}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 11)),
                                                  Text(
                                                      '${gift['coinPrice'] ?? gift['coin_price'] ?? 0}金币',
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors.orange)),
                                                ]),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              Text('${_giftPage + 1}/$pageCount',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      })
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  Future<void> _sendUserGift(Map<String, dynamic> gift) async {
    if (_giftSubmitting || widget.userId == null || !mounted) return;
    setState(() => _giftSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      await service.sendUserGift(
        token: token,
        userId: widget.userId!,
        giftId: int.parse('${gift['id']}'),
      );
      if (mounted) {
        _showTopNotice(context, const Text('礼物已送出'));
        await load();
      }
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    } finally {
      if (mounted) setState(() => _giftSubmitting = false);
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) {
        throw Exception('请先登录');
      }
      if (widget.userId == null) {
        throw Exception('用户信息不存在');
      }
      final data = await service.fetchUserProfile(token, widget.userId!);
      final me = await service.fetchMe(token);
      final currentBlocked =
          await service.fetchUserBlocked(token, widget.userId!);
      final avatarKey = '${data['avatarKey'] ?? data['avatar'] ?? ''}'.trim();
      final signedAvatar = avatarKey.isEmpty
          ? null
          : await service.resolveAvatarUrl(token, avatarKey);
      final loadedPosts = (data['posts'] is List)
          ? (data['posts'] as List)
              .whereType<Map>()
              .map((item) => DDPost.fromJson(
                    item.cast<String, dynamic>(),
                    preserveMediaKeys: true,
                  ))
              .toList()
          : <DDPost>[];
      final resolvedPosts = await Future.wait(
          loadedPosts.map((post) => service.resolvePostMedia(token, post)));
      if (mounted) {
        setState(() {
          profile = data;
          posts = resolvedPosts;
          isFollowing = data['followingByViewer'] == true;
          isSelfProfile = '${data['id']}' == '${me['id']}';
          blocked = currentBlocked;
          charmCoins = int.tryParse('${data['charmCoins'] ?? 0}') ?? 0;
          _sonicUrl = DDPostService.mediaUrl(data['voiceUrl']?.toString());
          _avatarUrl = signedAvatar;
          _avatarReviewRejected = data['avatarReviewStatus'] == 'rejected' ||
              data['avatar_review_status'] == 'rejected';
        });
      }
    } on UnsupportedError catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleSonic() async {
    final url = _sonicUrl;
    if (url == null || url.isEmpty || actionLoading) return;
    try {
      setState(() => actionLoading = true);
      if (_sonicPlaying) {
        await _sonicPlayer.pause();
      } else {
        await _sonicPlayer.play(UrlSource(url));
      }
      if (mounted) setState(() => _sonicPlaying = !_sonicPlaying);
    } catch (_) {
      if (mounted) setState(() => error = '声音播放失败');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> toggleFollow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty || widget.userId == null) throw Exception('请先登录');
      setState(() => actionLoading = true);
      await service.toggleFollow(token, widget.userId!);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final following = isFollowing;
    return Scaffold(
      appBar: AppBar(
        title: _showStickyNickname
            ? Text(
                '${p?['nickname'] ?? widget.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : const SizedBox.shrink(),
        actions: [
          if (!loading && !isSelfProfile)
            IconButton(
              tooltip: '送礼',
              onPressed: _openGiftMenu,
              icon: const Icon(Icons.card_giftcard_outlined),
            ),
          IconButton(
            onPressed: () => _showProfileMenu(context),
            icon: _tdIcon('more'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                controller: _profileScrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
                children: [
                  if (error != null)
                    _PageErrorState(
                        title: '主页加载失败', subtitle: error!, onRetry: load),
                  const SizedBox(height: 8),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p?['nickname'] ?? widget.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 30,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'ID：${p?['id'] ?? p?['userId'] ?? widget.userId ?? ''}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: .65),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'IP：${'${p?['city'] ?? ''}'.trim().isEmpty ? '未定位' : '${p?['city']}'.trim()}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: .65),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.zero,
                                    child: Row(
                                      children: [
                                        Expanded(
                                            child: _InlineProfileStat(
                                                label: '关注',
                                                value:
                                                    '${p?['following'] ?? 0}')),
                                        Expanded(
                                            child: _InlineProfileStat(
                                                label: '粉丝',
                                                value:
                                                    '${p?['followers'] ?? 0}')),
                                        Expanded(
                                            child: _InlineProfileStat(
                                                label: '访客',
                                                value:
                                                    '${p?['visitors'] ?? 0}')),
                                        Expanded(
                                            child: _InlineProfileStat(
                                                label: '魅力',
                                                value: '$charmCoins')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Container(
                                width: 108,
                                height: 108,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: p?['gender'] == '男'
                                      ? const LinearGradient(colors: [
                                          Color(0xFF69B7FF),
                                          Color(0xFF1677FF),
                                          Color(0xFF0B3D91)
                                        ])
                                      : p?['gender'] == '女'
                                          ? const LinearGradient(colors: [
                                              Color(0xFFFFB6D5),
                                              Color(0xFFFF6FAE),
                                              Color(0xFFC2185B)
                                            ])
                                          : null,
                                  color:
                                      p?['gender'] == '男' || p?['gender'] == '女'
                                          ? null
                                          : Theme.of(context).dividerColor,
                                ),
                                child: ClipOval(
                                  child: SizedBox(
                                    width: 102,
                                    height: 102,
                                    child: _avatarReviewRejected
                                        ? const ColoredBox(
                                            color: Colors.black12,
                                            child: Center(
                                                child: Text('图片涉嫌违规',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.black54))))
                                        : _avatarUrl == null ||
                                                _avatarUrl!.isEmpty
                                            ? const ColoredBox(
                                                color: Colors.black12,
                                                child: Icon(Icons.person,
                                                    size: 40))
                                            : _PermanentCachedImage(
                                                url: _avatarUrl!,
                                                width: 102,
                                                height: 102,
                                                fit: BoxFit.cover,
                                                placeholder: const ColoredBox(
                                                    color: Colors.black12,
                                                    child: Icon(Icons.person,
                                                        size: 40))),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${p?['signature'] ?? p?['bio'] ?? ''}',
                          softWrap: true,
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Expanded(
                          child: _ProfileActionButton(
                              icon: TIcons.sonic,
                              label: '声音',
                              onTap: _toggleSonic)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: _ProfileActionButton(
                              icon: Icons.auto_awesome_outlined,
                              label: '展馆',
                              onTap: _openGiftExhibition)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ProfileActionButton(
                          icon: TIcons.space,
                          label: '空间',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileSpacePage(
                                nickname:
                                    '${profile?['nickname'] ?? widget.name}',
                                avatarUrl: _avatarUrl,
                                userId: widget.userId,
                                isOwner: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ProfileActionButton(
                          icon: TIcons.browse_gallery,
                          label: '频道',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ProfileChannelPage(
                                      userId: widget.userId, isOwner: false))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MyProfileIconTabs(
                    selectedTab: 0,
                    onSelect: (_) {},
                    postsOnly: true,
                  ),
                  const SizedBox(height: 12),
                  if (posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 42),
                      child: Center(child: Text('暂无内容')),
                    )
                  else
                    _MyProfileGrid(posts: posts),
                  const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 12),
                    child: Center(
                      child: Text(
                        '暂时没有更多了',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: (!loading && !isSelfProfile)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: actionLoading ? null : toggleFollow,
                        icon: Icon(following
                            ? Icons.person_remove_outlined
                            : Icons.person_add_alt_1_outlined),
                        label: Text(actionLoading
                            ? '处理中…'
                            : following
                                ? (p?['followedByViewer'] == true
                                    ? '好友'
                                    : '已关注')
                                : (p?['followedByViewer'] == true
                                    ? '回关'
                                    : '关注')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openPrivateChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('私聊'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _openGiftExhibition() async {
    final userId = widget.userId;
    if (userId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftExhibitionPage(
          userId: userId,
          userName: '${profile?['nickname'] ?? widget.name}',
          onSendGift: () async {
            await _openGiftMenu();
          },
        ),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    final userId = widget.userId;
    if (userId == null || actionLoading) return;
    try {
      setState(() => actionLoading = true);
      final token = (await SharedPreferences.getInstance())
          .getString('friend.auth.token');
      if (token == null || token.isEmpty) throw Exception('请先登录');
      final next = await service.toggleUserBlock(token, userId);
      if (mounted) setState(() => blocked = next);
    } catch (error) {
      if (mounted) {
        _showTopNotice(context, Text('$error'));
      }
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  void _showProfileMenu(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Wrap(
            children: [
              ListTile(leading: _FigmaIcon('link'), title: Text('分享主页')),
              ListTile(
                leading: Icon(blocked ? Icons.lock_open : Icons.block),
                title: Text(blocked ? '解除拉黑' : '拉黑用户'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_toggleBlock());
                },
              ),
            ],
          ),
        ),
      );
}
