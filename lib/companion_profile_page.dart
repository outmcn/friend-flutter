part of 'main.dart';

class CompanionProfilePage extends StatelessWidget {
  const CompanionProfilePage({super.key, required this.data});
  final CompanionProfile data;

  @override
  Widget build(BuildContext context) {
    final p = data;
    final tags = p.tags.isEmpty ? const ['暂无标签'] : p.tags;
    return Scaffold(
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
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.white)),
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
                          Text(
                            p.gender.isEmpty
                                ? '陪玩 · ${p.game}'
                                : '${p.gender} · ${p.game}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: () {},
                        icon:
                            const Icon(Icons.more_horiz, color: Colors.white)),
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
                      Text('${p.price}币 /小时',
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
                    Text(p.description.isEmpty ? '暂无详细介绍' : p.description),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          tags.map((tag) => _CompactTag(text: tag)).toList(),
                    ),
                    const SizedBox(height: 12),
                    const _DetailInfoRow(label: '可1陪2', value: '是'),
                    const _DetailInfoRow(label: '擅长地图', value: '零号大坝 航天基地'),
                    const _DetailInfoRow(label: '游戏模式', value: '机密 绝密'),
                    const _CompanionSection(title: '近期表现'),
                    _GameProfileStat(
                        value: p.rating.isEmpty ? '暂无' : p.rating, label: '评分'),
                    const SizedBox(height: 14),
                    Container(
                        height: 150,
                        decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Text('暂无真实展示内容'))),
                    const _CompanionSection(title: '用户评价'),
                    _ReviewSummary(rating: p.rating),
                    const SizedBox(height: 10),
                    const Text('暂无真实评价'),
                    const _CompanionSection(title: '购买须知'),
                    const _DetailNotice(),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            openCompanionChat(context, data.userId, data.name),
                        child: const Text('⚡ 聊一聊'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _openOrder(context, data),
                        child: const Text('立即下单'),
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
}

Future<void> _openOrder(BuildContext context, CompanionProfile data) async {
  final price = num.tryParse(data.price);
  if (data.userId.isEmpty || price == null || price <= 0) {
    _showTopNotice(context, const Text('当前陪玩价格未配置，暂时无法下单'));
    return;
  }
  final controller = TextEditingController(text: '1');
  final noteController = TextEditingController();
  final confirmed = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('立即下单'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('陪玩：${data.name}'),
          Text('价格：${data.price} 钻石 / 小时'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '购买小时数'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '订单备注（选填）'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final hours = int.tryParse(controller.text.trim());
            if (hours != null && hours > 0 && hours <= 100) {
              Navigator.pop(dialogContext, hours);
            }
          },
          child: const Text('确认下单'),
        ),
      ],
    ),
  );
  final orderNote = noteController.text.trim();
  controller.dispose();
  noteController.dispose();
  if (confirmed == null || !context.mounted) return;
  final amount = price * confirmed;
  try {
    final api = GameClubBackendClient();
    await api.post('/api/game-club/orders', {
      'companionUserId': int.tryParse(data.userId),
      'amount': amount,
      'note': orderNote,
    });
    api.dispose();
    if (context.mounted) {
      _showTopNotice(
          context, Text('下单成功，已冻结 ${amount.toStringAsFixed(2)} 颗钻石'));
    }
  } catch (e) {
    if (context.mounted) _showTopNotice(context, Text('$e'));
  }
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
  const _ReviewSummary({this.rating = ''});
  final String rating;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(rating.isEmpty ? '暂无评分' : '⭐ $rating'),
          subtitle: const Text('暂无真实评价数据'),
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
