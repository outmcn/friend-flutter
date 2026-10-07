part of 'main.dart';

class ListenTogetherPage extends StatefulWidget {
  const ListenTogetherPage({super.key});
  @override
  State<ListenTogetherPage> createState() => _ListenTogetherPageState();
}

class _ListenTogetherPageState extends State<ListenTogetherPage> {
  bool playing = true;
  bool liked = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff0c0a14),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text('一起听'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
            ]),
        body: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff542c91), Color(0xff0c0a14)])))),
          Column(children: [
            const SizedBox(height: 26),
            Container(
                width: 235,
                height: 235,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff1a1620),
                    border: Border.all(color: Colors.white12, width: 8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 30)
                    ]),
                child: Center(
                    child: Container(
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              Color(0xff7c3aed),
                              Color(0xffe8558c)
                            ])),
                        child: const Icon(Icons.music_note,
                            size: 40, color: Colors.white)))),
            const SizedBox(height: 28),
            const Text('夜空中最亮的星',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('逃跑计划 · 和 苏念 一起听',
                style: TextStyle(color: Colors.white54)),
            Padding(
                padding: const EdgeInsets.fromLTRB(32, 26, 32, 0),
                child: Column(children: [
                  LinearProgressIndicator(
                      value: .42,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(9)),
                  const SizedBox(height: 10),
                  const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('01:42',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11)),
                        Text('04:12',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11))
                      ])
                ])),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(
                  onPressed: () => setState(() => liked = !liked),
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.pinkAccent : Colors.white)),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white, size: 33)),
              Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xff7c3aed), Color(0xffe8558c)])),
                  child: IconButton(
                      onPressed: () => setState(() => playing = !playing),
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white, size: 32))),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white, size: 33)),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.queue_music, color: Colors.white))
            ]),
            const SizedBox(height: 34),
          ]),
        ]),
      );
}

class VoiceMatchPage extends StatefulWidget {
  const VoiceMatchPage({super.key});
  @override
  State<VoiceMatchPage> createState() => _VoiceMatchPageState();
}

class _VoiceMatchPageState extends State<VoiceMatchPage> {
  bool matching = true;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff0f0a1a),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(matching ? '语音匹配' : '匹配成功')),
        body: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff673a8c), Color(0xff0f0a1a)])))),
          Center(
              child: matching
                  ? _VoiceMatchingContent(
                      onSuccess: () => setState(() => matching = false))
                  : _VoiceMatchSuccess(
                      onRestart: () => setState(() => matching = true))),
        ]),
      );
}

class _VoiceMatchingContent extends StatelessWidget {
  const _VoiceMatchingContent({required this.onSuccess});
  final VoidCallback onSuccess;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _VoiceUiNotice(),
        const SizedBox(height: 32),
        Stack(alignment: Alignment.center, children: [
          for (final size in [290.0, 225.0, 160.0])
            Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: .35)))),
          Container(
              width: 108,
              height: 108,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Color(0xffa855f7), Color(0xffff6b9d)])),
              child: const Icon(Icons.mic, color: Colors.white, size: 45))
        ]),
        const SizedBox(height: 48),
        const Text('正在寻找有趣的声音',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('戴上耳机，和陌生人聊聊吧', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 22),
        const Text('等待 00:12', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 42),
        FilledButton(onPressed: onSuccess, child: const Text('模拟匹配成功')),
        const SizedBox(height: 12),
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消匹配')),
      ]));
}

class _VoiceMatchSuccess extends StatelessWidget {
  const _VoiceMatchSuccess({required this.onRestart});
  final VoidCallback onRestart;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _VoiceUiNotice(),
        const SizedBox(height: 32),
        const CircleAvatar(
            radius: 66, child: Icon(Icons.face_3_outlined, size: 62)),
        const SizedBox(height: 24),
        const Text('林小满',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        const Text('已为你匹配到一位声音伙伴', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: const [
          Chip(label: Text('音乐')),
          Chip(label: Text('旅行')),
          Chip(label: Text('在线'))
        ]),
        const SizedBox(height: 28),
        const Text('通话 00:03', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 26),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.mic_none, color: Colors.white)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.volume_up_outlined, color: Colors.white)),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon:
                  const Icon(Icons.call_end, color: Colors.redAccent, size: 34))
        ]),
        const SizedBox(height: 18),
        TextButton(onPressed: onRestart, child: const Text('重新模拟匹配')),
      ]));
}

class _VoiceUiNotice extends StatelessWidget {
  const _VoiceUiNotice();
  @override
  Widget build(BuildContext context) => const Text('语音匹配',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white60, fontSize: 11));
}
