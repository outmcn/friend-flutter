part of 'main.dart';

class _CompanionNotice extends StatelessWidget {
  const _CompanionNotice();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Text('陪玩广场', style: Theme.of(context).textTheme.labelSmall));
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Stack(children: [
                  CircleAvatar(radius: 26, child: Icon(data.icon, size: 25)),
                  Positioned(right: 0, bottom: 0, child: _OnlineDot()),
                ]),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(data.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${data.game} · ★${data.rating} · 在线',
                          style: Theme.of(context).textTheme.labelSmall),
                    ])),
                FilledButton(onPressed: onOrder, child: const Text('约玩')),
              ]),
              const SizedBox(height: 10),
              Text(data.voice,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 9),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: data.tags
                      .map((t) => Chip(
                          label: Text(t), visualDensity: VisualDensity.compact))
                      .toList()),
              const Divider(height: 24),
              Row(children: [
                Text('¥ ${data.price}/局起',
                    style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xffff4d8a),
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                const Text('已服务 1,286 次',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
          ),
        ),
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
