part of 'main.dart';

class VoiceRoomPage extends StatefulWidget {
  const VoiceRoomPage({super.key, this.room});
  final Map<String, dynamic>? room;
  String get roomTitle =>
      '${room?['room']?['title'] ?? room?['title'] ?? '语音频道'}';
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
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          title: Text(widget.roomTitle),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff673a8c), Color(0xff1a1224)])))),
          ListView(
              padding: const EdgeInsets.fromLTRB(16, 78, 16, 100),
              children: [
                const SizedBox(height: 28),
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
                  Text(
                      widget.room?['room']?['title']?.toString() ??
                          widget.room?['title']?.toString() ??
                          '暂无频道名称',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ])),
                const SizedBox(height: 32),
                const Center(
                    child: Text('暂无实时成员资料',
                        style: TextStyle(color: Colors.white70))),
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
                          child: Text(joined ? '已上麦' : '申请上麦'))),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.card_giftcard_outlined,
                          color: Colors.white))
                ]))),
      );
}
