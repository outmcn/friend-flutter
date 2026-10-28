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
  final Future<void> Function()? onSendGift;

  @override
  State<GiftExhibitionPage> createState() => _GiftExhibitionPageState();
}

class _GiftExhibitionPageState extends State<GiftExhibitionPage> {
  final DDPostService service = DDPostService();
  List<Map<String, dynamic>> gifts = const [];

  String _giftAsset(Map<String, dynamic> gift, int index) {
    const names = [
      '心动之心',
      '彩虹甜甜圈',
      '缤纷糖果',
      '甜蜜比心',
      '梦幻棒棒糖',
      '心愿奶茶',
      '粉色玫瑰',
      '甜心蛋糕',
      '抱抱小熊',
      '幸运星',
      '爱心气球',
      '梦幻皇冠',
      '星愿魔法棒',
      '星空许愿瓶',
      '梦幻音乐盒',
      '幸福摩天轮',
      '星河钻石',
      '梦幻城堡',
      '心动火箭',
      '流星心愿',
    ];
    final byName = names.indexOf('${gift['name']}');
    return 'assets/profile_gifts/gift_${(byName >= 0 ? byName : index).clamp(0, 19) + 1}.png';
  }

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

  Future<void> _showGiftDetail(Map<String, dynamic> gift, int index) async {
    final userId = widget.userId;
    final giftId = int.tryParse('${gift['id'] ?? gift['gift_id'] ?? ''}');
    if (userId == null || giftId == null) return;
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('friend.auth.token') ??
          '';
      final ranking = await service.fetchUserGiftRanking(token, userId, giftId);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (dialogContext) {
          final scheme = Theme.of(dialogContext).colorScheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${gift['name'] ?? '礼物'}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Image.asset(_giftAsset(gift, index), width: 86, height: 86),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      ranking.isEmpty
                          ? '暂无'
                          : '冠名：${ranking.first['nickname'] ?? '用户'} · ${ranking.first['quantity'] ?? 0} 个',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (slot) {
                      final row = slot < ranking.length ? ranking[slot] : null;
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: scheme.primaryContainer,
                            backgroundImage:
                                row == null || '${row['avatar'] ?? ''}'.isEmpty
                                    ? null
                                    : NetworkImage('${row['avatar']}'),
                            child: row == null
                                ? Text('${slot + 1}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700))
                                : '${row['avatar'] ?? ''}'.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 82,
                            child: Text(
                              row == null
                                  ? 'No.${slot + 1}：暂无'
                                  : 'No.${slot + 1}：${row['nickname'] ?? '用户'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (row != null)
                            Text('${row['quantity'] ?? 0} 个',
                                style: const TextStyle(fontSize: 11)),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('关闭'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  Future<void> _showAllGiftsDetail() async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('全部礼物',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Icon(Icons.card_giftcard, size: 86, color: scheme.primary),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                    3,
                    (index) => Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: scheme.primaryContainer,
                              child: Text('礼物${index + 1}',
                                  style: const TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(height: 6),
                            Text('No.${index + 1}：暂无'),
                          ],
                        )),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('全部领取'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
              widget.userName == null ? '礼物展馆' : '${widget.userName}的礼物展馆'),
          actions: [
            if (widget.userId != null && widget.onSendGift != null)
              TextButton.icon(
                onPressed: () async {
                  await widget.onSendGift?.call();
                  if (mounted) await _load();
                },
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
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: gifts.length + 1,
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return InkWell(
                          onTap: _showAllGiftsDetail,
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      size: 58,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 8),
                                  const Text('全部点亮',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text('点亮 ${gifts.where((gift) {
                                    final quantity = int.tryParse(
                                            '${gift['received_quantity'] ?? gift['receivedQuantity'] ?? 0}') ??
                                        0;
                                    return quantity > 0;
                                  }).length} 个'),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final gift = gifts[index - 1];
                      final received = int.tryParse(
                              '${gift['received_quantity'] ?? gift['receivedQuantity'] ?? 0}') ??
                          0;
                      final image = Image.asset(
                        _giftAsset(gift, index),
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                      );
                      return InkWell(
                        onTap: () => _showGiftDetail(gift, index),
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ColorFiltered(
                                  colorFilter: received > 0
                                      ? const ColorFilter.mode(
                                          Colors.transparent, BlendMode.dst)
                                      : const ColorFilter.matrix([
                                          0.2126,
                                          0.7152,
                                          0.0722,
                                          0,
                                          0,
                                          0.2126,
                                          0.7152,
                                          0.0722,
                                          0,
                                          0,
                                          0.2126,
                                          0.7152,
                                          0.0722,
                                          0,
                                          0,
                                          0,
                                          0,
                                          0,
                                          1,
                                          0,
                                        ]),
                                  child: image,
                                ),
                                const SizedBox(height: 8),
                                Text('${gift['name'] ?? '礼物'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                    '收到 ${gift['received_quantity'] ?? gift['receivedQuantity'] ?? 0} 个'),
                              ],
                            ),
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

class ProfileSpacePage extends StatefulWidget {
  const ProfileSpacePage(
      {super.key,
      this.nickname,
      this.avatarUrl,
      this.avatarLocalPath,
      this.userId,
      this.isOwner = true});

  final String? nickname;
  final String? avatarUrl;
  final String? avatarLocalPath;
  final int? userId;
  final bool isOwner;

  @override
  State<ProfileSpacePage> createState() => _ProfileSpacePageState();
}

class _ProfileSpacePageState extends State<ProfileSpacePage> {
  Map<String, dynamic>? partner;
  Map<String, dynamic>? checkin;
  Map<String, dynamic>? loveTree;

  @override
  void initState() {
    super.initState();
    _loadPartner();
    _loadCheckin();
    _loadLoveTree();
  }

  Future<void> _loadCheckin() async {
    if (widget.userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    try {
      final data = await DDPostService().fetchCpCheckin(token, widget.userId!);
      if (mounted) setState(() => checkin = data);
    } catch (_) {}
  }

  Future<void> _loadLoveTree() async {
    if (widget.userId == null) return;
    final token = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    if (token.isEmpty) return;
    try {
      final data = await DDPostService().fetchCpLoveTree(token, widget.userId!);
      if (mounted) setState(() => loveTree = data);
    } catch (_) {}
  }

  Future<void> _doCheckin() async {
    if (widget.userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    try {
      final data = await DDPostService().checkinCpSpace(token, widget.userId!);
      if (mounted) setState(() => checkin = data);
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  Future<void> _loadPartner() async {
    if (widget.userId == null) return;
    final token = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    if (token.isEmpty) return;
    try {
      final data = await DDPostService().fetchCpSpace(token, widget.userId!);
      if (mounted)
        setState(() => partner = data['partner'] as Map<String, dynamic>?);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => _SpaceLayout(
        nickname: widget.nickname ?? '我',
        avatarUrl: widget.avatarUrl,
        avatarLocalPath: widget.avatarLocalPath,
        isOwner: widget.isOwner,
        userId: widget.userId,
        partner: partner,
        checkin: checkin,
        loveTree: loveTree,
        onCheckin: _doCheckin,
      );
}

class _SpaceLayout extends StatelessWidget {
  const _SpaceLayout({
    required this.nickname,
    this.avatarUrl,
    this.avatarLocalPath,
    required this.isOwner,
    this.userId,
    this.partner,
    this.checkin,
    this.loveTree,
    required this.onCheckin,
  });

  final String nickname;
  final String? avatarUrl;
  final String? avatarLocalPath;
  final bool isOwner;
  final int? userId;
  final Map<String, dynamic>? partner;
  final Map<String, dynamic>? checkin;
  final Map<String, dynamic>? loveTree;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF160D3B),
        appBar: AppBar(
          title: const Text('CP空间'),
          backgroundColor: const Color(0xFF6A3BC4),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: '进入小窝',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CpSpaceDetailPage(
                    nickname: nickname,
                    avatarUrl: avatarUrl,
                    avatarLocalPath: avatarLocalPath,
                    userId: userId,
                    partner: partner,
                    checkin: checkin,
                    onCheckin: onCheckin,
                  ),
                ),
              ),
              icon: const Icon(Icons.home_work_outlined),
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A3BC4), Color(0xFF160D3B)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 112, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0x886F42D8), Color(0x553A1C91)]),
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: const Color(0xFFB991FF), width: 1.4),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SpaceAvatar(
                              label: nickname,
                              url: avatarUrl,
                              localPath: avatarLocalPath),
                          const _HeartPulse(),
                          _SpaceAvatar(
                            label: partner?['nickname']?.toString() ?? '虚位以待',
                            url: partner?['avatar']?.toString(),
                            localPath: null,
                            isEmpty: partner == null,
                            onTap: () => _CpHouseCard(
                              nickname: nickname,
                              avatarUrl: avatarUrl,
                              avatarLocalPath: avatarLocalPath,
                              partner: partner,
                              userId: userId,
                              isOwner: isOwner,
                            )._openPartnerAction(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _CpLoveTreeCard(
                    experience:
                        int.tryParse('${loveTree?['experience']}') ?? 0),
                const SizedBox(height: 14),
                _CpBlessingCard(),
              ],
            ),
          ),
        ),
      );
}

class _CpLoveTreeCard extends StatelessWidget {
  const _CpLoveTreeCard({required this.experience});
  final int experience;
  static const thresholds = [
    0,
    100,
    300,
    650,
    1200,
    2000,
    3100,
    4600,
    6600,
    9200
  ];
  static const titles = [
    '初遇',
    '心动',
    '暧昧',
    '热恋',
    '默契',
    '守护',
    '相知',
    '挚爱',
    '永恒',
    '传奇'
  ];

  @override
  Widget build(BuildContext context) {
    final safe = experience.clamp(0, 1000000);
    var level = 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (safe >= thresholds[i]) level = i;
    }
    final max = level == thresholds.length - 1;
    final start = thresholds[level];
    final required = max ? 0 : thresholds[level + 1] - start;
    final current = safe - start;
    final progress = max ? 1.0 : (current / required).clamp(0.0, 1.0);

    return Column(children: [
      const Text('爱情树',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Image.asset('assets/cp_love_tree/level_${level + 1}.png',
          width: double.infinity, height: 190, fit: BoxFit.contain),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
            color: const Color(0x443B2184),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x887E5CC9))),
        child: Row(children: [
          Text('Lv.${level + 1} · ${titles[level]}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0x553B2184),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xffffc1e1))))),
          const SizedBox(width: 8),
          Text(max ? '$safe/9200+' : '$current/$required',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    ]);
  }
}

class _CpHouseCard extends StatelessWidget {
  const _CpHouseCard(
      {required this.nickname,
      this.avatarUrl,
      this.avatarLocalPath,
      this.partner,
      this.userId,
      required this.isOwner});

  final String nickname;
  final String? avatarUrl;
  final String? avatarLocalPath;
  final Map<String, dynamic>? partner;
  final int? userId;
  final bool isOwner;

  void _openPartnerAction(BuildContext context) {
    if (partner != null) return;
    if (isOwner) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CpApplicationListPage()));
    } else if (userId != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CpApplyPage(ownerId: userId!)));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0x886F42D8), Color(0x553A1C91)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFB991FF), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Color(0x884F2AAB), blurRadius: 20, spreadRadius: 2)
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SpaceAvatar(
                  label: nickname,
                  url: avatarUrl,
                  localPath: avatarLocalPath,
                ),
                const _HeartPulse(),
                _SpaceAvatar(
                  label: partner?['nickname']?.toString() ?? '虚位以待',
                  url: partner?['avatar']?.toString(),
                  localPath: null,
                  isEmpty: partner == null,
                  onTap: () => _openPartnerAction(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C42D4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDAB8FF)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CpSpaceDetailPage(
                      nickname: nickname,
                      avatarUrl: avatarUrl,
                      avatarLocalPath: avatarLocalPath,
                    ),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Text('CP空间',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      );
}

class CpSpaceDetailPage extends StatefulWidget {
  const CpSpaceDetailPage({
    super.key,
    required this.nickname,
    this.avatarUrl,
    this.avatarLocalPath,
    this.userId,
    this.partner,
    this.checkin,
    this.onCheckin,
  });
  final String nickname;
  final String? avatarUrl;
  final String? avatarLocalPath;
  final int? userId;
  final Map<String, dynamic>? partner;
  final Map<String, dynamic>? checkin;
  final VoidCallback? onCheckin;
  @override
  State<CpSpaceDetailPage> createState() => _CpSpaceDetailPageState();
}

class _CpSpaceDetailPageState extends State<CpSpaceDetailPage> {
  Map<String, dynamic>? dissolution;
  Map<String, dynamic>? currentCheckin;
  Map<String, dynamic>? currentLoveTree;

  bool get dissolutionPending {
    final effectiveAt =
        dissolution?['effectiveAt'] ?? dissolution?['dissolution_effective_at'];
    return effectiveAt != null && '$effectiveAt'.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    currentCheckin = widget.checkin;
    _loadDissolution();
  }

  Future<void> _reloadProgress() async {
    if (widget.userId == null) return;
    final token = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    if (token.isEmpty) return;
    try {
      final data = await DDPostService().fetchCpCheckin(token, widget.userId!);
      if (mounted) setState(() => currentCheckin = data);
    } catch (_) {}
  }

  Future<void> _loadDissolution() async {
    if (widget.userId == null) return;
    final token = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    try {
      final value =
          await DDPostService().fetchCpDissolution(token, widget.userId!);
      if (mounted) setState(() => dissolution = value);
    } catch (_) {}
  }

  Future<void> _requestDissolution() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('解除CP关系'),
                content: const Text(
                    '确认解除吗？确认后将进入7天倒计时，期间可以取消。倒计时结束后会删除CP经验、签到和礼物数据。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('确认解除'))
                ]));
    if (ok != true || widget.userId == null) return;
    final token = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    try {
      final value =
          await DDPostService().requestCpDissolution(token, widget.userId!);
      if (mounted) setState(() => dissolution = value);
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  Future<void> _cancelDissolution() async {
    if (widget.userId == null) return;
    final token = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    try {
      await DDPostService().cancelCpDissolution(token, widget.userId!);
      if (mounted) setState(() => dissolution = null);
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF160D3B),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('CP 小窝'),
          backgroundColor: const Color(0xFF6A3BC4),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed:
                  dissolutionPending ? _cancelDissolution : _requestDissolution,
              child: Text(dissolutionPending ? '取消解除' : '解除关系',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A3BC4), Color(0xFF160D3B)],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 74, 16, 28),
              children: [
                _CpCastleCard(
                    experience: currentCheckin?['experience'] is int
                        ? currentCheckin!['experience'] as int
                        : int.tryParse('${currentCheckin?['experience']}') ??
                            0),
                const SizedBox(height: 14),
                _CpSpaceLevelCard(
                    experience: currentCheckin?['experience'] is int
                        ? currentCheckin!['experience'] as int
                        : int.tryParse('${currentCheckin?['experience']}') ??
                            0),
                const SizedBox(height: 14),
                _CpTaskCard(
                    checkin: currentCheckin,
                    userId: widget.userId,
                    partnerId: int.tryParse('${widget.partner?['userId']}'),
                    partnerExists: widget.partner != null),
                const SizedBox(height: 14),
                _CpGiftCard(
                    userId: widget.userId,
                    partnerId: int.tryParse('${widget.partner?['userId']}'),
                    partnerExists: widget.partner != null,
                    onGiftSent: _reloadProgress),
                const SizedBox(height: 14),
                _CpCheckinCard(
                    checkin: currentCheckin,
                    onCheckin: widget.onCheckin ?? () {}),
                const SizedBox(height: 14),
                const _SpaceDetailEmptyCard(title: '空间动态'),
              ],
            ),
          ),
        ),
      );
}

class _CpBlessingCard extends StatelessWidget {
  const _CpBlessingCard();
  static const names = [
    '初见心滴',
    '晶莹心语',
    '彩色情缘',
    '星光心愿',
    '花漾恋曲',
    '梦幻告白',
    '星月相伴',
    '永恒心海'
  ];
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: .9),
        itemBuilder: (_, i) => Column(children: [
          Image.asset('assets/cp_waterdrops/gift_${i + 1}.png',
              width: 48, height: 48),
          Text(names[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ]),
      );
}

class _CpGiftCard extends StatefulWidget {
  const _CpGiftCard(
      {required this.userId,
      required this.partnerId,
      required this.partnerExists,
      this.onGiftSent});
  final int? userId;
  final int? partnerId;
  final bool partnerExists;
  final Future<void> Function()? onGiftSent;

  @override
  State<_CpGiftCard> createState() => _CpGiftCardState();
}

class _CpGiftCardState extends State<_CpGiftCard> {
  List<Map<String, dynamic>> gifts = const [];
  List<Map<String, dynamic>> blessingGifts = const [];
  bool loading = true;
  bool sending = false;

  static const _cpGiftNames = [
    '心动初遇',
    '甜蜜糖果',
    '浪漫花束',
    '情侣手链',
    '怦然心动',
    '浪漫烟花',
    '永恒对戒',
    '真爱水晶',
    '一生一世',
    '双燕同心',
    '幸福碰杯',
    '桃枝相依',
    '喜结铃缘',
    '星月长伴',
    '比翼双飞',
    '好运双灯',
    '彩虹相守',
    '甜蜜成双',
  ];

  static const _cpGiftPrices = [
    9,
    19,
    29,
    39,
    49,
    59,
    69,
    79,
    89,
    99,
    109,
    119,
    129,
    139,
    149,
    159,
    169,
    179,
  ];

  static const _blessingNames = [
    '双燕同心',
    '幸福碰杯',
    '桃枝相依',
    '喜结铃缘',
    '星月长伴',
    '比翼双飞',
    '好运双灯',
    '彩虹相守',
    '甜蜜成双',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _token() async =>
      (await SharedPreferences.getInstance()).getString('friend.auth.token') ??
      '';

  Future<void> _load() async {
    if (widget.userId == null ||
        widget.partnerId == null ||
        !widget.partnerExists) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final token = await _token();
      final result = await DDPostService().fetchCpGifts(token, widget.userId!);
      if (mounted) {
        setState(() {
          gifts = result.asMap().entries.map((entry) {
            final gift = Map<String, dynamic>.from(entry.value);
            gift['name'] ??= _cpGiftNames[entry.key];
            gift['coinPrice'] ??= _cpGiftPrices[entry.key];
            gift['experience'] ??= _cpGiftPrices[entry.key];
            gift['receivedQuantity'] ??= 0;
            return gift;
          }).toList();
          blessingGifts = const [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sendGift(Map<String, dynamic> gift) async {
    if (sending || widget.partnerId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('确认送礼'),
        content: Text('是否赠送「${gift['name']}」？需要 ${gift['coinPrice']} 金币。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('确认赠送')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => sending = true);
    try {
      await DDPostService().sendCpGift(
          token: await _token(),
          userId: widget.partnerId!,
          name: '${gift['name']}');
      await _load();
      await widget.onGiftSent?.call();
    } catch (e) {
      if (mounted) {
        final message = '$e'.replaceFirst('Exception: ', '');
        final insufficient = message.contains('金币余额不足');
        await showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: '错误提示',
          barrierColor: Colors.black38,
          transitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (dialogContext, animation, secondaryAnimation) =>
              SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width - 32,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xff342047),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xff9b70e8)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 14),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.orangeAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(message,
                            style: const TextStyle(color: Colors.white)),
                      ),
                      if (insufficient)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const WalletPage()),
                            );
                          },
                          child: const Text('进入钱包'),
                        )
                      else
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0x443B2184),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x887E5CC9))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('小窝礼物',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 8),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (!widget.partnerExists)
            const Text('暂无CP礼物', style: TextStyle(color: Colors.white60))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: 18,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 3,
                  childAspectRatio: 1.02),
              itemBuilder: (_, i) {
                final index = i;
                final gift = index < gifts.length
                    ? gifts[index]
                    : <String, dynamic>{
                        'name': _cpGiftNames[index],
                        'coinPrice': _cpGiftPrices[index],
                        'receivedQuantity': 0,
                        'index': index + 1,
                      };
                final name = '${gift['name'] ?? _cpGiftNames[index]}';
                final asset = index < 9
                    ? 'assets/cp_gifts/gift_${index + 1}.png'
                    : 'assets/cp_blessings/gift_${index - 8}.png';
                return InkWell(
                  onTap: sending ? null : () => _sendGift(gift),
                  child: Column(children: [
                    Image.asset(asset, width: 48, height: 48),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                    Text('×${gift['receivedQuantity'] ?? 0}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ]),
                );
              },
            ),
        ]),
      );
}

class _CpTaskCard extends StatefulWidget {
  const _CpTaskCard(
      {this.checkin, this.userId, this.partnerId, this.partnerExists});
  final Map<String, dynamic>? checkin;
  final int? userId;
  final int? partnerId;
  final bool? partnerExists;
  @override
  State<_CpTaskCard> createState() => _CpTaskCardState();
}

class _CpTaskCardState extends State<_CpTaskCard> {
  List<Map<String, dynamic>> gifts = const [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId == null ||
        widget.partnerId == null ||
        widget.partnerExists != true) return;
    final token = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    try {
      final data = await DDPostService().fetchCpGifts(token, widget.partnerId!);
      if (mounted) setState(() => gifts = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final both = widget.checkin?['ownerCheckedIn'] == true &&
        widget.checkin?['partnerCheckedIn'] == true;
    final streak = widget.checkin?['streakDays'] ?? 0;
    final giftDone = gifts.any((gift) => gift['sentToday'] == true);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0x443B2184),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x887E5CC9))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CP任务',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _taskRow('双方每日签到', both ? '已完成 · +10经验' : '双方签到后 +10经验', both),
        _taskRow('连续签到7天', '当前连续 $streak 天 · 达成后额外 +30经验', streak >= 7),
        _taskRow('每日赠送CP礼物', '不限次数 · 每次扣除对应金币，经验与金币相同', giftDone),
      ]),
    );
  }

  Widget _taskRow(String title, String detail, bool done) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.greenAccent : Colors.white54, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: const TextStyle(color: Colors.white70)),
                Text(detail,
                    style: const TextStyle(color: Colors.white54, fontSize: 12))
              ])),
        ]),
      );
}

class _CpCheckinCard extends StatelessWidget {
  const _CpCheckinCard({this.checkin, required this.onCheckin});
  final Map<String, dynamic>? checkin;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final checked = checkin?['checkedIn'] == true;
    final owner = checkin?['ownerCheckedIn'] == true;
    final partner = checkin?['partnerCheckedIn'] == true;
    final rewarded = checkin?['rewarded'] == true;
    final streak = checkin?['streakDays'] ?? 0;
    final bonus = checkin?['bonusExperience'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0x443B2184),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x887E5CC9))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_month, color: Color(0xffd3b5ff)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('每日签到',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800))),
          Text('连续 $streak 天', style: const TextStyle(color: Colors.white70)),
        ]),
        const SizedBox(height: 10),
        Text('我：${checked ? '已签到' : '未签到'}    对方：${partner ? '已签到' : '未签到'}',
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),
        Text(
            rewarded
                ? '双方已签到，今日已增加10经验${bonus > 0 ? '，连续7天额外+30经验' : ''}'
                : owner && partner
                    ? '今日已完成签到'
                    : '今日签到状态',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: checked ? null : onCheckin,
            child: Text(checked ? '今日已签到' : '签到')),
      ]),
    );
  }
}

class _CpCastleCard extends StatelessWidget {
  const _CpCastleCard({required this.experience});
  final int experience;

  @override
  Widget build(BuildContext context) {
    final safe = experience < 0 ? 0 : experience;
    var index = 0;
    const thresholds = [0, 100, 300, 650, 1200, 2000, 3100, 4600, 6600, 9200];
    for (var i = 0; i < thresholds.length; i++) {
      if (safe >= thresholds[i]) index = i;
    }
    return Image.asset(
      'assets/cp_levels/level_${index + 1}.png',
      width: double.infinity,
      height: 230,
      fit: BoxFit.contain,
    );
  }
}

class _CpSpaceLevelCard extends StatelessWidget {
  const _CpSpaceLevelCard({this.experience = 0});
  final int experience;
  static const thresholds = [
    0,
    100,
    300,
    650,
    1200,
    2000,
    3100,
    4600,
    6600,
    9200
  ];
  static const titles = [
    '初遇',
    '心动',
    '暧昧',
    '热恋',
    '默契',
    '守护',
    '相知',
    '挚爱',
    '永恒',
    '传奇'
  ];
  @override
  Widget build(BuildContext context) {
    final safe = experience < 0 ? 0 : experience;
    var index = 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (safe >= thresholds[i]) index = i;
    }
    final isMax = index == thresholds.length - 1;
    final start = thresholds[index];
    final required = isMax ? 0 : thresholds[index + 1] - start;
    final current = safe - start;
    final progress = isMax ? 1.0 : (current / required).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
          color: const Color(0x443B2184),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x887E5CC9))),
      child: Row(children: [
        const SizedBox(width: 10),
        Text('Lv.${index + 1} · ${titles[index]}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0x553B2184),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xffd3b5ff))))),
        const SizedBox(width: 8),
        Text(isMax ? '$safe/9200+' : '$current/$required',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

class _SpaceDetailEmptyCard extends StatelessWidget {
  const _SpaceDetailEmptyCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0x443B2184),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x887E5CC9)),
        ),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('暂无内容', style: TextStyle(color: Colors.white60)),
          ],
        ),
      );
}

class _HeartPulse extends StatelessWidget {
  const _HeartPulse();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.favorite, color: Color(0xFFFF9DD8), size: 34);
}

class _SpaceAvatar extends StatelessWidget {
  const _SpaceAvatar(
      {required this.label,
      this.url,
      this.localPath,
      this.isEmpty = false,
      this.onTap});

  final String label;
  final String? url;
  final String? localPath;
  final bool isEmpty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE4C7FF), width: 2),
              ),
              child: ClipOval(
                child: localPath != null && localPath!.isNotEmpty
                    ? Image.file(File(localPath!), fit: BoxFit.cover)
                    : url != null && url!.isNotEmpty
                        ? _PermanentCachedImage(
                            url: url!, width: 72, height: 72, fit: BoxFit.cover)
                        : ColoredBox(
                            color: const Color(0xFF24164E),
                            child: Icon(isEmpty ? Icons.add : Icons.person,
                                color: Colors.white70, size: 32),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ],
      );
}

class CpApplyPage extends StatefulWidget {
  const CpApplyPage({super.key, required this.ownerId});
  final int ownerId;
  @override
  State<CpApplyPage> createState() => _CpApplyPageState();
}

class _CpApplyPageState extends State<CpApplyPage> {
  bool busy = false;
  Future<void> _apply() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('friend.auth.token') ??
          '';
      await DDPostService().applyCpSpace(token, widget.ownerId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('申请CP空间')),
      body: Center(
          child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.card_giftcard,
                        size: 56, color: Color(0xFF8E52D8)),
                    const SizedBox(height: 12),
                    const Text('送出戒指，申请加入CP空间',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('戒指 · 999金币'),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: busy ? null : _apply,
                        child: Text(busy ? '提交中…' : '送出戒指并申请')),
                  ])))));
}

class CpApplicationListPage extends StatefulWidget {
  const CpApplicationListPage({super.key});
  @override
  State<CpApplicationListPage> createState() => _CpApplicationListPageState();
}

class _CpApplicationListPageState extends State<CpApplicationListPage> {
  List<Map<String, dynamic>> rows = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = (await SharedPreferences.getInstance())
              .getString('friend.auth.token') ??
          '';
      final r = await DDPostService().fetchCpApplications(t);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  Future<void> _act(Map<String, dynamic> row, bool accept) async {
    final t = (await SharedPreferences.getInstance())
            .getString('friend.auth.token') ??
        '';
    try {
      if (accept)
        await DDPostService().acceptCpApplication(t, int.parse('${row['id']}'));
      else
        await DDPostService().rejectCpApplication(t, int.parse('${row['id']}'));
      await _load();
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('申请列表')),
      body: rows.isEmpty
          ? const Center(child: Text('暂无申请'))
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                    leading: CircleAvatar(
                        backgroundImage: (r['avatar'] ?? '').toString().isEmpty
                            ? null
                            : NetworkImage('${r['avatar']}'),
                        child: (r['avatar'] ?? '').toString().isEmpty
                            ? const Icon(Icons.person)
                            : null),
                    title: Text('${r['nickname'] ?? '用户'}'),
                    subtitle: const Text('戒指 · 999金币'),
                    trailing: Wrap(spacing: 4, children: [
                      TextButton(
                          onPressed: () => _act(r, false),
                          child: const Text('拒绝')),
                      FilledButton(
                          onPressed: () => _act(r, true),
                          child: const Text('同意'))
                    ]));
              }));
}

class _FriendSlotCard extends StatelessWidget {
  const _FriendSlotCard({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x885A36B7), Color(0x44301972)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9C73E9)),
        ),
        child: Column(
          children: [
            const Text('朋友空间',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Icon(Icons.add_circle_outline,
                color: Colors.white70, size: 36),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onInvite,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD5B8FF)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
              child: const Text('邀请'),
            ),
          ],
        ),
      );
}

class ProfileChannelPage extends StatefulWidget {
  const ProfileChannelPage({super.key, this.userId, this.isOwner = true});
  final int? userId;
  final bool isOwner;
  @override
  State<ProfileChannelPage> createState() => _ProfileChannelPageState();
}

class _ProfileChannelPageState extends State<ProfileChannelPage> {
  final service = DDPostService();
  List<Map<String, dynamic>> rooms = const [];
  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('friend.auth.token') ??
          '';
      final response = await service.fetchVoiceRooms(token);
      final targetId = widget.userId ??
          int.tryParse((await SharedPreferences.getInstance())
                  .getString('friend.auth.userId') ??
              '');
      final owned = targetId == null
          ? response
          : response
              .where((room) =>
                  '${room['ownerUserId'] ?? room['owner_user_id']}' ==
                  '$targetId')
              .toList();
      if (mounted) setState(() => rooms = owned.take(1).toList());
    } catch (e) {
      if (mounted) setState(() => loadError = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final controller = TextEditingController(text: '语音频道');
    String? category;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('创建语音频道'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                    labelText: '房间名字', hintText: '请输入房间名字'),
              ),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: '频道分类（必选）'),
                items: const ['闲聊', '点歌', '开黑', '睡眠', '树洞']
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setDialogState(() => category = value),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消')),
            FilledButton(
              onPressed: category == null
                  ? null
                  : () => Navigator.pop(dialogContext, {
                        'title': controller.text.trim(),
                        'category': category!,
                      }),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    final title = result?['title']?.trim() ?? '';
    if (title.isEmpty) return;
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('friend.auth.token') ??
          '';
      final selectedCategory = result?['category'];
      if (selectedCategory == null || selectedCategory.isEmpty) return;
      final data = await service.createVoiceRoom(token,
          title: title, category: selectedCategory);
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => VoiceRoomPage(room: data)));
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF160D3B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('频道'),
          actions: const [],
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5E36B5), Color(0xFF160D3B)],
            ),
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : loadError != null && rooms.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('频道加载失败：$loadError'),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('重试'))
                    ]))
                  : rooms.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(20, 116, 20, 32),
                          children: [
                            if (widget.isOwner)
                              FilledButton.icon(
                                onPressed: _create,
                                icon: const Icon(Icons.add),
                                label: const Text('创建频道'),
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52)),
                              ),
                            if (widget.isOwner) const SizedBox(height: 28),
                            const _ChannelProfileCard(),
                          ],
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 116, 16, 28),
                            children: [
                              _ChannelSummaryCard(
                                  room: rooms.first,
                                  onEnter: () async {
                                    final token =
                                        (await SharedPreferences.getInstance())
                                                .getString(
                                                    'friend.auth.token') ??
                                            '';
                                    final joined = await service.joinVoiceRoom(
                                        token, '${rooms.first['id']}');
                                    if (context.mounted)
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  VoiceRoomPage(room: joined)));
                                  }),
                              const SizedBox(height: 16),
                              _ChannelProfileCard(room: rooms.first),
                            ],
                          ),
                        ),
        ),
      );
}

class _ChannelSummaryCard extends StatelessWidget {
  const _ChannelSummaryCard({required this.room, required this.onEnter});
  final Map<String, dynamic> room;
  final VoidCallback onEnter;
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xff241936),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const CircleAvatar(radius: 30, child: Icon(Icons.mic)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${room['title'] ?? '语音频道'}',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  Text('创建者：${room['nickname'] ?? '暂无资料'}',
                      style: const TextStyle(color: Colors.white60)),
                ])),
            FilledButton(onPressed: onEnter, child: const Text('进入频道')),
          ]),
        ),
      );
}

class _ChannelProfileCard extends StatelessWidget {
  const _ChannelProfileCard({this.room});
  final Map<String, dynamic>? room;

  String _value(String key) {
    if (room == null) return '暂无资料';
    final raw = room![key];
    return raw == null || raw.toString().trim().isEmpty
        ? '暂无资料'
        : raw.toString();
  }

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xff241936),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('频道资料',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              _ChannelInfoRow(
                  icon: Icons.workspace_premium,
                  title: '频道等级',
                  value: _value('level')),
              const Divider(height: 24),
              _ChannelInfoRow(
                  icon: Icons.auto_awesome,
                  title: '频道特权',
                  value: _value('privileges')),
              const Divider(height: 24),
              _ChannelInfoRow(
                  icon: Icons.groups_rounded,
                  title: '在线人数',
                  value: _value('online_count')),
            ],
          ),
        ),
      );
}

class _ChannelInfoRow extends StatelessWidget {
  const _ChannelInfoRow(
      {required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: const Color(0xffc9a7ff)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70))),
        ],
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
      3,
      (tab) => FeedShellTab(
        title: tab == 0
            ? '我的动态'
            : tab == 1
                ? '收藏'
                : '私密动态',
        icon: tab == 0
            ? TIcons.highlight_1
            : tab == 1
                ? TIcons.bookmark
                : TIcons.lock_on,
        selectedIcon: tab == 0
            ? TIcons.highlight_1_filled
            : tab == 1
                ? TIcons.bookmark_filled
                : TIcons.lock_on,
        cacheKey: 'dd.profile.my.v2.tab.$tab',
        fetch: (offset) async {
          final token = await _token();
          final loaded = tab == 0
              ? await service.fetchMyPosts(token, offset: offset)
              : tab == 1
                  ? await service.fetchFavoritedPosts(token, offset: offset)
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('状态设置',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PresenceCircleSwitch(
                        label: '在线',
                        value: !_stealth,
                        onChanged: _presenceUpdating
                            ? null
                            : (value) => unawaited(_setPresenceMode(
                                value ? 'online' : 'stealth', setSheetState))),
                    _PresenceCircleSwitch(
                        label: _matching ? '想聊' : '沉默',
                        value: _matching,
                        onChanged: (value) {
                          final before = _matching;
                          setSheetState(() => _matching = value);
                          unawaited(_savePreferences(
                              matchingEnabled: value,
                              onFailure: () =>
                                  setSheetState(() => _matching = before)));
                        }),
                    _PresenceCircleSwitch(
                        label: '雷达',
                        value: _smartBlock,
                        onChanged: (value) {
                          final before = _smartBlock;
                          setSheetState(() => _smartBlock = value);
                          unawaited(_savePreferences(
                              smartBlock: value,
                              onFailure: () =>
                                  setSheetState(() => _smartBlock = before)));
                        }),
                    _PresenceCircleSwitch(
                        label: '防护',
                        value: _antiHarassment,
                        onChanged: (value) {
                          final before = _antiHarassment;
                          setSheetState(() => _antiHarassment = value);
                          unawaited(_savePreferences(
                              antiHarassment: value,
                              onFailure: () => setSheetState(
                                  () => _antiHarassment = before)));
                        }),
                  ],
                ),
              ],
            ),
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
      if (mounted) _showTopNotice(context, Text('$e'));
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
      if (mounted) _showTopNotice(context, Text('$e'));
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

  int? _profileUserId() {
    final value = profile?['id'] ?? profile?['userId'] ?? _currentUserId;
    return value is int ? value : int.tryParse('$value');
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
                          child: const SizedBox.shrink(),
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
                                                        height: 1.0,
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
                                            Row(
                                              children: [
                                                Text(
                                                  'ID：${p?['id'] ?? p?['userId'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    height: 1.0,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: .65),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: '复制ID',
                                                  icon: const Icon(TIcons.copy,
                                                      size: 16),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints
                                                          .tightFor(
                                                          width: 16,
                                                          height: 16),
                                                  onPressed: () async {
                                                    final id =
                                                        '${p?['id'] ?? p?['userId'] ?? ''}';
                                                    if (id.trim().isEmpty)
                                                      return;
                                                    await Clipboard.setData(
                                                        ClipboardData(
                                                            text: id));
                                                    if (context.mounted)
                                                      _showTopNotice(context,
                                                          const Text('ID已复制'));
                                                  },
                                                ),
                                                const SizedBox(width: 6),
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
                                              padding: const EdgeInsets.only(
                                                  top: 0, bottom: 14),
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
                                                    label: '访客',
                                                    value: _formatCount(
                                                        p?['visitors']),
                                                    onTap: () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              const _UserRelationListPage(
                                                                  relation:
                                                                      'history',
                                                                  title: '访客')),
                                                    ),
                                                  )),
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
                                            const EdgeInsets.only(bottom: 18),
                                        child: Column(
                                          children: [
                                            GestureDetector(
                                              child: SizedBox(
                                                width: 104,
                                                height: 104,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Container(
                                                      width: 90,
                                                      height: 90,
                                                      clipBehavior:
                                                          Clip.antiAlias,
                                                      decoration:
                                                          const BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle),
                                                      child:
                                                          _avatarReviewRejected
                                                              ? const ColoredBox(
                                                                  color: Colors
                                                                      .black12,
                                                                  child: Center(
                                                                      child: Text(
                                                                          '图片涉嫌违规',
                                                                          textAlign: TextAlign
                                                                              .center,
                                                                          style: TextStyle(
                                                                              fontSize: 11,
                                                                              color: Colors.black54))),
                                                                )
                                                              : _avatarLocalPath !=
                                                                      null
                                                                  ? Image.file(
                                                                      File(
                                                                          _avatarLocalPath!),
                                                                      fit: BoxFit
                                                                          .cover)
                                                                  : _avatarUrl == null ||
                                                                          _avatarUrl!
                                                                              .isEmpty
                                                                      ? const ColoredBox(
                                                                          color: Colors
                                                                              .black12,
                                                                          child: Icon(Icons.person,
                                                                              size:
                                                                                  40))
                                                                      : _PermanentCachedImage(
                                                                          url:
                                                                              _avatarUrl!,
                                                                          width:
                                                                              90,
                                                                          height:
                                                                              90,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                          placeholder: const ColoredBox(
                                                                              color: Colors.black12,
                                                                              child: Icon(Icons.person, size: 40))),
                                                    ),
                                                    Container(
                                                      width: 96,
                                                      height: 96,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: p?['gender'] ==
                                                                  '女'
                                                              ? const Color(
                                                                  0xFFFF82B7)
                                                              : const Color(
                                                                  0xFF4E9BFF),
                                                          width: 3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                                  const SizedBox(height: 18),
                                  const SizedBox(height: 12),
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
                                                          GiftExhibitionPage(
                                                            userId:
                                                                _profileUserId(),
                                                            userName:
                                                                '${profile?['nickname'] ?? '我的'}',
                                                          ))))),
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
                                                  '${profile?['nickname'] ?? '我'}',
                                              avatarUrl: _avatarUrl,
                                              avatarLocalPath: _avatarLocalPath,
                                              userId: _currentUserId,
                                            ),
                                          ),
                                        ),
                                      )),
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

class _PresenceCircleSwitch extends StatelessWidget {
  const _PresenceCircleSwitch(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                  color: value
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Icon(value ? Icons.check_rounded : Icons.remove_rounded,
                color: value
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      );
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
