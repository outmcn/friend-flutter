part of 'main.dart';

class CompanionProfilePage extends StatelessWidget {
  const CompanionProfilePage({super.key, required this.data});
  final CompanionProfile data;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                Container(
                  height: 230,
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xff4a2a6b), Color(0xffe05ca8)]),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white)),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                              radius: 40, child: Icon(data.icon, size: 38)),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -7,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text('Lv68',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                  child: Text(data.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800))),
                              const SizedBox(width: 4),
                              const Icon(TIcons.verified_filled,
                                  color: Colors.lightBlueAccent, size: 17),
                              const SizedBox(width: 6),
                              const _OnlineDot(),
                              const SizedBox(width: 4),
                              const Text('秒接单',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ]),
                            const SizedBox(height: 6),
                            Text('♂ 27 · ${data.game}',
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz,
                              color: Colors.white)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('首局9折',
                            style: TextStyle(color: Colors.orange)),
                        const SizedBox(width: 16),
                        Text('${data.price}币 /小时',
                            style: const TextStyle(
                                fontSize: 20,
                                color: Colors.orange,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        const Text('40币/小时',
                            style: TextStyle(
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough)),
                        const Spacer(),
                        const Text('可叠加 5局9折', style: TextStyle(fontSize: 11)),
                      ]),
                      const Divider(height: 28),
                      const _DetailServiceRow(
                          icon: TIcons.search,
                          title: '官方考核',
                          subtitle: '官方考核技术认证 | 退款免举证'),
                      const _DetailServiceRow(
                          icon: TIcons.gamepad,
                          title: '娱乐大神',
                          subtitle: '四套四弹起 | 全图物资优先老板不私藏'),
                      const _DetailServiceRow(
                          icon: TIcons.shield_error,
                          title: '订单保障',
                          subtitle: '差必退 | 假必赔 | 追缴包赔'),
                      const _CompanionSection(title: '游戏技能'),
                      Text(
                          '时长2000h 机密KD2 绝密KD1.8 全赛季巅峰 东北幽默男\n枪法意识在线 摸红圣手 熟悉各种地图 各种英雄'),
                      const SizedBox(height: 10),
                      const _CompactTag(text: '三角洲巅峰'),
                      const SizedBox(height: 12),
                      const _DetailInfoRow(label: '可1陪2', value: '是'),
                      const _DetailInfoRow(label: '擅长地图', value: '零号大坝 航天基地'),
                      const _DetailInfoRow(label: '游戏模式', value: '机密 绝密'),
                      const _CompanionSection(title: '近期表现'),
                      const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _GameProfileStat(value: '10', label: '近期局数'),
                            _GameProfileStat(value: '1.50', label: '平均击杀'),
                            _GameProfileStat(value: '30.00%', label: '撤离率'),
                          ]),
                      const SizedBox(height: 14),
                      Container(
                          height: 150,
                          decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(14)),
                          child:
                              const Center(child: Icon(Icons.image, size: 48))),
                      const _CompanionSection(title: '用户评价'),
                      const _ReviewSummary(),
                      const SizedBox(height: 10),
                      const _GameReview(name: '熊******', text: '很不错'),
                      const _GameReview(name: '孤***', text: '枪很硬'),
                      const _GameReview(
                          name: 'o******', text: '枪法意识都在线，带我肥肥得吃啦'),
                      const _CompanionSection(title: '购买须知'),
                      const _DetailNotice(),
                    ],
                  ),
                ),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => openCompanionChat(
                              context, data.userId, data.name),
                          child: const Text('⚡ 聊一聊'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _showOrderNotice(context),
                          child: const Text('下单'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

void _showOrderNotice(BuildContext context) {
  _showTopNotice(context, const Text('下单流程正在接入，请稍后再试'));
}

class _DetailServiceRow extends StatelessWidget {
  const _DetailServiceRow(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(TIcons.chevron_right),
      );
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Text(label), const Spacer(), Text(value)]),
      );
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary();
  @override
  Widget build(BuildContext context) => Card(
        child: const ListTile(
          title: Text('⭐ 4.5     共91条评价'),
          subtitle: Text('近三个月服务29人 · 总计27人比心'),
        ),
      );
}

class _DetailNotice extends StatelessWidget {
  const _DetailNotice();
  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✓ 有效期        下单之后30天有效'),
          SizedBox(height: 8),
          Text('📄 退款规则      未开始服务随时退，到期未服务自动退'),
          SizedBox(height: 8),
          Text('⚠️ 温馨提示      建议用平台房间沟通'),
        ],
      );
}
