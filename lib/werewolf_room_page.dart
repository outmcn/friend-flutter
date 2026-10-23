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
  final TextEditingController _notebookController = TextEditingController();
  late Map<String, dynamic> room;
  static const List<String> _noticeLines = [
    '系统提示：房间创建成功，等待玩家加入',
    '系统提示：当前玩法为预女猎守',
    '系统提示：请确认身份牌并准备',
    '系统提示：请勿发送与游戏无关的信息',
    '系统提示：房主准备后将开始游戏',
    '系统提示：请保持麦克风清晰，轮到发言时再开启',
    '系统提示：投票阶段请谨慎选择目标',
    '系统提示：夜晚行动期间请耐心等待',
    '系统提示：游戏中禁止透露身份信息',
    '系统提示：祝各位玩家游戏愉快',
  ];
  final Map<String, bool> settings = {
    '音乐': true,
    '音效': true,
    '开启视频': false,
    '其他玩家视频': true,
    '隐藏身份牌': false,
    '屏蔽礼物': false,
    '固定座位': true,
    '狼人发言可自爆': false,
  };
  final Map<String, String> _avatarUrls = {};
  final Set<String> _avatarLoading = {};
  bool ready = false;
  bool talking = false;
  String? error;

  Future<void> _loadAvatar(Map<String, dynamic> item) async {
    final key = '${item['avatarKey'] ?? ''}'.trim();
    if (key.isEmpty ||
        _avatarUrls.containsKey(key) ||
        _avatarLoading.contains(key)) {
      return;
    }
    _avatarLoading.add(key);
    try {
      final url = await service.resolveAvatarUrl(await _token(), key);
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _avatarUrls[key] = url);
      }
    } catch (_) {
      // 加载失败时保留默认头像
    } finally {
      _avatarLoading.remove(key);
    }
  }

  Widget _occupiedAvatar(Map<String, dynamic> item) {
    final key = '${item['avatarKey'] ?? ''}'.trim();
    final url = _avatarUrls[key];
    if (key.isNotEmpty) _loadAvatar(item);
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff4c251f),
        border: Border.all(color: const Color(0xffe3a24e)),
      ),
      child: url == null
          ? const Icon(Icons.person_rounded, color: Color(0xffffc279), size: 24)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                  color: Color(0xffffc279), size: 24),
            ),
    );
  }

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
    _notebookController.dispose();
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

  Widget _settingRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x19c8965a))),
      ),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(color: Color(0xffe3d0b2), fontSize: 14))),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: const WidgetStatePropertyAll(Color(0xffffc477)),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? const Color(0xff874126)
                  : const Color(0xff30282b)),
        ),
      ]),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff151119),
      barrierColor: Colors.black.withValues(alpha: .72),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xffc8965a).withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(
                    child: Text('房间设置',
                        style: TextStyle(
                            color: Color(0xffffe4b8),
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2))),
                IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xffb69a7b))),
              ]),
              const SizedBox(height: 8),
              ...settings.keys.map((label) => _settingRow(
                  label,
                  settings[label]!,
                  (value) => setSheetState(() => settings[label] = value))),
            ]),
          ),
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
              child: occupied
                  ? _occupiedAvatar(item)
                  : const Icon(Icons.shield_rounded,
                      color: Color(0xffffc279), size: 24),
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

  Widget _inviteButton() => GestureDetector(
        onTap: () => setState(() => error = '邀请功能暂未接入'),
        child: Container(
          width: 78,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xff21191a),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x8cc8965a)),
          ),
          child: const Text('邀请',
              style: TextStyle(
                  color: Color(0xffe6c59c),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ),
      );

  Widget _holdTalkButton() => GestureDetector(
        onLongPressStart: (_) => setState(() => talking = true),
        onLongPressEnd: (_) => setState(() => talking = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: talking ? const Color(0xff7e3825) : const Color(0xff21191a),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: talking
                    ? const Color(0xffffb26d)
                    : const Color(0x8cc8965a)),
            boxShadow: talking
                ? [const BoxShadow(color: Color(0x59e26136), blurRadius: 16)]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(talking ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 17, color: const Color(0xffffd39d)),
            const SizedBox(width: 6),
            Text(talking ? '正在发言' : '按住发言',
                style: const TextStyle(
                    color: Color(0xffe6c59c),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
  Widget _startedSeatRow(int index, bool left) {
    final item = seat(index);
    final occupied = item != null;
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: occupied
                        ? const Color(0xff4c251f)
                        : const Color(0xff8b5a2a),
                    border: Border.all(color: const Color(0xffe3a24e))),
                child: occupied
                    ? _occupiedAvatar(item)
                    : const Icon(Icons.shield_rounded,
                        color: Color(0xffffc279), size: 24)),
            if (occupied) ...[
              const SizedBox(width: 5),
              SizedBox(
                  width: 62,
                  child: Column(
                      crossAxisAlignment: left
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Text('${item['nickname'] ?? '玩家'}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xffffddb5),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        Text('Lv.${item['userId'] ?? '-'}',
                            style: const TextStyle(
                                color: Color(0xffd89558),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noticeLine(String text) => Row(children: [
        const Icon(Icons.info_outline_rounded,
            size: 13, color: Color(0xffd99a5e)),
        const SizedBox(width: 7),
        Expanded(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Color(0xffb9a28a), fontSize: 10))),
      ]);

  void _showAllNotices() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xff16131b),
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 80),
        child: Container(
          height: MediaQuery.of(context).size.height * .62,
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          child: Column(children: [
            Row(children: [
              const Expanded(
                  child: Text('全部系统提示',
                      style: TextStyle(
                          color: Color(0xffffe4b8),
                          fontSize: 17,
                          fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xffcbb49a))),
            ]),
            const Divider(color: Color(0x33c8965a), height: 1),
            const SizedBox(height: 8),
            Expanded(
                child: SingleChildScrollView(
                    child: Column(
                        children: _noticeLines.map(_noticeLine).toList()))),
          ]),
        ),
      ),
    );
  }

  Widget _startedNotice() => Container(
        width: double.infinity,
        height: 92,
        padding: const EdgeInsets.fromLTRB(20, 7, 12, 7),
        decoration: const BoxDecoration(color: Color(0xd4141219)),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.only(right: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _noticeLines.take(5).map(_noticeLine).toList(),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _showAllNotices,
              icon: const Icon(Icons.open_in_full_rounded,
                  size: 17, color: Color(0xffd99a5e)),
            ),
          ),
        ]),
      );

  Widget _bottomAction(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xff21191a),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x8cc8965a)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: const Color(0xffe7b36f)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Color(0xffe6c59c),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _startedBottomBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(children: [
          Expanded(
              child:
                  _bottomAction(Icons.menu_book_rounded, '记事本', _showNotebook)),
          const SizedBox(width: 10),
          Expanded(
              child: _bottomAction(
                  Icons.how_to_vote_rounded, '投票记录', _showVoteRecords)),
          const SizedBox(width: 10),
          Expanded(
              child: _bottomAction(Icons.card_giftcard_rounded, '送礼', null)),
        ]),
      );

  void _showNotebook() {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xff151119),
        builder: (sheet) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(sheet).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('我的记事本',
                  style: TextStyle(
                      color: Color(0xffffe4b8),
                      fontSize: 19,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                  controller: _notebookController,
                  maxLines: 5,
                  style: const TextStyle(color: Color(0xfff1ddbb)),
                  decoration: const InputDecoration(
                      hintText: '记录玩家发言、身份猜测或投票思路…', filled: true)),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => Navigator.pop(sheet),
                      child: const Text('保存笔记'))),
            ])));
  }

  void _showVoteRecords() {
    showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
                backgroundColor: const Color(0xff151119),
                title: const Text(
                  '投票记录',
                  style: TextStyle(color: Color(0xffffe4b8)),
                ),
                content: const Text(
                  '暂无真实投票记录',
                  style: TextStyle(color: Color(0xffb9a28a)),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('关闭'))
                ]));
  }

  Widget _startedPage(String code) {
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
                      const Text('预女猎守',
                          style: TextStyle(
                              color: Color(0xffffe4b8),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4)),
                      Text('房间号  $code',
                          style: const TextStyle(
                              color: Color(0xff9e8b77),
                              fontSize: 11,
                              letterSpacing: 1.1)),
                    ])),
                IconButton(
                    onPressed: _showSettings,
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: Color(0xffcbb49a))),
              ])),
          Expanded(
              child: LayoutBuilder(
                  builder: (context, c) => Padding(
                      padding: const EdgeInsets.fromLTRB(0, 18, 6, 12),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                children: List.generate(
                                    6,
                                    (i) => Expanded(
                                        child: _startedSeatRow(i, true))))),
                        SizedBox(width: c.maxWidth * .28),
                        Expanded(
                            child: Column(
                                children: List.generate(
                                    6,
                                    (i) => Expanded(
                                        child:
                                            _startedSeatRow(i + 6, false))))),
                      ])))),
          _startedNotice(),
          _startedBottomBar(),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = '${room['roomCode'] ?? ''}';
    if (room['status'] == 'started') return _startedPage(roomCode);
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
                      const Text('预女猎守',
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
                    ])),
                IconButton(
                    onPressed: _showSettings,
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: Color(0xffcbb49a))),
              ])),
          Expanded(
              child: LayoutBuilder(
                  builder: (context, c) => Stack(children: [
                        Positioned.fill(
                            child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(6, 18, 6, 12),
                                child: Row(children: [
                                  Expanded(
                                      child: Column(
                                          children: List.generate(
                                              6,
                                              (i) => Expanded(
                                                  child: _seatRow(i, true))))),
                                  SizedBox(width: c.maxWidth * .28),
                                  Expanded(
                                      child: Column(
                                          children: List.generate(
                                              6,
                                              (i) => Expanded(
                                                  child: _seatRow(
                                                      i + 6, false))))),
                                ]))),
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
                                              color: const Color(0xffe05a31)
                                                  .withValues(
                                                      alpha: .10 +
                                                          _pulse.value * .08),
                                              blurRadius: 30,
                                              spreadRadius: 7)
                                        ]),
                                    child: const Text('等待开局',
                                        style: TextStyle(
                                            color: Color(0xffffe4b8),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2))))),
                      ]))),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(error!,
                    style: const TextStyle(color: Colors.redAccent))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: SizedBox(
              width: 124,
              height: 46,
              child: FilledButton(
                onPressed: _toggleReady,
                child: Text(ready ? '已准备 ✓' : '准备'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(children: [
              _inviteButton(),
              const SizedBox(width: 10),
              Expanded(child: _holdTalkButton()),
            ]),
          ),
        ])),
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
