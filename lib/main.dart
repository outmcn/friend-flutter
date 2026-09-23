import 'package:flutter/material.dart';

const blue = Color(0xff4d8dff);

void main() => runApp(const FriendApp());

class FriendApp extends StatelessWidget {
  const FriendApp({super.key});

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
      home: const FriendShell(),
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

class FriendShell extends StatefulWidget {
  const FriendShell({super.key});
  @override
  State<FriendShell> createState() => _FriendShellState();
}

class _FriendShellState extends State<FriendShell> {
  int tab = 0;
  final posts = <UiPost>[
    UiPost('动态图片测试', '15305113400', '22:34', Icons.image_outlined, 0, 0),
    UiPost(
      '图片接口冒烟测试',
      '15305113400',
      '22:25',
      Icons.photo_library_outlined,
      0,
      0,
    ),
    UiPost(
      '项目测试 动态1',
      '15305113400',
      '22:21',
      Icons.auto_awesome_outlined,
      0,
      0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      DiscoveryPage(posts: posts, onCreate: _createPost),
      const MessagePage(),
      ProfilePage(posts: posts),
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

  void _createPost(String text) => setState(
    () => posts.insert(
      0,
      UiPost(text, '15305113400', '刚刚', Icons.auto_awesome_outlined, 0, 0),
    ),
  );
}

class UiPost {
  final String text, author, time;
  final IconData icon;
  final int likes, favorites;
  UiPost(
    this.text,
    this.author,
    this.time,
    this.icon,
    this.likes,
    this.favorites,
  );
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
  final ValueChanged<String> onCreate;
  const DiscoveryPage({super.key, required this.posts, required this.onCreate});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListView(
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
              icon: Icon(Icons.add_circle_outline, color: c.primary, size: 29),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const ChoiceChips(),
        const SizedBox(height: 18),
        ...posts.map(
          (post) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(post: post),
          ),
        ),
      ],
    );
  }

  Future<void> _compose(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      builder: (context) => Padding(
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 5,
              decoration: InputDecoration(hintText: '分享你的想法…'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
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
  const PostCard({super.key, required this.post});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailPage(post: post)),
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
              const SizedBox(height: 14),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [c.primaryContainer, c.surfaceContainerHighest],
                  ),
                ),
                child: Icon(post.icon, size: 52, color: c.primary),
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

class ProfilePage extends StatelessWidget {
  final List<UiPost> posts;
  const ProfilePage({super.key, required this.posts});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
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
                    Text(
                      '15305113400',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: c.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
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
        const Row(
          children: [
            Expanded(child: _ProfileTab(text: '动态', selected: true)),
            Expanded(child: _ProfileTab(text: '收藏')),
            Expanded(child: _ProfileTab(text: '点赞')),
          ],
        ),
        const SizedBox(height: 16),
        ...posts.map(
          (post) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(post: post),
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String text;
  final bool selected;
  const _ProfileTab({required this.text, this.selected = false});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
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
  const DetailPage({super.key, required this.post});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final commentController = TextEditingController();
  final comments = <String>[];
  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 1.18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.primaryContainer,
                            c.surfaceContainerHighest,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(post.icon, size: 66, color: c.primary),
                      ),
                    ),
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
                      title: Text('我'),
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
                  FilledButton(onPressed: sendComment, child: const Text('发送')),
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.favorite_border, color: c.primary),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.star_border, color: c.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void sendComment() {
    final value = commentController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      comments.add(value);
      commentController.clear();
    });
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
