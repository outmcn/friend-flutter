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
  DDPostService? _service;
  Timer? _poll;
  bool matching = false;
  bool startingCall = false;
  Map<String, dynamic>? peer;
  String? conversationId;
  String? token;
  String error = '';
  int waitingSeconds = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startMatching({String mode = 'all'}) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('friend.auth.token') ?? '';
    if (authToken.isEmpty) {
      if (mounted) setState(() => error = '请先登录');
      return;
    }
    _service?.dispose();
    final service = DDPostService();
    _service = service;
    if (mounted)
      setState(() {
        token = authToken;
        matching = true;
        error = '';
        peer = null;
        conversationId = null;
        waitingSeconds = 0;
      });
    try {
      final result = await service.joinVoiceMatch(authToken, mode: mode);
      _applyMatch(result);
      if (mounted && peer == null) {
        _poll = Timer.periodic(const Duration(seconds: 2), (_) => _pollMatch());
      }
    } catch (_) {
      if (mounted)
        setState(() {
          matching = false;
          error = '语音匹配失败';
        });
    }
  }

  void _applyMatch(Map<String, dynamic> result) {
    if (!mounted) return;
    final matched = result['status'] == 'matched' && result['peer'] is Map;
    if (matched) {
      _poll?.cancel();
      setState(() {
        matching = false;
        peer = Map<String, dynamic>.from(result['peer'] as Map);
        conversationId = '${result['conversationId'] ?? ''}';
      });
    }
  }

  Future<void> _pollMatch() async {
    final service = _service;
    final authToken = token;
    if (service == null || authToken == null || !mounted) return;
    waitingSeconds += 2;
    try {
      _applyMatch(await service.voiceMatchStatus(authToken));
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    _poll?.cancel();
    final service = _service;
    final authToken = token;
    if (service != null && authToken != null) {
      try {
        await service.leaveVoiceMatch(authToken);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        matching = false;
        waitingSeconds = 0;
        error = '';
        peer = null;
        conversationId = null;
      });
    }
  }

  Future<void> _startCall() async {
    if (startingCall ||
        token == null ||
        conversationId == null ||
        conversationId!.isEmpty) return;
    setState(() => startingCall = true);
    try {
      final result =
          await ImSession.instance.startCall(token!, conversationId!);
      if (!mounted) return;
      final call = (result['call'] as Map?)?.cast<String, dynamic>() ?? {};
      final rtc = (result['rtc'] as Map?)?.cast<String, dynamic>() ?? {};
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _AudioCallPage(call: call, rtc: rtc, token: token!)));
    } catch (_) {
      if (mounted) setState(() => error = '发起通话失败');
    } finally {
      if (mounted) setState(() => startingCall = false);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xff0f0a1a),
        appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(peer == null ? '语音匹配' : '匹配成功')),
        body: Stack(children: [
          const Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff673a8c), Color(0xff0f0a1a)])))),
          Center(
              child: peer == null
                  ? _VoiceMatchingContent(
                      waitingSeconds: waitingSeconds,
                      error: error,
                      onCancel: _leave,
                      onStart: matching ? _leave : _startMatching,
                      matching: matching)
                  : _VoiceMatchSuccess(
                      peer: peer!,
                      startingCall: startingCall,
                      error: error,
                      onCall: _startCall,
                      onRestart: _startMatching)),
        ]),
      );
}

class _VoiceMatchingContent extends StatefulWidget {
  const _VoiceMatchingContent(
      {required this.waitingSeconds,
      required this.error,
      required this.onCancel,
      required this.onStart,
      required this.matching});
  final int waitingSeconds;
  final String error;
  final VoidCallback onCancel;
  final VoidCallback onStart;
  final bool matching;
  @override
  State<_VoiceMatchingContent> createState() => _VoiceMatchingContentState();
}

class _VoiceMatchingContentState extends State<_VoiceMatchingContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    if (widget.matching) pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _VoiceMatchingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.matching && !oldWidget.matching) {
      pulse
        ..reset()
        ..repeat();
    } else if (!widget.matching && oldWidget.matching) {
      pulse.reset();
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final rings = <Widget>[];
              if (widget.matching) {
                for (final index in [0, 1, 2]) {
                  final phase = (pulse.value + index / 3) % 1.0;
                  rings.add(
                    Opacity(
                      opacity: 1 - phase,
                      child: Transform.scale(
                        scale: .38 + phase * .62,
                        child: Container(
                          width: 290,
                          height: 290,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.purpleAccent.withValues(alpha: .65),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  ...rings,
                  Container(
                    width: 108,
                    height: 108,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xffa855f7), Color(0xffff6b9d)]),
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 45),
                  ),
                ],
              );
            }),
        const SizedBox(height: 48),
        const Text('正在寻找有趣的声音',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (widget.error.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(widget.error,
                  style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 42),
        FilledButton.icon(
            onPressed: widget.onStart,
            icon: Icon(widget.matching ? Icons.close : Icons.mic_none),
            label: Text(widget.matching
                ? '正在匹配 ${widget.waitingSeconds ~/ 60}:${(widget.waitingSeconds % 60).toString().padLeft(2, '0')} 点击取消'
                : '开始匹配')),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _startMatching(mode: 'city'),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('同城匹配'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _showTopNotice(
                  context, const SnackBar(content: Text('加速匹配功能即将开放'))),
              icon: const Icon(Icons.bolt_outlined),
              label: const Text('加速匹配'),
            ),
          ],
        ),
      ]));
}

class _VoiceMatchSuccess extends StatelessWidget {
  const _VoiceMatchSuccess(
      {required this.peer,
      required this.startingCall,
      required this.error,
      required this.onCall,
      required this.onRestart});
  final Map<String, dynamic> peer;
  final bool startingCall;
  final String error;
  final VoidCallback onCall;
  final VoidCallback onRestart;
  @override
  Widget build(BuildContext context) {
    final avatar = '${peer['avatarUrl'] ?? ''}';
    return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const _VoiceUiNotice(),
          const SizedBox(height: 32),
          CircleAvatar(
              radius: 66,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child:
                  avatar.isEmpty ? const Icon(Icons.person, size: 62) : null),
          const SizedBox(height: 24),
          Text('${peer['nickname'] ?? '声音伙伴'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          const Text('已为你匹配到一位声音伙伴', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final tag
                in (peer['tags'] is List ? peer['tags'] as List : const []))
              Chip(label: Text('$tag'))
          ]),
          const SizedBox(height: 28),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: startingCall ? null : onCall,
              icon: const Icon(Icons.phone_outlined),
              label: Text(startingCall ? '连接中…' : '开始语音通话')),
          const SizedBox(height: 12),
          TextButton(onPressed: onRestart, child: const Text('重新匹配'))
        ]));
  }
}

class _VoiceUiNotice extends StatelessWidget {
  const _VoiceUiNotice();
  @override
  Widget build(BuildContext context) => const Text('语音匹配',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white60, fontSize: 11));
}
