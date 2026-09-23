import 'package:flutter/material.dart';

const navy = Color(0xff080d20);
const card = Color(0xff11182d);
const blue = Color(0xff4d8dff);
const muted = Color(0xff8892ad);

void main() => runApp(const FriendApp());

class FriendApp extends StatelessWidget {
  const FriendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Friend',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xff0b1226),
          indicatorColor: Color(0xff244b9a),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const FriendShell(),
    );
  }
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

  void _createPost(String text) {
    setState(
      () => posts.insert(
        0,
        UiPost(text, '15305113400', '刚刚', Icons.auto_awesome_outlined, 0, 0),
      ),
    );
  }
}

class UiPost {
  final String text;
  final String author;
  final String time;
  final IconData icon;
  final int likes;
  final int favorites;
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
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            const Text(
              'Friend',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('找到真实的交流', style: TextStyle(color: muted, fontSize: 14)),
            const SizedBox(height: 28),
            _heroCard(),
            const SizedBox(height: 20),
            const SectionTitle(title: '今日推荐', action: '查看全部'),
            const SizedBox(height: 12),
            const RecommendationCard(),
          ]),
        ),
      ),
    ],
  );

  Widget _heroCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        colors: [Color(0xff172f69), Color(0xff10172e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: blue.withValues(alpha: .28)),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xff274b9b),
          child: Icon(Icons.public, size: 34, color: Colors.white),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '分享此刻的想法',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text('去发现新的朋友和兴趣', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      ],
    ),
  );
}

class DiscoveryPage extends StatelessWidget {
  final List<UiPost> posts;
  final ValueChanged<String> onCreate;
  const DiscoveryPage({super.key, required this.posts, required this.onCreate});
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            Row(
              children: [
                const Text(
                  '发现',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _compose(context),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: blue,
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
                child: PostCard(post: post),
              ),
            ),
          ]),
        ),
      ),
    ],
  );

  Future<void> _compose(BuildContext context) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
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
            const Text(
              '发一条',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(hintText: '分享你的想法…'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  onCreate(value);
                  Navigator.pop(context);
                }
              },
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
  Widget build(BuildContext context) => Row(
    children: ['推荐', '附近', '关注']
        .map(
          (text) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(text),
              selected: text == '推荐',
              onSelected: (_) {},
              selectedColor: blue,
              backgroundColor: Colors.white.withValues(alpha: .07),
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),
        )
        .toList(),
  );
}

class PostCard extends StatelessWidget {
  final UiPost post;
  const PostCard({super.key, required this.post});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(post: post)),
    ),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xff2852a2),
                child: Icon(Icons.public, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      post.time,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: muted),
            ],
          ),
          const SizedBox(height: 14),
          Text(post.text, style: const TextStyle(fontSize: 16, height: 1.35)),
          const SizedBox(height: 14),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0xff172b59), Color(0xff10152b)],
              ),
            ),
            child: Icon(post.icon, size: 52, color: blue.withValues(alpha: .8)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.favorite_border, size: 19, color: muted),
              const SizedBox(width: 5),
              Text('${post.likes}', style: const TextStyle(color: muted)),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline, size: 18, color: muted),
              const SizedBox(width: 5),
              const Text('0', style: TextStyle(color: muted)),
              const SizedBox(width: 20),
              const Icon(Icons.star_border, size: 19, color: muted),
              const SizedBox(width: 5),
              Text('${post.favorites}', style: const TextStyle(color: muted)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ],
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  final List<UiPost> posts;
  const ProfilePage({super.key, required this.posts});
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [card, Color(0xff142552)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '15305113400',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '关注  0     粉丝  0     获赞  0',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xff2b58ac),
                    child: Icon(Icons.public, size: 48),
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
          ]),
        ),
      ),
    ],
  );
}

class _ProfileTab extends StatelessWidget {
  final String text;
  final bool selected;
  const _ProfileTab({required this.text, this.selected = false});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: selected ? blue : Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
    children: [
      const Text(
        '消息',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 18),
      ...List.generate(
        6,
        (i) => Card(
          color: card,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 5,
            ),
            leading: const CircleAvatar(
              backgroundColor: Color(0xff2852a2),
              child: Icon(Icons.public),
            ),
            title: Text('星空用户 ${i + 1}'),
            subtitle: const Text('期待和你交流', style: TextStyle(color: muted)),
            trailing: const Text(
              '刚刚',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ),
      ),
    ],
  );
}

class DetailPage extends StatelessWidget {
  final UiPost post;
  const DetailPage({super.key, required this.post});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('动态详情')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        PostCard(post: post),
        const SizedBox(height: 18),
        const Text(
          '评论',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const EmptyState(text: '还没有评论'),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  const SectionTitle({super.key, required this.title, required this.action});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
      const Spacer(),
      Text(action, style: const TextStyle(color: blue, fontSize: 13)),
    ],
  );
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xff2852a2),
          child: Icon(Icons.public, size: 30),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('探索新的兴趣', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text('去发现页看看附近的人', style: TextStyle(color: muted)),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 15, color: muted),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, color: muted, size: 36),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: muted)),
      ],
    ),
  );
}
