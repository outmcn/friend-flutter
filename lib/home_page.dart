part of 'main.dart';

class _HomeCategoryButton extends StatelessWidget {
  const _HomeCategoryButton(
      {required this.label, required this.onTap, this.active = false});
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: active ? 22 : 20,
                        fontWeight: FontWeight.w800,
                        color: active ? null : Theme.of(context).hintColor)),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: active ? 24 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(99)),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HomeChannelPlazaPage extends StatefulWidget {
  const _HomeChannelPlazaPage();
  @override
  State<_HomeChannelPlazaPage> createState() => _HomeChannelPlazaPageState();
}

class _HomeChannelPlazaPageState extends State<_HomeChannelPlazaPage> {
  final service = DDPostService();
  List<Map<String, dynamic>> rooms = const [];
  bool loading = true;
  String? error;
  String selectedCategory = '闲聊';
  static const channelCategories = ['闲聊', '点歌', '开黑', '睡眠', '树洞'];

  String _roomCategory(Map<String, dynamic> room) =>
      '${room['category'] ?? room['category_name'] ?? room['categoryName'] ?? ''}';

  bool _entering = false;

  Future<void> _enterChannel(Map<String, dynamic> room) async {
    if (_entering) return;
    setState(() => _entering = true);
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('friend.auth.token') ??
          '';
      final joined = await service.joinVoiceRoom(token, '${room['id']}');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VoiceRoomPage(room: joined)),
      );
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('进入频道失败：$e'));
    } finally {
      if (mounted) setState(() => _entering = false);
    }
  }

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
      final data = await service.fetchVoiceRooms(token);
      if (mounted) setState(() => rooms = data);
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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor: Color(0xff160d3b),
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text('频道加载失败：$error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: channelCategories.map((category) {
                                    final active = selectedCategory == category;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(category),
                                        selected: active,
                                        showCheckmark: false,
                                        onSelected: (_) => setState(
                                            () => selectedCategory = category),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Builder(builder: (context) {
                            final filtered = rooms
                                .where((room) =>
                                    _roomCategory(room) == selectedCategory)
                                .toList();
                            return filtered.isEmpty
                                ? ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: [
                                      const SizedBox(height: 120),
                                      Center(
                                          child: Text(rooms.isEmpty
                                              ? '暂无频道'
                                              : '该分类暂无频道')),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 28),
                                    itemCount: filtered.length,
                                    itemBuilder: (_, index) {
                                      final room = filtered[index];
                                      return _ChannelSummaryCard(
                                        room: room,
                                        onEnter: () => _enterChannel(room),
                                      );
                                    },
                                  );
                          }),
                        ),
                      ],
                    ),
                  ),
      ));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedCategory = 0;

  void _unavailable(BuildContext context, String feature) {
    _showTopNotice(context, Text('$feature功能暂未开放'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leadingWidth: 230,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HomeCategoryButton(
                label: '推荐',
                active: selectedCategory == 0,
                onTap: () => setState(() => selectedCategory = 0),
              ),
              _HomeCategoryButton(
                label: '陪玩',
                active: selectedCategory == 1,
                onTap: () => setState(() => selectedCategory = 1),
              ),
              _HomeCategoryButton(
                label: '频道',
                active: selectedCategory == 2,
                onTap: () => setState(() => selectedCategory = 2),
              ),
            ],
          ),
          title: const SizedBox.shrink(),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: selectedCategory == 1
            ? const GameCompanionPlazaPage()
            : selectedCategory == 2
                ? const _HomeChannelPlazaPage()
                : SafeArea(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        SizedBox(
                          height: 140,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 11,
                                child: _HomeFolderCard(
                                  icon: Icons.auto_awesome,
                                  title: '缘分匹配',
                                  subtitle: '遇见聊得来的人',
                                  meta: 'FATE',
                                  tabLabel: '',
                                  colors: const [
                                    Color(0xffff6b9d),
                                    Color(0xffa855f7)
                                  ],
                                  tabAlignment: Alignment.topRight,
                                  borderRadius: BorderRadius.circular(28),
                                  height: 140,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FateMatchPage(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 9,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: _HomeFolderCard(
                                        icon: Icons.mic_none,
                                        title: '语音匹配',
                                        subtitle: '遇见懂你的人',
                                        meta: '',
                                        tabLabel: '',
                                        colors: const [
                                          Color(0xff6e4fe0),
                                          Color(0xffd46bc8)
                                        ],
                                        tabAlignment: Alignment.topLeft,
                                        borderRadius: BorderRadius.circular(24),
                                        height: 63,
                                        compactText: true,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const VoiceMatchPage(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: _HomeNormalCard(
                                        icon: Icons.sports_esports_outlined,
                                        title: '心动雷达',
                                        colors: const [
                                          Color(0xffff9a5a),
                                          Color(0xffff5f8f),
                                        ],
                                        height: 63,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const HeartRadarPage(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _HomeCartoonCard(
                          icon: Icons.menu_book_outlined,
                          title: '视频狼人杀',
                          subtitle: '黑 夜 降 临 · 谁 是 狼 人',
                          badge: 'GO',
                          colors: const [Color(0xff352b62), Color(0xff8b4e9f)],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WerewolfGamePage()),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _HomeCartoonCard(
                                icon: Icons.groups_2_outlined,
                                title: '真人带本',
                                subtitle: '52局等待中',
                                badge: 'LIVE',
                                colors: const [
                                  Color(0xff5a315b),
                                  Color(0xffd46b82)
                                ],
                                onTap: () => _unavailable(context, '真人带本'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _HomeCartoonCard(
                                icon: Icons.smart_toy_outlined,
                                title: 'AI剧本杀',
                                subtitle: '随时开局',
                                badge: 'AI',
                                colors: const [
                                  Color(0xff164b68),
                                  Color(0xff3c9fa9)
                                ],
                                onTap: () => _unavailable(context, 'AI剧本杀'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _HomeCartoonCard(
                                icon: Icons.mic_external_on_outlined,
                                title: '嗨歌抢唱',
                                subtitle: '轮到你开唱',
                                badge: 'NEW',
                                colors: const [
                                  Color(0xff713b42),
                                  Color(0xffe38d57)
                                ],
                                onTap: () => _unavailable(context, '嗨歌抢唱'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _HomeCartoonCard(
                                icon: Icons.casino_outlined,
                                title: '骗子酒馆',
                                subtitle: '猜猜谁在说谎',
                                badge: 'NEW',
                                colors: const [
                                  Color(0xff254d72),
                                  Color(0xff63a5c5)
                                ],
                                onTap: () => _unavailable(context, '骗子酒馆'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _HomeCartoonCard(
                          icon: Icons.flight_takeoff_outlined,
                          title: '飞行棋',
                          subtitle: '轻松玩一局',
                          badge: 'PLAY',
                          colors: const [Color(0xff2c5d3a), Color(0xff83bc67)],
                          onTap: () => _unavailable(context, '飞行棋'),
                        ),
                      ],
                    ),
                  ),
      );
}
