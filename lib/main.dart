import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = 'https://friend.outmcn.net/api';
const imageBase = 'https://friend.outmcn.net';

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
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xff080d20),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff3b82f6),
        brightness: Brightness.dark,
      ),
    ),
    home: token == null
        ? LoginPage(onLogin: (value) => setState(() => token = value))
        : HomePage(token: token!),
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
  final pass = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await http.post(
        Uri.parse('$apiBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': user.text.trim(), 'password': pass.text}),
      );
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode < 200 || r.statusCode >= 300 || body['ok'] != true) {
        throw Exception(body['message'] ?? '登录失败');
      }
      final t = (body['data'] as Map<String, dynamic>)['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('friend.auth.token', t);
      widget.onLogin(t);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
    if (mounted) setState(() => busy = false);
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
              const Icon(Icons.public, size: 70, color: Color(0xff60a5fa)),
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
                  labelText: '账号',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
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

class HomePage extends StatefulWidget {
  final String token;
  const HomePage({super.key, required this.token});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  Map<String, dynamic>? profile;
  List<Post> posts = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await api('/me/summary', widget.token);
      final d = data['data'] as Map<String, dynamic>;
      setState(() {
        profile = d['profile'];
        posts = (d['posts'] as List).map((e) => Post.fromJson(e)).toList();
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: tab,
        children: [
          const Center(child: Text('主页')),
          DiscoveryPage(token: widget.token, onRefresh: load),
          const Center(child: Text('消息')),
          ProfilePage(
            token: widget.token,
            profile: profile,
            posts: posts,
            loading: loading,
            onRefresh: load,
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '主页'),
        NavigationDestination(icon: Icon(Icons.explore_outlined), label: '发现'),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: '消息',
        ),
        NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
      ],
    ),
  );
}

class Post {
  final int id;
  final String content, createdAt, nickname;
  final String? imageURL;
  final int likes, favorites;
  Post({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.nickname,
    this.imageURL,
    this.likes = 0,
    this.favorites = 0,
  });
  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: j['id'],
    content: j['content'] ?? '',
    createdAt: j['createdAt'] ?? '',
    nickname: j['nickname'] ?? '',
    imageURL: j['imageURL'] == null || j['imageURL'] == ''
        ? null
        : '$imageBase${j['imageURL']}',
    likes: j['likes'] ?? 0,
    favorites: j['favorites'] ?? 0,
  );
}

class ProfilePage extends StatelessWidget {
  final String token;
  final Map<String, dynamic>? profile;
  final List<Post> posts;
  final bool loading;
  final Future<void> Function() onRefresh;
  const ProfilePage({
    super.key,
    required this.token,
    required this.profile,
    required this.posts,
    required this.loading,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    final nickname = profile?['nickname']?.toString() ?? '';
    final name = nickname.trim().isNotEmpty
        ? nickname
        : (profile?['username'] ?? (loading ? '加载中…' : ''));
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '关注 ${profile?['following'] ?? 0}    粉丝 ${profile?['followers'] ?? 0}    获赞 ${profile?['likes'] ?? 0}    动态 ${profile?['posts'] ?? 0}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...posts.map(
            (p) => PostCard(
              post: p,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailPage(post: p)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoveryPage extends StatelessWidget {
  final String token;
  final Future<void> Function() onRefresh;
  const DiscoveryPage({
    super.key,
    required this.token,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          '推荐',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        const Center(child: Text('发现页')),
      ],
    ),
  );
}

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  const PostCard({super.key, required this.post, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.content, style: const TextStyle(fontSize: 16)),
            if (post.imageURL != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(post.imageURL!, fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              '♡ ${post.likes}    ☆ ${post.favorites}    ${post.createdAt}',
              style: TextStyle(
                color: Colors.white.withOpacity(.55),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DetailPage extends StatelessWidget {
  final Post post;
  const DetailPage({super.key, required this.post});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('动态详情')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          post.nickname,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (post.content.isNotEmpty)
          Text(post.content, style: const TextStyle(fontSize: 19)),
        if (post.imageURL != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Image.network(post.imageURL!, fit: BoxFit.contain),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.favorite_border),
              label: Text('点赞 ${post.likes}'),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.star_border),
              label: Text('收藏 ${post.favorites}'),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<Map<String, dynamic>> api(String path, String token) async {
  final r = await http.get(
    Uri.parse('$apiBase$path'),
    headers: {'Authorization': 'Bearer $token'},
  );
  final b = jsonDecode(r.body) as Map<String, dynamic>;
  if (r.statusCode < 200 || r.statusCode >= 300 || b['ok'] != true)
    throw Exception(b['message'] ?? '请求失败');
  return b;
}

Future<Uint8List> compressForUpload(
  Uint8List bytes, {
  int maxSide = 2048,
}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final resized = (decoded.width > maxSide || decoded.height > maxSide)
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
        )
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
}
