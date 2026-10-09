part of 'main.dart';

class DDApp extends StatelessWidget {
  const DDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          _KeyboardDismissBehavior(child: child ?? const SizedBox.shrink()),
      title: 'DD',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffa77bff),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7f5fb),
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
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
            return false;
          },
          child: widget.child,
        ),
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
          .getUrl(Uri.parse('https://api.outmcn.com/api'))
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
      return const DDShell();
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

  @override
  void initState() {
    super.initState();
    auth = FriendAuthClient();
    // Render the shell immediately; token restoration continues in the background.
    // A valid token will keep the user on the main page without a startup spinner.
    _restore();
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
    auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (token != null) return const DDShell();
    if (loading) {
      return const DDShell();
    }
    return AuthPage(
      auth: auth,
      onAuthenticated: (value) => setState(() => token = value),
    );
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
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = '请输入账号和密码');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.auth.login(
        username: username.text,
        password: password.text,
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
        title: '密码登录',
        subtitle: '使用手机号和密码登录 DD',
        child: Column(
          children: [
            _AuthFieldController(
                label: '手机号码',
                icon: Icons.phone_outlined,
                controller: username),
            const SizedBox(height: 14),
            _AuthFieldController(
                label: '密码',
                icon: Icons.lock_outline,
                controller: password,
                obscureText: true),
            if (error != null) ...[
              const SizedBox(height: 10),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(error!,
                      style: const TextStyle(color: Colors.orange))),
            ],
            const SizedBox(height: 18),
            _PrimaryAuthButton(
                label: loading ? '登录中…' : '登录',
                onTap: loading ? () {} : _login),
            TextButton(onPressed: () {}, child: const Text('没有账号？注册')),
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
    'search': TIcons.search,
    'notification': TIcons.notification,
    'bookmark': TIcons.bookmark,
    'heart': TIcons.heart,
    'comment': TIcons.chat_bubble,
    'share': TIcons.share,
    'link': TIcons.link,
    'more': TIcons.more,
    'back': TIcons.chevron_left,
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
