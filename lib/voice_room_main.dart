part of 'main.dart';

class _VoiceRoomFloatingOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, Map<String, dynamic>? room) {
    if (_entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        right: 16,
        bottom: 112,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              entry.remove();
              _entry = null;
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => VoiceRoomPage(room: room)),
              );
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xff7c4dff),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 12)
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void remove() {
    _entry?.remove();
    _entry = null;
  }
}

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
  bool _leaving = false;
  bool _rtcJoined = false;

  @override
  void initState() {
    super.initState();
    _joinRtc();
  }

  Future<void> _joinRtc() async {
    final rtc = widget.room?['rtc'];
    if (rtc is! Map || '${rtc['token'] ?? ''}'.isEmpty) return;
    try {
      await AliyunRtcBridge.join(rtc.cast<String, dynamic>());
      await AliyunRtcBridge.subscribeRemoteAudio(true);
      _rtcJoined = true;
    } catch (_) {}
  }

  Future<void> _exitRoom() async {
    if (_leaving) return;
    _leaving = true;
    _VoiceRoomFloatingOverlay.remove();
    if (_rtcJoined) {
      try {
        await AliyunRtcBridge.leave().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出频道'),
        content: const Text('退出后将停止接收频道声音，确定退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (exit == true) await _exitRoom();
  }

  void _minimize() {
    _VoiceRoomFloatingOverlay.show(context, widget.room);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!_leaving) {
      // 返回或右滑进入浮窗时保留 RTC，不在此处离开频道。
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _minimize();
        },
        child: Scaffold(
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
              IconButton(
                  onPressed: _confirmExit, icon: const Icon(Icons.close)),
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
                            border: Border.all(
                                color: Colors.purpleAccent, width: 2)),
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
        ),
      );
}
