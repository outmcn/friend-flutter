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
  bool isProfileLiked = false;
  bool isSelfProfile = false;
  int profileLikes = 0;
  int selectedContentTab = 0;
  bool _showStickyNickname = false;
  bool _sonicPlaying = false;
  String? _sonicUrl;
  String? _avatarUrl;
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

  @override
  void dispose() {
    _profileScrollController.removeListener(_handleProfileScroll);
    _profileScrollController.dispose();
    _sonicPlayer.dispose();
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
      if (token.isEmpty) {
        throw Exception('请先登录');
      }
      if (widget.userId == null) {
        throw Exception('用户信息不存在');
      }
      final data = await service.fetchUserProfile(token, widget.userId!);
      final me = await service.fetchMe(token);
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
          isProfileLiked = data['likedByViewer'] == true;
          isSelfProfile = '${data['id']}' == '${me['id']}';
          profileLikes = int.tryParse('${data['receivedLikes'] ?? 0}') ?? 0;
          _sonicUrl = DDPostService.mediaUrl(data['voiceUrl']?.toString());
          _avatarUrl = signedAvatar;
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

  Future<void> toggleProfileLike() async {
    final userId = widget.userId;
    if (userId == null || actionLoading) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      setState(() => actionLoading = true);
      final result = await service.toggleProfileLike(token, userId);
      if (mounted) {
        setState(() {
          isProfileLiked = result['liked'] == true;
          profileLikes += isProfileLiked ? 1 : -1;
          if (profileLikes < 0) profileLikes = 0;
        });
      }
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
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ProfileLikePill(
                liked: isProfileLiked,
                onTap: actionLoading ? null : toggleProfileLike,
              ),
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
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    child: _avatarUrl == null ||
                                            _avatarUrl!.isEmpty
                                        ? const Icon(Icons.person_outline,
                                            size: 34)
                                        : ClipOval(
                                            child: _PermanentCachedImage(
                                              url: _avatarUrl!,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              placeholder: const ColoredBox(
                                                color: Colors.black12,
                                                child: Icon(Icons.person,
                                                    size: 42),
                                              ),
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: -12,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: _ProfileTag(
                                        text: '${p?['city'] ?? '未知'}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 80,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '${p?['nickname'] ?? widget.name}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 25,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _SonicProfileButton(
                                                playing: _sonicPlaying,
                                                enabled:
                                                    _sonicUrl?.isNotEmpty ==
                                                        true,
                                                onTap: _toggleSonic,
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              _InlineProfileStat(
                                                label: '关注',
                                                value:
                                                    '${p?['following'] ?? 0}',
                                                valueFontSize: 18,
                                                labelFontSize: 14,
                                              ),
                                              const SizedBox(width: 18),
                                              _InlineProfileStat(
                                                label: '粉丝',
                                                value:
                                                    '${p?['followers'] ?? 0}',
                                                valueFontSize: 18,
                                                labelFontSize: 14,
                                              ),
                                              const SizedBox(width: 18),
                                              _InlineProfileStat(
                                                label: '获赞',
                                                value:
                                                    '${p?['receivedLikes'] ?? 0}',
                                                valueFontSize: 18,
                                                labelFontSize: 14,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 32,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: (profile?['tags'] is List
                                                  ? (profile!['tags'] as List)
                                                      .map((value) => '$value')
                                                      .where((value) => value
                                                          .trim()
                                                          .isNotEmpty)
                                                      .toList()
                                                  : <String>[])
                                              .map((tag) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    child:
                                                        _ProfileTag(text: tag),
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                    if ('${p?['clubName'] ?? p?['club'] ?? ''}'
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.groups_outlined,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${p?['clubName'] ?? p?['club']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ),
                                            if ('${p?['clubMemberCount'] ?? ''}'
                                                .trim()
                                                .isNotEmpty)
                                              Text('${p?['clubMemberCount']}',
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                          .hintColor)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      actionLoading ? null : toggleFollow,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: following
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                        : Colors.white,
                                    backgroundColor: following
                                        ? Colors.transparent
                                        : Colors.red,
                                    side: BorderSide(
                                      color: following
                                          ? Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                          : Colors.red,
                                    ),
                                  ),
                                  icon: Icon(
                                    following
                                        ? Icons.person_remove_outlined
                                        : Icons.person_add_alt_1_outlined,
                                  ),
                                  label: Text(
                                    actionLoading
                                        ? '处理中…'
                                        : following
                                            ? (p?['followedByViewer'] == true
                                                ? '好友'
                                                : '已关注')
                                            : (p?['followedByViewer'] == true
                                                ? '回关'
                                                : '关注'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(content: Text('私聊功能暂未接入')),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('私聊'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
    );
  }

  void _showProfileMenu(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const SafeArea(
          child: Wrap(
            children: [
              ListTile(leading: _FigmaIcon('link'), title: Text('分享主页')),
              ListTile(
                leading: Icon(Icons.report_gmailerrorred_outlined),
                title: Text('举报用户'),
              ),
            ],
          ),
        ),
      );
}
