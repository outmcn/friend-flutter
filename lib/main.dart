import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tdesign_flutter_icons/tdesign_flutter_icons.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import 'post_service.dart';

String formatDDTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final value = parsed.toUtc().add(const Duration(hours: 8));
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final difference = now.difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inMinutes < 60) return '${difference.inMinutes}分钟前';
  if (difference.inHours < 24) return '${difference.inHours}小时前';
  if (difference.inDays < 7) return '${difference.inDays}天前';
  return '${value.year}年${value.month}月${value.day}日';
}

Future<void> syncCachedLocation(DDPostService service, String token) async {
  const cacheAge = Duration(hours: 1);
  try {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedAt = prefs.getInt('dd.location.cachedAt');
    var latitude = prefs.getDouble('dd.location.latitude');
    var longitude = prefs.getDouble('dd.location.longitude');
    final cacheValid = cachedAt != null &&
        now - cachedAt < cacheAge.inMilliseconds &&
        latitude != null &&
        longitude != null;
    if (!cacheValid) {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      latitude = position.latitude;
      longitude = position.longitude;
      await prefs.setDouble('dd.location.latitude', latitude);
      await prefs.setDouble('dd.location.longitude', longitude);
      await prefs.setInt('dd.location.cachedAt', now);
    }
    await service.updateLocation(
      token: token,
      latitude: latitude,
      longitude: longitude,
    );
  } catch (_) {
    // Location is optional; feeds remain available without it.
  }
}

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
      const HomePage(),
      const DiscoverPage(),
      const ChatPage(),
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
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '聊天',
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('首页'),
          actions: [IconButton(onPressed: () {}, icon: _tdIcon('search'))],
        ),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            28 + MediaQuery.of(context).padding.bottom + 88,
          ),
          children: [
            _DiscoverTile(
              icon: Icons.sports_esports_outlined,
              title: '游戏陪玩',
              subtitle: '寻找一起开黑的游戏伙伴',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GamePlayPage()),
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
          ],
        ),
      );
}

class _DynamicPostCard extends StatelessWidget {
  const _DynamicPostCard({
    required this.post,
    required this.onLike,
    required this.onFavorite,
    required this.onOpen,
    this.onComment,
    this.onFollow,
    this.onDelete,
    this.authorNavigation = true,
  });
  final DDPost post;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;
  final VoidCallback? onComment;
  final VoidCallback? onFollow;
  final VoidCallback? onDelete;
  final bool authorNavigation;

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
                  InkWell(
                    onTap: !authorNavigation || post.userId == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OtherProfilePage(
                                  userId: post.userId,
                                  name: post.nickname,
                                ),
                              ),
                            ),
                    borderRadius: BorderRadius.circular(24),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: post.avatar.isEmpty
                          ? null
                          : NetworkImage(DDPostService.mediaUrl(post.avatar)),
                      child: post.avatar.isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: !authorNavigation || post.userId == null
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OtherProfilePage(
                                            userId: post.userId,
                                            name: post.nickname,
                                          ),
                                        ),
                                      ),
                              child: Text(post.nickname,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (post.distanceKm != null) ...[
                              const SizedBox(width: 7),
                              _DistanceBadge(distanceKm: post.distanceKm!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatDDTime(post.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: '删除动态',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    )
                  else if (onFollow != null && post.userId != null)
                    OutlinedButton(
                      onPressed: post.following ? null : onFollow,
                      child: Text(post.following ? '私聊' : '关注'),
                    ),
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
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Image.network(
                      post.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onLike,
                    icon: Icon(
                        post.liked ? Icons.thumb_up : Icons.thumb_up_outlined),
                    label: Text('${post.likes}'),
                  ),
                  TextButton.icon(
                    onPressed: onComment ?? onOpen,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text('${post.comments}'),
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
              MaterialPageRoute(builder: (_) => const ChatPage()),
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

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final DDPostService service = DDPostService();
  List<DDPost> posts = const [];
  bool loading = true;
  bool _refreshing = false;
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

  Future<void> load({bool fromRefresh = false}) async {
    if (fromRefresh) {
      if (_refreshing) return;
      _refreshing = true;
    } else {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('dd.auth.token') ?? '';
      if (t.isEmpty) throw Exception('登录后加载发现内容');
      await syncCachedLocation(service, t);
      posts = await service.fetchPosts(t);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          _refreshing = false;
        });
      } else {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('发现'),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatPage(),
                ),
              ),
              icon: const Icon(Icons.notifications_none),
              tooltip: '通知中心',
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreatePostPage(),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '创建动态',
            ),
          ],
        ),
        body: RefreshIndicator(
            onRefresh: () => load(fromRefresh: true),
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    18, 8, 18, 28 + MediaQuery.of(context).padding.bottom + 88),
                children: [
                  const SizedBox(height: 18),
                  if (loading)
                    const _PageLoadState(
                      title: '动态加载中',
                      subtitle: '正在读取发现内容',
                    ),
                  if (!loading && error != null)
                    _PageErrorState(
                      title: '发现加载失败',
                      subtitle: error!,
                      onRetry: load,
                    ),
                  if (!loading && error == null && posts.isEmpty)
                    const _EmptyStateCard(
                      icon: Icons.article_outlined,
                      title: '暂无动态',
                      subtitle: '暂时没有可发现的真实动态',
                    ),
                  if (!loading && error == null)
                    ...posts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DynamicPostCard(
                          post: post,
                          onLike: () async {
                            try {
                              final p = await SharedPreferences.getInstance();
                              final t = p.getString('dd.auth.token') ?? '';
                              if (t.isEmpty) throw Exception('请先登录');
                              await service.toggleLike(t, post.id);
                              await load();
                            } catch (e) {
                              if (mounted) {
                                setState(() => error = e
                                    .toString()
                                    .replaceFirst('Exception: ', ''));
                              }
                            }
                          },
                          onFavorite: () async {
                            try {
                              final p = await SharedPreferences.getInstance();
                              final t = p.getString('dd.auth.token') ?? '';
                              if (t.isEmpty) throw Exception('请先登录');
                              await service.toggleFavorite(t, post.id);
                              await load();
                            } catch (e) {
                              if (mounted) {
                                setState(() => error = e
                                    .toString()
                                    .replaceFirst('Exception: ', ''));
                              }
                            }
                          },
                          onOpen: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DynamicDetailPage(postId: post.id),
                            ),
                          ),
                          onComment: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DynamicDetailPage(
                                postId: post.id,
                                focusComment: true,
                              ),
                            ),
                          ),
                          onFollow: post.userId == null
                              ? null
                              : () async {
                                  final p =
                                      await SharedPreferences.getInstance();
                                  final t = p.getString('dd.auth.token') ?? '';
                                  if (t.isEmpty) return;
                                  await service.toggleFollow(t, post.userId!);
                                  await load();
                                },
                        ),
                      ),
                    ),
                ])),
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

class _PostLocation {
  const _PostLocation(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
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
    final decoded = img.decodeImage(bytes);
    final resized = decoded == null
        ? null
        : (decoded.width > 1600
            ? img.copyResize(decoded, width: 1600)
            : decoded);
    final compressed =
        resized == null ? bytes : img.encodeJpg(resized, quality: 82);
    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  Future<_PostLocation?> _locationForPost(String token) async {
    const cacheAge = Duration(hours: 1);
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt('dd.location.cachedAt');
    final cachedLatitude = prefs.getDouble('dd.location.latitude');
    final cachedLongitude = prefs.getDouble('dd.location.longitude');
    final now = DateTime.now().millisecondsSinceEpoch;
    double? latitude;
    double? longitude;
    if (cachedAt != null &&
        now - cachedAt < cacheAge.inMilliseconds &&
        cachedLatitude != null &&
        cachedLongitude != null) {
      latitude = cachedLatitude;
      longitude = cachedLongitude;
    } else {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      latitude = position.latitude;
      longitude = position.longitude;
      await prefs.setDouble('dd.location.latitude', latitude);
      await prefs.setDouble('dd.location.longitude', longitude);
      await prefs.setInt('dd.location.cachedAt', now);
    }
    await _service.updateLocation(
      token: token,
      latitude: latitude,
      longitude: longitude,
    );
    return _PostLocation(latitude, longitude);
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
                        final location = await _locationForPost(token);
                        await _service.createPost(
                          token: token,
                          content: _content.text.trim(),
                          imageDataUrl: await _imageDataUrl(),
                          latitude: location?.latitude,
                          longitude: location?.longitude,
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

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
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
                    subtitle: Text(formatDDTime(item.createdAt)))),
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
  const DynamicDetailPage({
    super.key,
    required this.postId,
    this.focusComment = false,
  });
  final int postId;
  final bool focusComment;
  @override
  State<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DynamicDetailPageState extends State<DynamicDetailPage> {
  final DDPostService service = DDPostService();
  final commentController = TextEditingController();
  final commentFocusNode = FocusNode();
  DDComment? replyingTo;
  DDPost? post;
  List<DDComment> comments = const [];
  bool loading = true;
  bool deleting = false;
  bool followLoading = false;
  String? error;
  int? currentUserId;
  bool get isOwner => post?.userId != null && currentUserId == post!.userId;

  @override
  void initState() {
    super.initState();
    load();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(commentFocusNode);
      });
    }
  }

  @override
  void dispose() {
    commentFocusNode.dispose();
    commentController.dispose();
    service.dispose();
    super.dispose();
  }

  Future<String> token() async {
    final p = await SharedPreferences.getInstance();
    final value = p.getString('dd.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final t = await token();
      final me = await service.fetchMe(t);
      currentUserId = (me['id'] as num?)?.toInt();
      post = await service.fetchPost(t, widget.postId);
      comments = await service.fetchComments(t, widget.postId);
      if (post == null) throw Exception('动态不存在');
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submitComment() async {
    final value = commentController.text.trim();
    if (value.isEmpty) return;
    try {
      await service.createComment(
        token: await token(),
        postId: widget.postId,
        content: value,
        parentId: replyingTo?.id,
      );
      commentController.clear();
      if (mounted) setState(() => replyingTo = null);
      await load();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<Widget> _buildCommentTree(List<DDComment> source) {
    final roots = source.where((c) => c.parentId == null).toList();
    final repliesByParent = <int, List<DDComment>>{};
    for (final comment in source.where((c) => c.parentId != null)) {
      repliesByParent.putIfAbsent(comment.parentId!, () => []).add(comment);
    }
    final result = <Widget>[];
    for (final root in roots) {
      result.add(_commentTile(root));
      final replies = repliesByParent[root.id] ?? const <DDComment>[];
      if (replies.isNotEmpty) {
        result.add(
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Column(
              children: replies.map(_commentTile).toList(),
            ),
          ),
        );
      }
    }
    return result;
  }

  Future<void> _commentMenu(DDComment comment) async {
    final isMine = currentUserId != null && comment.userId == currentUserId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading:
                  Icon(isMine ? Icons.delete_outline : Icons.report_outlined),
              title: Text(isMine ? '删除' : '举报'),
              onTap: () => Navigator.pop(context, isMine ? 'delete' : 'report'),
            ),
          ],
        ),
      ),
    );
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: comment.content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制')),
        );
      }
    } else if (action == 'delete') {
      try {
        await service.deleteComment(await token(), comment.id);
        await load();
      } catch (e) {
        if (mounted) {
          setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        }
      }
    } else if (action == 'report') {
      final reason = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _ReportPostPageState.reportReasons
                .map((item) => ListTile(
                      title: Text(item),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, item),
                    ))
                .toList(),
          ),
        ),
      );
      if (reason == null) return;
      try {
        await service.reportComment(
          token: await token(),
          commentId: comment.id,
          reason: reason,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('举报已提交')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  Widget _commentTile(DDComment comment) => InkWell(
        onTap: () => setState(() => replyingTo = comment),
        onLongPress: () => _commentMenu(comment),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: InkWell(
            onTap: comment.userId == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherProfilePage(
                          userId: comment.userId,
                          name: comment.nickname,
                        ),
                      ),
                    ),
            borderRadius: BorderRadius.circular(20),
            child: const CircleAvatar(
              child: Icon(Icons.person_outline, size: 18),
            ),
          ),
          title: InkWell(
            onTap: comment.userId == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherProfilePage(
                          userId: comment.userId,
                          name: comment.nickname,
                        ),
                      ),
                    ),
            child: Text(
              comment.nickname,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          subtitle: Text(comment.content),
          trailing: Text(
            formatDDTime(comment.createdAt),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      );

  Future<void> _toggleLike() async {
    try {
      await service.toggleLike(await token(), widget.postId);
      await load();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await service.toggleFavorite(await token(), widget.postId);
      await load();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleFollow() async {
    if (isOwner || post?.userId == null || followLoading) return;
    try {
      setState(() => followLoading = true);
      await service.toggleFollow(await token(), post!.userId!);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => followLoading = false);
    }
  }

  Future<void> _delete() async {
    try {
      setState(() => deleting = true);
      await service.deletePost(await token(), widget.postId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  Future<void> _openReportPage() async {
    if (isOwner) return;
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPostPage(
          postId: widget.postId,
          service: service,
          token: token,
        ),
      ),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('举报已提交')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = post;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        automaticallyImplyLeading: true,
        title: const Text('动态详情'),
        actions: [
          if (item != null && !isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  onPressed: _openReportPage,
                  icon: const Icon(Icons.report_gmailerrorred_outlined),
                ),
              ),
            ),
          if (item != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  onPressed: () {},
                  icon: const Icon(TIcons.share_1),
                  tooltip: '分享',
                ),
              ),
            ),
          if (item != null && isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  onPressed: deleting ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除动态',
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  children: [
                    if (error != null)
                      _PageErrorState(
                          title: '加载失败', subtitle: error!, onRetry: load),
                    if (item != null) ...[
                      Row(children: [
                        InkWell(
                          onTap: item.userId == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OtherProfilePage(
                                        userId: item.userId,
                                        name: item.nickname,
                                      ),
                                    ),
                                  ),
                          borderRadius: BorderRadius.circular(26),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundImage: item.avatar.isEmpty
                                ? null
                                : NetworkImage(item.avatar),
                            child: item.avatar.isEmpty
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              InkWell(
                                onTap: item.userId == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OtherProfilePage(
                                              userId: item.userId,
                                              name: item.nickname,
                                            ),
                                          ),
                                        ),
                                child: Text(item.nickname,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17)),
                              ),
                              const SizedBox(height: 4),
                              Text(formatDDTime(item.createdAt),
                                  style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                      fontSize: 12))
                            ])),
                        if (!isOwner)
                          OutlinedButton(
                            onPressed: followLoading || item.following
                                ? null
                                : _toggleFollow,
                            child: Text(followLoading
                                ? '处理中…'
                                : (item.following ? '私聊' : '关注')),
                          ),
                      ]),
                      const SizedBox(height: 18),
                      if (item.content.trim().isNotEmpty)
                        Text(item.content,
                            style: const TextStyle(fontSize: 18, height: 1.5)),
                      if (item.imageUrl != null &&
                          item.imageUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PostImageHolder(url: item.imageUrl!)
                      ],
                      const SizedBox(height: 18),
                      Row(children: [
                        _DetailAction(
                            icon: item.liked
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            label: '${item.likes}',
                            active: item.liked,
                            onTap: _toggleLike),
                        const SizedBox(width: 24),
                        _DetailAction(
                            icon: Icons.chat_bubble_outline,
                            label: '${comments.length}',
                            onTap: () {}),
                        const SizedBox(width: 24),
                        _DetailAction(
                            icon: item.favorited
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            label: '${item.favorites}',
                            active: item.favorited,
                            onTap: _toggleFavorite),
                      ]),
                      const Divider(height: 32),
                      const Text('评论',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (comments.isEmpty)
                        const _EmptyStateCard(
                            icon: Icons.chat_bubble_outline,
                            title: '暂无评论',
                            subtitle: '成为第一个评论的人')
                      else
                        ..._buildCommentTree(comments),
                    ],
                  ]),
            ),
      bottomNavigationBar: item == null || loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: commentController,
                  focusNode: commentFocusNode,
                  decoration: InputDecoration(
                    filled: true,
                    hintText: replyingTo == null
                        ? '写下你的评论…'
                        : '回复 ${replyingTo!.nickname}…',
                    suffixIcon: IconButton(
                      onPressed: deleting ? null : submitComment,
                      icon: const Icon(Icons.send),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _PostImageHolder extends StatelessWidget {
  const _PostImageHolder({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (_, __, ___) => Container(
            height: 220,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 42),
                SizedBox(height: 8),
                Text('图片加载失败'),
              ],
            ),
          ),
        ),
      );
}

class _DetailAction extends StatelessWidget {
  const _DetailAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? Colors.pinkAccent : null),
              const SizedBox(width: 5),
              Text(label),
            ],
          ),
        ),
      );
}

class ReportPostPage extends StatefulWidget {
  const ReportPostPage({
    super.key,
    required this.postId,
    required this.service,
    required this.token,
  });
  final int postId;
  final DDPostService service;
  final Future<String> Function() token;

  @override
  State<ReportPostPage> createState() => _ReportPostPageState();
}

class _ReportPostPageState extends State<ReportPostPage> {
  static const reportReasons = [
    '低俗色情',
    '攻击辱骂',
    '涉嫌诈骗',
    '未成年人',
    '政治敏感',
    '网络谣言',
    '违法信息',
    '血腥暴力',
    '广告引流',
    '网乞相关',
    '恶意诱导到其他平台',
    '其他',
  ];

  String? reason;
  bool submitting = false;
  String? error;

  Future<void> submit() async {
    if (reason == null || submitting) return;
    try {
      setState(() {
        submitting = true;
        error = null;
      });
      await widget.service.reportPost(
        token: await widget.token(),
        postId: widget.postId,
        reason: reason!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          submitting = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('举报动态')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              '请选择举报原因',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...reportReasons.map(
              (item) => RadioListTile<String>(
                value: item,
                groupValue: reason,
                title: Text(item),
                secondary: const Icon(Icons.chevron_right),
                onChanged: submitting
                    ? null
                    : (value) => setState(() => reason = value),
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: reason == null || submitting ? null : submit,
              child: Text(submitting ? '提交中…' : '提交举报'),
            ),
          ],
        ),
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
  final String? avatarAsset;
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
  bool isFollowing = false;
  bool isProfileLiked = false;
  int profileLikes = 0;
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
      final rawProfile = data['profile'];
      final loadedProfile = rawProfile is Map
          ? rawProfile.cast<String, dynamic>()
          : <String, dynamic>{...data};
      final followingState = data['following'] == true;
      profile = loadedProfile;
      isFollowing = followingState;
      isProfileLiked = data['liked'] == true;
      profileLikes = (loadedProfile['likes'] as num?)?.toInt() ?? 0;
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
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> toggleProfileLike() async {
    if (widget.userId == null || isProfileLiked) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('dd.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      setState(() => actionLoading = true);
      final response = await service.toggleProfileLike(token, widget.userId!);
      isProfileLiked = response['liked'] == true;
      profileLikes = (response['likes'] as num?)?.toInt() ?? profileLikes;
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final following = isFollowing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ta的主页'),
        actions: [
          IconButton(
            onPressed: () => _showProfileMenu(context),
            icon: _tdIcon('more'),
          ),
        ],
      ),
      bottomNavigationBar: loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: actionLoading || following ? null : toggleFollow,
                    child: Text(
                      actionLoading ? '处理中…' : (following ? '私聊' : '关注'),
                    ),
                  ),
                ),
              ),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(18), children: [
                if (error != null)
                  _PageErrorState(
                      title: '主页加载失败', subtitle: error!, onRetry: load),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p?['nickname'] ?? widget.name}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('${p?['city'] ?? ''}'),
                        Text('在线 ${p?['activeDays'] ?? 0} 天'),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundImage:
                            (p?['avatar']?.toString() ?? '').trim().isEmpty
                                ? null
                                : NetworkImage(
                                    DDPostService.mediaUrl(
                                      p?['avatar']?.toString(),
                                    ),
                                  ),
                        child: (p?['avatar']?.toString() ?? '').trim().isEmpty
                            ? const Icon(Icons.person_outline, size: 34)
                            : null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ]),
                const SizedBox(height: 24),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                          value: '${p?['posts'] ?? posts.length}', label: '动态'),
                      _Stat(value: '${p?['following'] ?? 0}', label: '关注'),
                      _Stat(value: '${p?['followers'] ?? 0}', label: '粉丝'),
                      InkWell(
                        onTap: isProfileLiked ? null : toggleProfileLike,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            children: [
                              Icon(
                                isProfileLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    isProfileLiked ? Colors.pinkAccent : null,
                              ),
                              Text('$profileLikes'),
                              const Text('赞'),
                            ],
                          ),
                        ),
                      ),
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
                      authorNavigation: false,
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
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_outlined),
                title: const Text('举报用户'),
              ),
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
  List<DDPost> posts = [];
  int selectedTab = 0;
  bool loading = true;
  bool tabLoading = false;
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

  Future<void> load({int? tab}) async {
    final targetTab = tab ?? selectedTab;
    final isTabSwitch = tab != null && !loading;
    if (mounted) {
      setState(() {
        error = null;
        if (isTabSwitch) {
          selectedTab = targetTab;
          tabLoading = true;
        } else {
          loading = true;
        }
      });
    }
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('dd.auth.token') ?? '';
      if (t.isEmpty) throw Exception('请先登录');
      final loadedProfile = await service.fetchMe(t);
      final loadedPosts = targetTab == 0
          ? await service.fetchMyPosts(t)
          : targetTab == 1
              ? await service.fetchLikedPosts(t)
              : await service.fetchFavoritedPosts(t);
      if (!mounted) return;
      setState(() {
        profile = loadedProfile;
        posts = loadedPosts;
        selectedTab = targetTab;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          tabLoading = false;
        });
      }
    }
  }

  Future<void> _deletePostFromProfile(DDPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确认删除这条动态？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('dd.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      await service.deletePost(token, post.id);
      await load(tab: 0);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('动态已删除')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
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
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (error != null)
                    _PageErrorState(
                      title: '资料加载失败',
                      subtitle: error!,
                      onRetry: load,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: (p?['avatar']?.toString() ?? '')
                                .trim()
                                .isNotEmpty
                            ? NetworkImage(
                                DDPostService.mediaUrl(p!['avatar'].toString()))
                            : null,
                        child: (p?['avatar']?.toString() ?? '').trim().isEmpty
                            ? const Icon(Icons.person, size: 34)
                            : null,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text('${p?['nickname'] ?? 'DD 用户'}',
                                    style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800)),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const EditProfilePage()));
                                  if (mounted) load();
                                },
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('编辑'),
                              ),
                            ]),
                            const SizedBox(height: 9),
                            Wrap(spacing: 7, runSpacing: 7, children: [
                              _ProfileTag(
                                  text: '在线 ${p?['activeDays'] ?? 0} 天'),
                              _ProfileTag(text: '${p?['city'] ?? '未知地区'}'),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(value: '${p?['following'] ?? 0}', label: '关注'),
                        _Stat(value: '${p?['followers'] ?? 0}', label: '粉丝'),
                        _Stat(value: '${p?['likes'] ?? 0}', label: '获赞'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: ['动态', '喜欢', '收藏']
                        .asMap()
                        .entries
                        .map((entry) => Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => load(tab: entry.key),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(entry.value,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: selectedTab == entry.key
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : null,
                                            )),
                                        const SizedBox(height: 7),
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 160),
                                          curve: Curves.easeOutCubic,
                                          width:
                                              selectedTab == entry.key ? 24 : 0,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                        ),
                                      ]),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  if (error != null)
                    _PageErrorState(
                      title: '动态加载失败',
                      subtitle: error!,
                      onRetry: () => load(tab: selectedTab),
                    )
                  else if (tabLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 38),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _MyPostWaterfall(
                      posts: posts,
                      onDelete:
                          selectedTab == 0 ? _deletePostFromProfile : null,
                      emptyLabel: selectedTab == 0
                          ? '动态'
                          : selectedTab == 1
                              ? '喜欢'
                              : '收藏',
                    ),
                ],
              ),
            ),
    );
  }
}

class _MyPostWaterfall extends StatelessWidget {
  const _MyPostWaterfall({
    required this.posts,
    required this.emptyLabel,
    this.onDelete,
  });
  final List<DDPost> posts;
  final String emptyLabel;
  final ValueChanged<DDPost>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return _ProfileEmptyTab(label: emptyLabel);
    final left = <DDPost>[];
    final right = <DDPost>[];
    for (var i = 0; i < posts.length; i++) {
      (i.isEven ? left : right).add(posts[i]);
    }
    Widget column(List<DDPost> items) => Expanded(
          child: Column(
            children: items
                .map((post) => _MyWaterfallCard(post: post, onDelete: onDelete))
                .toList(),
          ),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      column(left),
      const SizedBox(width: 10),
      column(right),
    ]);
  }
}

class _MyWaterfallCard extends StatelessWidget {
  const _MyWaterfallCard({required this.post, this.onDelete});
  final DDPost post;
  final ValueChanged<DDPost>? onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DynamicDetailPage(postId: post.id)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (post.imageUrl?.trim().isNotEmpty == true)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    DDPostService.mediaUrl(post.imageUrl),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 112,
                      child: Center(
                          child: Icon(Icons.image_not_supported_outlined)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.content.isEmpty ? '分享了一条动态' : post.content,
                          maxLines: 4, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (onDelete != null) ...[
                          IconButton(
                            tooltip: '删除动态',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => onDelete!(post),
                            icon: const Icon(Icons.delete_outline, size: 17),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Icon(
                            post.liked
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 15),
                        const SizedBox(width: 3),
                        Text('${post.likes}',
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(width: 10),
                        const Icon(Icons.chat_bubble_outline, size: 15),
                        const SizedBox(width: 3),
                        Text('${post.comments}',
                            style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ]),
              ),
            ]),
          ),
        ),
      );
}

class _ProfileEmptyTab extends StatelessWidget {
  const _ProfileEmptyTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 46),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, size: 38),
            const SizedBox(height: 10),
            Text('暂无$label内容'),
          ]),
        ),
      );
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

class GamePlayPage extends StatelessWidget {
  const GamePlayPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('游戏陪玩')),
        body: const Center(
          child: _EmptyStateCard(
            icon: Icons.sports_esports_outlined,
            title: '游戏陪玩暂未接入',
            subtitle: '陪玩匹配和服务功能将在后续开放',
          ),
        ),
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

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});
  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final service = DDPostService();
  List<DDPost> posts = const [];
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
      posts = await service.fetchMyPosts(token);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deletePost(DDPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确认删除这条动态？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token =
          (await SharedPreferences.getInstance()).getString('dd.auth.token') ??
              '';
      if (token.isEmpty) throw Exception('请先登录');
      await service.deletePost(token, post.id);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('动态已删除')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('我的动态')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    24 + MediaQuery.of(context).padding.bottom + 88,
                  ),
                  children: [
                    if (error != null)
                      _PageErrorState(
                        title: '动态加载失败',
                        subtitle: error!,
                        onRetry: load,
                      )
                    else if (posts.isEmpty)
                      const _EmptyStateCard(
                        icon: Icons.article_outlined,
                        title: '暂无动态',
                        subtitle: '发布你的第一条动态吧',
                      )
                    else
                      ...posts.map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DynamicPostCard(
                            post: post,
                            authorNavigation: false,
                            onDelete: () => _deletePost(post),
                            onLike: () async {
                              final token =
                                  (await SharedPreferences.getInstance())
                                          .getString('dd.auth.token') ??
                                      '';
                              if (token.isNotEmpty) {
                                await service.toggleLike(token, post.id);
                                await load();
                              }
                            },
                            onFavorite: () async {
                              final token =
                                  (await SharedPreferences.getInstance())
                                          .getString('dd.auth.token') ??
                                      '';
                              if (token.isNotEmpty) {
                                await service.toggleFavorite(token, post.id);
                                await load();
                              }
                            },
                            onOpen: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DynamicDetailPage(postId: post.id),
                              ),
                            ),
                            onComment: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DynamicDetailPage(
                                  postId: post.id,
                                  focusComment: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final service = DDPostService();
  final nickname = TextEditingController();
  final city = TextEditingController();
  XFile? image;
  bool loading = true;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.dispose();
    nickname.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final token = p.getString('dd.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final data = await service.fetchMe(token);
      nickname.text = '${data['nickname'] ?? ''}';
      city.text = '${data['city'] ?? ''}';
    } catch (e) {
      if (mounted) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickAvatar() async {
    try {
      final value = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (value != null && mounted)
        setState(() {
          image = value;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '头像选择失败：$e');
    }
  }

  Future<String?> _avatarDataUrl() async {
    if (image == null) return null;
    final bytes = await image!.readAsBytes();
    final decoded = img.decodeImage(bytes);
    final resized =
        decoded == null ? null : img.copyResize(decoded, width: 512);
    final compressed =
        resized == null ? bytes : img.encodeJpg(resized, quality: 86);
    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  Future<void> save() async {
    try {
      setState(() => saving = true);
      final p = await SharedPreferences.getInstance();
      final token = p.getString('dd.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final avatar = await _avatarDataUrl();
      await service.updateMe(
          token: token,
          nickname: nickname.text.trim(),
          city: city.text.trim(),
          avatar: avatar);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('编辑资料'), actions: [
          TextButton(
              onPressed: loading || saving ? null : save,
              child: Text(saving ? '保存中…' : '保存'))
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(18), children: [
                GestureDetector(
                    onTap: pickAvatar,
                    child: CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            image == null ? null : FileImage(File(image!.path)),
                        child: image == null
                            ? const Icon(Icons.add_a_photo_outlined, size: 30)
                            : null)),
                const SizedBox(height: 22),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.orange)),
                TextField(
                    controller: nickname,
                    decoration: const InputDecoration(labelText: '昵称')),
                const SizedBox(height: 14),
                TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: '城市')),
              ]),
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
            const _EmptyStateCard(
              icon: Icons.play_circle_outline,
              title: '推荐动态',
              subtitle: '登录后显示真实推荐动态',
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
        onTap: null,
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

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distanceKm});
  final double distanceKm;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '${distanceKm.toStringAsFixed(1)} km',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _ProfileShortcuts extends StatelessWidget {
  const _ProfileShortcuts({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final entries = <Map<String, dynamic>>[
      {'icon': Icons.auto_awesome_outlined, 'label': '会员中心'},
      {'icon': Icons.storefront_outlined, 'label': '个性商城'},
      {'icon': Icons.collections_bookmark_outlined, 'label': '数字藏馆'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: entries
            .map((entry) => Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: entry['label'] == '个性商城'
                        ? onEdit
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${entry['label']}暂未接入'))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(entry['icon'] as IconData, size: 23),
                        const SizedBox(height: 6),
                        Text(entry['label'] as String,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
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
