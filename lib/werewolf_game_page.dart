part of 'main.dart';

class WerewolfGamePage extends StatefulWidget {
  const WerewolfGamePage({super.key});

  @override
  State<WerewolfGamePage> createState() => _WerewolfGamePageState();
}

class _WerewolfGamePageState extends State<WerewolfGamePage>
    with TickerProviderStateMixin {
  late final AnimationController _eyeCtrl;
  late final AnimationController _panelCtrl;

  bool _showMatch = false;
  String _selectedZone = '进阶区';
  bool _matching = false;
  String _startBtnText = '开始匹配';
  final roomController = TextEditingController();
  final service = DDPostService();
  String? roomCode;
  String? error;

  static const List<double> _farHeights = [
    0.35,
    0.43,
    0.36,
    0.49,
    0.39,
    0.47,
    0.38,
    0.52,
    0.40,
    0.50,
    0.38,
    0.48,
    0.37,
    0.51,
    0.36,
    0.49,
    0.39,
    0.47,
    0.38,
    0.50,
    0.37,
    0.46,
    0.39,
    0.49,
    0.35,
    0.51,
    0.37,
    0.48,
    0.38,
    0.50,
    0.36,
    0.49,
    0.38,
    0.51,
    0.35,
  ];
  static const List<double> _midHeights = [
    0.30,
    0.52,
    0.36,
    0.58,
    0.40,
    0.52,
    0.38,
    0.60,
    0.37,
    0.55,
    0.36,
    0.58,
    0.38,
    0.54,
    0.35,
    0.60,
    0.37,
    0.55,
    0.38,
    0.58,
    0.36,
    0.56,
    0.38,
    0.60,
    0.37,
    0.54,
    0.36,
    0.58,
    0.38,
    0.56,
    0.35,
    0.59,
    0.38,
    0.55,
    0.30,
  ];
  static const List<double> _nearHeights = [
    0.55,
    0.25,
    0.50,
    0.18,
    0.48,
    0.22,
    0.52,
    0.16,
    0.46,
    0.20,
    0.54,
    0.14,
    0.48,
    0.18,
    0.52,
    0.15,
    0.50,
    0.20,
    0.46,
    0.16,
    0.52,
    0.14,
    0.48,
    0.18,
    0.54,
    0.16,
    0.46,
    0.20,
    0.50,
    0.18,
    0.52,
    0.15,
    0.55,
  ];

  @override
  void initState() {
    super.initState();
    _eyeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..repeat();
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _eyeCtrl.dispose();
    _panelCtrl.dispose();
    roomController.dispose();
    service.dispose();
    super.dispose();
  }

  void _openMatch() {
    setState(() => _showMatch = true);
    _panelCtrl.forward();
  }

  Future<void> _closeMatch() async {
    if (_matching) {
      _matching = false;
      final token = await _token();
      await service.stopWerewolfMatch(token);
    }
    setState(() {
      _showMatch = false;
      _matching = false;
      _startBtnText = '开始匹配';
    });
    _panelCtrl.reverse();
  }

  Future<String> _token() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('friend.auth.token') ?? '';
    if (t.isEmpty) throw Exception('请先登录');
    return t;
  }

  Future<void> _startMatching() async {
    if (_matching) return;
    setState(() {
      _matching = true;
      _startBtnText = '匹配中…';
      error = null;
    });
    try {
      final d = await service.startWerewolfMatch(await _token());
      final code = '${d['roomCode'] ?? ''}';
      if (code.isNotEmpty && mounted) {
        setState(() {
          roomCode = code;
          _startBtnText = '匹配成功';
        });
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) _showRoomCode();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          _matching = false;
          _startBtnText = '开始匹配';
        });
      }
    }
  }

  Future<void> _createRoom() async {
    try {
      final d = await service.createWerewolfRoom(await _token());
      if (mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => WerewolfRoomPage(room: d)));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _findRoom() async {
    roomController.clear();
    final passwordController = TextEditingController();
    try {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                backgroundColor: const Color(0xff19130f),
                title: const Text('查找房间',
                    style: TextStyle(color: Color(0xffe8d5b0))),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: roomController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: '房间号')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: '密码')),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () async {
                        final code = roomController.text.trim();
                        final password = passwordController.text;
                        if (code.isEmpty || password.isEmpty) {
                          setState(() => error = '请输入房间号和密码');
                          return;
                        }
                        Navigator.pop(context);
                        try {
                          final d = await service.joinWerewolfRoom(
                              await _token(), code, password);
                          if (!mounted) return;
                          Navigator.of(this.context).push(MaterialPageRoute(
                              builder: (_) => WerewolfRoomPage(room: d)));
                        } catch (e) {
                          if (mounted) setState(() => error = '$e');
                        }
                      },
                      child: const Text('进入房间'))
                ],
              ));
    } finally {
      passwordController.dispose();
    }
  }

  void _showRoomCode() {
    if (!mounted) return;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: const Color(0xff19130f),
              title: const Text('狼人杀房间',
                  style: TextStyle(color: Color(0xffe8d5b0))),
              content: Text('房间号：$roomCode',
                  style: const TextStyle(color: Colors.white, fontSize: 20)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // 天空
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B0F1A),
                  Color(0xFF101725),
                  Color(0xFF1B1F2B),
                  Color(0xFF2B1D1C),
                  Color(0xFF1A1212),
                  Color(0xFF0D0A0A),
                ],
                stops: [0.0, 0.25, 0.45, 0.65, 0.85, 1.0],
              ),
            ),
          ),
          // 星空
          Positioned.fill(
              child: CustomPaint(painter: _StarsPainter(animation: _eyeCtrl))),
          // 血月
          Positioned(
            top: size.height * 0.20,
            left: (size.width - 210) / 2,
            child: _buildMoon(),
          ),
          // 远景森林
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.46,
            child: CustomPaint(
              painter: _ForestPainter(
                heights: _farHeights,
                color: const Color(0xFF0F1319).withValues(alpha: 0.55),
              ),
            ),
          ),
          // 中景森林
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.38,
            child: CustomPaint(
              painter: _ForestPainter(
                heights: _midHeights,
                color: const Color(0xFF090C10).withValues(alpha: 0.85),
              ),
            ),
          ),
          // 雾
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.16,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF3C4B5A).withValues(alpha: 0.12),
                    const Color(0xFF28323E).withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // 爪印
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.10,
            height: 120,
            child: CustomPaint(painter: _PawPainter()),
          ),
          // 红眼
          _buildEyes(size),
          // 标题
          _buildTitle(size),
          // 按钮
          _buildActions(size),
          // 近景森林
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.26,
            child: CustomPaint(
              painter: _ForestPainter(
                heights: _nearHeights,
                color: const Color(0xFF04060A),
              ),
            ),
          ),
          // 底部文字
          _buildBottomHint(size),
          // 暗角
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.32, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // 匹配覆盖层
          _buildMatchOverlay(size),
        ],
      ),
    );
  }

  // ===== 修复方形边缘的月亮 =====
  Widget _buildMoon() {
    return AnimatedBuilder(
      animation: _eyeCtrl,
      builder: (context, child) {
        final t = _eyeCtrl.value * 2 * math.pi;
        final glow = 0.88 + 0.12 * (0.5 + 0.5 * math.sin(t));
        return Opacity(opacity: glow, child: child);
      },
      child: SizedBox(
        width: 210,
        height: 210,
        child: Stack(
          clipBehavior: Clip.none, // 允许外层发光溢出
          children: [
            // 使用 RadialGradient 来做环境泛光，去除了容易引起 Bug 的 boxShadow
            Positioned(
              left: -80,
              top: -80,
              right: -80,
              bottom: -80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFDC8C50).withValues(alpha: 0.35),
                      const Color(0xFFC85032).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            // 月亮本体
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.24, -0.36),
                  radius: 0.9,
                  colors: [
                    Color(0xFFF5E6C8),
                    Color(0xFFE8C99A),
                    Color(0xFFD4A06B),
                    Color(0xFFB87448),
                    Color(0xFF8B4A30),
                  ],
                  stops: [0.0, 0.25, 0.5, 0.72, 1.0],
                ),
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    _crater(left: 40, top: 45, d: 44, a: 0.35),
                    _crater(right: 40, top: 65, d: 32, a: 0.28),
                    _crater(left: 70, top: 115, d: 56, a: 0.30),
                    _crater(right: 55, top: 120, d: 24, a: 0.22),
                    _crater(left: 26, top: 110, d: 20, a: 0.25),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _crater({
    double? left,
    double? top,
    double? right,
    required double d,
    required double a,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF8C5537).withValues(alpha: a),
        ),
      ),
    );
  }

  // ===== 红眼 =====
  Widget _buildEyes(Size size) {
    return Stack(
      children: [
        _eyePair(
          left: size.width * 0.09,
          bottom: size.height * 0.20,
          eyeSize: 8,
          gap: 12,
          rotate: -4,
          baseOpacity: 0.85,
          phase: 0.0,
        ),
        _eyePair(
          left: size.width * 0.31,
          bottom: size.height * 0.135,
          eyeSize: 11,
          gap: 15,
          rotate: 3,
          baseOpacity: 1.0,
          phase: 0.24,
        ),
        _eyePair(
          right: size.width * 0.12,
          bottom: size.height * 0.20,
          eyeSize: 9,
          gap: 13,
          rotate: -3,
          baseOpacity: 0.9,
          phase: 0.44,
        ),
        _eyePair(
          right: size.width * 0.31,
          bottom: size.height * 0.25,
          eyeSize: 6,
          gap: 8,
          rotate: 2,
          baseOpacity: 0.65,
          phase: 0.65,
        ),
      ],
    );
  }

  Widget _eyePair({
    double? left,
    double? right,
    required double bottom,
    required double eyeSize,
    required double gap,
    required double rotate,
    required double baseOpacity,
    required double phase,
  }) {
    return Positioned(
      left: left,
      right: right,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: _eyeCtrl,
        builder: (context, child) {
          final t = (_eyeCtrl.value + phase) % 1.0;
          final o = 0.55 + 0.40 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
          return Opacity(
            opacity: (baseOpacity * o).clamp(0.0, 1.0),
            child: child,
          );
        },
        child: Transform.rotate(
          angle: rotate * math.pi / 180,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _eye(eyeSize),
              SizedBox(width: gap),
              _eye(eyeSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eye(double s) {
    return Container(
      width: s,
      height: s * 0.62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(0, -0.1),
          colors: [
            Color(0xFFFFE0C0),
            Color(0xFFFF7A3C),
            Color(0xFFE03A1A),
            Color(0xFF8A1A08),
          ],
          stops: [0.0, 0.32, 0.62, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6461E).withValues(alpha: 0.85),
            blurRadius: 6,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFC82814).withValues(alpha: 0.5),
            blurRadius: 18,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: const Color(0xFFA0140A).withValues(alpha: 0.22),
            blurRadius: 44,
            spreadRadius: 14,
          ),
        ],
      ),
    );
  }

  // ===== 标题 =====
  Widget _buildTitle(Size size) {
    return Positioned(
      top: size.height * 0.09,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Text(
            '狼 人 杀',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: const Color(0xFFE8D5B0),
              fontFamilyFallback: const [
                'STKaiti',
                'KaiTi',
                'Noto Serif SC',
                'SimSun'
              ],
              shadows: [
                Shadow(
                    color: const Color(0xFFC8783C).withValues(alpha: 0.6),
                    blurRadius: 12),
                Shadow(
                    color: const Color(0xFFB44628).withValues(alpha: 0.4),
                    blurRadius: 32),
                Shadow(
                    color: Colors.black.withValues(alpha: 0.9),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'W E R E W O L F',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 5,
              color: const Color(0xFF9A8A70),
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.9), blurRadius: 3),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 70,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFC8965A).withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 主按钮组 =====
  Widget _buildActions(Size size) {
    return Positioned(
      top: size.height * 0.70,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _sideButton('建房', _createRoom),
          const SizedBox(width: 14),
          _mainButton('快速匹配', _openMatch),
          const SizedBox(width: 14),
          _sideButton('查找', _findRoom),
        ],
      ),
    );
  }

  Widget _sideButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xD21C1612), Color(0xE6100C0A)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: const Color(0xFFC8965A).withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamilyFallback: const [
              'STKaiti',
              'KaiTi',
              'Noto Serif SC',
              'SimSun'
            ],
            fontSize: 14,
            letterSpacing: 1.6,
            color: const Color(0xFFE8D5B0),
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xEB482016), Color(0xF2220F0C)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: const Color(0xFFE6A05A).withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD25A2D).withValues(alpha: 0.38),
                blurRadius: 18),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamilyFallback: const [
              'STKaiti',
              'KaiTi',
              'Noto Serif SC',
              'SimSun'
            ],
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: const Color(0xFFFFE4B8),
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 3),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 底部文字 =====
  Widget _buildBottomHint(Size size) {
    return Positioned(
      bottom: size.height * 0.055,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            width: 120,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFB48250).withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '黑 夜 降 临 · 谁 是 狼 人',
            style: TextStyle(
              fontFamilyFallback: const [
                'STKaiti',
                'KaiTi',
                'Noto Serif SC',
                'SimSun'
              ],
              fontSize: 13,
              letterSpacing: 4,
              color: const Color(0xFF8A7A62),
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.9), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'N I G H T   F A L L S',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 3,
              color: const Color(0xFF5A5045),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 匹配覆盖层 =====
  Widget _buildMatchOverlay(Size size) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showMatch,
        child: AnimatedOpacity(
          opacity: _showMatch ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            children: [
              GestureDetector(
                onTap: _closeMatch,
                child: Container(
                    color: const Color(0xFF050608).withValues(alpha: 0.72)),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSlide(
                  offset: _showMatch ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: _buildPanel(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1310), Color(0xFF0D0907)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(
              color: const Color(0xFFC8965A).withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 40,
              offset: const Offset(0, -10)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(22, 22, 22, 30 + safeBottom),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8A06E).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '选 择 匹 配 区',
                style: TextStyle(
                  fontFamilyFallback: const [
                    'STKaiti',
                    'KaiTi',
                    'Noto Serif SC',
                    'SimSun'
                  ],
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: const Color(0xFFE8D5B0),
                  shadows: [
                    Shadow(
                        color: const Color(0xFFC8783C).withValues(alpha: 0.4),
                        blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _zoneItem('新手区', '初入狼村 · 轻松对局', '入门'),
              const SizedBox(height: 10),
              _zoneItem('进阶区', '策略博弈 · 高手过招', '推荐'),
              const SizedBox(height: 10),
              _zoneItem('排位区', '巅峰对决 · 王者之争', '高难'),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF141010).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFC8965A).withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '版 型',
                      style: TextStyle(
                        fontFamilyFallback: const [
                          'STKaiti',
                          'KaiTi',
                          'Noto Serif SC',
                          'SimSun'
                        ],
                        fontSize: 13,
                        letterSpacing: 3,
                        color: const Color(0xFF8A7A62),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE08A3E),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE08A3E)
                                    .withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '预女猎守',
                          style: TextStyle(
                            fontFamilyFallback: const [
                              'STKaiti',
                              'KaiTi',
                              'Noto Serif SC',
                              'SimSun'
                            ],
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: const Color(0xFFF0D9B4),
                            shadows: [
                              Shadow(
                                  color: const Color(0xFFD26E32)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: _startMatching,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xF5582618), Color(0xFA26100C)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: const Color(0xFFE6A05A).withValues(alpha: 0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD25A2D)
                            .withValues(alpha: _matching ? 0.6 : 0.42),
                        blurRadius: _matching ? 26 : 22,
                      ),
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 22,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Text(
                    _startBtnText,
                    style: TextStyle(
                      fontFamilyFallback: const [
                        'STKaiti',
                        'KaiTi',
                        'Noto Serif SC',
                        'SimSun'
                      ],
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: const Color(0xFFFFE4B8),
                      shadows: [
                        Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 关闭按钮
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: _closeMatch,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF141010).withValues(alpha: 0.7),
                  border: Border.all(
                      color: const Color(0xFFC8965A).withValues(alpha: 0.25)),
                ),
                child: const Text(
                  '✕',
                  style: TextStyle(fontSize: 13, color: Color(0xFFA89478)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneItem(String name, String desc, String tag) {
    final selected = _selectedZone == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedZone = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xEB4E2418), Color(0xF526110D)],
                )
              : null,
          color:
              selected ? null : const Color(0xFF1E1814).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFE6A05A).withValues(alpha: 0.85)
                : const Color(0xFFC8965A).withValues(alpha: 0.16),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFD25A2D).withValues(alpha: 0.32),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamilyFallback: const [
                            'STKaiti',
                            'KaiTi',
                            'Noto Serif SC',
                            'SimSun'
                          ],
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                          color: selected
                              ? const Color(0xFFFFE4B8)
                              : const Color(0xFFE0CCAB),
                          shadows: selected
                              ? [
                                  Shadow(
                                    color: const Color(0xFFDC783C)
                                        .withValues(alpha: 0.55),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: selected
                              ? const Color(0xFFB39473)
                              : const Color(0xFF86765E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFE6A05A).withValues(alpha: 0.55)
                          : const Color(0xFFC8965A).withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: selected
                          ? const Color(0xFFFFD9A8)
                          : const Color(0xFF8A7A62),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===== CustomPainters =====

class _ForestPainter extends CustomPainter {
  final List<double> heights;
  final Color color;
  _ForestPainter({required this.heights, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()..moveTo(0, size.height);
    for (int i = 0; i < heights.length; i++) {
      final x = size.width * i / (heights.length - 1);
      final y = size.height * (1 - heights[i]);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ForestPainter oldDelegate) =>
      oldDelegate.heights != heights || oldDelegate.color != color;
}

class _PawPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5A6878).withValues(alpha: 0.22);
    const paws = <List<double>>[
      [0.15, 0.68, -14, 1.0],
      [0.28, 0.55, -6, 0.9],
      [0.69, 0.62, 10, 1.0],
      [0.82, 0.77, 16, 0.9],
      [0.50, 0.80, -2, 0.8],
    ];
    for (final p in paws) {
      final cx = size.width * p[0];
      final cy = size.height * p[1];
      final angle = p[2] * math.pi / 180;
      final s = p[3];
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, 8 * s),
          width: 18 * s,
          height: 14 * s,
        ),
        paint,
      );
      final toes = <List<double>>[
        [-12, -4, 3.6],
        [-4, -10, 3.6],
        [5, -10, 3.6],
        [12, -3, 3.6],
      ];
      for (final t in toes) {
        canvas.drawCircle(Offset(t[0] * s, t[1] * s), t[2] * s, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({required this.animation}) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint();
    for (int i = 0; i < 40; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height * 0.5;
      final r = 0.5 + rand.nextDouble() * 0.8;
      final phase = (animation.value + i * 0.071) % 1.0;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
      paint.color = Colors.white.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), r * (0.85 + twinkle * 0.25), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) =>
      oldDelegate.animation.value != animation.value;
}
