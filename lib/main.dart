import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

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
  final profileKey = GlobalKey<ProfilePageState>();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final response = await http.get(
        Uri.parse('https://friend.outmcn.net/api/posts'),
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
        if (mounted) {
          setState(() {
            posts
              ..clear()
              ..addAll(loaded);
            loadingPosts = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      DiscoveryPage(posts: posts, onCreate: _createPost, onRefresh: _loadPosts),
      const MessagePage(),
      ProfilePage(key: profileKey, posts: posts, token: widget.token),
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
          decoded['ok'] != true)
        throw Exception(decoded['message'] ?? '发布失败');
      await _loadPosts();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
    }
  }
}

class UiPost {
  final int id;
  final String text, author, time;
  final IconData icon;
  final int likes, favorites;
  final String? imageUrl;
  UiPost(
    this.text,
    this.author,
    this.time,
    this.icon,
    this.likes,
    this.favorites, {
    this.id = 0,
    this.imageUrl,
  });
  factory UiPost.fromJson(Map<String, dynamic> json) => UiPost(
    json['content']?.toString() ?? '',
    json['nickname']?.toString() ?? '',
    json['createdAt']?.toString() ?? '',
    Icons.image_outlined,
    (json['likes'] as num?)?.toInt() ?? 0,
    (json['favorites'] as num?)?.toInt() ?? 0,
    id: (json['id'] as num?)?.toInt() ?? 0,
    imageUrl: _normalizeImage(json['imageURL']),
  );
  static String? _normalizeImage(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : 'https://friend.outmcn.net$raw';
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
        _hero(context),
        const SizedBox(height: 20),
        SectionTitle(title: '今日推荐', action: '查看全部'),
        const SizedBox(height: 12),
        const RecommendationCard(),
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
            child: Icon(Icons.public, size: 34, color: c.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分享此刻的想法',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text('去发现新的朋友和兴趣', style: TextStyle(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: c.onSurfaceVariant),
        ],
      ),
    );
  }
}

class DiscoveryPage extends StatelessWidget {
  final List<UiPost> posts;
  final Future<void> Function(String, XFile?) onCreate;
  final Future<void> Function() onRefresh;
  const DiscoveryPage({
    super.key,
    required this.posts,
    required this.onCreate,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        children: [
          Row(
            children: [
              Text(
                '发现',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: c.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _compose(context),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: c.primary,
                  size: 29,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ChoiceChips(),
          const SizedBox(height: 18),
          ...posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(post: post, onActionChanged: onRefresh),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _compose(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      builder: (_) => ComposeSheet(onCreate: onCreate),
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
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty && selectedImage == null) return;
              await widget.onCreate(text, selectedImage);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('发布'),
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
  const ChoiceChips({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: ['推荐', '附近', '关注']
          .map(
            (text) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(text),
                selected: text == '推荐',
                onSelected: (_) {},
                selectedColor: c.primary,
                backgroundColor: c.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: text == '推荐' ? c.onPrimary : c.onSurface,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class PostCard extends StatelessWidget {
  final UiPost post;
  final Future<void> Function()? onActionChanged;
  const PostCard({super.key, required this.post, this.onActionChanged});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetailPage(post: post, onActionChanged: onActionChanged),
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: c.primary,
                    child: Icon(Icons.public, size: 21, color: c.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: c.onSurface,
                          ),
                        ),
                        Text(
                          post.time,
                          style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_horiz, color: c.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                post.text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: c.onSurface,
                ),
              ),
              if (post.imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      post.imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 19,
                    color: c.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${post.likes}',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                  const SizedBox(width: 20),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: c.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text('0', style: TextStyle(color: c.onSurfaceVariant)),
                  const SizedBox(width: 20),
                  Icon(Icons.star_border, size: 19, color: c.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    '${post.favorites}',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final List<UiPost> posts;
  final String token;
  const ProfilePage({super.key, required this.posts, required this.token});
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String nickname = '';
  bool loading = true;
  int section = 0;
  List<UiPost> favoritePosts = [];
  List<UiPost> likedPosts = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> refreshFromServer() => _loadProfile();

  Future<void> _loadProfile() async {
    try {
      final r = await http.get(
        Uri.parse('https://friend.outmcn.net/api/me/summary'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final d = b['data'];
      if (b['ok'] == true && d is Map<String, dynamic> && mounted) {
        final p = d['profile'] as Map<String, dynamic>;
        setState(() {
          nickname =
              (p['nickname']?.toString().trim().isNotEmpty == true
                      ? p['nickname']
                      : p['username'])
                  .toString();
          favoritePosts = (d['favorited'] as List)
              .whereType<Map<String, dynamic>>()
              .map(UiPost.fromJson)
              .toList();
          likedPosts = (d['liked'] as List)
              .whereType<Map<String, dynamic>>()
              .map(UiPost.fromJson)
              .toList();
          loading = false;
        });
      }
    } catch (_) {}
    if (mounted && loading) setState(() => loading = false);
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: nickname);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改名字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: '输入新的名字'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    final r = await http.put(
      Uri.parse('https://friend.outmcn.net/api/me'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'nickname': value}),
    );
    final b = jsonDecode(r.body) as Map<String, dynamic>;
    if (b['ok'] == true && mounted) setState(() => nickname = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final visiblePosts = section == 0
        ? widget.posts
        : (section == 1 ? favoritePosts : likedPosts);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [c.surfaceContainer, c.primaryContainer],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            loading ? '加载中…' : nickname,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: c.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _editNickname,
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: c.onSurfaceVariant,
                          ),
                          tooltip: '修改名字',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '关注  0     粉丝  0     获赞  0',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 42,
                backgroundColor: c.primary,
                child: Icon(Icons.public, size: 48, color: c.onPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ProfileTab(
                text: '动态',
                selected: section == 0,
                onTap: () => setState(() => section = 0),
              ),
            ),
            Expanded(
              child: _ProfileTab(
                text: '收藏',
                selected: section == 1,
                onTap: () => setState(() => section = 1),
              ),
            ),
            Expanded(
              child: _ProfileTab(
                text: '点赞',
                selected: section == 2,
                onTap: () => setState(() => section = 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visiblePosts.isEmpty)
          EmptyState(
            text: section == 0 ? '还没有动态' : (section == 1 ? '还没有收藏' : '还没有点赞'),
          ),
        ...visiblePosts.map(
          (post) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(post: post, onActionChanged: refreshFromServer),
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  const _ProfileTab({required this.text, this.selected = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? c.onPrimary : c.onSurface,
          ),
        ),
      ),
    );
  }
}

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      children: [
        Text(
          '消息',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: c.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(
          6,
          (i) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 5,
              ),
              leading: CircleAvatar(
                backgroundColor: c.primary,
                child: Icon(Icons.public, color: c.onPrimary),
              ),
              title: Text('星空用户 ${i + 1}'),
              subtitle: Text(
                '期待和你交流',
                style: TextStyle(color: c.onSurfaceVariant),
              ),
              trailing: Text(
                '刚刚',
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DetailPage extends StatefulWidget {
  final UiPost post;
  final Future<void> Function()? onActionChanged;
  const DetailPage({super.key, required this.post, this.onActionChanged});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final commentController = TextEditingController();
  final comments = <String>[];
  String? token;
  bool liked = false;
  bool favorited = false;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    liked = widget.post.likes > 0;
    favorited = widget.post.favorites > 0;
    _loadSession();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('friend.auth.token');
    await _loadComments();
  }

  Future<void> _loadComments() async {
    if (token == null || widget.post.id == 0) return;
    try {
      final r = await http.get(
        Uri.parse(
          'https://friend.outmcn.net/api/posts/${widget.post.id}/comments',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && b['data'] is List && mounted)
        setState(() {
          comments
            ..clear()
            ..addAll(
              (b['data'] as List).whereType<Map<String, dynamic>>().map(
                (x) => x['content'].toString(),
              ),
            );
        });
    } catch (_) {}
  }

  Future<void> _toggleAction(String action) async {
    if (token == null || widget.post.id == 0) return;
    try {
      final r = await http.post(
        Uri.parse(
          'https://friend.outmcn.net/api/posts/${widget.post.id}/$action',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true && mounted) {
        setState(() {
          if (action == 'like')
            liked = b['data']['liked'] == true;
          else
            favorited = b['data']['favorited'] == true;
        });
        await widget.onActionChanged?.call();
      }
    } catch (_) {}
  }

  Future<void> sendComment() async {
    final value = commentController.text.trim();
    if (value.isEmpty || token == null || widget.post.id == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => sending = true);
    try {
      final r = await http.post(
        Uri.parse(
          'https://friend.outmcn.net/api/posts/${widget.post.id}/comments',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': value}),
      );
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['ok'] == true) {
        commentController.clear();
        await _loadComments();
        await widget.onActionChanged?.call();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final post = widget.post;
    return Scaffold(
      appBar: AppBar(title: const Text('动态详情')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: c.primary,
                      child: Icon(Icons.public, color: c.onPrimary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: c.onSurface,
                          ),
                        ),
                        Text(
                          post.time,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (post.text.isNotEmpty)
                  Text(
                    post.text,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.45,
                      color: c.onSurface,
                    ),
                  ),
                const SizedBox(height: 18),
                if (post.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      post.imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                const SizedBox(height: 22),
                Divider(color: c.outlineVariant),
                const SizedBox(height: 8),
                Text(
                  '评论',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (comments.isEmpty)
                  EmptyState(text: '还没有评论')
                else
                  ...comments.map(
                    (text) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: c.primary,
                        child: Icon(Icons.public, color: c.onPrimary),
                      ),
                      title: const Text('评论'),
                      subtitle: Text(text),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendComment(),
                      decoration: InputDecoration(
                        hintText: '写评论…',
                        fillColor: c.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: sending ? null : sendComment,
                    child: Text(sending ? '发送中…' : '发送'),
                  ),
                  IconButton(
                    onPressed: () => _toggleAction('like'),
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.red : c.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleAction('favorite'),
                    icon: Icon(
                      favorited ? Icons.star : Icons.star_border,
                      color: favorited ? Colors.amber : c.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: c.onSurfaceVariant, size: 36),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}
