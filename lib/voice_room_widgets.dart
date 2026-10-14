part of 'main.dart';
// ignore_for_file: unused_element

class _CompanionNotice extends StatelessWidget {
  const _CompanionNotice();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Text('Game 俱乐部', style: Theme.of(context).textTheme.labelSmall));
}

class _VoiceRoomNotice extends StatelessWidget {
  const _VoiceRoomNotice();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('语音房、麦位和房间消息',
          style: TextStyle(color: Colors.white70, fontSize: 11)));
}

class _CompanionSection extends StatelessWidget {
  const _CompanionSection({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 11),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)));
}

class _CompanionRecommendCard extends StatelessWidget {
  const _CompanionRecommendCard({required this.data, required this.onTap});
  final CompanionProfile data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Center(
                    child: CircleAvatar(
                        radius: 34, child: Icon(data.icon, size: 30)))),
            Text(data.name,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(data.voice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            Text('¥${data.price}/局 · ★${data.rating}',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.primary))
          ])));
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
          border: Border.all(
              color: Theme.of(context).colorScheme.surface, width: 2),
        ),
      );
}

class _CompanionListCard extends StatelessWidget {
  const _CompanionListCard(
      {required this.data, required this.onTap, required this.onOrder});
  final CompanionProfile data;
  final VoidCallback onTap;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(data.icon, size: 30),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -7,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Lv68',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(data.name,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(TIcons.verified_filled,
                                  size: 16, color: Color(0xff3b82f6)),
                              const Spacer(),
                              const _OnlineDot(),
                              const SizedBox(width: 4),
                              const Text('在线',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _CompactTag(text: '${data.game} · 战神'),
                              const SizedBox(width: 6),
                              Text('★${data.rating}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: data.tags
                                .take(3)
                                .map((tag) => _CompactTag(text: tag))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CompanionMetric(value: '320', label: '接单'),
                    _CompanionMetric(value: '98%', label: '好评'),
                    _CompanionMetric(value: '2分钟', label: '响应'),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('¥${data.price}/局',
                        style: const TextStyle(
                            color: Color(0xffff4d8a),
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    FilledButton(onPressed: onOrder, child: const Text('立即下单')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _CompactTag extends StatelessWidget {
  const _CompactTag({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text, style: const TextStyle(fontSize: 10)),
      );
}

class _CompanionMetric extends StatelessWidget {
  const _CompanionMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        ],
      );
}

class _CompanionVoiceCard extends StatelessWidget {
  const _CompanionVoiceCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
          title: Text(text),
          subtitle: const Text('声音名片 · '),
          trailing: const Text('00:16')));
}

class _VoiceSeat extends StatelessWidget {
  const _VoiceSeat(
      {required this.icon, required this.name, this.empty = false});
  final IconData icon;
  final String name;
  final bool empty;
  @override
  Widget build(BuildContext context) => Column(children: [
        CircleAvatar(
            radius: 27,
            backgroundColor: empty ? Colors.white10 : null,
            child: Icon(icon, color: empty ? Colors.white38 : null)),
        const SizedBox(height: 5),
        Text(name,
            style: TextStyle(
                fontSize: 11, color: empty ? Colors.white38 : Colors.white70),
            overflow: TextOverflow.ellipsis)
      ]);
}

class _VoiceRoomMessage extends StatelessWidget {
  const _VoiceRoomMessage({required this.name, required this.text});
  final String name;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
          text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
            TextSpan(
                text: '$name  ',
                style: const TextStyle(
                    color: Color(0xffe8b8ff), fontWeight: FontWeight.w700)),
            TextSpan(text: text)
          ])));
}
