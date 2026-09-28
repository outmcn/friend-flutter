import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:tdesign_flutter_icons/tdesign_flutter_icons.dart' show TIcons;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models/ui_post.dart';
import 'pages/profile_page.dart';
import 'pages/message_page.dart';
import 'pages/game_page.dart';
import 'widgets/post_card.dart';
import 'widgets/discovery_top_bar.dart';
import 'pages/compose_page.dart';
import 'services/api_client.dart';
import 'services/location_service.dart';

const blue = Color(0xff4d8dff);

void main() => runApp(const FriendApp());

class FriendApp extends StatefulWidget {
  const FriendApp({super.key});
  @override
  State<FriendApp> createState() => _FriendAppState();
}

class _FriendAppState extends State<FriendApp> {
  String? token;
  bool _networkDialogShown = false;
  @override
  void initState() {
    super.initState();
    _loadToken();
    _requestStartupAccess();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => token = prefs.getString('friend.auth.token'));
  }

  Future<void> _requestStartupAccess() async {
    try {
      await _showNetworkAccessDialog();
      await LocationService().requestPermissionAtStartup();
    } catch (_) {
      // Permission denial is handled by the location service; startup remains usable.
    }
  }

  Future<void> _showNetworkAccessDialog() async {
    if (_networkDialogShown) return;
    _networkDialogShown = true;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要网络访问'),
        content: const Text('Friend 需要连接网络加载动态、消息和用户资料。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    await Connectivity().checkConnectivity();
  }

  @override
  Widget build(BuildContext context) {
    final light = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
    );
    final dark = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Friend',
      theme: appTheme(light),
      darkTheme: appTheme(dark),
      themeMode: ThemeMode.system,
      home: token == null
          ? LoginPage(onLogin: (value) => setState(() => token = value))
          : FriendShell(token: token!),
    );
  }

  ThemeData appTheme(ColorScheme colors) => ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    cardTheme: CardThemeData(
      color: colors.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainer,
      indicatorColor: colors.primaryContainer,
      height: 54,
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 10)),
      labelPadding: const EdgeInsets.only(top: 8, bottom: 0),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final ValueChanged<String> onLogin;
  const LoginPage({super.key, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final body = await const ApiClient(token: '').post(
        '/api/auth/login',
        body: {'username': user.text.trim(), 'password': password.text},
      );
      final token = (body['data'] as Map<String, dynamic>)['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('friend.auth.token', token);
      widget.onLogin(token);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.public, size: 70, color: blue),
              const SizedBox(height: 18),
              const Text(
                'Friend',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 42),
              TextField(
                controller: user,
                decoration: const InputDecoration(
                  hintText: '账号',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : login,
                child: Text(busy ? '登录中…' : '登录'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FriendShell extends StatefulWidget {
  final String token;
  const FriendShell({super.key, required this.token});
  @override
  State<FriendShell> createState() => _FriendShellState();
}

class _FriendShellState extends State<FriendShell> {
  int tab = 0;
  bool loadingPosts = true;
  final posts = <UiPost>[];
  String selectedFilter = '推荐';
  int filterRequestId = 0;
  bool postsRequestActive = false;
  String? discoveryError;
  Position? currentPosition;
  int currentUserId = 0;
  final profileKey = GlobalKey<ProfilePageState>();
  late final ApiClient _api = ApiClient(token: widget.token);
  final _location = LocationService();
  Future<Position?> _currentPosition() => _location.currentPosition();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadCurrentPosition();
    _loadCurrentUser();
  }

  Future<Position?> _freshPositionForPost() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('friend.location.cachedAt');
    await prefs.remove('friend.location.latitude');
    await prefs.remove('friend.location.longitude');
    return _currentPosition();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final body = await _api.get('/api/me');
      final data = body['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() => currentUserId = (data['id'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentPosition() async {
    final position = await _currentPosition();
    if (mounted) setState(() => currentPosition = position);
  }

  Future<void> _loadPosts() async {
    if (postsRequestActive) return;
    postsRequestActive = true;
    final requestId = ++filterRequestId;
    if (mounted) {
      setState(() {
        loadingPosts = true;
        discoveryError = null;
      });
    }
    try {
      final path = selectedFilter == '关注'
          ? '/api/posts/following'
          : selectedFilter == '附近'
          ? '/api/posts/nearby'
          : '/api/posts';
      final body = await _api.get(path);
      final data = body['data'];
      if (data is List) {
        final loaded = data
            .whereType<Map<String, dynamic>>()
            .map(UiPost.fromJson)
            .toList();
        if (mounted && requestId == filterRequestId) {
          setState(() {
            posts
              ..clear()
              ..addAll(loaded);
            loadingPosts = false;
            discoveryError = null;
          });
        }
        postsRequestActive = false;
        return;
      }
    } catch (e) {
      if (mounted && requestId == filterRequestId) {
        setState(() {
          loadingPosts = false;
          discoveryError = '加载失败，请重试';
        });
      }
    }
    postsRequestActive = false;
  }

  Future<void> _refreshAll() async {
    await _loadPosts();
    await profileKey.currentState?.refreshFromServer();
  }

  Future<void> _changeFilter(String filter) async {
    if (postsRequestActive) return;
    postsRequestActive = true;
    final requestId = ++filterRequestId;
    if (mounted) {
      setState(() {
        selectedFilter = filter;
        loadingPosts = true;
        discoveryError = null;
      });
    }
    final path = filter == '关注'
        ? '/api/posts/following'
        : filter == '附近'
        ? '/api/posts/nearby'
        : '/api/posts';
    try {
      final body = await _api.get(path);
      final data = body['data'];
      if (body['ok'] == true &&
          data is List &&
          mounted &&
          requestId == filterRequestId) {
        setState(() {
          posts
            ..clear()
            ..addAll(
              data.whereType<Map<String, dynamic>>().map(UiPost.fromJson),
            );
          loadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == filterRequestId) {
        setState(() {
          loadingPosts = false;
          discoveryError = '加载失败，请重试';
        });
      }
    }
    postsRequestActive = false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      DiscoveryPage(
        posts: posts,
        token: widget.token,
        onCreate: _createPost,
        onRefresh: _loadPosts,
        onActionChanged: _refreshAll,
        onFilterChanged: _changeFilter,
        selectedFilter: selectedFilter,
        currentLatitude: currentPosition?.latitude,
        currentLongitude: currentPosition?.longitude,
        currentUserId: currentUserId,

        loading: loadingPosts,
        error: discoveryError,
      ),
      MessagePage(token: widget.token),
      ProfilePage(key: profileKey, token: widget.token),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          height: 54,
          labelPadding: EdgeInsets.only(top: 1, bottom: 0),
        ),
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) {
            HapticFeedback.selectionClick();
            setState(() => tab = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.cd),
              ),
              selectedIcon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.cd_filled),
              ),
              label: '主页',
            ),
            NavigationDestination(
              icon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.dart_board),
              ),
              selectedIcon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.dart_board_filled),
              ),
              label: '发现',
            ),
            NavigationDestination(
              icon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.chat_bubble_1),
              ),
              selectedIcon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.chat_bubble_1_filled),
              ),
              label: '消息',
            ),
            NavigationDestination(
              icon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.highlight_1),
              ),
              selectedIcon: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(TIcons.highlight_1_filled),
              ),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost(String text, XFile? image) async {
    final content = text.trim();
    if (content.isEmpty && image == null) return;
    try {
      String? imageData;
      if (image != null) {
        final bytes = await image.readAsBytes();
        final decodedImage = img.decodeImage(bytes);
        if (decodedImage == null) throw Exception('图片读取失败');
        final resized = decodedImage.width > 2048 || decodedImage.height > 2048
            ? img.copyResize(
                decodedImage,
                width: decodedImage.width >= decodedImage.height ? 2048 : null,
                height: decodedImage.height > decodedImage.width ? 2048 : null,
              )
            : decodedImage;
        final compressed = Uint8List.fromList(
          img.encodeJpg(resized, quality: 90),
        );
        imageData = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      }
      final payload = <String, dynamic>{'content': content};
      final position = await _freshPositionForPost();
      if (position != null) {
        payload['latitude'] = position.latitude;
        payload['longitude'] = position.longitude;
      }
      if (imageData != null) payload['image'] = imageData;
      await _api.post('/api/posts', body: payload);
      await _loadPosts();
      await profileKey.currentState?.refreshFromServer();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openGame(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const GamePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff111111),
      child: SafeArea(
        child: ListView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            const Text(
              'Friend',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '找到真实的交流',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = 12.0;
                final leftWidth = (constraints.maxWidth - gap) * 0.49;
                final rightWidth = constraints.maxWidth - gap - leftWidth;
                final rightTopHeight = leftWidth * 0.52;
                final rightBottomHeight = leftWidth * 0.30;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: leftWidth,
                      height: leftWidth * 0.92,
                      child: _IrregularHomeCard(
                        clipper: const _PlayScriptClipper(),
                        gradient: const LinearGradient(
                          colors: [Color(0xffb6f5f2), Color(0xff89ddeb)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => _openGame(context),
                        child: const _PlayScriptContent(),
                      ),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: rightWidth,
                      child: Column(
                        children: [
                          SizedBox(
                            height: rightTopHeight,
                            child: _IrregularHomeCard(
                              clipper: const _HostScriptClipper(),
                              gradient: const LinearGradient(
                                colors: [Color(0xfff7b5ea), Color(0xffeca8e9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: () => _openGame(context),
                              child: const _HostScriptContent(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: rightBottomHeight,
                            child: _IrregularHomeCard(
                              clipper: const _ReasoningClipper(),
                              gradient: const LinearGradient(
                                colors: [Color(0xffd5f58a), Color(0xfff4f77b)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              onTap: () => _openGame(context),
                              child: const _ReasoningContent(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IrregularHomeCard extends StatelessWidget {
  const _IrregularHomeCard({
    required this.clipper,
    required this.gradient,
    required this.child,
    required this.onTap,
  });

  final CustomClipper<Path> clipper;
  final Gradient gradient;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: clipper,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PlayScriptContent extends StatelessWidget {
  const _PlayScriptContent();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 18,
          top: 28,
          child: Text(
            '玩剧本',
            style: TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Positioned(
          left: 18,
          top: 68,
          child: Text(
            '拨开迷雾  寻找真相',
            style: TextStyle(
              color: Color(0xff5d9195),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 25,
          child: Container(
            width: 112,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Text(
              'GO',
              style: TextStyle(
                color: Color(0xffeaf36e),
                fontSize: 28,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const Positioned(
          right: -8,
          bottom: -8,
          child: Text('🤖', style: TextStyle(fontSize: 128)),
        ),
      ],
    );
  }
}

class _HostScriptContent extends StatelessWidget {
  const _HostScriptContent();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 12,
          top: -10,
          child: Transform.rotate(
            angle: -0.06,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xffd927e5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  '首局特惠',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 18,
          top: 48,
          child: Text(
            '主持带本',
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Positioned(
          left: 18,
          top: 82,
          child: Text(
            '18周等候中',
            style: TextStyle(
              color: Color(0xff997398),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Positioned(
          right: -8,
          bottom: -10,
          child: Text('🧑‍🎤', style: TextStyle(fontSize: 92)),
        ),
      ],
    );
  }
}

class _ReasoningContent extends StatelessWidget {
  const _ReasoningContent();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: const [
        Positioned(
          left: 18,
          top: 22,
          child: Text(
            '三分钟推理',
            style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          right: -4,
          top: -18,
          child: Text('😮', style: TextStyle(fontSize: 76)),
        ),
      ],
    );
  }
}

class _PlayScriptClipper extends CustomClipper<Path> {
  const _PlayScriptClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(28, 0)
      ..quadraticBezierTo(size.width * .35, 10, size.width * .58, 0)
      ..quadraticBezierTo(size.width * .84, -7, size.width, 24)
      ..lineTo(size.width, size.height - 28)
      ..quadraticBezierTo(
        size.width * .88,
        size.height + 8,
        size.width * .62,
        size.height - 2,
      )
      ..quadraticBezierTo(
        size.width * .27,
        size.height + 9,
        22,
        size.height - 2,
      )
      ..quadraticBezierTo(-8, size.height * .7, 0, 28)
      ..quadraticBezierTo(7, 4, 28, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _PlayScriptClipper oldClipper) => false;
}

class _HostScriptClipper extends CustomClipper<Path> {
  const _HostScriptClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(24, 0)
      ..quadraticBezierTo(size.width * .55, 8, size.width - 24, 0)
      ..quadraticBezierTo(size.width + 8, 12, size.width, 30)
      ..lineTo(size.width, size.height - 24)
      ..quadraticBezierTo(
        size.width * .82,
        size.height + 6,
        size.width * .52,
        size.height - 1,
      )
      ..quadraticBezierTo(size.width * .2, size.height + 5, 0, size.height - 26)
      ..lineTo(0, 28)
      ..quadraticBezierTo(2, 5, 24, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _HostScriptClipper oldClipper) => false;
}

class _ReasoningClipper extends CustomClipper<Path> {
  const _ReasoningClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(22, 0)
      ..quadraticBezierTo(size.width * .5, 7, size.width - 25, 0)
      ..quadraticBezierTo(
        size.width + 6,
        size.height * .25,
        size.width,
        size.height - 20,
      )
      ..quadraticBezierTo(
        size.width * .76,
        size.height + 5,
        size.width * .42,
        size.height,
      )
      ..quadraticBezierTo(
        size.width * .12,
        size.height + 4,
        0,
        size.height - 22,
      )
      ..quadraticBezierTo(-5, size.height * .45, 22, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ReasoningClipper oldClipper) => false;
}

class HomeTopBar extends StatelessWidget {
  final VoidCallback? onQrCode;
  final VoidCallback? onSettings;
  final List<Widget> trailingActions;
  final bool showTitle;
  final bool showDefaultActions;
  const HomeTopBar({
    super.key,
    this.onQrCode,
    this.onSettings,
    this.trailingActions = const [],
    this.showTitle = true,
    this.showDefaultActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surface,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 5),
          child: Row(
            children: [
              if (showTitle)
                Text(
                  '主页',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
                ),
              const Spacer(),
              if (showDefaultActions) ...[
                IconButton(
                  onPressed:
                      onQrCode ??
                      () => showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text('二维码'),
                          content: Icon(Icons.qr_code_2, size: 190),
                        ),
                      ),
                  tooltip: '二维码',
                  icon: const Icon(Icons.qr_code_2_outlined),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  onPressed:
                      onSettings ??
                      () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => const SafeArea(
                          child: ListTile(
                            leading: Icon(Icons.settings_outlined),
                            title: Text('设置'),
                            subtitle: Text('设置功能正在完善'),
                          ),
                        ),
                      ),
                  tooltip: '设置',
                  icon: const Icon(Icons.settings_outlined),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
              ...trailingActions,
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryTextTab extends StatelessWidget {
  const _DiscoveryTextTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 4, 7, 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontSize: 20,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                width: selected ? 18 : 0,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoveryPage extends StatelessWidget {
  final List<UiPost> posts;
  final String token;
  final Future<void> Function(String, XFile?) onCreate;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onActionChanged;
  final Future<void> Function(String) onFilterChanged;
  final String selectedFilter;
  final bool loading;
  final String? error;
  final double? currentLatitude, currentLongitude;
  final int currentUserId;
  const DiscoveryPage({
    super.key,
    required this.posts,
    required this.token,
    required this.onCreate,
    required this.onRefresh,
    required this.onActionChanged,
    required this.onFilterChanged,
    required this.selectedFilter,
    required this.loading,
    required this.error,
    this.currentLatitude,
    this.currentLongitude,
    this.currentUserId = 0,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          toolbarHeight: 40,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              for (final option in DiscoveryTopBar.options) ...[
                _DiscoveryTextTab(
                  label: option,
                  selected: option == selectedFilter,
                  onTap: () {
                    if (option != selectedFilter) {
                      HapticFeedback.selectionClick();
                      onFilterChanged(option);
                    }
                  },
                ),
                if (option != DiscoveryTopBar.options.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => _compose(context),
              tooltip: '发布动态',
              icon: const Icon(Icons.loupe_outlined, size: 24),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: MasonryGridView.count(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              itemCount: posts.isNotEmpty ? posts.length : 1,
              itemBuilder: (context, index) {
                if (posts.isNotEmpty) {
                  return PostCard(
                    post: posts[index],
                    token: token,
                    onActionChanged: onActionChanged,
                    currentLatitude: currentLatitude,
                    currentLongitude: currentLongitude,
                    currentUserId: currentUserId,
                  );
                }
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (error != null) {
                  return _DiscoveryNotice(
                    icon: Icons.cloud_off_outlined,
                    message: error!,
                    actionLabel: '重新加载',
                    onAction: onRefresh,
                  );
                }
                return _DiscoveryNotice(
                  icon: Icons.auto_awesome_outlined,
                  message: selectedFilter == '关注'
                      ? '还没有关注的人发布动态'
                      : selectedFilter == '附近'
                      ? '附近暂无动态'
                      : '暂无动态',
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _compose(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ComposePage(onCreate: onCreate)),
    );
  }
}

class _DiscoveryNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _DiscoveryNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: colors.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ComposeSheet extends StatefulWidget {
  final Future<void> Function(String, XFile?) onCreate;
  const ComposeSheet({super.key, required this.onCreate});
  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  final picker = ImagePicker();
  final controller = TextEditingController();
  XFile? selectedImage;
  bool publishing = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '发一条',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '分享你的想法…'),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(selectedImage == null ? '添加图片' : '更换图片'),
          ),
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(selectedImage!.path),
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: publishing
                ? null
                : () async {
                    final text = controller.text.trim();
                    if (text.isEmpty && selectedImage == null) return;
                    setState(() => publishing = true);
                    try {
                      await widget.onCreate(text, selectedImage);
                      if (context.mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => publishing = false);
                    }
                  },
            child: Text(publishing ? '发布中…' : '发布'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => selectedImage = image);
  }
}

class ChoiceChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const ChoiceChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: ['推荐', '附近', '关注']
          .map(
            (text) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: text == selected
                        ? c.primary
                        : c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: text == selected ? c.onPrimary : c.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title, action;
  const SectionTitle({super.key, required this.title, required this.action});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: c.onSurface,
          ),
        ),
        const Spacer(),
        Text(action, style: TextStyle(color: c.primary, fontSize: 13)),
      ],
    );
  }
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: c.primary,
              child: Icon(Icons.public, size: 30, color: c.onPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '探索新的兴趣',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: c.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '去发现页看看附近的人',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 15, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
