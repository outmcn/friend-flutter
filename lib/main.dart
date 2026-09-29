import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tdesign_flutter_icons/tdesign_flutter_icons.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:image_picker/image_picker.dart';

import 'post_service.dart';

void main() => runApp(const DDApp());

class DDApp extends StatelessWidget {
  const DDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DD',
      theme: ThemeData(
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: .56)),
          prefixIconColor: Colors.white.withValues(alpha: .72),
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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool signedIn = false;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('dd.auth.token') ?? '';
    if (mounted) {
      setState(() {
        signedIn = token.isNotEmpty;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return signedIn ? const DDShell() : const OnboardingPage();
  }
}

class _FigmaIcon extends StatelessWidget {
  const _FigmaIcon(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: 22,
        height: 22,
        color: Theme.of(context).colorScheme.onSurface,
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

class _SafeAvatar extends StatelessWidget {
  const _SafeAvatar({required this.asset});
  final String asset;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundImage: AssetImage(asset),
        onBackgroundImageError: (_, __) {},
        child: const Icon(Icons.person),
      );
}

class _SafeAssetImage extends StatelessWidget {
  const _SafeAssetImage({
    required this.asset,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });
  final String asset;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Image.asset(
          asset,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: TextButton(onPressed: () {}, child: const Text('重新加载')),
          ),
        ),
      );
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'DD',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                '发现有趣的人，分享真实生活。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .68),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 34),
              ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: _SafeAssetImage(
                  asset: 'assets/figma/hero-laptop.png',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(34),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: const Text('开始使用'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '登录',
        subtitle: '使用手机号登录 DD',
        child: Column(
          children: [
            const _AuthField(label: '手机号码', icon: Icons.phone_outlined),
            const SizedBox(height: 14),
            const _AuthField(label: '验证码', icon: Icons.verified_outlined),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PasswordLoginPage()),
                  ),
                  child: const Text('密码登录'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ResetPasswordPage()),
                  ),
                  child: const Text('找回密码'),
                ),
              ],
            ),
            _PrimaryAuthButton(
              label: '登录',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('手机号验证码登录接口尚未接入')),
              ),
            ),
          ],
        ),
      );
}

class PasswordLoginPage extends StatefulWidget {
  const PasswordLoginPage({super.key});
  @override
  State<PasswordLoginPage> createState() => _PasswordLoginPageState();
}

class _PasswordLoginPageState extends State<PasswordLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _service = DDPostService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = '请输入手机号和密码');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.login(
        username: _username.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DDShell()),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
                controller: _username),
            const SizedBox(height: 14),
            _AuthFieldController(
                label: '密码',
                icon: Icons.lock_outline,
                obscureText: true,
                controller: _password),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.orange))),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
                ),
                child: const Text('找回密码'),
              ),
            ),
            _PrimaryAuthButton(
                label: _loading ? '登录中…' : '登录',
                onTap: _loading ? () {} : _login),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回验证码登录')),
          ],
        ),
      );
}

class _AuthFieldController extends StatelessWidget {
  const _AuthFieldController(
      {required this.label,
      required this.icon,
      required this.controller,
      this.obscureText = false});
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '注册',
        subtitle: '创建账号，开始你的 DD 旅程',
        child: Column(
          children: [
            const _AuthField(label: '用户名', icon: Icons.person_outline),
            const SizedBox(height: 14),
            const _AuthField(label: '邮箱或手机号', icon: Icons.alternate_email),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EmailRegisterPage()),
                    ),
                    child: const Text('邮箱注册'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PhoneRegisterPage()),
                    ),
                    child: const Text('手机注册'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _AuthField(
              label: '设置密码',
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: '继续',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSetupPage()),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
              child: const Text('已有账号？返回登录'),
            ),
          ],
        ),
      );
}

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '找回密码',
        subtitle: '输入绑定信息获取验证码',
        child: Column(
          children: [
            const _AuthField(label: '邮箱或手机号', icon: Icons.person_outline),
            const SizedBox(height: 14),
            const _AuthField(label: '验证码', icon: Icons.verified_outlined),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
                label: '确认', onTap: () => Navigator.pop(context)),
          ],
        ),
      );
}

class FilledLoginPage extends StatelessWidget {
  const FilledLoginPage({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '登录',
        subtitle: '已填写账号，继续完成登录',
        child: Column(
          children: [
            const _AuthField(
              label: '邮箱或手机号',
              icon: Icons.person,
              initialText: 'friend@example.com',
            ),
            const SizedBox(height: 14),
            const _AuthField(
              label: '密码',
              icon: Icons.lock_outline,
              obscureText: true,
              initialText: '••••••••',
            ),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: '登录',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DDShell()),
              ),
            ),
          ],
        ),
      );
}

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: title,
        subtitle: '验证码已发送，请输入验证码',
        child: Column(
          children: [
            const _AuthField(label: '验证码', icon: Icons.verified_outlined),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () {}, child: const Text('重新获取验证码')),
            ),
            const SizedBox(height: 18),
            _PrimaryAuthButton(
                label: '确认', onTap: () => Navigator.pop(context)),
          ],
        ),
      );
}

class PhoneRegisterPage extends StatelessWidget {
  const PhoneRegisterPage({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '手机注册',
        subtitle: '使用手机号创建 DD 账号',
        child: Column(
          children: [
            const _AuthField(label: '手机号码', icon: Icons.phone_outlined),
            const SizedBox(height: 14),
            const _AuthField(label: '验证码', icon: Icons.verified_outlined),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: '下一步',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PasswordSetupPage()),
              ),
            ),
          ],
        ),
      );
}

class EmailRegisterPage extends StatelessWidget {
  const EmailRegisterPage({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '邮箱注册',
        subtitle: '使用邮箱创建 DD 账号',
        child: Column(
          children: [
            const _AuthField(label: '邮箱地址', icon: Icons.email_outlined),
            const SizedBox(height: 14),
            const _AuthField(label: '邮箱验证码', icon: Icons.verified_outlined),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: '下一步',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PasswordSetupPage()),
              ),
            ),
          ],
        ),
      );
}

class PasswordSetupPage extends StatelessWidget {
  const PasswordSetupPage({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '设置密码',
        subtitle: '为你的 DD 账号设置安全密码',
        child: Column(
          children: [
            const _AuthField(
              label: '设置密码',
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            const _AuthField(
              label: '确认密码',
              icon: Icons.lock_reset_outlined,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: '完成注册',
              onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DDShell()),
                (_) => false,
              ),
            ),
          ],
        ),
      );
}

class ProfileSetupPage extends StatelessWidget {
  const ProfileSetupPage({super.key});

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '完善资料',
        subtitle: '让大家更快认识你',
        child: Column(
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: const AssetImage(
                'assets/figma/profile-portrait-1.jpg',
              ),
              onBackgroundImageError: (_, __) {},
              child: const Icon(Icons.add_a_photo_outlined, size: 30),
            ),
            const SizedBox(height: 20),
            const _AuthField(label: '昵称', icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            const _AuthField(label: '一句话介绍自己', icon: Icons.edit_outlined),
            const SizedBox(height: 14),
            const _AuthField(label: '选择兴趣标签', icon: Icons.local_offer_outlined),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: '完成',
              onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DDShell()),
                (_) => false,
              ),
            ),
          ],
        ),
      );
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
          ),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.initialText,
  });
  final String label;
  final IconData icon;
  final bool obscureText;
  final String? initialText;
  @override
  Widget build(BuildContext context) => TextField(
        obscureText: obscureText,
        controller: initialText == null
            ? null
            : TextEditingController(text: initialText),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(label),
        ),
      );
}

class DDShell extends StatefulWidget {
  const DDShell({super.key});
  @override
  State<DDShell> createState() => _DDShellState();
}

class _DDShellState extends State<DDShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const DDHomePage(),
      const DiscoverPage(),
      const NotificationsPage(),
      const DDProfilePage(),
    ];
    return Scaffold(
      body: pages[index],
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
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: '通知',
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

class _PageLoadState extends StatelessWidget {
  const _PageLoadState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('$title\n$subtitle')),
            ],
          ),
        ),
      );
}

class _PageErrorState extends StatelessWidget {
  const _PageErrorState(
      {required this.title, required this.subtitle, this.onRetry});
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
        ),
      );
}

class DDHomePage extends StatefulWidget {
  const DDHomePage({super.key});

  @override
  State<DDHomePage> createState() => _DDHomePageState();
}

class _DDHomePageState extends State<DDHomePage> {
  final DDPostService _postService = DDPostService();
  List<DDPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _postService.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      final token = prefs.getString('dd.auth.token') ?? '';
      if (token.isEmpty) {
        throw Exception('登录后加载动态');
      }
      final posts = await _postService.fetchPosts(token);
      if (mounted) setState(() => _posts = posts);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _loadPosts, icon: _tdIcon('search')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            const _SectionTitle(title: '主播推荐', action: '查看全部'),
            SizedBox(
              height: 114,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) => _CreatorChip(index: index),
              ),
            ),
            const SizedBox(height: 10),
            _SectionTitle(
              title: '动态',
              action: '刷新',
              onTap: _loadPosts,
            ),
            if (_loading)
              const _PageLoadState(title: '动态加载中', subtitle: '正在读取最新动态')
            else if (_error != null)
              _PageErrorState(
                  title: '动态加载失败', subtitle: _error!, onRetry: _loadPosts)
            else if (_posts.isEmpty)
              const _EmptyStateCard(
                icon: Icons.article_outlined,
                title: '暂无动态',
                subtitle: '登录后即可查看服务器中的动态',
              )
            else
              ..._posts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DynamicPostCard(
                    post: post,
                    onLike: () async {
                      final prefs =
                          await SharedPreferences.getInstance().timeout(
                        const Duration(seconds: 1),
                      );
                      final token = prefs.getString('dd.auth.token') ?? '';
                      if (token.isEmpty) return;
                      await _postService.toggleLike(token, post.id);
                      await _loadPosts();
                    },
                    onFavorite: () async {
                      final prefs =
                          await SharedPreferences.getInstance().timeout(
                        const Duration(seconds: 1),
                      );
                      final token = prefs.getString('dd.auth.token') ?? '';
                      if (token.isEmpty) return;
                      await _postService.toggleFavorite(token, post.id);
                      await _loadPosts();
                    },
                    onOpen: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContentDetailPage(
                          title: '动态详情',
                          video: false,
                          postId: post.id,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _HomeQuickActions(
              onCreatePost: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostPage()),
                );
                if (mounted) _loadPosts();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DynamicPostCard extends StatelessWidget {
  const _DynamicPostCard({
    required this.post,
    required this.onLike,
    required this.onFavorite,
    required this.onOpen,
  });
  final DDPost post;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        post.avatar.isEmpty ? null : NetworkImage(post.avatar),
                    child: post.avatar.isEmpty
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.nickname,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(post.createdAt,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz),
                ],
              ),
              if (post.content.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(post.content,
                    style: const TextStyle(fontSize: 16, height: 1.4)),
              ],
              if (post.imageUrl != null &&
                  post.imageUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onLike,
                    icon: Icon(
                        post.liked ? Icons.favorite : Icons.favorite_border),
                    label: Text('${post.likes}'),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('评论'),
                  ),
                  TextButton.icon(
                    onPressed: onFavorite,
                    icon: Icon(post.favorited
                        ? Icons.bookmark
                        : Icons.bookmark_border),
                    label: Text('${post.favorites}'),
                  ),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('详情'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({required this.onCreatePost});

  final Future<void> Function() onCreatePost;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_box_outlined,
            label: '创建动态',
            onTap: () => onCreatePost(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.notifications_none,
            label: '通知中心',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: _iconFor(icon),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}

// ignore: unused_element
class _ScrollStateCard extends StatelessWidget {
  const _ScrollStateCard();

  @override
  Widget build(BuildContext context) => const _ContentPreviewCard(
        title: '继续浏览',
        subtitle: '向下滑动查看更多推荐内容',
        icon: Icons.keyboard_arrow_down,
      );
}

class _TrendPreviewCard extends StatelessWidget {
  const _TrendPreviewCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ContentPreviewCard(
        title: '流行趋势',
        subtitle: '本周正在流行的话题和内容',
        icon: Icons.trending_up,
        onTap: onTap,
      );
}

class _RecommendationPreviewCard extends StatelessWidget {
  const _RecommendationPreviewCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ContentPreviewCard(
        title: '为你推荐动态',
        subtitle: '点击查看完整内容',
        icon: Icons.play_circle_outline,
        onTap: onTap,
      );
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title:
              const Text('发现', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RecommendationFeedPage()),
              ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索话题、活动和用户',
              ),
            ),
            const SizedBox(height: 18),
            _DiscoverTile(
              icon: Icons.local_fire_department,
              title: '热门话题',
              subtitle: '看看大家正在讨论什么',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TopicPage()),
              ),
            ),
            _DiscoverTile(
              icon: Icons.event_available,
              title: '活动中心',
              subtitle: '参加线上线下有趣活动',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventsPage()),
              ),
            ),
            _DiscoverTile(
              icon: Icons.trending_up,
              title: '趋势榜单',
              subtitle: '本周最受关注的内容',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrendsPage()),
              ),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(title: '热门话题', action: '全部'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                '周末去哪儿',
                '电影分享',
                '城市漫步',
                '新朋友',
              ].map((e) => Chip(label: Text('#$e'))).toList(),
            ),
            const SizedBox(height: 18),
            const _PageLoadState(title: '推荐内容加载中', subtitle: '这是静态加载状态预览'),
            const _PageErrorState(title: '推荐内容加载失败', subtitle: '网络异常时可点击重试'),
            _ContentPreviewCard(
              title: '为你推荐',
              subtitle: '发现更多有趣内容',
              icon: Icons.auto_awesome,
              imageAsset: 'assets/figma/post-thumbnail-4.jpg',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ContentDetailPage(title: '为你推荐', video: true),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _TrendPreviewCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrendsPage()),
              ),
            ),
            const SizedBox(height: 12),
            _RecommendationPreviewCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ContentDetailPage(title: '推荐动态', video: true),
                ),
              ),
            ),
          ],
        ),
      );
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            leading: _iconFor(icon),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
}

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  String? mediaType;
  XFile? selectedImage;
  String visibility = '所有人可见';
  bool publishing = false;
  final TextEditingController _content = TextEditingController();
  final DDPostService _service = DDPostService();
  String? error;

  @override
  void dispose() {
    _content.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          selectedImage = image;
          mediaType = '图片';
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '图片选择失败：$e');
    }
  }

  Future<String?> _imageDataUrl() async {
    if (selectedImage == null) return null;
    final bytes = await selectedImage!.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw Exception('图片不能超过 8MB');
    }
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  void _clearImage() => setState(() {
        selectedImage = null;
        if (mediaType == '图片') mediaType = null;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          title: const Text('发布动态'),
          actions: [
            TextButton(
              onPressed: publishing
                  ? null
                  : () async {
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('dd.auth.token') ?? '';
                      if (token.isEmpty) {
                        setState(() => error = '请先登录后发布动态');
                        return;
                      }
                      if (_content.text.trim().isEmpty && mediaType == null) {
                        setState(() => error = '请输入动态内容或选择图片');
                        return;
                      }
                      setState(() {
                        publishing = true;
                        error = null;
                      });
                      try {
                        await _service.createPost(
                          token: token,
                          content: _content.text.trim(),
                          imageDataUrl: await _imageDataUrl(),
                        );
                        if (mounted) {
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            publishing = false;
                            error =
                                e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      } finally {
                        if (mounted) setState(() => publishing = false);
                      }
                    },
              child: Text(publishing ? '发布中…' : '发布'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              controller: _content,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: '分享此刻的想法…',
                alignLabelWithHint: true,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _MediaAction(
                  icon: Icons.photo_outlined,
                  label: selectedImage != null ? '已选图片' : '图片',
                  onTap: _pickImage,
                ),
                _MediaAction(
                  icon: Icons.videocam_outlined,
                  label: mediaType == '视频' ? '已选视频' : '视频',
                  onTap: () => setState(() => mediaType = '视频'),
                ),
                _MediaAction(
                  icon: Icons.tag,
                  label: mediaType == '话题' ? '已选话题' : '话题',
                  onTap: () => setState(() => mediaType = '话题'),
                ),
              ],
            ),
            if (selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(selectedImage!.path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: _clearImage,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            const Text('可见范围', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: _iconFor(Icons.public),
              title: Text(visibility),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ['所有人可见', '仅关注者可见', '仅自己可见']
                        .map(
                          (item) => ListTile(
                            title: Text(item),
                            trailing: item == visibility
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () {
                              setState(() => visibility = item);
                              Navigator.pop(context);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ContentPreviewCard(
              title: '添加话题',
              subtitle: '让更多人发现你的动态',
              icon: Icons.tag,
            ),
          ],
        ),
      );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DDPostService service = DDPostService();
  List<DDNotification> items = const [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('dd.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      items = await service.fetchNotifications(token);
      await service.markNotificationsRead(token);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('通知')),
        body: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(18), children: [
              if (loading)
                const _PageLoadState(title: '通知加载中', subtitle: '正在读取真实通知'),
              if (!loading && error != null)
                _PageErrorState(
                    title: '通知加载失败', subtitle: error!, onRetry: load),
              if (!loading && error == null && items.isEmpty)
                const _EmptyStateCard(
                    icon: Icons.notifications_none,
                    title: '暂无通知',
                    subtitle: '新的点赞、评论和关注会显示在这里'),
              if (!loading && error == null)
                ...items.map((item) => ListTile(
                    leading: Icon(item.type == 'comment'
                        ? Icons.comment
                        : item.type == 'follow'
                            ? Icons.person_add
                            : Icons.favorite),
                    title: Text(item.nickname == null
                        ? item.content
                        : '${item.nickname} ${item.content}'),
                    subtitle: Text(item.createdAt))),
            ])),
      );
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatePreviewCard extends StatelessWidget {
  const _StatePreviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(child: _iconFor(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class DynamicDetailPage extends StatefulWidget {
  const DynamicDetailPage({super.key, required this.postId});
  final int postId;
  @override
  State<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DynamicDetailPageState extends State<DynamicDetailPage> {
  final DDPostService service = DDPostService();
  final commentController = TextEditingController();
  DDPost? post;
  List<DDComment> comments = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    commentController.dispose();
    service.dispose();
    super.dispose();
  }

  Future<String> token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('dd.auth.token') ?? '';
    if (value.isEmpty) {
      throw Exception('请先登录');
    }
    return value;
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final t = await token();
      final list = await service.fetchPosts(t);
      final matches = list.where((item) => item.id == widget.postId).toList();
      post = matches.isEmpty ? null : matches.first;
      comments = await service.fetchComments(t, widget.postId);
      if (post == null) throw Exception('动态不存在');
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submitComment() async {
    final value = commentController.text.trim();
    if (value.isEmpty) return;
    try {
      await service.createComment(
          token: await token(), postId: widget.postId, content: value);
      commentController.clear();
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('动态详情')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(padding: const EdgeInsets.all(18), children: [
                  if (error != null)
                    _PageErrorState(
                        title: '加载失败', subtitle: error!, onRetry: load),
                  if (post != null) ...[
                    if (post!.imageUrl != null && post!.imageUrl!.isNotEmpty)
                      ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(post!.imageUrl!,
                              height: 260,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                  height: 260,
                                  child: Center(child: Text('图片加载失败'))))),
                    const SizedBox(height: 16),
                    Text(post!.nickname,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(post!.createdAt),
                    const SizedBox(height: 12),
                    Text(post!.content,
                        style: const TextStyle(fontSize: 17, height: 1.45)),
                    const SizedBox(height: 16),
                    Text('点赞 ${post!.likes}    收藏 ${post!.favorites}'),
                    const SizedBox(height: 22),
                    const Text('评论',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    if (comments.isEmpty)
                      const _EmptyStateCard(
                          icon: Icons.chat_bubble_outline,
                          title: '暂无评论',
                          subtitle: '成为第一个评论的人')
                    else
                      ...comments.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.nickname),
                          subtitle: Text(item.content),
                          trailing: Text(item.createdAt))),
                    TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                            hintText: '写下评论',
                            suffixIcon: IconButton(
                                onPressed: submitComment,
                                icon: const Icon(Icons.send)))),
                  ],
                ]),
              ),
      );
}

class ContentDetailPage extends StatelessWidget {
  const ContentDetailPage({
    super.key,
    required this.title,
    required this.video,
    this.authorName = '推荐用户',
    this.authorAsset = 'assets/figma/profile-portrait-2.jpg',
    this.postId,
  });

  final String title;
  final bool video;
  final String authorName;
  final String authorAsset;
  final int? postId;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: _tdIcon('back'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: _tdIcon('bookmark')),
                    IconButton(
                      onPressed: () => _showShare(context),
                      icon: _tdIcon('share'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                  children: [
                    _SafeAssetImage(
                      asset: video
                          ? 'assets/figma/post-thumbnail-1.jpg'
                          : 'assets/figma/post-thumbnail-2.jpg',
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    Center(
                      child: Icon(
                        video ? Icons.play_circle_fill : Icons.image_outlined,
                        size: 76,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtherProfilePage(
                            name: authorName,
                            avatarAsset: authorAsset,
                          ),
                        ),
                      ),
                      leading: _SafeAvatar(asset: authorAsset),
                      title: Text(
                        authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('刚刚发布'),
                      trailing: const OutlinedButton(
                        onPressed: null,
                        child: Text('关注'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '分享生活中的有趣瞬间，发现更多真实内容。',
                      style: TextStyle(fontSize: 17, height: 1.45),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DetailAction(icon: 'heart', label: '点赞', onTap: () {}),
                        _DetailAction(
                            icon: 'comment', label: '评论', onTap: () {}),
                        _DetailAction(
                            icon: 'bookmark', label: '收藏', onTap: () {}),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _StatePreviewCard(
                      title: '暂无更多评论',
                      subtitle: '成为第一个评论的人',
                      icon: Icons.chat_bubble_outline,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '评论',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const _CommentPreview(),
                    const _CommentPreview(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  void _showShare(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: _tdIcon('link'),
                title: const Text('复制链接'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('链接已复制')));
                },
              ),
              ListTile(
                leading: _tdIcon('message'),
                title: const Text('分享给好友'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: _tdIcon('more'),
                title: const Text('更多分享方式'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
}

class _DetailAction extends StatefulWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  @override
  State<_DetailAction> createState() => _DetailActionState();
}

class _DetailActionState extends State<_DetailAction> {
  bool active = false;
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () {
          setState(() => active = !active);
          widget.onTap();
        },
        icon: _tdIcon(
          active && widget.icon == 'heart'
              ? 'red-heart'
              : active && widget.icon == 'bookmark'
                  ? 'bookmark-filled'
                  : widget.icon,
        ),
        label: Text(active ? '已${widget.label}' : widget.label),
      );
}

class _CommentPreview extends StatelessWidget {
  const _CommentPreview();
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title:
            const Text('用户评论', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('这条内容很有意思，期待更多分享。'),
      );
}

class OtherProfilePage extends StatefulWidget {
  const OtherProfilePage({
    super.key,
    this.name = '推荐用户',
    this.avatarAsset = 'assets/figma/profile-portrait-2.jpg',
    this.userId,
  });
  final String name;
  final String avatarAsset;
  final int? userId;
  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  final DDPostService service = DDPostService();
  Map<String, dynamic>? profile;
  List<DDPost> posts = const [];
  bool loading = true;
  bool actionLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('dd.auth.token') ?? '';
      if (token.isEmpty) {
        throw Exception('请先登录');
      }
      if (widget.userId == null) {
        throw Exception('用户信息不存在');
      }
      final data = await service.fetchUserProfile(token, widget.userId!);
      profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? data;
      final raw = data['posts'];
      posts = raw is List
          ? raw.whereType<Map<String, dynamic>>().map(DDPost.fromJson).toList()
          : const [];
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleFollow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('dd.auth.token') ?? '';
      if (token.isEmpty || widget.userId == null) throw Exception('请先登录');
      setState(() => actionLoading = true);
      await service.toggleFollow(token, widget.userId!);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final following = p?['following'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Ta的主页'), actions: [
        IconButton(
            onPressed: () => _showProfileMenu(context), icon: _tdIcon('more'))
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(18), children: [
                if (error != null)
                  _PageErrorState(
                      title: '主页加载失败', subtitle: error!, onRetry: load),
                Row(children: [
                  CircleAvatar(
                      radius: 42,
                      backgroundImage: AssetImage(widget.avatarAsset)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${p?['nickname'] ?? widget.name}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('${p?['city'] ?? ''}'),
                        const SizedBox(height: 10),
                        FilledButton(
                            onPressed: actionLoading ? null : toggleFollow,
                            child: Text(actionLoading
                                ? '处理中…'
                                : (following ? '已关注' : '关注')))
                      ]))
                ]),
                const SizedBox(height: 24),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                          value: '${p?['posts'] ?? posts.length}', label: '动态'),
                      _Stat(value: '${p?['following'] ?? 0}', label: '关注'),
                      _Stat(value: '${p?['followers'] ?? 0}', label: '粉丝')
                    ]),
                const SizedBox(height: 24),
                if (posts.isEmpty)
                  const _EmptyStateCard(
                      icon: Icons.article_outlined,
                      title: '暂无动态',
                      subtitle: 'Ta 还没有发布动态')
                else
                  ...posts.map((post) => _DynamicPostCard(
                      post: post,
                      onLike: () {},
                      onFavorite: () {},
                      onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  DynamicDetailPage(postId: post.id))))),
              ]),
            ),
    );
  }

  void _showProfileMenu(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const SafeArea(
          child: Wrap(
            children: [
              ListTile(leading: _FigmaIcon('link'), title: Text('分享主页')),
              ListTile(leading: _FigmaIcon('more'), title: Text('举报用户')),
            ],
          ),
        ),
      );
}

class DDProfilePage extends StatefulWidget {
  const DDProfilePage({super.key});
  @override
  State<DDProfilePage> createState() => _DDProfilePageState();
}

class _DDProfilePageState extends State<DDProfilePage> {
  final DDPostService service = DDPostService();
  Map<String, dynamic>? profile;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('dd.auth.token') ?? '';
      if (t.isEmpty) throw Exception('请先登录');
      profile = await service.fetchMe(t);
    } catch (e) {
      if (mounted) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Scaffold(
        appBar: AppBar(title: const Text('我的'), actions: [
          IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage())),
              icon: _tdIcon('more'))
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(18), children: [
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.orange)),
                Row(children: [
                  const CircleAvatar(
                      radius: 38,
                      backgroundImage:
                          AssetImage('assets/figma/profile-portrait-3.jpg')),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text('${p?['nickname'] ?? 'DD 用户'}',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)))
                ]),
                const SizedBox(height: 24),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(value: '${p?['posts'] ?? 0}', label: '动态'),
                      _Stat(value: '${p?['following'] ?? 0}', label: '关注'),
                      _Stat(value: '${p?['followers'] ?? 0}', label: '粉丝')
                    ]),
                const SizedBox(height: 24),
                _ProfileAction(
                    icon: Icons.edit_outlined,
                    title: '编辑资料',
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfilePage()));
                      if (mounted) load();
                    }),
                _ProfileAction(
                    icon: Icons.article_outlined,
                    title: '我的动态',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MyPostsPage())))
              ]));
  }
}

class MyQrCodePage extends StatelessWidget {
  const MyQrCodePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('我的二维码')),
        body: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const Text(
              'DD 用户',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 22),
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_2, size: 190, color: Colors.black),
              ),
            ),
            const SizedBox(height: 18),
            const Text('扫一扫，添加我为好友', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.ios_share),
              label: const Text('保存或分享二维码'),
            ),
          ],
        ),
      );
}

class TopicPage extends StatelessWidget {
  const TopicPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleListPage(
        title: '热门话题',
        items: const ['周末去哪儿', '电影分享', '城市漫步', '新朋友', '美食探店'],
      );
}

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleListPage(
        title: '活动中心',
        items: const ['周末线下见面会', '城市摄影活动', '兴趣交友派对', '创作者交流会'],
      );
}

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleListPage(
        title: '趋势榜单',
        items: const ['本周热门动态', '最受欢迎用户', '热门兴趣圈', '城市热度排行'],
      );
}

class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      _SimpleListPage(title: '我的动态', items: const ['暂无动态', '创建你的第一条动态']);
}

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('编辑资料'),
          actions: [TextButton(onPressed: () {}, child: const Text('保存'))],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: const [
            Center(
              child: CircleAvatar(
                radius: 44,
                child: Icon(Icons.add_a_photo_outlined, size: 30),
              ),
            ),
            SizedBox(height: 22),
            TextField(decoration: InputDecoration(labelText: '昵称')),
            SizedBox(height: 14),
            TextField(decoration: InputDecoration(labelText: '个人简介')),
            SizedBox(height: 14),
            TextField(decoration: InputDecoration(labelText: '城市')),
            SizedBox(height: 14),
            TextField(decoration: InputDecoration(labelText: '兴趣标签')),
          ],
        ),
      );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('账户设置')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _SettingsGroup(
              title: '账号与安全',
              items: ['账号信息', '修改密码', '绑定邮箱和手机号'],
            ),
            _SettingsGroup(
              title: '隐私与通知',
              items: const ['隐私设置', '通知设置', '黑名单'],
              onItemTap: (item) {
                if (item == '通知设置') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsPage(),
                    ),
                  );
                }
              },
            ),
            const _SettingsGroup(title: '其他', items: ['清理缓存', '关于 DD', '退出登录']),
          ],
        ),
      );
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool likes = true;
  bool comments = true;
  bool follows = true;
  bool system = true;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('通知设置')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SwitchListTile(
              title: const Text('点赞通知'),
              subtitle: const Text('有人点赞你的内容时通知'),
              value: likes,
              onChanged: (v) => setState(() => likes = v),
            ),
            SwitchListTile(
              title: const Text('评论通知'),
              subtitle: const Text('有人评论你的内容时通知'),
              value: comments,
              onChanged: (v) => setState(() => comments = v),
            ),
            SwitchListTile(
              title: const Text('关注通知'),
              subtitle: const Text('有人关注你时通知'),
              value: follows,
              onChanged: (v) => setState(() => follows = v),
            ),
            SwitchListTile(
              title: const Text('系统通知'),
              subtitle: const Text('接收 DD 系统消息'),
              value: system,
              onChanged: (v) => setState(() => system = v),
            ),
          ],
        ),
      );
}

class AccountSwitchPage extends StatelessWidget {
  const AccountSwitchPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('切换账户')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('DD 用户'),
              trailing: Icon(Icons.check_circle),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.add)),
              title: const Text('添加其他账户'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          ],
        ),
      );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.items,
    this.onItemTap,
  });
  final String title;
  final List<String> items;
  final ValueChanged<String>? onItemTap;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Card(
            child: Column(
              children: items
                  .map(
                    (item) => ListTile(
                      onTap: onItemTap == null ? null : () => onItemTap!(item),
                      title: Text(item),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
}

class _SimpleListPage extends StatelessWidget {
  const _SimpleListPage({required this.title, required this.items});
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(items[index]),
              subtitle: const Text('静态演示内容'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );
}

class RecommendationFeedPage extends StatelessWidget {
  const RecommendationFeedPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('为你推荐')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _ContentPreviewCard(
              title: '推荐动态 01',
              subtitle: '静态推荐内容',
              icon: Icons.auto_awesome,
              imageAsset: 'assets/figma/post-thumbnail-4.jpg',
            ),
            const _ContentPreviewCard(
              title: '推荐动态 02',
              subtitle: '更多生活方式分享',
              icon: Icons.photo_outlined,
              imageAsset: 'assets/figma/post-thumbnail-5.jpg',
            ),
            _ContentPreviewCard(
              title: '完整视频动态',
              subtitle: '点击查看详情',
              icon: Icons.play_circle_outline,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ContentDetailPage(title: '完整视频动态', video: true),
                ),
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action, this.onTap});
  final String title;
  final String action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onTap,
              child: Text(
                action,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      );
}

class _ContentPreviewCard extends StatelessWidget {
  const _ContentPreviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.imageAsset,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 3,
          ),
          leading: imageAsset == null
              ? _iconFor(icon)
              : CircleAvatar(backgroundImage: AssetImage(imageAsset!)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _CreatorChip extends StatelessWidget {
  const _CreatorChip({required this.index});
  final int index;
  static const _images = [
    'assets/figma/profile-portrait-1.jpg',
    'assets/figma/profile-portrait-2.jpg',
    'assets/figma/profile-portrait-3.jpg',
    'assets/figma/profile-portrait-4.jpg',
    'assets/figma/profile-portrait-5.jpg',
  ];

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherProfilePage(
              name: '创作者 ${index + 1}',
              avatarAsset: _images[index % _images.length],
            ),
          ),
        ),
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundImage: AssetImage(_images[index % _images.length]),
              ),
              const SizedBox(height: 7),
              Text('用户${index + 1}', overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _FeaturePostCard extends StatelessWidget {
  const _FeaturePostCard({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: AssetImage('assets/figma/post-thumbnail-3.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                '今天也要发现一点小惊喜',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      );
}

// Kept for the reference-detail routes.
// ignore: unused_element
class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow();
  @override
  Widget build(BuildContext context) => const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text('推荐用户'),
        subtitle: Text('分享了新的生活动态'),
        trailing: Icon(Icons.chevron_right),
      );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      );
}

class _MediaAction extends StatelessWidget {
  const _MediaAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
            Text(label),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: .6))),
        ],
      );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: _iconFor(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}
