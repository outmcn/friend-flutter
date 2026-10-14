part of 'main.dart';
// ignore_for_file: unused_element

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

class _DeltaBanner extends StatelessWidget {
  const _DeltaBanner({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 0, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xff263b59), Color(0xff9b4c48)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
}

class _DeltaCompanionPageState extends State<DeltaCompanionPage> {
  int tab = 0;
  int playbookTab = 0;
  static const categories = <String>[
    '体验单',
    '保底单',
    '趣味单',
    '陪玩单',
    '转盘单',
    '大红单',
    '礼物单',
    '任务单',
  ];

  static const data = <Map<String, dynamic>>[
    {
      'title': '体验单',
      'badge': '新手首选',
      'desc': '低门槛尝鲜，用一顿奶茶钱感受三角洲护航的真实体验。适合第一次点陪玩的玩家，先试一单再决定长期合作。',
      'items': [
        [
          '🆕',
          '新手首单体验',
          '1 局机密大坝带打，打手全程语音指挥，帮你熟悉地图和撤离路线。',
          '9.9',
          '/局',
          ['机密', '大坝', '语音指挥']
        ],
        [
          '👑',
          '魔王护体验局',
          '高 KD 魔王级打手带 1 局机密，体验清图节奏与高价值物资路线。',
          '88',
          '/局',
          ['魔王护', '机密', '清图']
        ],
        [
          '🎯',
          '1 元试玩',
          '极低价体验 1 局普通图，感受陪玩节奏与沟通风格，不满意可换人。',
          '1',
          '/局',
          ['普通图', '换人保障']
        ],
        [
          '📚',
          '免费教学局',
          '打手带 1 局教学，讲解出生点选择、物资分布与基础架枪点位。',
          '免费',
          '',
          ['教学', '点位讲解']
        ],
        [
          '👫',
          '双人陪玩体验',
          '两位打手带队，一个主攻一个辅助，体验双护配合的压制力。',
          '158',
          '/局',
          ['双护', '配合']
        ],
      ],
    },
    {
      'title': '保底单',
      'badge': '稳定收益',
      'desc': '以物资价值为结算标准，打手承诺带出指定价值的物品，达不到保底不结单或补局。适合想稳定积累哈夫币的玩家。',
      'items': [
        [
          '🛡️',
          '128 保 1000w',
          '机密图带队，保底带出 1000 万哈夫币物资，未达标免费补局。',
          '128',
          '/单',
          ['机密', '1000w', '补局']
        ],
        [
          '🛡️',
          '588 保 2088w',
          '绝密图高阶护航，保底 2088 万，打手承担战损。',
          '588',
          '/单',
          ['绝密', '2088w', '包战损']
        ],
        [
          '🛡️',
          '3188 保 1.2 亿',
          '一命五图挑战模式，保底 1.2 亿，适合追求高收益的老板。',
          '3188',
          '/单',
          ['一命多图', '1.2亿', '挑战']
        ],
        [
          '🛡️',
          '888 保 3888w',
          '进阶保底方案，绝密图为主，打手自备钥匙卡。',
          '888',
          '/单',
          ['绝密', '钥匙卡', '进阶']
        ],
        [
          '🛡️',
          '自定义保底',
          '按你指定的目标金额定制保底方案，客服 1v1 报价。',
          '定制',
          '',
          ['定制', '1v1报价']
        ],
      ],
    },
    {
      'title': '趣味单',
      'badge': '情绪拉满',
      'desc': '以整活、剧情、人设为核心的娱乐向玩法，胜负不重要，过程开心最重要。适合想放松心情或和朋友一起找乐子的玩家。',
      'items': [
        [
          '🎭',
          '人设陪打',
          '打手全程保持指定人设，边打边演不崩人设。',
          '68',
          '/局',
          ['人设', '剧情', '整活']
        ],
        [
          '💕',
          '恋爱攻略限定',
          '投喂道具积攒好感值，目标达成触发特殊剧情。',
          '128',
          '/局',
          ['恋爱', '好感值', '剧情']
        ],
        [
          '💔',
          '拆散鹊桥计划',
          '猎杀地图中的 CP 组合，完成指定击杀任务拿保底。',
          '98',
          '/局',
          ['猎杀', 'CP', 'BUFF']
        ],
        [
          '😂',
          '整活单',
          '使用奇葩配装/打法，主打节目效果。',
          '58',
          '/局',
          ['整活', '节目效果']
        ],
        [
          '🎬',
          '剧情互动单',
          '围绕你设定的剧情线展开，打手配合演出。',
          '158',
          '/局',
          ['剧情', '互动', '定制']
        ],
      ],
    },
    {
      'title': '陪玩单',
      'badge': '组队开黑',
      'desc': '纯粹找人一起玩游戏，打手负责沟通、报点、配合，不承诺保底收益。',
      'items': [
        [
          '🎧',
          '标准陪玩',
          '1 位打手全程语音陪伴，报点、架枪、掩护撤离。',
          '38',
          '/小时',
          ['语音', '报点', '组队']
        ],
        [
          '👫',
          '双人陪玩',
          '两位打手组队带打，分工协作。',
          '68',
          '/小时',
          ['双护', '协作']
        ],
        [
          '🎤',
          '声优陪玩',
          '声线优质的陪玩打手，提供舒适语音陪伴。',
          '58',
          '/小时',
          ['声优', '语音陪伴']
        ],
        [
          '🌙',
          '通宵陪伴局',
          '22:00-06:00 时段陪玩，适合夜猫子老板组队。',
          '268',
          '/晚',
          ['通宵', '夜场']
        ],
        [
          '👩',
          '女陪专场',
          '女性陪玩打手，风格温柔，适合轻松沟通。',
          '48',
          '/小时',
          ['女陪', '轻松']
        ],
      ],
    },
    {
      'title': '转盘单',
      'badge': '随机惊喜',
      'desc': '转盘决定地图、装备或打法，每局结果不可预测。',
      'items': [
        [
          '🎡',
          '地图转盘',
          '转盘决定本局地图，打手全程配合。',
          '58',
          '/局',
          ['随机地图', '转盘']
        ],
        [
          '🎰',
          '装备转盘',
          '转盘决定本局配装等级。',
          '88',
          '/局',
          ['随机装备', '刺激']
        ],
        [
          '🏆',
          '赏金转盘',
          '转盘决定本局目标，超额完成有奖励。',
          '128',
          '/局',
          ['赏金', '红包奖励']
        ],
        [
          '🎲',
          '双转盘组合',
          '地图和装备双转盘同时开。',
          '158',
          '/局',
          ['双转盘', '节目效果']
        ],
      ],
    },
    {
      'title': '大红单',
      'badge': '高价值',
      'desc': '以带出红色品质物品为目标的高价值玩法。',
      'items': [
        [
          '🔴',
          '大红保底单',
          '目标带出至少 1 件大红，未达成免费补局。',
          '168',
          '/单',
          ['大红', '保底', '归老板']
        ],
        [
          '🔴',
          '红卡房卡单',
          '主攻高价值房卡点位。',
          '228',
          '/单',
          ['房卡', '大红']
        ],
        [
          '🔴',
          '多红挑战单',
          '一局内尽量带出多件大红。',
          '388',
          '/单',
          ['多红', '分成']
        ],
        [
          '🔴',
          '大红接单模式',
          '围绕红点搜刮，路线经过优化。',
          '98',
          '/局',
          ['红点路线', '效率']
        ],
      ],
    },
    {
      'title': '礼物单',
      'badge': '互动打赏',
      'desc': '下单后向打手赠送虚拟礼物，获得额外服务或返利。',
      'items': [
        [
          '🎁',
          '基础礼物单',
          '赠送基础礼物，打手额外陪打 1 局普通图。',
          '18',
          '/次',
          ['基础礼物', '加局']
        ],
        [
          '🎁',
          '进阶礼物单',
          '赠送进阶礼物，提供 1 局机密图护航。',
          '58',
          '/次',
          ['进阶礼物', '机密']
        ],
        [
          '🎁',
          '豪华礼物单',
          '赠送豪华礼物，提供定制服务方案。',
          '188',
          '/次',
          ['豪华', '定制', '优先接单']
        ],
        [
          '🎁',
          '礼物返利单',
          '按礼物价值比例返利，具体比例咨询客服。',
          '按比例',
          '',
          ['返利', '红包']
        ],
      ],
    },
    {
      'title': '任务单',
      'badge': '代肝代办',
      'desc': '帮老板完成游戏内任务、通行证和赛季目标。',
      'items': [
        [
          '📋',
          '每日任务代肝',
          '完成当日日常任务，含活跃度奖励。',
          '15',
          '/天',
          ['日常', '活跃度']
        ],
        [
          '📋',
          '周任务代肝',
          '完成本周全部周常任务，含通行证经验。',
          '68',
          '/周',
          ['周常', '通行证']
        ],
        [
          '📋',
          '赛季通行证代肝',
          '包赛季通行证满级，支持进度查询。',
          '328',
          '/赛季',
          ['赛季', '满级', '进度查询']
        ],
        [
          '📋',
          '干员任务代做',
          '完成指定干员解锁任务与专属挑战。',
          '定制',
          '',
          ['干员任务', '定制']
        ],
        [
          '📋',
          '跑刀单',
          '纯跑刀积累哈夫币，可指定地图与目标金额。',
          '40',
          '/1000w',
          ['跑刀', '包战损', '可监督']
        ],
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tab == 2 ? const Color(0xff0f0f11) : null,
      appBar: AppBar(title: const Text('三角洲 - 端游')),
      body: Column(
        children: [
          _deltaBanners(),
          _topTabs(),
          Expanded(child: tab == 2 ? _playbookBody() : _topTabBody()),
        ],
      ),
    );
  }

  Widget _deltaBanners() => SizedBox(
        height: 78,
        child: PageView(
          controller: PageController(viewportFraction: .92),
          children: const [
            _DeltaBanner(title: '百强大神推荐榜', subtitle: '服务贴心 · 好评优选'),
            _DeltaBanner(title: '三角洲巅峰护航', subtitle: '高 KD 打手 · 快速接单'),
            _DeltaBanner(title: '新手体验专区', subtitle: '低门槛尝鲜 · 轻松开局'),
          ],
        ),
      );

  Widget _topTabs() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          children: List.generate(3, (index) {
            final selected = tab == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => tab = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xffff6a1f)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(['明星陪玩', '魔王技术', '玩法合集'][index],
                      style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                ),
              ),
            );
          }),
        ),
      );

  Widget _topTabBody() {
    if (tab == 0) {
      return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
          children: const [
            _DeltaCompanionCard(
                name: '若尘',
                price: '80',
                tags: ['百强大神榜TOP10', '金牌娱乐', '三角洲巅峰', '秒接单']),
            _DeltaCompanionCard(
                name: '圆子ovo冲冲冲', price: '64', tags: ['金牌娱乐', '三角洲巅峰', '秒接单']),
            _DeltaCompanionCard(
                name: '董可爱呀', price: '88', tags: ['魔王技术', '金牌娱乐', '三角洲巅峰']),
          ]);
    }
    if (tab == 1) {
      return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
          children: const [
            _DeltaCompanionCard(
                name: '魔王S大神', price: '108', tags: ['魔王S', '三角洲巅峰', '技术指导']),
            _DeltaCompanionCard(
                name: '金牌大神', price: '96', tags: ['金牌大神', '航天基地', '秒接单']),
          ]);
    }
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: const [
          Text('我的要求',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Card(
              child: ListTile(title: Text('性别'), subtitle: Text('不限 · 男 · 女'))),
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

  Widget _playbookBody() {
    final item = data[playbookTab];
    final items = (item['items'] as List).cast<List<dynamic>>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 148,
          child: ColoredBox(
            color: const Color(0xff141416),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
              children: [
                const Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 10, 18),
                    child: Text('玩法合集',
                        style: TextStyle(
                            color: Color(0xfff3f4f6),
                            fontSize: 16,
                            fontWeight: FontWeight.w700))),
                for (var i = 0; i < categories.length; i++)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _sidebarItem(i, categories[i])),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
            children: [
              Row(children: [
                Text('${item['title']}',
                    style: const TextStyle(
                        color: Color(0xfff3f4f6),
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0x23ff6a1f),
                        border: Border.all(color: const Color(0x40ff6a1f)),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${item['badge']}',
                        style: const TextStyle(
                            color: Color(0xffff6a1f),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)))
              ]),
              const SizedBox(height: 6),
              Text('${item['desc']}',
                  style: const TextStyle(
                      color: Color(0xff9ca3af), fontSize: 13, height: 1.6)),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700
                    ? 3
                    : constraints.maxWidth >= 430
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final project in items)
                    SizedBox(width: width, child: _projectCard(project))
                ]);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebarItem(int index, String label) {
    final active = playbookTab == index;
    return GestureDetector(
      onTap: () => setState(() => playbookTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active ? const Color(0x1fff6a1f) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xffff6a1f) : const Color(0xff9ca3af),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: active
                        ? const Color(0xffff6a1f)
                        : const Color(0xff9ca3af),
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _projectCard(List<dynamic> project) {
    final icon = '${project[0]}';
    final title = '${project[1]}';
    final desc = '${project[2]}';
    final price = '${project[3]}';
    final unit = '${project[4]}';
    final tags = (project[5] as List).cast<String>();
    return GestureDetector(
      onTap: () => _showProject(project),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xff1c1c1e),
          border: Border.all(color: const Color(0x14ffffff)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 10),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xfff3f4f6),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xff9ca3af), fontSize: 12, height: 1.55)),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: tags
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x0fffffff),
                            border: Border.all(color: const Color(0x14ffffff)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(tag,
                              style: const TextStyle(
                                  color: Color(0xff9ca3af), fontSize: 10)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(color: Color(0x14ffffff), height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xffff6a1f)),
                    children: [
                      TextSpan(
                          text: price,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      TextSpan(
                          text: unit,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xff9ca3af))),
                    ],
                  ),
                ),
                const Text('→',
                    style: TextStyle(color: Color(0xff9ca3af), fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProject(List<dynamic> project) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${project[1]}'),
        content: Text('${project[2]}\n\n价格：${project[3]}${project[4]}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('继续')),
        ],
      ),
    );
  }
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
                      Text('三角洲 - 端游',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Game 俱乐部')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索游戏、声音或陪玩',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          _DeltaGameEntryButton(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DeltaCompanionPage(),
              ),
            ),
          ),
        ],
      ),
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
