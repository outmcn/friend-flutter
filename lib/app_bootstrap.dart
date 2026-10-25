part of 'main.dart';

class _GlobalScrollToTopRegistry {
  static final controllers = <ScrollController>{};
  static void register(ScrollController controller) =>
      controllers.add(controller);
  static void unregister(ScrollController controller) =>
      controllers.remove(controller);
  static void scrollTop() {
    for (final controller in List<ScrollController>.of(controllers)) {
      if (!controller.hasClients) continue;
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({
    required this.avatarUrl,
    this.frameAsset,
    this.size = 48,
    this.placeholder,
  });
  final String avatarUrl;
  final String? frameAsset;
  final double size;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final frame = frameAsset?.trim() ?? '';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: avatarUrl.trim().isEmpty
                ? (placeholder ??
                    const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.person_outline),
                    ))
                : _PermanentCachedImage(
                    url: avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: placeholder ??
                        const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.person_outline),
                        ),
                  ),
          ),
          if (frame.isNotEmpty)
            Positioned.fill(
              child:
                  IgnorePointer(child: Image.asset(frame, fit: BoxFit.contain)),
            ),
        ],
      ),
    );
  }
}

OverlayEntry? _activeTopNotice;

String _simplifyNoticeText(String value) {
  var text = value.trim();
  text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');
  text = text.replaceFirst(RegExp(r'^Error:\s*'), '');
  text =
      text.replaceFirst(RegExp(r'\s*\(HTTP\s*\d+\)', caseSensitive: false), '');
  text = text.replaceFirst(RegExp(r'\s*HTTP\s*\d+', caseSensitive: false), '');
  const replacements = {
    'Network is unreachable': '网络不可用',
    'Connection refused': '网络连接失败',
    'Connection reset by peer': '网络连接中断',
    'Failed host lookup': '网络连接失败',
    'SocketException': '网络连接失败',
    'TimeoutException': '请求超时',
    'Request timeout': '请求超时',
    'Unauthorized': '登录状态已失效',
    'Forbidden': '暂无权限',
    'Not Found': '内容不存在',
    'Internal Server Error': '服务器暂时不可用',
    'The data couldn\'t be read because it isn\'t in the correct format':
        '数据格式错误',
  };
  for (final entry in replacements.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  if (text.isEmpty) return '操作失败';
  return text.length > 80 ? '${text.substring(0, 80)}…' : text;
}

Widget _simplifyNoticeContent(Widget content) {
  if (content is Text && content.data != null) {
    return Text(_simplifyNoticeText(content.data!),
        maxLines: 2, overflow: TextOverflow.ellipsis);
  }
  return content;
}

void _showTopNotice(BuildContext context, Widget content,
    {VoidCallback? onTap}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _activeTopNotice?.remove();
  late OverlayEntry entry;
  void close() {
    if (identical(_activeTopNotice, entry)) _activeTopNotice = null;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _FloatingNotice(
      content: _simplifyNoticeContent(content),
      onTap: onTap,
      onClose: close,
    ),
  );
  _activeTopNotice = entry;
  overlay.insert(entry);
}

class _FloatingNotice extends StatefulWidget {
  const _FloatingNotice(
      {required this.content, this.onTap, required this.onClose});
  final Widget content;
  final VoidCallback? onTap;
  final VoidCallback onClose;

  @override
  State<_FloatingNotice> createState() => _FloatingNoticeState();
}

class _FloatingNoticeState extends State<_FloatingNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(seconds: 5), widget.onClose);
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: controller, curve: Curves.easeOutCubic)),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(child: widget.content),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DDApp extends StatelessWidget {
  const DDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _appNavigatorKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Stack(
        children: [
          _KeyboardDismissBehavior(child: child ?? const SizedBox.shrink()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _GlobalScrollToTopRegistry.scrollTop,
            ),
          ),
        ],
      ),
      title: 'DD',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffa77bff),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7f5fb),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xff342047),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          contentTextStyle: const TextStyle(color: Colors.white70),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18))),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        tooltipTheme: const TooltipThemeData(
          triggerMode: TooltipTriggerMode.manual,
          waitDuration: Duration(days: 365),
          showDuration: Duration.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xffefedf4),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          hintStyle: TextStyle(color: Colors.black54),
          prefixIconColor: Colors.black54,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: const Color(0xffa77bff).withValues(alpha: .72),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff101010),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffa77bff),
          brightness: Brightness.dark,
        ),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xff342047),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          contentTextStyle: const TextStyle(color: Colors.white70),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18))),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        tooltipTheme: const TooltipThemeData(
          triggerMode: TooltipTriggerMode.manual,
          waitDuration: Duration(days: 365),
          showDuration: Duration.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff242329),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          hintStyle: TextStyle(color: Colors.white54),
          prefixIconColor: Colors.white70,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
                color: const Color(0xffa77bff).withValues(alpha: .72)),
          ),
        ),
      ),
      home: const StartupNetworkGate(),
    );
  }
}

class _KeyboardDismissBehavior extends StatefulWidget {
  const _KeyboardDismissBehavior({required this.child});
  final Widget child;

  @override
  State<_KeyboardDismissBehavior> createState() =>
      _KeyboardDismissBehaviorState();
}

class _KeyboardDismissBehaviorState extends State<_KeyboardDismissBehavior> {
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: widget.child,
      );
}

class StartupNetworkGate extends StatefulWidget {
  const StartupNetworkGate({super.key, this.checker});
  final Future<bool> Function()? checker;

  @override
  State<StartupNetworkGate> createState() => _StartupNetworkGateState();
}

class _StartupNetworkGateState extends State<StartupNetworkGate> {
  bool checking = true;
  bool connected = false;
  String? error;

  @override
  void initState() {
    super.initState();
    checkNetwork();
  }

  Future<bool> _probeNetwork() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(Uri.parse('https://friend.outmcn.com/health'))
          .timeout(const Duration(seconds: 10));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      return response.statusCode < 500;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> checkNetwork() async {
    if (mounted) {
      setState(() {
        checking = true;
        error = null;
      });
    }
    try {
      final reachable = await (widget.checker ?? _probeNetwork)();
      if (!mounted) return;
      setState(() {
        connected = reachable;
        checking = false;
        error = reachable ? null : '服务器暂时无法连接';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        connected = false;
        checking = false;
        error = '请检查网络连接后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!connected) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                const Text('网络连接失败',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(error ?? '请连接网络后重试', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: checkNetwork,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新连接'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const AuthGate();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  String? token;
  late final FriendAuthClient auth;
  StreamSubscription<Map<String, dynamic>>? _messageNoticeSubscription;

  @override
  void initState() {
    super.initState();
    auth = FriendAuthClient();
    _messageNoticeSubscription =
        ImSession.instance.events.listen(_handleMessageNotice);
    // Render the shell immediately; token restoration continues in the background.
    // A valid token will keep the user on the main page without a startup spinner.
    _restore();
  }

  void _handleMessageNotice(Map<String, dynamic> event) {
    if (!mounted || event['type'] != 'message:new') return;
    final message = event['message'];
    if (message is! Map) return;
    final senderId = '${message['senderId'] ?? message['sender_id'] ?? ''}';
    final selfId = ImSession.instance.userId ?? '';
    if (senderId.isEmpty || senderId == selfId) return;
    final text = '${message['text'] ?? ''}'.trim();
    final kind = '${message['kind'] ?? 'text'}';
    final preview = text.isNotEmpty
        ? text
        : (kind == 'image'
            ? '图片消息'
            : kind == 'audio'
                ? '语音消息'
                : '收到一条新消息');
    final conversationId =
        '${message['conversationId'] ?? message['conversation_id'] ?? ''}';
    _showTopNotice(
      context,
      Row(children: [
        const Text('收到新消息：'),
        Expanded(
            child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis))
      ]),
      onTap: conversationId.isEmpty
          ? null
          : () => unawaited(_openMessageConversation(conversationId)),
    );
  }

  Future<void> _openMessageConversation(String conversationId) async {
    final navigator = _appNavigatorKey.currentState;
    if (navigator == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    final currentUserId = prefs.getString('friend.auth.userId') ??
        ImSession.instance.userId ??
        '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final rows = await service.fetchImConversations(token);
      final conversation = rows.firstWhere((item) => item.id == conversationId,
          orElse: () => const DDConversation(id: '', kind: 'dm'));
      if (conversation.id.isEmpty) return;
      final peer = conversation.peer;
      final last = conversation.lastMessage;
      final chat = _ChatPreview(
        peer?.nickname ?? '用户',
        _conversationLastMessagePreview(last) ?? '',
        peer?.avatarUrl,
        peer?.avatarKey,
        peer?.id,
        conversation.id,
        conversation.unreadCount,
        conversation.peerReadMessageId,
        conversation.updatedAt,
        conversation.kind,
      );
      await navigator.push(MaterialPageRoute(
          builder: (_) =>
              _ChatDetailPage(chat: chat, currentUserId: currentUserId)));
    } finally {
      service.dispose();
    }
  }

  Future<void> _restore() async {
    final restored = await auth.restoreToken();
    if (restored != null) {
      await ImSession.instance.start(restored);
    }
    if (!mounted) return;
    setState(() {
      token = restored;
      loading = false;
    });
  }

  @override
  void dispose() {
    _messageNoticeSubscription?.cancel();
    auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (token != null) return const DDShell();
    if (loading) {
      return const DDShell();
    }
    return const PasswordLoginPage();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage(
      {super.key, required this.auth, required this.onAuthenticated});
  final FriendAuthClient auth;
  final ValueChanged<String> onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final phone = TextEditingController();
  final code = TextEditingController();
  Timer? timer;
  int seconds = 0;
  bool loading = false;
  bool sendingCode = false;
  String? error;

  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (sendingCode || seconds > 0) return;
    if (!RegExp(r'^1\d{10}$').hasMatch(phone.text.trim())) {
      setState(() => error = '请输入正确的手机号');
      return;
    }
    setState(() {
      sendingCode = true;
      error = null;
    });
    try {
      await widget.auth.sendSmsCode(phone.text.trim());
      if (!mounted) return;
      setState(() => seconds = 60);
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (seconds > 0) seconds--;
        });
      });
    } on FriendAuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = '无法连接新后端');
    } finally {
      if (mounted) setState(() => sendingCode = false);
    }
  }

  Future<void> _loginBySms() async {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone.text.trim())) {
      setState(() => error = '请输入正确的手机号');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = '请输入6位验证码');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.auth.loginBySms(
        phone: phone.text,
        code: code.text,
      );
      await ImSession.instance.start(value);
      if (mounted) widget.onAuthenticated(value);
    } on FriendAuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = '无法连接新后端');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '短信登录',
        subtitle: '使用手机号或密码登录',
        child: Column(
          children: [
            _AuthFieldController(
                label: '手机号码', icon: Icons.phone_outlined, controller: phone),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _AuthFieldController(
                    label: '验证码',
                    icon: Icons.verified_outlined,
                    controller: code),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: seconds == 0 && !sendingCode ? _sendCode : null,
                child: Text(sendingCode
                    ? '发送中…'
                    : seconds == 0
                        ? '获取验证码'
                        : '${seconds}s'),
              ),
            ]),
            if (error != null) ...[
              const SizedBox(height: 10),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(error!,
                      style: const TextStyle(color: Colors.orange))),
            ],
            const SizedBox(height: 18),
            _PrimaryAuthButton(
                label: loading ? '登录中…' : '登录 / 注册',
                onTap: loading ? () {} : _loginBySms),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PasswordLoginPage(initialPhone: phone.text.trim())),
              ),
              child: const Text('密码登录'),
            ),
          ],
        ),
      );
}

Widget _tdIcon(String name, {double size = 22, Color? color}) {
  final icons = <String, IconData>{
    'home': TIcons.home,
    'home-filled': TIcons.home_filled,
    'account': TIcons.user_avatar,
    'account-filled': TIcons.user_avatar_filled,
    'user-add': TIcons.user_add,
    'search': TIcons.search,
    'add': TIcons.add_circle,
    'minus': TIcons.remove,
    'chevron-right': TIcons.chevron_right,
    'notification': TIcons.notification,
    'bookmark': TIcons.bookmark,
    'heart': TIcons.heart,
    'comment': TIcons.chat_bubble,
    'share': TIcons.share,
    'link': TIcons.link,
    'more': TIcons.more,
    'back': TIcons.rollback,
    'video': TIcons.video,
    'video-filled': TIcons.video_filled,
  };
  return Icon(icons[name] ?? TIcons.help_circle, size: size, color: color);
}

Widget _iconFor(IconData icon, {double size = 22}) {
  final map = <IconData, String>{
    Icons.home_outlined: 'home',
    Icons.home: 'home-filled',
    Icons.person_outline: 'account',
    Icons.person: 'account-filled',
    Icons.search: 'search',
    Icons.notifications_none: 'notification',
    Icons.notifications: 'notification',
    Icons.bookmark_border: 'bookmark',
    Icons.favorite_border: 'heart',
    Icons.favorite: 'red-heart',
    Icons.chat_bubble_outline: 'comment',
    Icons.share_outlined: 'share',
    Icons.link: 'link',
    Icons.more_horiz: 'more',
    Icons.send: 'send',
    Icons.arrow_back: 'back',
    Icons.keyboard_arrow_down: 'down-arrow',
  };
  final name = map[icon];
  if (name == null) return _tdIcon('unknown', size: size);
  return _tdIcon(name, size: size, color: Colors.white);
}
