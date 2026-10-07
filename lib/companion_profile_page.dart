part of 'main.dart';

class CompanionProfilePage extends StatelessWidget {
  const CompanionProfilePage({super.key, required this.data});
  final CompanionProfile data;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          Container(
              height: 270,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xff4a2a6b), Color(0xffe05ca8)]))),
          SafeArea(
              child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white))),
          ListView(
              padding: const EdgeInsets.fromLTRB(16, 220, 16, 108),
              children: [
                const _CompanionNotice(),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Stack(children: [
                                  CircleAvatar(
                                      radius: 38,
                                      child: Icon(data.icon, size: 36)),
                                  Positioned(
                                      right: 0, bottom: 1, child: _OnlineDot())
                                ]),
                                const SizedBox(width: 13),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Text(data.name,
                                            style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified,
                                            color: Colors.lightBlue, size: 17)
                                      ]),
                                      const SizedBox(height: 5),
                                      Text('${data.game} · ★ ${data.rating}',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary)),
                                      const SizedBox(height: 4),
                                      Text('在线5 分钟内响应',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall)
                                    ]))
                              ]),
                              const SizedBox(height: 14),
                              const Text('喜欢轻松聊天和开黑，一起享受游戏的快乐吧～'),
                              const Divider(height: 28),
                              const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _GameProfileStat(
                                        value: '99%', label: '好评率'),
                                    _GameProfileStat(
                                        value: '6分钟', label: '平均响应'),
                                    _GameProfileStat(
                                        value: '1,286', label: '接单数')
                                  ]),
                            ]))),
                const _CompanionSection(title: '声音名片'),
                _CompanionVoiceCard(text: data.voice),
                const _CompanionSection(title: '陪玩服务'),
                _GameProfileServiceRow(
                    game: data.game, title: '娱乐开黑 · 语音陪伴', price: data.price),
                _GameProfileServiceRow(
                    game: data.game, title: '上分陪玩 · 全程连麦', price: '59'),
                const _CompanionSection(title: '标签与评价'),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        data.tags.map((t) => Chip(label: Text(t))).toList()),
                const SizedBox(height: 12),
                const _GameReview(name: '小橘', text: '声音很好听，开黑很开心。'),
              ]),
        ]),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton(
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text(''))),
                    child: Text('¥ ${data.price} 起 · 立即约玩')))),
      );
}
