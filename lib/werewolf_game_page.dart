part of 'main.dart';

class WerewolfGamePage extends StatefulWidget {
  const WerewolfGamePage({super.key});
  @override
  State<WerewolfGamePage> createState() => _WerewolfGamePageState();
}

class _WerewolfGamePageState extends State<WerewolfGamePage> {
  final roomController = TextEditingController();
  final service = DDPostService();
  String? roomId;
  String? roomCode;
  bool matching = false, ready = false, loading = false;
  String? error;
  List<Map<String, dynamic>> seats = [];

  @override
  void dispose() {
    roomController.dispose();
    service.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('friend.auth.token') ?? '';
    if (t.isEmpty) throw Exception('请先登录');
    return t;
  }

  Future<void> _enterRoom(Map<String, dynamic> d) async {
    if (!mounted) return;
    setState(() {
      roomId = '${d['roomId'] ?? ''}';
      roomCode = '${d['roomCode'] ?? ''}';
      seats = (d['seats'] as List? ?? [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    });
  }

  Future<void> _createRoom() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      await _enterRoom(await service.createWerewolfRoom(await _token()));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = roomController.text.trim();
    if (code.isEmpty) {
      setState(() => error = '请输入房间号');
      return;
    }
    try {
      setState(() {
        loading = true;
        error = null;
      });
      await _enterRoom(await service.joinWerewolfRoom(await _token(), code));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleSeat(int seat) async {
    if (roomId == null) return;
    try {
      await _enterRoom(
          await service.takeWerewolfSeat(await _token(), roomId!, seat));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _toggleReady() async {
    if (roomId == null) return;
    try {
      await _enterRoom(
          await service.readyWerewolfRoom(await _token(), roomId!, !ready));
      if (mounted) setState(() => ready = !ready);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _toggleMatching() async {
    try {
      if (matching) {
        await service.stopWerewolfMatch(await _token());
      } else {
        final d = await service.startWerewolfMatch(await _token());
        if ('${d['roomId'] ?? ''}'.isNotEmpty) await _enterRoom(d);
      }
      if (mounted) setState(() => matching = !matching);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _showFindRoom() async {
    roomController.clear();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff19130f),
        title: const Text('查找房间', style: TextStyle(color: Color(0xffe8d5b0))),
        content: TextField(
          controller: roomController,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: '输入房间号'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _joinRoom();
              },
              child: const Text('进入房间')),
        ],
      ),
    );
  }

  Widget _seat(int index) {
    final item = seats
        .cast<Map<String, dynamic>?>()
        .firstWhere((e) => e?['seat'] == index, orElse: () => null);
    final name = item?['nickname']?.toString();
    return Card(
      color: const Color(0xff211a17),
      child: InkWell(
        onTap: name == null ? () => _toggleSeat(index) : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: const Color(0xff493229),
                child: _tdIcon('user')),
            const SizedBox(width: 8),
            Expanded(
                child: Text(name ?? '点击入座',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xffe8d5b0)))),
            if (item?['ready'] == true)
              const Icon(Icons.check_circle, color: Color(0xffc98958)),
          ]),
        ),
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback? onPressed,
      {bool main = false}) {
    return SizedBox(
      width: main ? 128 : 86,
      height: main ? 54 : 42,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xffffe4b8),
          backgroundColor:
              main ? const Color(0xdd482016) : const Color(0xd21c1612),
          side: BorderSide(
              color: main ? const Color(0xffe6a05a) : const Color(0xff92704c)),
          shape: const StadiumBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: main ? 17 : 14,
                fontWeight: main ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _roomPanel() {
    return SafeArea(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
          children: [
            Text('房间号：$roomCode',
                style: const TextStyle(
                    color: Color(0xffffe4b8),
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(children: List.generate(6, (i) => _seat(i)))),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      Column(children: List.generate(6, (i) => _seat(i + 6)))),
            ]),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _toggleReady, child: Text(ready ? '取消准备' : '准备')),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: const TextStyle(color: Colors.redAccent))),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inRoom = roomCode != null;
    return Scaffold(
      backgroundColor: const Color(0xff0b0e14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(inRoom ? '狼人杀房间' : '狼人杀',
            style: const TextStyle(color: Color(0xffe8d5b0))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xffe8d5b0),
      ),
      body: inRoom
          ? _roomPanel()
          : Stack(children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _WerewolfBackdropPainter())),
              SafeArea(
                  child: Stack(children: [
                Positioned(
                  top: 54,
                  left: 0,
                  right: 0,
                  child: Column(children: const [
                    Text('狼 人 杀',
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 34,
                            letterSpacing: 10,
                            color: Color(0xffe8d5b0),
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('W E R E W O L F',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 5,
                            color: Color(0xff9a8a70))),
                    SizedBox(height: 10),
                    SizedBox(
                        width: 70,
                        child: Divider(color: Color(0xffa77b4a), height: 1)),
                  ]),
                ),
                Positioned(
                    top: MediaQuery.sizeOf(context).height * .70,
                    left: 0,
                    right: 0,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _actionButton('建房', _createRoom),
                          const SizedBox(width: 14),
                          _actionButton(
                              matching ? '停止匹配' : '快速匹配', _toggleMatching,
                              main: true),
                          const SizedBox(width: 14),
                          _actionButton('查找', _showFindRoom),
                        ])),
                Positioned(
                    bottom: 42,
                    left: 0,
                    right: 0,
                    child: Column(children: const [
                      SizedBox(
                          width: 120, child: Divider(color: Color(0xff8b6845))),
                      SizedBox(height: 12),
                      Text('黑 夜 降 临 · 谁 是 狼 人',
                          style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 13,
                              letterSpacing: 6,
                              color: Color(0xff9a896f))),
                      SizedBox(height: 6),
                      Text('N I G H T   F A L L S',
                          style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 4,
                              color: Color(0xff5a5045))),
                    ])),
                if (error != null)
                  Positioned(
                      bottom: 120,
                      left: 24,
                      right: 24,
                      child: Text(error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent))),
              ])),
            ]),
    );
  }
}

class _WerewolfBackdropPainter extends CustomPainter {
  const _WerewolfBackdropPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xff0b0f1a),
          Color(0xff101725),
          Color(0xff2b1d1c),
          Color(0xff0d0a0a)
        ],
        stops: [0, .25, .65, 1],
      ).createShader(r);
    canvas.drawRect(r, sky);
    final stars = Paint()..color = const Color(0xfff5e6c8);
    for (final p in const [
      Offset(.12, .08),
      Offset(.28, .12),
      Offset(.45, .06),
      Offset(.62, .10),
      Offset(.78, .05),
      Offset(.88, .14),
      Offset(.15, .22),
      Offset(.55, .20),
      Offset(.72, .26),
      Offset(.92, .32),
      Offset(.08, .38)
    ]) {
      canvas.drawCircle(
          Offset(size.width * p.dx, size.height * p.dy), 1.2, stars);
    }
    final moonCenter = Offset(size.width / 2, size.height * .27);
    canvas.drawCircle(
        moonCenter, size.width * .27, Paint()..color = const Color(0x554c2119));
    canvas.drawCircle(
        moonCenter,
        size.width * .235,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0xfff5e6c8),
            Color(0xffd4a06b),
            Color(0xff8b4a30)
          ]).createShader(
              Rect.fromCircle(center: moonCenter, radius: size.width * .235)));
    final far = Paint()..color = const Color(0xff0f1319);
    final mid = Paint()..color = const Color(0xff090c10);
    _forest(canvas, size, size.height * .58, size.height * .22, far);
    _forest(canvas, size, size.height * .68, size.height * .26, mid);
    final near = Paint()..color = const Color(0xff04060a);
    _forest(canvas, size, size.height * .80, size.height * .24, near);
    final eyes = Paint()
      ..color = const Color(0xffe03a1a)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    for (final p in [
      Offset(size.width * .14, size.height * .72),
      Offset(size.width * .36, size.height * .79),
      Offset(size.width * .78, size.height * .72),
      Offset(size.width * .67, size.height * .66)
    ]) {
      canvas.drawCircle(p, 3.5, eyes);
      canvas.drawCircle(p + const Offset(13, 0), 3.5, eyes);
    }
    final vignette = Paint()
      ..shader =
          const RadialGradient(colors: [Colors.transparent, Color(0xaa000000)])
              .createShader(r);
    canvas.drawRect(r, vignette);
  }

  void _forest(
      Canvas canvas, Size size, double top, double height, Paint paint) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, top + height * .45);
    for (int i = 0; i <= 20; i++) {
      final x = size.width * i / 20;
      final peak = top + (i.isEven ? height * .05 : height * .42);
      path.lineTo(x, peak);
      path.lineTo(x + size.width / 40, top + height * .55);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
