part of 'main.dart';

class GameCompanionPlazaPage extends StatefulWidget {
  const GameCompanionPlazaPage({super.key});
  @override
  State<GameCompanionPlazaPage> createState() => _GameCompanionPlazaPageState();
}

class DeltaCompanionPage extends StatefulWidget {
  const DeltaCompanionPage({super.key});
  @override
  State<DeltaCompanionPage> createState() => _DeltaCompanionPageState();
}

class _DeltaCompanionPageState extends State<DeltaCompanionPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('三角洲端游')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            _deltaBanner(),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                4,
                (index) {
                  final selected = tab == index;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => tab = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        ['明星陪玩', '魔王技术', '玩法合集', '一键找人'][index],
                        style: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (tab == 0)
              _starPage()
            else if (tab == 1)
              _techPage()
            else if (tab == 2)
              _orderPage()
            else
              _filterPage(),
          ],
        ),
      );

  Widget _deltaBanner() => Container(
        height: 156,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xff263b59), Color(0xff9b4c48)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('百强大神推荐榜',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('服务贴心 · 好评优选',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );

  Widget _starPage() => const Column(children: [
        _DeltaCompanionCard(
            name: '若尘',
            price: '80',
            tags: ['百强大神榜TOP10', '金牌娱乐', '三角洲巅峰', '秒接单']),
        _DeltaCompanionCard(
            name: '圆子ovo冲冲冲', price: '64', tags: ['金牌娱乐', '三角洲巅峰', '秒接单']),
        _DeltaCompanionCard(
            name: '董可爱呀', price: '88', tags: ['魔王技术', '金牌娱乐', '三角洲巅峰']),
      ]);

  Widget _techPage() => const Column(children: [
        _DeltaCompanionCard(
            name: '魔王S大神', price: '108', tags: ['魔王S', '三角洲巅峰', '技术指导']),
        _DeltaCompanionCard(
            name: '金牌大神', price: '96', tags: ['金牌大神', '航天基地', '秒接单']),
      ]);

  Widget _orderPage() =>
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('玩法合集',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('体验单')),
            Chip(label: Text('保底单')),
            Chip(label: Text('趣味单')),
            Chip(label: Text('陪玩单')),
            Chip(label: Text('转盘单')),
            Chip(label: Text('大红单')),
            Chip(label: Text('礼物单')),
            Chip(label: Text('任务单')),
          ],
        ),
      ]);

  Widget _filterPage() =>
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('我的要求',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Card(child: ListTile(title: Text('性别'), subtitle: Text('不限 · 男 · 女'))),
        Card(child: ListTile(title: Text('服务模式'), subtitle: Text('机密价'))),
        Card(child: ListTile(title: Text('游戏模式'), subtitle: Text('不限'))),
        Card(
            child: ListTile(
                title: Text('游戏地图'),
                subtitle: Text('不限 · 巴克什 · 潮汐监狱 · 航天基地 · 长弓溪谷 · 零号大坝'))),
        Card(
            child: ListTile(
                title: Text('考核等级'), subtitle: Text('不限 · 魔王S · 金牌大神'))),
        Card(child: ListTile(title: Text('是否单陪'), subtitle: Text('不限'))),
        Card(
            child: ListTile(
                title: Text('更多要求'), subtitle: Text('达到等级 ≥ 白银2 后解锁'))),
      ]);
}

class _DeltaGameEntryButton extends StatelessWidget {
  const _DeltaGameEntryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff182b49), Color(0xff8a3d45)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 34),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('三角洲端游',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('百强大神推荐榜 · 好评优选',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      );
}

class _DeltaCompanionCard extends StatelessWidget {
  const _DeltaCompanionCard({
    required this.name,
    required this.price,
    required this.tags,
  });
  final String name;
  final String price;
  final List<String> tags;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                child: Icon(Icons.person_outline, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: tags
                          .map((tag) => Chip(
                                label: Text(tag),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 4),
                    Text('$price 币 / 小时',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              FilledButton(onPressed: () {}, child: const Text('查看')),
            ],
          ),
        ),
      );
}

class CompanionProfile {
  const CompanionProfile(
      {required this.name,
      required this.game,
      required this.price,
      required this.rating,
      required this.icon,
      required this.tags,
      required this.voice});
  final String name;
  final String game;
  final String price;
  final String rating;
  final IconData icon;
  final List<String> tags;
  final String voice;
}

class _GameCompanionPlazaPageState extends State<GameCompanionPlazaPage> {
  final search = TextEditingController();
  int game = 0;
  int type = 0;
  final games = const ['王者荣耀', '英雄联盟', '和平精英', '原神', '更多'];
  final types = const ['全部', '上分陪玩', '娱乐开黑', '语音陪伴', '新手教学'];
  final companions = const [
    CompanionProfile(
        name: '小鹿',
        game: '王者荣耀',
        price: '39',
        rating: '4.9',
        icon: Icons.face_3_outlined,
        tags: ['声音好听', '国服打野', '秒回'],
        voice: '温柔声线 · 试听 16 秒'),
    CompanionProfile(
        name: '苏念',
        game: '英雄联盟',
        price: '49',
        rating: '5.0',
        icon: Icons.music_note,
        tags: ['氛围感', '可连麦', '晚间在线'],
        voice: '甜妹音 · 试听 12 秒'),
    CompanionProfile(
        name: '桃子',
        game: '和平精英',
        price: '35',
        rating: '4.8',
        icon: Icons.favorite_outline,
        tags: ['带萌新', '不压力', '情绪价值'],
        voice: '元气音 · 试听 18 秒'),
    CompanionProfile(
        name: '北辰',
        game: '原神',
        price: '45',
        rating: '4.9',
        icon: Icons.auto_awesome_outlined,
        tags: ['探索陪伴', '任务带做', '耐心'],
        voice: '治愈音 · 试听 14 秒'),
  ];
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.trim();
    final visible = companions
        .where((c) =>
            q.isEmpty ||
            c.name.contains(q) ||
            c.game.contains(q) ||
            c.tags.any((tag) => tag.contains(q)))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('陪玩广场'), actions: [
        IconButton(
            onPressed: () => _notice('陪玩订单'),
            icon: const Icon(Icons.receipt_long_outlined))
      ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            _DeltaGameEntryButton(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeltaCompanionPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _CompanionNotice(),
            const SizedBox(height: 12),
            TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    hintText: '搜索游戏、声音或陪玩', prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 13),
            _GameFilterRow(
                labels: games,
                selected: game,
                onSelected: (v) => setState(() => game = v),
                icon: Icons.sports_esports_outlined),
            const SizedBox(height: 9),
            _GameFilterRow(
                labels: types,
                selected: type,
                onSelected: (v) => setState(() => type = v)),
            const _CompanionSection(title: '今日推荐'),
            SizedBox(
                height: 208,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: companions
                        .take(3)
                        .map((c) => _CompanionRecommendCard(
                            data: c, onTap: () => _open(c)))
                        .toList())),
            const _CompanionSection(title: '在线陪玩'),
            ...visible.map((c) => _CompanionListCard(
                data: c, onTap: () => _open(c), onOrder: _showFakeOrderDialog)),
          ]),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                  onPressed: () => _notice('发布陪玩需求'),
                  icon: const Icon(Icons.add),
                  label: const Text('发布陪玩需求')))),
    );
  }

  void _open(CompanionProfile c) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => CompanionProfilePage(data: c)));
  Future<void> _showFakeOrderDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('胡进正在伪装，请稍后……'),
        content: const Text('当前进度：正在插入变声器'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _notice(String feature) {}
}
