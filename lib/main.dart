import 'package:flutter/material.dart';

import 'auth_client.dart';

void main() {
  runApp(const FriendUiApp());
}

/// UI-only Flutter shell.
///
/// This file intentionally contains no network client, authentication,
/// token storage, database access, OSS access, or business service calls.
class FriendUiApp extends StatelessWidget {
  const FriendUiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Friend',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff9b7bff),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff8f6fb),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff9b7bff),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff111014),
      ),
      home: const AuthPage(),
    );
  }
}

/// Authentication screen for the new backend. The rest of the app remains
/// UI-only until each feature receives its own backend integration.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  late final FriendAuthClient auth;
  bool registerMode = false;
  bool loading = false;
  bool restoring = true;
  String? error;
  FriendLoginResult? session;

  @override
  void initState() {
    super.initState();
    auth = FriendAuthClient();
    restoreSession();
  }

  /// Restore and validate the persisted session before showing login or app
  /// content. This prevents a visible flash of the wrong screen on startup.
  Future<void> restoreSession() async {
    try {
      final restored = await auth.restoreSession();
      if (mounted) setState(() => session = restored);
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    nickname.dispose();
    auth.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (username.text.trim().length < 3 || password.text.length < 6) {
      setState(() => error = '账号至少3位，密码至少6位');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (registerMode) {
        await auth.register(
          username: username.text,
          password: password.text,
          nickname: nickname.text,
        );
        if (mounted) setState(() => registerMode = false);
      } else {
        final result = await auth.login(
          username: username.text,
          password: password.text,
        );
        if (mounted) setState(() => session = result);
      }
    } on FriendAuthException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = '无法连接新后端');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    final current = session;
    if (current == null) return;
    try {
      await auth.logout(current.token);
    } finally {
      if (mounted) setState(() => session = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final current = session;
    if (current != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(current.user.nickname),
          actions: [
            IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
          ],
        ),
        body: const AppShell(),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    registerMode ? '注册' : '登录',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(labelText: '账号'),
                  ),
                  if (registerMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: nickname,
                      decoration: const InputDecoration(labelText: '昵称（可选）'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '密码'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : submit,
                    child: Text(loading ? '处理中…' : registerMode ? '注册' : '登录'),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() {
                              registerMode = !registerMode;
                              error = null;
                            }),
                    child: Text(registerMode ? '已有账号？登录' : '没有账号？注册'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Static page shell retained for later backend integration.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  static const pages = <Widget>[
    HomePage(),
    DiscoverPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
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
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '首页',
      action: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.notifications_none),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          _StoryStrip(),
          SizedBox(height: 18),
          _StaticPostCard(
            title: '记录此刻的生活',
            body: '这里保留原有内容卡片的 UI 结构，后续再接入真实数据。',
          ),
          _StaticPostCard(
            title: '周末随手拍',
            body: '当前页面只展示组件和布局，不调用任何后端接口。',
          ),
        ],
      ),
    );
  }
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '发现',
      action: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.search),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionTabs(),
          SizedBox(height: 18),
          _StaticPostCard(
            title: '今日推荐',
            body: '推荐内容卡片仅作为界面占位。',
          ),
          _StaticPostCard(
            title: '认识新的朋友',
            body: '用户、动态和互动数据将在后续对接新后端。',
          ),
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '消息',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _MessageTile(
            name: '小组讨论',
            preview: '消息列表组件占位',
            color: Color(0xff9b7bff),
          ),
          _MessageTile(
            name: '新的朋友',
            preview: '暂未连接真实消息',
            color: Color(0xff70b7a3),
          ),
          _MessageTile(
            name: '系统消息',
            preview: '静态列表项占位',
            color: Color(0xffe7a467),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '我的',
      action: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.settings_outlined),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 38,
                child: Icon(Icons.person, size: 34),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '用户昵称',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text('个人资料组件占位'),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('编辑'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(value: '0', label: '关注'),
              _StatItem(value: '0', label: '粉丝'),
              _StatItem(value: '0', label: '获赞'),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            '我的内容',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const _EmptyPanel(),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StoryStrip extends StatelessWidget {
  const _StoryStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _Story(label: '你的故事', add: true),
          _Story(label: '周末'),
          _Story(label: '旅行'),
          _Story(label: '生活'),
        ],
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.label, this.add = false});
  final String label;
  final bool add;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 29,
                child: Icon(Icons.person_outline),
              ),
              if (add)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 10,
                    child: Icon(Icons.add, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs();

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('推荐')),
        ButtonSegment(value: 1, label: Text('附近')),
        ButtonSegment(value: 2, label: Text('关注')),
      ],
      selected: const {0},
      onSelectionChanged: (_) {},
      showSelectedIcon: false,
    );
  }
}

class _StaticPostCard extends StatelessWidget {
  const _StaticPostCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .65),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, size: 42),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(body),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.favorite_border, size: 18),
                SizedBox(width: 18),
                Icon(Icons.chat_bubble_outline, size: 18),
                SizedBox(width: 18),
                Icon(Icons.bookmark_border, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.name,
    required this.preview,
    required this.color,
  });
  final String name;
  final String preview;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        backgroundColor: color,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
      title: Text(name),
      subtitle: Text(preview),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: .35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 36),
          SizedBox(height: 8),
          Text('暂无内容'),
        ],
      ),
    );
  }
}
