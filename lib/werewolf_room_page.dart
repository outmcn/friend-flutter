part of 'main.dart';

class WerewolfRoomPage extends StatefulWidget {
  const WerewolfRoomPage({super.key, required this.room});
  final Map<String, dynamic> room;

  @override
  State<WerewolfRoomPage> createState() => _WerewolfRoomPageState();
}

class _WerewolfRoomPageState extends State<WerewolfRoomPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final service = DDPostService();
  late Map<String, dynamic> room;
  bool ready = false;
  String? error;

  @override
  void initState() {
    super.initState();
    room = Map<String, dynamic>.from(widget.room);
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    service.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('friend.auth.token') ?? '';
    if (token.isEmpty) throw Exception('请先登录');
    return token;
  }

  List<Map<String, dynamic>> get seats => (room['seats'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Map<String, dynamic>? seat(int index) {
    for (final item in seats) {
      if (item['seat'] == index) return item;
    }
    return null;
  }

  Future<void> _refresh(Map<String, dynamic> next) async {
    if (mounted) setState(() => room = next);
  }

  Future<void> _takeSeat(int index) async {
    try {
      await _refresh(await service.takeWerewolfSeat(
          await _token(), '${room['roomId']}', index));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _toggleReady() async {
    try {
      final next = await service.readyWerewolfRoom(
          await _token(), '${room['roomId']}', !ready);
      await _refresh(next);
      if (mounted) setState(() => ready = !ready);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151119),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('房间设置',
              style: TextStyle(
                  color: Color(0xffffe4b8),
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _seatRow(int index, bool left) {
    final item = seat(index);
    final occupied = item != null;
    return GestureDetector(
      onTap: occupied ? null : () => _takeSeat(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          textDirection: left ? TextDirection.ltr : TextDirection.rtl,
          children: [
            SizedBox(
                width: 22,
                child: Text('${index + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xfffff0d0),
                        fontSize: 16,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 5),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: occupied
                    ? const Color(0xff4c251f)
                    : const Color(0xff8b5a2a),
                border: Border.all(color: const Color(0xffe3a24e)),
              ),
              child: Icon(
                  occupied ? Icons.person_rounded : Icons.shield_rounded,
                  color: const Color(0xffffc279),
                  size: 24),
            ),
            if (occupied) ...[
              const SizedBox(width: 5),
              SizedBox(
                width: 58,
                child: Column(
                  crossAxisAlignment:
                      left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${item['nickname'] ?? '玩家'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xffffddb5),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Text(item['ready'] == true ? '已准备' : '等待中',
                        style: const TextStyle(
                            color: Color(0xff9a8372), fontSize: 10)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = '${room['roomCode'] ?? ''}';
    return Scaffold(
      backgroundColor: const Color(0xff0b0c12),
      body: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: _RoomBackdrop())),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
              child: Row(children: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xffcbb49a), size: 18)),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('赤月庄园 · 预女猎守',
                            style: TextStyle(
                                color: Color(0xffffe4b8),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4)),
                        Text('房间号  $roomCode  ·  ${seats.length}/12 人',
                            style: const TextStyle(
                                color: Color(0xff9e8b77),
                                fontSize: 11,
                                letterSpacing: 1.1)),
                      ]),
                ),
                IconButton(
                    onPressed: _showSettings,
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: Color(0xffcbb49a))),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Stack(children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 18, 6, 12),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                children: List.generate(
                                    6,
                                    (i) =>
                                        Expanded(child: _seatRow(i, true))))),
                        SizedBox(width: c.maxWidth * .28),
                        Expanded(
                            child: Column(
                                children: List.generate(
                                    6,
                                    (i) => Expanded(
                                        child: _seatRow(i + 6, false))))),
                      ]),
                    ),
                  ),
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: c.maxWidth * .27,
                        height: c.maxHeight * .28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const RadialGradient(colors: [
                            Color(0xff5c251d),
                            Color(0xff24100f),
                            Color(0x00120b0d)
                          ]),
                          border: Border.all(
                              color: const Color(0xffc8965a)
                                  .withValues(alpha: .22)),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xffe05a31).withValues(
                                    alpha: .10 + _pulse.value * .08),
                                blurRadius: 30,
                                spreadRadius: 7)
                          ],
                        ),
                        child: Text(
                            room['status'] == 'waiting' ? '等待开局' : '游戏进行中',
                            style: const TextStyle(
                                color: Color(0xffffe4b8),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!,
                      style: const TextStyle(color: Colors.redAccent))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: SizedBox(
                width: 124,
                height: 46,
                child: FilledButton(
                    onPressed: _toggleReady,
                    child: Text(ready ? '已准备 ✓' : '准备')),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RoomBackdrop extends CustomPainter {
  const _RoomBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff0b0f1a),
              Color(0xff101725),
              Color(0xff2b1d1c),
              Color(0xff0d0a0a)
            ],
          ).createShader(rect));
    final stars = Paint()..color = const Color(0xfff5e6c8);
    final random = math.Random(7);
    for (var i = 0; i < 55; i++) {
      canvas.drawCircle(
          Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height * .48),
          .6 + random.nextDouble(),
          stars);
    }
    final forest = Paint()..color = const Color(0xff04060a);
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i <= 42; i++) {
      final x = size.width * i / 42;
      path.lineTo(x, size.height * (.82 - (i.isEven ? .14 : .03)));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, forest);
  }

  @override
  bool shouldRepaint(covariant _RoomBackdrop oldDelegate) => false;
}
