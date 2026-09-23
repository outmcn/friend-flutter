import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'models/ui_post.dart';
import 'pages/profile_page.dart';
import 'pages/contacts_page.dart';
import 'pages/user_list_page.dart';
import 'pages/game_page.dart';
import 'widgets/post_card.dart';
import 'widgets/discovery_top_bar.dart';
import 'pages/compose_page.dart';

const blue = Color(0xff4d8dff);

void main() => runApp(const FriendApp());

class FriendApp extends StatefulWidget {
  const FriendApp({super.key});
  @override
  State<FriendApp> createState() => _FriendAppState();
}

class _FriendAppState extends State<FriendApp> {
  String? token;
  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => token = prefs.getString('friend.auth.token'));
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
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11)),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
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
      final response = await http.post(
        Uri.parse('https://friend.outmcn.net/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': user.text.trim(),
          'password': password.text,
        }),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['ok'] != true) {
        throw Exception(body['message'] ?? '登录失败');
      }
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
                decoration: const InputDecoration(labelText: '账号'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
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

  Future<Position?> _currentPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt('friend.location.cachedAt') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedLat = prefs.getDouble('friend.location.latitude');
    final cachedLon = prefs.getDouble('friend.location.longitude');
    if (cachedLat != null &&
        cachedLon != null &&
        now - cachedAt < 6 * 60 * 60 * 1000) {
      return Position(
        latitude: cachedLat,
        longitude: cachedLon,
        timestamp: DateTime.fromMillisecondsSinceEpoch(cachedAt),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition();
    await prefs.setDouble('friend.location.latitude', position.latitude);
    await prefs.setDouble('friend.location.longitude', position.longitude);
    await prefs.setInt('friend.location.cachedAt', now);
    return position;
  }

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
    final response = await http.get(
      Uri.parse('https://friend.outmcn.net/api/me'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (body['ok'] == true && data != null && mounted) {
      setState(() => currentUserId = (data['id'] as num?)?.toInt() ?? 0);
    }
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
      final response = await http.get(
        Uri.parse('https://friend.outmcn.net$path'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body['ok'] == true &&
          data is List) {
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
      final response = await http.get(
        Uri.parse('https://friend.outmcn.net$path'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
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
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '主页',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '消息',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
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
      final response = await http.post(
        Uri.parse('https://friend.outmcn.net/api/posts'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['ok'] != true) {
        throw Exception(decoded['message'] ?? '发布失败');
      }
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
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Text(
          'Friend',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: c.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '找到真实的交流',
          style: TextStyle(color: c.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GamePage()),
          ),
          child: _hero(context),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [c.primaryContainer, c.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: c.primary.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: c.primary,
            child: Icon(Icons.sports_esports, size: 34, color: c.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '进入游戏',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text('和朋友一起玩游戏', style: TextStyle(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: c.onSurfaceVariant),
        ],
      ),
    );
  }
}

class HomeTopBar extends StatelessWidget {
  final VoidCallback? onQrCode;
  final VoidCallback? onSettings;
  const HomeTopBar({super.key, this.onQrCode, this.onSettings});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surface,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 12, 5),
          child: Row(
            children: [
              Text(
                '主页',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c.onSurface,
                ),
              ),
              const Spacer(),
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
        DiscoveryTopBar(
          selected: selectedFilter,
          onSelected: onFilterChanged,
          onCompose: () => _compose(context),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              children: [
                if (!loading && error != null) Center(child: Text(error!)),
                if (!loading && error == null && posts.isEmpty)
                  Center(
                    child: Text(
                      selectedFilter == '关注'
                          ? '还没有关注的人发布动态'
                          : selectedFilter == '附近'
                          ? '附近暂无动态'
                          : '暂无动态',
                    ),
                  ),
                if (!loading && error == null)
                  ...posts.map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PostCard(
                        post: post,
                        token: token,
                        onActionChanged: onActionChanged,
                        currentLatitude: currentLatitude,
                        currentLongitude: currentLongitude,
                        currentUserId: currentUserId,
                      ),
                    ),
                  ),
              ],
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

class MessagePage extends StatelessWidget {
  final String token;
  const MessagePage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      children: [
        const HomeTopBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            children: [
              Row(
                children: [
                  Text(
                    '消息',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: c.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactsPage(token: token),
                      ),
                    ),
                    icon: const Icon(Icons.contacts_outlined),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListPage(
                          token: token,
                          title: '搜索用户',
                          searchable: true,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactsPage(token: token),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(
                6,
                (i) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 76,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: c.primary,
                            child: Icon(Icons.public, color: c.onPrimary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '星空用户 ${i + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '期待和你交流',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '刚刚',
                            style: TextStyle(
                              color: c.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
