part of 'main.dart';

class VoiceRoomPage extends StatefulWidget {
  const VoiceRoomPage({super.key});
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  bool muted = false;
  bool joined = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff1a1224),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text('深夜电台 · 一起听'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
            ]),
        body: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff673a8c), Color(0xff1a1224)])))),
          ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              children: [
                const _VoiceRoomNotice(),
                const SizedBox(height: 18),
                Center(
                    child: Column(children: [
                  Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.purpleAccent, width: 2)),
                    ),
                    const CircleAvatar(
                        radius: 41, child: Icon(Icons.mic, size: 38)),
                  ]),
                  const SizedBox(height: 12),
                  const Text('苏念  房主',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 5),
                  const Chip(
                      label: Text('正在说话'),
                      avatar: Icon(Icons.graphic_eq, size: 15))
                ])),
                const SizedBox(height: 28),
                const Text('麦位  ·  128 人在听',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 18,
                    children: const [
                      _VoiceSeat(icon: Icons.music_note, name: '小鹿'),
                      _VoiceSeat(icon: Icons.favorite_outline, name: '桃子'),
                      _VoiceSeat(
                          icon: Icons.sports_esports_outlined, name: '北辰'),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true)
                    ]),
                const SizedBox(height: 24),
                const Text('房间消息',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const _VoiceRoomMessage(name: '小鹿', text: '这首歌好好听～'),
                const _VoiceRoomMessage(name: '桃子', text: '新来的朋友晚上好'),
              ]),
        ]),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
                color: const Color(0xff21172e),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  IconButton(
                      onPressed: () => setState(() => muted = !muted),
                      icon: Icon(muted ? Icons.mic_off : Icons.mic_none,
                          color: Colors.white)),
                  Expanded(
                      child: FilledButton(
                          onPressed: () => setState(() => joined = !joined),
                          child: Text(joined ? '已上麦（UI）' : '申请上麦'))),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.card_giftcard_outlined,
                          color: Colors.white))
                ]))),
      );
}
