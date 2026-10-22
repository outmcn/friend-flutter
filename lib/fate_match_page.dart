part of 'main.dart';
// ignore_for_file: unused_element, unused_element_parameter

class FateMatchPage extends StatefulWidget {
  const FateMatchPage({super.key});
  @override
  State<FateMatchPage> createState() => _FateMatchPageState();
}

class _FateMatchPageState extends State<FateMatchPage> {
  DDPostService? _service;
  Timer? _poll;
  String? token;
  String? conversationId;
  Map<String, dynamic>? peer;
  bool matching = false;
  int waitingSeconds = 0;
  String error = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startMatching() async {
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
      final result = await _service!.joinFateMatch(authToken);
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

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xff191019),
        appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(peer == null ? '缘分匹配' : '匹配成功')),
        body: Stack(children: [
          const Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xffff6f9a), Color(0xff191019)])))),
          Center(
              child: peer == null
                  ? _FateWaiting(
                      seconds: waitingSeconds,
                      error: error,
                      onCancel: _leave,
                      onStart: matching ? _leave : _startMatching,
                      matching: matching)
                  : _FateSuccess(
                      peer: peer!,
                      error: error,
                      onChat: _openChat,
                      onRestart: _startMatching)),
        ]),
      );
}

class _FateWaiting extends StatefulWidget {
  const _FateWaiting(
      {required this.seconds,
      required this.error,
      required this.onCancel,
      required this.onStart,
      required this.matching});
  final int seconds;
  final String error;
  final VoidCallback onCancel;
  final VoidCallback onStart;
  final bool matching;
  @override
  State<_FateWaiting> createState() => _FateWaitingState();
}

class _FateWaitingState extends State<_FateWaiting>
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const _VoiceUiNotice(),
          const SizedBox(height: 32),
          AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Stack(alignment: Alignment.center, children: [
                    if (widget.matching)
                      for (final size in [290.0, 225.0, 160.0])
                        Opacity(
                            opacity: 1 - pulse.value,
                            child: Transform.scale(
                                scale: .38 + pulse.value * .62,
                                child: Container(
                                    width: size,
                                    height: size,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.pinkAccent
                                                .withValues(alpha: .65),
                                            width: 1.5))))),
                    Container(
                        width: 108,
                        height: 108,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Color(0xffff5f8f)),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 45))
                  ])),
          const SizedBox(height: 48),
          Text(widget.matching ? '正在为您匹配……' : '寻找有缘人',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (widget.matching) ...[],
          if (widget.error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(widget.error,
                    style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 42),
          FilledButton.icon(
              onPressed: widget.onStart,
              icon:
                  Icon(widget.matching ? Icons.close : Icons.favorite_outline),
              label: Text(widget.matching
                  ? '正在匹配 ${widget.seconds ~/ 60}:${(widget.seconds % 60).toString().padLeft(2, '0')} 点击取消'
                  : '开始匹配')),
        ]),
      );
}

class _FateSuccess extends StatelessWidget {
  const _FateSuccess(
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
          CircleAvatar(
              radius: 66,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child:
                  avatar.isEmpty ? const Icon(Icons.person, size: 62) : null),
          const SizedBox(height: 24),
          Text('${peer['nickname'] ?? '有缘人'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          const Text('已为你匹配到一位有缘人', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final tag
                in (peer['tags'] is List ? peer['tags'] as List : const []))
              Chip(label: Text('$tag'))
          ]),
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

class _GameFilterRow extends StatelessWidget {
  const _GameFilterRow(
      {required this.labels,
      required this.selected,
      required this.onSelected,
      this.icon});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView(
            scrollDirection: Axis.horizontal,
            children: labels
                .asMap()
                .entries
                .map((entry) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: icon != null && entry.key == selected
                            ? Icon(icon, size: 15)
                            : null,
                        label: Text(entry.value),
                        selected: selected == entry.key,
                        onSelected: (_) => onSelected(entry.key),
                      ),
                    ))
                .toList()),
      );
}

class _GameProfileStat extends StatelessWidget {
  const _GameProfileStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _GameProfileServiceRow extends StatelessWidget {
  const _GameProfileServiceRow(
      {required this.game, required this.title, required this.price});
  final String game;
  final String title;
  final String price;
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        leading: const Icon(Icons.sports_esports_outlined),
        title: Text(title),
        subtitle: Text(game),
        trailing: Text('¥$price 起',
            style: const TextStyle(
                color: Color(0xffff4d6a), fontWeight: FontWeight.w800)),
      ));
}

class _GameReview extends StatelessWidget {
  const _GameReview({required this.name, required this.text});
  final String name;
  final String text;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(name),
        subtitle: Text(text),
        trailing: const Text('★ 5.0'),
      );
}
