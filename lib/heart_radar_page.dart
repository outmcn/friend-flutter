part of 'main.dart';
// ignore_for_file: unused_element, unused_element_parameter

class HeartRadarPage extends StatefulWidget {
  const HeartRadarPage({super.key});
  @override
  State<HeartRadarPage> createState() => _HeartRadarPageState();
}

class _HeartRadarPageState extends State<HeartRadarPage> {
  DDPostService? _service;
  Timer? _poll;
  String? token;
  String? conversationId;
  Map<String, dynamic>? peer;
  bool matching = false;
  int waitingSeconds = 0;
  int fateRemaining = 30;
  String error = '';

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
    _service = DDPostService();
    token = authToken;
    if (mounted)
      setState(() {
        matching = true;
        peer = null;
        conversationId = null;
        error = '';
        waitingSeconds = 0;
      });
    try {
      final result = await _service!.joinFateMatch(
        authToken,
        mode: mode,
        distanceBucket:
            selectedDistanceBucket == 0 ? null : selectedDistanceBucket - 1,
        minAge: ageRange.start.round() <= 18 ? null : ageRange.start.round(),
        maxAge: ageRange.end.round() >= 60 ? null : ageRange.end.round(),
      );
      fateRemaining =
          ((result['quota'] as Map?)?['remaining'] as num?)?.toInt() ??
              fateRemaining;
      _apply(result);
      if (mounted && peer == null)
        _poll =
            Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
    } catch (_) {
      if (mounted)
        setState(() {
          matching = false;
          error = '缘分匹配失败';
        });
    }
  }

  void _apply(Map<String, dynamic> result) {
    if (!mounted || result['status'] != 'matched' || result['peer'] is! Map)
      return;
    _poll?.cancel();
    setState(() {
      matching = false;
      peer = Map<String, dynamic>.from(result['peer'] as Map);
      conversationId = '${result['conversationId'] ?? ''}';
    });
  }

  Future<void> _pollStatus() async {
    if (_service == null || token == null) return;
    waitingSeconds += 2;
    try {
      _apply(await _service!.fateMatchStatus(token!));
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    _poll?.cancel();
    final service = _service;
    final authToken = token;
    if (service != null && authToken != null) {
      try {
        await service.leaveFateMatch(authToken);
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

  Future<void> _openChat() async {
    if (token == null || peer == null) return;
    try {
      final id = await _service!.createDirectConversation(
        token!,
        '${peer!['id']}',
      );
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('friend.auth.userId') ?? '';
      if (!mounted) return;
      final chat = _ChatPreview(
        '${peer!['nickname'] ?? '有缘人'}',
        '开始一段新的聊天',
        '${peer!['avatarUrl'] ?? ''}',
        '${peer!['avatarKey'] ?? ''}',
        '${peer!['id'] ?? ''}',
        id,
        0,
        null,
        null,
        'dm',
        false,
        false,
        true,
        (peer!['latitude'] as num?)?.toDouble(),
        (peer!['longitude'] as num?)?.toDouble(),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ChatDetailPage(
            chat: chat,
            currentUserId: currentUserId,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => error = '打开聊天失败');
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _service?.dispose();
    super.dispose();
  }

  int selectedDistance = 0;
  int selectedGender = 0;
  int selectedDistanceBucket = 0;
  RangeValues ageRange = const RangeValues(18, 60);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff160d3b),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text(''),
        ),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.35,
                    colors: [Color(0xff7542c8), Color(0xff160d3b)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text('立即匹配',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('今日剩余${fateRemaining == 30 ? 1 : fateRemaining}次',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 30),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _distanceSlider(),
                            const SizedBox(height: 24),
                            _filterSection('性别', ['不限', '异性'], selectedGender,
                                (v) => setState(() => selectedGender = v)),
                            const SizedBox(height: 24),
                            _ageSlider(),
                            if (error.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(error,
                                  style:
                                      const TextStyle(color: Colors.redAccent)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: matching ? _leave : _startMatching,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffff5f8f),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                        ),
                        child: Text(matching ? '取消匹配' : '立即匹配',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _distanceSlider() => _filterSection(
        '距离',
        const ['全部', '0-10km', '10-30km', '30km+'],
        selectedDistanceBucket,
        (value) => setState(() => selectedDistanceBucket = value),
      );

  Widget _ageSlider() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('年龄：${ageRange.start.round()}-${ageRange.end.round()}岁',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          RangeSlider(
            values: ageRange,
            min: 18,
            max: 60,
            divisions: 42,
            labels: RangeLabels(
                '${ageRange.start.round()}岁', '${ageRange.end.round()}岁'),
            activeColor: const Color(0xffff5f8f),
            onChanged: (value) => setState(() => ageRange = value),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('18岁', style: TextStyle(color: Colors.white60)),
              Text('60岁', style: TextStyle(color: Colors.white60)),
            ],
          ),
        ],
      );

  Widget _filterSection(String title, List<String> options, int selected,
      ValueChanged<int> onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: options.asMap().entries.map((entry) {
            final active = entry.key == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: entry.key == options.length - 1 ? 0 : 10),
                child: GestureDetector(
                  onTap: () => onSelected(entry.key),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xffff5f8f)
                          : Colors.white.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: active
                              ? const Color(0xffff8bad)
                              : Colors.white24),
                    ),
                    child: Text(entry.value,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _HeartRadarFateWaiting extends StatefulWidget {
  const _HeartRadarFateWaiting(
      {required this.seconds,
      required this.error,
      required this.onCancel,
      required this.onStart,
      required this.onCityStart,
      required this.onSpeedStart,
      required this.matching,
      required this.remaining});
  final int seconds;
  final String error;
  final VoidCallback onCancel;
  final VoidCallback onStart;
  final VoidCallback onCityStart;
  final VoidCallback onSpeedStart;
  final bool matching;
  final int remaining;
  @override
  State<_FateWaiting> createState() => _FateWaitingState();
}

class _HeartRadarFateWaitingState extends State<_FateWaiting>
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
  void didUpdateWidget(covariant _FateWaiting oldWidget) {
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
  Widget build(BuildContext context) => SizedBox.expand(
        child: Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 118),
              child: Align(
                alignment: const Alignment(0, 0.16),
                child: SizedBox(
                  width: double.infinity,
                  height: 470,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 290,
                        child: AnimatedBuilder(
                          animation: pulse,
                          builder: (_, __) {
                            final rings = <Widget>[];
                            if (widget.matching) {
                              for (final index in [0, 1, 2]) {
                                final phase = (pulse.value + index / 3) % 1.0;
                                rings.add(Opacity(
                                  opacity: 1 - phase,
                                  child: Transform.scale(
                                    scale: .38 + phase * .62,
                                    child: Container(
                                      width: 290,
                                      height: 290,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.pinkAccent
                                                .withValues(alpha: .65),
                                            width: 1.5),
                                      ),
                                    ),
                                  ),
                                ));
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
                                        color: Color(0xffff5f8f)),
                                    child: const Icon(Icons.auto_awesome,
                                        color: Colors.white, size: 45),
                                  ),
                                ]);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 34,
                        child: Text(widget.matching ? '正在为您匹配……' : '寻找有缘人',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 24,
                        child: Text('今日剩余 ${widget.remaining} 次',
                            style: const TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: widget.onStart,
                          icon: Icon(widget.matching
                              ? Icons.close
                              : Icons.favorite_outline),
                          label: Text(widget.matching
                              ? '正在匹配 ${widget.seconds ~/ 60}:${(widget.seconds % 60).toString().padLeft(2, '0')} 点击取消'
                              : '开始匹配'),
                        ),
                      ),
                      if (widget.error.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(widget.error,
                                style:
                                    const TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: widget.onCityStart,
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('同城匹配'))),
                const SizedBox(width: 10),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: widget.onSpeedStart,
                        icon: const Icon(Icons.bolt_outlined),
                        label: const Text('加速匹配'))),
              ]),
            ),
          ),
        ]),
      );
}

class _HeartRadarFateSuccess extends StatelessWidget {
  const _HeartRadarFateSuccess(
      {required this.peer,
      required this.error,
      required this.onChat,
      required this.onRestart});
  final Map<String, dynamic> peer;
  final String error;
  final VoidCallback onChat;
  final VoidCallback onRestart;
  @override
  Widget build(BuildContext context) {
    final avatar = '${peer['avatarUrl'] ?? ''}';
    return Padding(
        padding: const EdgeInsets.all(26),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('缘分匹配',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 36),
          _FriendAvatar(
              avatarUrl: avatar,
              size: 132,
              placeholder: const Icon(Icons.person, size: 62)),
          const SizedBox(height: 24),
          Text('${peer['nickname'] ?? '有缘人'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          const Text('已为你匹配到一位有缘人', style: TextStyle(color: Colors.white60)),
          if (error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(error,
                    style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 28),
          Wrap(spacing: 10, children: [
            FilledButton(onPressed: onChat, child: const Text('开始聊天')),
            OutlinedButton(onPressed: onRestart, child: const Text('重新匹配'))
          ])
        ]));
  }
}
