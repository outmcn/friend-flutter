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
import 'package:video_player/video_player.dart';

import 'post_service.dart';

String _formatExactPostTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final value = parsed.toUtc().add(const Duration(hours: 8));
  String two(int value) => value.toString().padLeft(2, '0');
  final period = value.hour < 12 ? '上午' : '下午';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '$period ${two(hour)}:${two(value.minute)}';
}

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

Future<String> cachedCityLabel(DDPostService service, String token) async {
  const cacheAge = Duration(hours: 1);
  final prefs = await SharedPreferences.getInstance();
  final cachedAt = prefs.getInt('dd.location.cachedAt');
  final cachedCity = (prefs.getString('dd.location.city') ?? '').trim();
  final fresh = cachedAt != null &&
      DateTime.now().millisecondsSinceEpoch - cachedAt <
          cacheAge.inMilliseconds;
  if (fresh && cachedCity.isNotEmpty) return cachedCity;
  try {
    final profile = await service.fetchMe(token);
    final city = '${profile['city'] ?? ''}'.trim();
    if (city.isNotEmpty) await prefs.setString('dd.location.city', city);
    return city.isEmpty ? '城市' : city;
  } catch (_) {
    return cachedCity.isEmpty ? '城市' : cachedCity;
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
          .getUrl(Uri.parse('https://friend.outmcn.net/api'))
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('正在连接网络…'),
            ],
          ),
        ),
      );
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
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: '娱乐',
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

  void _unavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature暂未接入')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 28 + MediaQuery.of(context).padding.bottom + 88),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 11,
                    child: _HomeFolderCard(
                      icon: Icons.sports_esports_outlined,
                      title: '游戏陪玩',
                      subtitle: '开黑交友不孤单',
                      meta: '1,236 位陪玩',
                      tabLabel: 'PLAY',
                      colors: const [Color(0xffff6b9d), Color(0xffa855f7)],
                      tabAlignment: Alignment.topRight,
                      borderRadius: BorderRadius.circular(28),
                      height: 250,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const GameCompanionPlazaPage())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 9,
                    child: Column(
                      children: [
                        _HomeFolderCard(
                          icon: Icons.mic_none,
                          title: '语音匹配',
                          subtitle: '说句话，遇见懂你的人',
                          meta: '正在寻找声音伙伴',
                          tabLabel: 'VOICE',
                          colors: const [Color(0xff6e4fe0), Color(0xffd46bc8)],
                          tabAlignment: Alignment.topLeft,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(26),
                            bottomLeft: Radius.circular(22),
                            bottomRight: Radius.circular(12),
                          ),
                          height: 119,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const VoiceMatchPage())),
                        ),
                        const SizedBox(height: 12),
                        _HomeFolderCard(
                          icon: Icons.auto_awesome,
                          title: '缘分匹配',
                          subtitle: '遇见聊得来的人',
                          meta: '正在寻找默契伙伴',
                          tabLabel: 'FATE',
                          colors: const [Color(0xffff9a5a), Color(0xffff5f8f)],
                          tabAlignment: Alignment.topLeft,
                          borderRadius: BorderRadius.circular(22),
                          height: 119,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FateMatchPage())),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _HomeCartoonCard(
                icon: Icons.menu_book_outlined,
                title: '玩剧本',
                subtitle: '拨开迷雾，寻找真相',
                badge: 'GO',
                colors: const [Color(0xff352b62), Color(0xff8b4e9f)],
                onTap: () => _unavailable(context, '玩剧本'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.groups_2_outlined,
                      title: '真人带本',
                      subtitle: '52 局等待中',
                      badge: 'LIVE',
                      colors: const [Color(0xff5a315b), Color(0xffd46b82)],
                      onTap: () => _unavailable(context, '真人带本'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.smart_toy_outlined,
                      title: 'AI剧本杀',
                      subtitle: '随时开局',
                      badge: 'AI',
                      colors: const [Color(0xff164b68), Color(0xff3c9fa9)],
                      onTap: () => _unavailable(context, 'AI剧本杀'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.mic_external_on_outlined,
                      title: '嗨歌抢唱',
                      subtitle: '轮到你开唱',
                      badge: 'NEW',
                      colors: const [Color(0xff713b42), Color(0xffe38d57)],
                      onTap: () => _unavailable(context, '嗨歌抢唱'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.casino_outlined,
                      title: '骗子酒馆',
                      subtitle: '猜猜谁在说谎',
                      badge: 'NEW',
                      colors: const [Color(0xff254d72), Color(0xff63a5c5)],
                      onTap: () => _unavailable(context, '骗子酒馆'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _HomeCartoonCard(
                icon: Icons.flight_takeoff_outlined,
                title: '飞行棋',
                subtitle: '轻松玩一局',
                badge: 'PLAY',
                colors: const [Color(0xff2c5d3a), Color(0xff83bc67)],
                onTap: () => _unavailable(context, '飞行棋'),
              ),
            ],
          ),
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
    this.listMode = false,
  });
  final DDPost post;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;
  final VoidCallback? onComment;
  final VoidCallback? onFollow;
  final VoidCallback? onDelete;
  final bool authorNavigation;
  final bool listMode;
  @override
  Widget build(BuildContext context) {
    final content = Column(
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (post.distanceKm != null &&
                          post.distanceKm! <= 100) ...[
                        const SizedBox(width: 7),
                        _DistanceBadge(distanceKm: post.distanceKm!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatDDTime(post.createdAt),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .52),
                    ),
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
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(post.content,
                  style: const TextStyle(fontSize: 16, height: 1.4)),
            ),
          ),
        ],
        if (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
        if (post.videoUrl != null && post.videoUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _NetworkVideoPreview(url: post.videoUrl!),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton.icon(
              onPressed: onLike,
              icon: Icon(TIcons.thumb_up_1),
              label: Text('${post.likes}'),
            ),
            TextButton.icon(
              onPressed: onComment ?? onOpen,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text('${post.comments}'),
            ),
            TextButton.icon(
              onPressed: onFavorite,
              icon: Icon(TIcons.bookmark),
              label: Text('${post.favorites}'),
            ),
          ],
        ),
      ],
    );
    if (!listMode) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: .5),
          ),
        ],
      ),
    );
  }
}

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({required this.url});
  final String url;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          IconButton.filled(
            onPressed: () {
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
            icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
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
  int selectedTab = 0;
  bool tabLoading = false;
  String? cityLabel;
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

  Future<void> load({bool fromRefresh = false, int? tab}) async {
    final targetTab = tab ?? selectedTab;
    final switchingTab = tab != null && !fromRefresh && !loading;
    if (switchingTab) {
      setState(() {
        selectedTab = targetTab;
        tabLoading = true;
        error = null;
      });
    }
    if (fromRefresh) {
      if (_refreshing) return;
      _refreshing = true;
    } else if (!switchingTab) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('dd.auth.token') ?? '';
      if (t.isEmpty) throw Exception('登录后加载发现内容');
      final cachedCity = (p.getString('dd.location.city') ?? '').trim();
      if (mounted && cachedCity.isNotEmpty && cityLabel != cachedCity) {
        setState(() => cityLabel = cachedCity);
      }
      await syncCachedLocation(service, t);
      final city = await cachedCityLabel(service, t);
      if (mounted && cityLabel != city) setState(() => cityLabel = city);
      final loaded = targetTab == 0
          ? await service.fetchPosts(t)
          : targetTab == 1
              ? await service.fetchNearbyPosts(t)
              : await service.fetchFollowingPosts(t);
      if (mounted) {
        setState(() {
          posts = loaded;
          selectedTab = targetTab;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          tabLoading = false;
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
          titleSpacing: 16,
          title: Row(
            children: ['推荐', cityLabel ?? '', '关注']
                .asMap()
                .entries
                .map((entry) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => load(tab: entry.key),
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 20, top: 9, bottom: 6),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(entry.value,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: selectedTab == entry.key
                                    ? null
                                    : Theme.of(context).hintColor,
                              )),
                          const SizedBox(height: 5),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            width: selectedTab == entry.key ? 24 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ]),
                      ),
                    ))
                .toList(),
          ),
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
                  if (tabLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 36),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!loading && error == null && posts.isEmpty)
                    _EmptyStateCard(
                      icon: selectedTab == 1
                          ? Icons.location_off_outlined
                          : selectedTab == 2
                              ? Icons.person_outline
                              : Icons.article_outlined,
                      title: selectedTab == 1
                          ? '暂无附近动态'
                          : selectedTab == 2
                              ? '暂无关注动态'
                              : '暂无动态',
                      subtitle: selectedTab == 1
                          ? '授权定位并等待附近用户发布动态'
                          : selectedTab == 2
                              ? '关注用户后，他们的动态会显示在这里'
                              : '暂时没有可发现的真实动态',
                    ),
                  if (!loading && !tabLoading && error == null)
                    ...posts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DynamicPostCard(
                          post: post,
                          listMode: true,
                          onLike: () async {
                            try {
                              final p = await SharedPreferences.getInstance();
                              final t = p.getString('dd.auth.token') ?? '';
                              if (t.isEmpty) throw Exception('请先登录');
                              await service.toggleLike(t, post.id);
                              if (mounted) {
                                setState(() {
                                  final index = posts
                                      .indexWhere((item) => item.id == post.id);
                                  if (index >= 0) {
                                    posts[index] = posts[index].copyWith(
                                      liked: !posts[index].liked,
                                      likes: posts[index].likes +
                                          (posts[index].liked ? -1 : 1),
                                    );
                                  }
                                });
                              }
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
                              if (mounted) {
                                setState(() {
                                  final index = posts
                                      .indexWhere((item) => item.id == post.id);
                                  if (index >= 0) {
                                    posts[index] = posts[index].copyWith(
                                      favorited: !posts[index].favorited,
                                      favorites: posts[index].favorites +
                                          (posts[index].favorited ? -1 : 1),
                                    );
                                  }
                                });
                              }
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

class _HomeVoiceMatch extends StatelessWidget {
  const _HomeVoiceMatch({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 172,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff6e4fe0), Color(0xffd46bc8)],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('语音匹配',
                      style:
                          TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  SizedBox(height: 7),
                  Text('说句话，遇见懂你的人'),
                ],
              ),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                  color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.mic_none, color: Colors.white, size: 29),
            ),
          ]),
        ),
      );
}

class _HomeCartoonCard extends StatelessWidget {
  const _HomeCartoonCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.colors,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 112,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -18,
                child: Icon(icon,
                    size: 112, color: Colors.white.withValues(alpha: .16)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: colors.first,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .82),
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _HomeFolderCard extends StatelessWidget {
  const _HomeFolderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.tabLabel,
    required this.colors,
    required this.tabAlignment,
    required this.borderRadius,
    this.height = 132,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final String tabLabel;
  final List<Color> colors;
  final Alignment tabAlignment;
  final BorderRadius borderRadius;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Stack(clipBehavior: Clip.none, children: [
          InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Ink(
              height: height,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                      color: colors.last.withValues(alpha: .26),
                      blurRadius: 18,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(color: Colors.white70)),
                      const Spacer(),
                      Text(meta,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ])),
                Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                        color: Colors.white24, shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 29)),
              ]),
            ),
          ),
          Align(
            alignment: tabAlignment,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: colors.first.withValues(alpha: .94),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12))),
              child: Text(tabLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ),
          ),
        ]),
      );
}

class _HomeMiniCard extends StatelessWidget {
  const _HomeMiniCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.meta,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 128,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(meta, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}

class _HomeQuickAction extends StatelessWidget {
  const _HomeQuickAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon),
            ),
            const SizedBox(height: 7),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({required this.title, this.live = false});
  final String title;
  final bool live;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 13),
        child: Row(children: [
          if (live) ...[
            const Icon(Icons.radio_button_checked,
                color: Color(0xff2fd57e), size: 15),
            const SizedBox(width: 7),
          ],
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('全部',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const Icon(Icons.chevron_right, size: 17),
        ]),
      );
}

class _HomePartyCard extends StatelessWidget {
  const _HomePartyCard(
      {required this.icon,
      required this.tag,
      required this.title,
      required this.info});
  final IconData icon;
  final String tag;
  final String title;
  final String info;

  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16),
            const SizedBox(width: 5),
            Text(tag),
            const Spacer(),
            const Icon(Icons.circle, size: 8, color: Color(0xff2fd57e))
          ]),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(info, style: Theme.of(context).textTheme.labelSmall),
        ]),
      );
}

class _HomeCircleCard extends StatelessWidget {
  const _HomeCircleCard(
      {required this.icon, required this.title, required this.meta});
  final IconData icon;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall),
        ]),
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
                      if (_content.text.trim().isEmpty &&
                          selectedImage == null) {
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
                          visibility: visibility == '仅好友可见'
                              ? 'friends'
                              : visibility == '仅自己可见'
                                  ? 'private'
                                  : 'public',
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
              maxLength: 500,
              onChanged: (_) => setState(() {}),
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
                    children: ['所有人可见', '仅好友可见', '仅自己可见']
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
          ],
        ),
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class ChatPreview {
  const ChatPreview({
    required this.name,
    required this.preview,
    required this.time,
    required this.icon,
    this.unread = 0,
    this.online = false,
    this.pinned = false,
  });
  final String name;
  final String preview;
  final String time;
  final IconData icon;
  final int unread;
  final bool online;
  final bool pinned;
}

class _ChatPageState extends State<ChatPage> {
  final searchController = TextEditingController();
  int tab = 0;
  final chats = const <ChatPreview>[
    ChatPreview(
        name: '林小满',
        preview: '今天也要开心呀～',
        time: '12:36',
        icon: Icons.face_3_outlined,
        unread: 2,
        online: true,
        pinned: true),
    ChatPreview(
        name: '苏念',
        preview: '一起听的歌单发你了',
        time: '11:20',
        icon: Icons.music_note,
        unread: 1,
        online: true),
    ChatPreview(
        name: '小鹿',
        preview: '晚上开黑吗？',
        time: '昨天',
        icon: Icons.sports_esports_outlined),
    ChatPreview(
        name: '温小满',
        preview: '很高兴认识你',
        time: '昨天',
        icon: Icons.favorite_outline),
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim();
    final visible = chats
        .where((item) =>
            tab == 0 ||
            (tab == 1 && item.unread > 0) ||
            (tab == 2 && item.online))
        .where((item) =>
            query.isEmpty ||
            item.name.contains(query) ||
            item.preview.contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('聊天'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text('3',
                style: TextStyle(fontSize: 11, color: Colors.white)),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: '新聊天',
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('私聊服务暂未接入'))),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
        children: [
          const _ChatDemoNotice(),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索聊天',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 18),
          const _ChatSectionHeader(title: '新匹配', action: '查看全部'),
          SizedBox(
            height: 90,
            child: ListView(scrollDirection: Axis.horizontal, children: const [
              _NewMatch(name: '苏念', icon: Icons.music_note, online: true),
              _NewMatch(
                  name: '小鹿',
                  icon: Icons.sports_esports_outlined,
                  online: true),
              _NewMatch(name: '桃子', icon: Icons.face_4_outlined),
              _NewMatch(name: '更多', icon: Icons.add),
            ]),
          ),
          const SizedBox(height: 16),
          Row(
              children: ['全部', '未读', '在线']
                  .asMap()
                  .entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: tab == entry.key,
                          onSelected: (_) => setState(() => tab = entry.key),
                        ),
                      ))
                  .toList()),
          const SizedBox(height: 13),
          const Text('会话',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            const _EmptyStateCard(
                icon: TIcons.chat,
                title: '没有匹配的会话',
                subtitle: '聊天 UI 演示不包含真实私聊')
          else
            ...visible.map((chat) => _ChatListItem(
                  data: chat,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatDetailPage(peer: chat))),
                )),
        ],
      ),
    );
  }
}

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, required this.peer});
  final ChatPreview peer;
  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final input = TextEditingController();
  final messages = <_DemoMessage>[
    const _DemoMessage(text: '嗨，今天过得怎么样？', mine: false, time: '12:31'),
    const _DemoMessage(text: '还不错，刚好在听歌～', mine: true, time: '12:32'),
    const _DemoMessage(text: '那要不要分享一首？', mine: false, time: '12:33'),
  ];

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    setState(
        () => messages.add(_DemoMessage(text: text, mine: true, time: '刚刚')));
    input.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(children: [
            CircleAvatar(radius: 19, child: Icon(widget.peer.icon, size: 19)),
            const SizedBox(width: 9),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.peer.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              Text('在线 · UI 演示',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary)),
            ]),
          ]),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
          ],
        ),
        body: Column(children: [
          const _ChatDemoNotice(compact: true),
          Expanded(
              child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            children: [
              const Center(child: _ChatDateLabel(text: '今天 12:30')),
              const SizedBox(height: 18),
              ...messages.map((message) =>
                  _ChatBubble(message: message, icon: widget.peer.icon)),
            ],
          )),
          SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                color: Theme.of(context).colorScheme.surface,
                child: Row(children: [
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_circle_outline)),
                  Expanded(
                      child: TextField(
                    controller: input,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(hintText: '输入消息（演示）'),
                  )),
                  IconButton(onPressed: send, icon: const Icon(Icons.send)),
                ]),
              )),
        ]),
      );
}

class _DemoMessage {
  const _DemoMessage(
      {required this.text, required this.mine, required this.time});
  final String text;
  final bool mine;
  final String time;
}

class _ChatDemoNotice extends StatelessWidget {
  const _ChatDemoNotice({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
        padding:
            EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('聊天为 UI 演示，未接入私聊后端',
            style: Theme.of(context).textTheme.labelSmall),
      );
}

class _ChatSectionHeader extends StatelessWidget {
  const _ChatSectionHeader({required this.title, required this.action});
  final String title;
  final String action;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        Text(action,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.primary)),
      ]);
}

class _NewMatch extends StatelessWidget {
  const _NewMatch(
      {required this.name, required this.icon, this.online = false});
  final String name;
  final IconData icon;
  final bool online;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        child: Column(children: [
          Stack(children: [
            CircleAvatar(radius: 27, child: Icon(icon)),
            if (online)
              const Positioned(right: 0, bottom: 1, child: _OnlineDot()),
          ]),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall),
        ]),
      );
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
            color: const Color(0xff2fd57e),
            shape: BoxShape.circle,
            border: Border.all(
                color: Theme.of(context).colorScheme.surface, width: 2)),
      );
}

class _ChatListItem extends StatelessWidget {
  const _ChatListItem({required this.data, required this.onTap});
  final ChatPreview data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(radius: 27, child: Icon(data.icon)),
              if (data.online)
                const Positioned(right: -1, bottom: 0, child: _OnlineDot()),
            ]),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(data.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800))),
                    Text(data.time,
                        style: Theme.of(context).textTheme.labelSmall),
                  ]),
                  const SizedBox(height: 5),
                  Text(data.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
            if (data.unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle),
                child: Text('${data.unread}',
                    style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
          ]),
        ),
      );
}

class _ChatDateLabel extends StatelessWidget {
  const _ChatDateLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.icon});
  final _DemoMessage message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment:
              message.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!message.mine) ...[
              CircleAvatar(radius: 16, child: Icon(icon, size: 16)),
              const SizedBox(width: 8)
            ],
            Flexible(
                child: Column(
              crossAxisAlignment: message.mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.mine
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(message.text,
                      style: TextStyle(
                          color: message.mine
                              ? Theme.of(context).colorScheme.onPrimary
                              : null)),
                ),
                const SizedBox(height: 4),
                Text(message.time,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            )),
          ],
        ),
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
    final repliesByParent = <int, List<DDComment>>{};
    for (final comment in source.where((c) => c.parentId != null)) {
      repliesByParent.putIfAbsent(comment.parentId!, () => []).add(comment);
    }
    final result = <Widget>[];

    void append(DDComment comment, int depth) {
      result.add(Padding(
        padding: EdgeInsets.only(left: depth * 42.0),
        child: _commentTile(comment),
      ));
      for (final reply in repliesByParent[comment.id] ?? const <DDComment>[]) {
        append(reply, depth + 1);
      }
    }

    for (final root in source.where((c) => c.parentId == null)) {
      append(root, 0);
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
        onTap: () {
          setState(() => replyingTo = comment);
          FocusScope.of(context).requestFocus(commentFocusNode);
        },
        onLongPress: () => _commentMenu(comment),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
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
                  radius: 20,
                  child: Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.nickname,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(comment.content),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDDTime(comment.createdAt),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      );

  Future<void> _toggleLike() async {
    try {
      await service.toggleLike(await token(), widget.postId);
      if (mounted && post != null) {
        setState(() {
          post = post!.copyWith(
            liked: !post!.liked,
            likes: post!.likes + (post!.liked ? -1 : 1),
          );
        });
      }
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await service.toggleFavorite(await token(), widget.postId);
      if (mounted && post != null) {
        setState(() {
          post = post!.copyWith(
            favorited: !post!.favorited,
            favorites: post!.favorites + (post!.favorited ? -1 : 1),
          );
        });
      }
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
                  icon: Icon(TIcons.shield_error),
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
                      if (item.videoUrl != null &&
                          item.videoUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _NetworkVideoPreview(url: item.videoUrl!),
                      ],
                      const SizedBox(height: 18),
                      Row(children: [
                        _DetailAction(
                            icon: TIcons.thumb_up_1,
                            label: '${item.likes}',
                            active: item.liked,
                            onTap: _toggleLike),
                        const SizedBox(width: 24),
                        _DetailAction(
                            icon: TIcons.chat,
                            label: '${comments.length}',
                            onTap: () {}),
                        const SizedBox(width: 24),
                        _DetailAction(
                            icon: TIcons.bookmark,
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
                            icon: TIcons.chat,
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
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: TextField(
                    controller: commentController,
                    focusNode: commentFocusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => submitComment(),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
                children: [
                  if (error != null)
                    _PageErrorState(
                        title: '主页加载失败', subtitle: error!, onRetry: load),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: OutlinedButton.icon(
                              onPressed: actionLoading || isProfileLiked
                                  ? null
                                  : toggleProfileLike,
                              icon: Icon(isProfileLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border),
                              label: Text('$profileLikes'),
                            ),
                          ),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(children: [
                                  CircleAvatar(
                                    radius: 42,
                                    backgroundImage:
                                        (p?['avatar']?.toString() ?? '')
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : NetworkImage(
                                                DDPostService.mediaUrl(
                                                    p?['avatar']?.toString())),
                                    child: (p?['avatar']?.toString() ?? '')
                                            .trim()
                                            .isEmpty
                                        ? const Icon(Icons.person_outline,
                                            size: 34)
                                        : null,
                                  ),
                                  const Positioned(
                                    right: 1,
                                    bottom: 2,
                                    child: _OnlineDot(),
                                  ),
                                ]),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Flexible(
                                          child: Text(
                                              '${p?['nickname'] ?? widget.name}',
                                              style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight:
                                                      FontWeight.w800))),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified,
                                          size: 17, color: Colors.lightBlue),
                                    ]),
                                    const SizedBox(height: 6),
                                    Wrap(spacing: 6, runSpacing: 6, children: [
                                      _ProfileTag(
                                          text: '${p?['city'] ?? '未知地区'}'),
                                      _ProfileTag(
                                          text:
                                              '在线 ${p?['activeDays'] ?? 0} 天'),
                                    ]),
                                    const SizedBox(height: 10),
                                    Text('喜欢分享日常，也期待遇见聊得来的人。',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                )),
                              ]),
                          const Divider(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _Stat(
                                  value: '${p?['following'] ?? 0}',
                                  label: '关注'),
                              _Stat(
                                  value: '${p?['followers'] ?? 0}',
                                  label: '粉丝'),
                              _Stat(value: '$profileLikes', label: '获赞'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _OtherProfileVoiceCard(
                      name: '${p?['nickname'] ?? widget.name}的声音名片'),
                  const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 10),
                    child: Text('Ta的动态',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  if (posts.isEmpty)
                    const _EmptyStateCard(
                        icon: Icons.article_outlined,
                        title: '暂无动态',
                        subtitle: 'Ta 还没有发布动态')
                  else
                    ...posts.map((post) => _DynamicPostCard(
                        post: post,
                        listMode: true,
                        authorNavigation: false,
                        onLike: () {},
                        onFavorite: () {},
                        onOpen: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    DynamicDetailPage(postId: post.id))))),
                ],
              ),
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
  int selectedTab = 1;
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
          ? const <DDPost>[]
          : targetTab == 1
              ? await service.fetchMyPosts(t)
              : targetTab == 2
                  ? await service.fetchFavoritedPosts(t)
                  : await service.fetchLikedPosts(t);
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

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Scaffold(
      appBar: AppBar(title: const Text('我的'), actions: [
        IconButton(
          tooltip: '消息',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatPage()),
          ),
          icon: Icon(TIcons.scan),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage:
                                      (p?['avatar']?.toString() ?? '')
                                              .trim()
                                              .isNotEmpty
                                          ? NetworkImage(DDPostService.mediaUrl(
                                              p!['avatar'].toString()))
                                          : null,
                                  child: (p?['avatar']?.toString() ?? '')
                                          .trim()
                                          .isEmpty
                                      ? const Icon(Icons.person, size: 38)
                                      : null,
                                ),
                                const Positioned(
                                    right: 0, bottom: 1, child: _OnlineDot()),
                              ]),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(
                                        child: Text(
                                            '${p?['nickname'] ?? 'DD 用户'}',
                                            style: const TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w800))),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified,
                                        size: 17, color: Colors.lightBlue),
                                    const Spacer(),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const EditProfilePage()));
                                        if (mounted) load();
                                      },
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 16),
                                      label: const Text('编辑'),
                                    ),
                                  ]),
                                  const SizedBox(height: 9),
                                  Wrap(spacing: 7, runSpacing: 7, children: [
                                    _ProfileTag(
                                        text: '${p?['activeDays'] ?? 0} 天'),
                                    _ProfileTag(
                                        text: '${p?['city'] ?? '未知地区'}'),
                                  ]),
                                ],
                              )),
                            ],
                          ),
                          const Divider(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _Stat(
                                  value: '${p?['following'] ?? 0}',
                                  label: '关注'),
                              _Stat(
                                  value: '${p?['followers'] ?? 0}',
                                  label: '粉丝'),
                              _Stat(value: '${p?['likes'] ?? 0}', label: '获赞'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _MyProfileVoiceCard(name: '${p?['nickname'] ?? '我'}的声音名片'),
                  const SizedBox(height: 14),
                  Row(
                    children: ['置顶', '动态', '收藏', '喜欢']
                        .asMap()
                        .entries
                        .map((entry) => Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => load(tab: entry.key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: selectedTab == entry.key
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(entry.value,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: selectedTab == entry.key
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                            : null,
                                      )),
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
                    _MyPostList(
                      posts: posts,
                      emptyLabel: selectedTab == 0
                          ? '置顶'
                          : selectedTab == 1
                              ? '动态'
                              : selectedTab == 2
                                  ? '收藏'
                                  : '喜欢',
                    ),
                ],
              ),
            ),
    );
  }
}

class _MyProfileVoiceCard extends StatelessWidget {
  const _MyProfileVoiceCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.play_arrow, color: Colors.white),
          ),
          title: Text(name),
          subtitle: const Text('声音名片 · UI 演示，未接入真实语音'),
          trailing: const Text('00:16'),
        ),
      );
}

class _MyPostList extends StatelessWidget {
  const _MyPostList({
    required this.posts,
    required this.emptyLabel,
  });
  final List<DDPost> posts;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return _ProfileEmptyTab(label: emptyLabel);
    return Column(
      children: posts.map((post) => _MyListCard(post: post)).toList(),
    );
  }
}

class _MyPostWaterfall extends StatelessWidget {
  const _MyPostWaterfall({
    required this.posts,
    required this.emptyLabel,
  });
  final List<DDPost> posts;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return _ProfileEmptyTab(label: emptyLabel);
    return Column(
      children: posts.map((post) => _MyListCard(post: post)).toList(),
    );
  }
}

class _MyListCard extends StatelessWidget {
  const _MyListCard({required this.post});
  final DDPost post;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DynamicDetailPage(postId: post.id),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatExactPostTime(post.createdAt),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .55),
                    ),
                  ),
                  Text(
                    '浏览 ${post.views}',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .55),
                    ),
                  ),
                ],
              ),
              if (post.content.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(post.content,
                      style: const TextStyle(fontSize: 16, height: 1.4)),
                ),
              if (post.imageUrl?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 500),
                      child: Image.network(
                        DDPostService.mediaUrl(post.imageUrl),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              if (post.videoUrl?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _NetworkVideoPreview(url: post.videoUrl!),
                ),
              const Divider(height: 20),
            ],
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

class _OtherProfileVoiceCard extends StatelessWidget {
  const _OtherProfileVoiceCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.play_arrow, color: Colors.white),
          ),
          title: Text(name),
          subtitle: const Text('声音名片 · UI 演示，未接入真实语音'),
          trailing: const Text('00:16'),
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

class ListenTogetherPage extends StatefulWidget {
  const ListenTogetherPage({super.key});
  @override
  State<ListenTogetherPage> createState() => _ListenTogetherPageState();
}

class _ListenTogetherPageState extends State<ListenTogetherPage> {
  bool playing = true;
  bool liked = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff0c0a14),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text('一起听'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
            ]),
        body: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff542c91), Color(0xff0c0a14)])))),
          Column(children: [
            const _ListenDemoNotice(),
            const SizedBox(height: 26),
            Container(
                width: 235,
                height: 235,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff1a1620),
                    border: Border.all(color: Colors.white12, width: 8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 30)
                    ]),
                child: Center(
                    child: Container(
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              Color(0xff7c3aed),
                              Color(0xffe8558c)
                            ])),
                        child: const Icon(Icons.music_note,
                            size: 40, color: Colors.white)))),
            const SizedBox(height: 28),
            const Text('夜空中最亮的星',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('逃跑计划 · 和 苏念 一起听',
                style: TextStyle(color: Colors.white54)),
            Padding(
                padding: const EdgeInsets.fromLTRB(32, 26, 32, 0),
                child: Column(children: [
                  LinearProgressIndicator(
                      value: .42,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(9)),
                  const SizedBox(height: 6),
                  const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('01:42',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11)),
                        Text('04:12',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11))
                      ])
                ])),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(
                  onPressed: () => setState(() => liked = !liked),
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.pinkAccent : Colors.white)),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white, size: 33)),
              Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xff7c3aed), Color(0xffe8558c)])),
                  child: IconButton(
                      onPressed: () => setState(() => playing = !playing),
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white, size: 32))),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white, size: 33)),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.queue_music, color: Colors.white))
            ]),
            const SizedBox(height: 34),
          ]),
        ]),
      );
}

class VoiceMatchPage extends StatefulWidget {
  const VoiceMatchPage({super.key});
  @override
  State<VoiceMatchPage> createState() => _VoiceMatchPageState();
}

class _VoiceMatchPageState extends State<VoiceMatchPage> {
  bool matching = true;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff0f0a1a),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(matching ? '语音匹配' : '匹配成功')),
        body: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff673a8c), Color(0xff0f0a1a)])))),
          Center(
              child: matching
                  ? _VoiceMatchingContent(
                      onSuccess: () => setState(() => matching = false))
                  : _VoiceMatchSuccess(
                      onRestart: () => setState(() => matching = true))),
        ]),
      );
}

class _VoiceMatchingContent extends StatelessWidget {
  const _VoiceMatchingContent({required this.onSuccess});
  final VoidCallback onSuccess;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _VoiceUiNotice(),
        const SizedBox(height: 32),
        Stack(alignment: Alignment.center, children: [
          for (final size in [290.0, 225.0, 160.0])
            Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: .35)))),
          Container(
              width: 108,
              height: 108,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Color(0xffa855f7), Color(0xffff6b9d)])),
              child: const Icon(Icons.mic, color: Colors.white, size: 45))
        ]),
        const SizedBox(height: 48),
        const Text('正在寻找有趣的声音',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('戴上耳机，和陌生人聊聊吧', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 22),
        const Text('等待 00:12', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 42),
        FilledButton(onPressed: onSuccess, child: const Text('模拟匹配成功')),
        const SizedBox(height: 12),
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消匹配')),
      ]));
}

class _VoiceMatchSuccess extends StatelessWidget {
  const _VoiceMatchSuccess({required this.onRestart});
  final VoidCallback onRestart;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _VoiceUiNotice(),
        const SizedBox(height: 32),
        const CircleAvatar(
            radius: 66, child: Icon(Icons.face_3_outlined, size: 62)),
        const SizedBox(height: 24),
        const Text('林小满',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        const Text('已为你匹配到一位声音伙伴', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: const [
          Chip(label: Text('音乐')),
          Chip(label: Text('旅行')),
          Chip(label: Text('在线'))
        ]),
        const SizedBox(height: 28),
        const Text('通话 00:03 · UI 演示', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 26),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.mic_none, color: Colors.white)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.volume_up_outlined, color: Colors.white)),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon:
                  const Icon(Icons.call_end, color: Colors.redAccent, size: 34))
        ]),
        const SizedBox(height: 18),
        TextButton(onPressed: onRestart, child: const Text('重新模拟匹配')),
      ]));
}

class _ListenDemoNotice extends StatelessWidget {
  const _ListenDemoNotice();
  @override
  Widget build(BuildContext context) => const Text('一起听为 UI 演示，未接入真实音乐同步或房间服务',
      style: TextStyle(color: Colors.white60, fontSize: 11));
}

class _VoiceUiNotice extends StatelessWidget {
  const _VoiceUiNotice();
  @override
  Widget build(BuildContext context) => const Text('语音匹配为 UI 演示，未接入真实匹配和语音通话',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white60, fontSize: 11));
}

class GameCompanionPlazaPage extends StatefulWidget {
  const GameCompanionPlazaPage({super.key});
  @override
  State<GameCompanionPlazaPage> createState() => _GameCompanionPlazaPageState();
}

class CompanionProfile {
  const CompanionProfile(
      {required this.name,
      required this.game,
      required this.price,
      required this.rating,
      required this.icon,
      required this.tags,
      required this.voice});
  final String name;
  final String game;
  final String price;
  final String rating;
  final IconData icon;
  final List<String> tags;
  final String voice;
}

class _GameCompanionPlazaPageState extends State<GameCompanionPlazaPage> {
  final search = TextEditingController();
  int game = 0;
  int type = 0;
  final games = const ['王者荣耀', '英雄联盟', '和平精英', '原神', '更多'];
  final types = const ['全部', '上分陪玩', '娱乐开黑', '语音陪伴', '新手教学'];
  final companions = const [
    CompanionProfile(
        name: '小鹿',
        game: '王者荣耀',
        price: '39',
        rating: '4.9',
        icon: Icons.face_3_outlined,
        tags: ['声音好听', '国服打野', '秒回'],
        voice: '温柔声线 · 试听 16 秒'),
    CompanionProfile(
        name: '苏念',
        game: '英雄联盟',
        price: '49',
        rating: '5.0',
        icon: Icons.music_note,
        tags: ['氛围感', '可连麦', '晚间在线'],
        voice: '甜妹音 · 试听 12 秒'),
    CompanionProfile(
        name: '桃子',
        game: '和平精英',
        price: '35',
        rating: '4.8',
        icon: Icons.favorite_outline,
        tags: ['带萌新', '不压力', '情绪价值'],
        voice: '元气音 · 试听 18 秒'),
    CompanionProfile(
        name: '北辰',
        game: '原神',
        price: '45',
        rating: '4.9',
        icon: Icons.auto_awesome_outlined,
        tags: ['探索陪伴', '任务带做', '耐心'],
        voice: '治愈音 · 试听 14 秒'),
  ];
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.trim();
    final visible = companions
        .where((c) =>
            q.isEmpty ||
            c.name.contains(q) ||
            c.game.contains(q) ||
            c.tags.any((tag) => tag.contains(q)))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('陪玩广场'), actions: [
        IconButton(
            onPressed: () => _notice('陪玩订单'),
            icon: const Icon(Icons.receipt_long_outlined))
      ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            const _CompanionNotice(),
            const SizedBox(height: 12),
            TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    hintText: '搜索游戏、声音或陪玩', prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 13),
            _GameFilterRow(
                labels: games,
                selected: game,
                onSelected: (v) => setState(() => game = v),
                icon: Icons.sports_esports_outlined),
            const SizedBox(height: 9),
            _GameFilterRow(
                labels: types,
                selected: type,
                onSelected: (v) => setState(() => type = v)),
            const _CompanionSection(title: '今日推荐'),
            SizedBox(
                height: 208,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: companions
                        .take(3)
                        .map((c) => _CompanionRecommendCard(
                            data: c, onTap: () => _open(c)))
                        .toList())),
            const _CompanionSection(title: '在线陪玩'),
            ...visible.map((c) => _CompanionListCard(
                data: c,
                onTap: () => _open(c),
                onOrder: () => _notice('约玩服务'))),
          ]),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                  onPressed: () => _notice('发布陪玩需求'),
                  icon: const Icon(Icons.add),
                  label: const Text('发布陪玩需求')))),
    );
  }

  void _open(CompanionProfile c) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => CompanionProfilePage(data: c)));
  void _notice(String feature) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$feature暂未接入')));
}

class CompanionProfilePage extends StatelessWidget {
  const CompanionProfilePage({super.key, required this.data});
  final CompanionProfile data;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          Container(
              height: 270,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xff4a2a6b), Color(0xffe05ca8)]))),
          SafeArea(
              child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white))),
          ListView(
              padding: const EdgeInsets.fromLTRB(16, 220, 16, 108),
              children: [
                const _CompanionNotice(),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Stack(children: [
                                  CircleAvatar(
                                      radius: 38,
                                      child: Icon(data.icon, size: 36)),
                                  const Positioned(
                                      right: 0, bottom: 1, child: _OnlineDot())
                                ]),
                                const SizedBox(width: 13),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Text(data.name,
                                            style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified,
                                            color: Colors.lightBlue, size: 17)
                                      ]),
                                      const SizedBox(height: 5),
                                      Text('${data.game} · ★ ${data.rating}',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary)),
                                      const SizedBox(height: 4),
                                      Text('在线 · 5 分钟内响应',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall)
                                    ]))
                              ]),
                              const SizedBox(height: 14),
                              const Text('喜欢轻松聊天和开黑，一起享受游戏的快乐吧～'),
                              const Divider(height: 28),
                              const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _GameProfileStat(
                                        value: '99%', label: '好评率'),
                                    _GameProfileStat(
                                        value: '6分钟', label: '平均响应'),
                                    _GameProfileStat(
                                        value: '1,286', label: '接单数')
                                  ]),
                            ]))),
                const _CompanionSection(title: '声音名片'),
                _CompanionVoiceCard(text: data.voice),
                const _CompanionSection(title: '陪玩服务'),
                _GameProfileServiceRow(
                    game: data.game, title: '娱乐开黑 · 语音陪伴', price: data.price),
                _GameProfileServiceRow(
                    game: data.game, title: '上分陪玩 · 全程连麦', price: '59'),
                const _CompanionSection(title: '标签与评价'),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        data.tags.map((t) => Chip(label: Text(t))).toList()),
                const SizedBox(height: 12),
                const _GameReview(name: '小橘', text: '声音很好听，开黑很开心。'),
              ]),
        ]),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('约玩服务暂未接入'))),
                    child: Text('¥ ${data.price} 起 · 立即约玩')))),
      );
}

class VoiceRoomPage extends StatefulWidget {
  const VoiceRoomPage({super.key});
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  bool muted = false;
  bool joined = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff1a1224),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text('深夜电台 · 一起听'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
            ]),
        body: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.4,
                          colors: [Color(0xff673a8c), Color(0xff1a1224)])))),
          ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              children: [
                const _VoiceRoomNotice(),
                const SizedBox(height: 18),
                Center(
                    child: Column(children: [
                  Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.purpleAccent, width: 2)),
                    ),
                    const CircleAvatar(
                        radius: 41, child: Icon(Icons.mic, size: 38)),
                  ]),
                  const SizedBox(height: 12),
                  const Text('苏念  房主',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 5),
                  const Chip(
                      label: Text('正在说话'),
                      avatar: Icon(Icons.graphic_eq, size: 15))
                ])),
                const SizedBox(height: 28),
                const Text('麦位  ·  128 人在听',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 18,
                    children: const [
                      _VoiceSeat(icon: Icons.music_note, name: '小鹿'),
                      _VoiceSeat(icon: Icons.favorite_outline, name: '桃子'),
                      _VoiceSeat(
                          icon: Icons.sports_esports_outlined, name: '北辰'),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true),
                      _VoiceSeat(icon: Icons.add, name: '空麦位', empty: true)
                    ]),
                const SizedBox(height: 24),
                const Text('房间消息',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const _VoiceRoomMessage(name: '小鹿', text: '这首歌好好听～'),
                const _VoiceRoomMessage(name: '桃子', text: '新来的朋友晚上好'),
              ]),
        ]),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
                color: const Color(0xff21172e),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  IconButton(
                      onPressed: () => setState(() => muted = !muted),
                      icon: Icon(muted ? Icons.mic_off : Icons.mic_none,
                          color: Colors.white)),
                  Expanded(
                      child: FilledButton(
                          onPressed: () => setState(() => joined = !joined),
                          child: Text(joined ? '已上麦（UI）' : '申请上麦'))),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.card_giftcard_outlined,
                          color: Colors.white))
                ]))),
      );
}

class _CompanionNotice extends StatelessWidget {
  const _CompanionNotice();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Text('陪玩广场为 UI 演示，未接入约玩、订单、支付和私聊服务',
          style: Theme.of(context).textTheme.labelSmall));
}

class _VoiceRoomNotice extends StatelessWidget {
  const _VoiceRoomNotice();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('语音房为 UI 演示，未接入真实语音、麦位和房间消息',
          style: TextStyle(color: Colors.white70, fontSize: 11)));
}

class _CompanionSection extends StatelessWidget {
  const _CompanionSection({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 11),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)));
}

class _CompanionRecommendCard extends StatelessWidget {
  const _CompanionRecommendCard({required this.data, required this.onTap});
  final CompanionProfile data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Center(
                    child: CircleAvatar(
                        radius: 34, child: Icon(data.icon, size: 30)))),
            Text(data.name,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(data.voice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            Text('¥${data.price}/局 · ★${data.rating}',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.primary))
          ])));
}

class _CompanionListCard extends StatelessWidget {
  const _CompanionListCard(
      {required this.data, required this.onTap, required this.onOrder});
  final CompanionProfile data;
  final VoidCallback onTap;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Stack(children: [
                  CircleAvatar(radius: 26, child: Icon(data.icon, size: 25)),
                  const Positioned(right: 0, bottom: 0, child: _OnlineDot()),
                ]),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(data.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${data.game} · ★${data.rating} · 在线',
                          style: Theme.of(context).textTheme.labelSmall),
                    ])),
                FilledButton(onPressed: onOrder, child: const Text('约玩')),
              ]),
              const SizedBox(height: 10),
              Text(data.voice,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 9),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: data.tags
                      .map((t) => Chip(
                          label: Text(t), visualDensity: VisualDensity.compact))
                      .toList()),
              const Divider(height: 24),
              Row(children: [
                Text('¥ ${data.price}/局起',
                    style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xffff4d8a),
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                const Text('已服务 1,286 次',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
          ),
        ),
      );
}

class _CompanionVoiceCard extends StatelessWidget {
  const _CompanionVoiceCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
          title: Text(text),
          subtitle: const Text('声音名片 · UI 演示'),
          trailing: const Text('00:16')));
}

class _VoiceSeat extends StatelessWidget {
  const _VoiceSeat(
      {required this.icon, required this.name, this.empty = false});
  final IconData icon;
  final String name;
  final bool empty;
  @override
  Widget build(BuildContext context) => Column(children: [
        CircleAvatar(
            radius: 27,
            backgroundColor: empty ? Colors.white10 : null,
            child: Icon(icon, color: empty ? Colors.white38 : null)),
        const SizedBox(height: 5),
        Text(name,
            style: TextStyle(
                fontSize: 11, color: empty ? Colors.white38 : Colors.white70),
            overflow: TextOverflow.ellipsis)
      ]);
}

class _VoiceRoomMessage extends StatelessWidget {
  const _VoiceRoomMessage({required this.name, required this.text});
  final String name;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
          text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
            TextSpan(
                text: '$name  ',
                style: const TextStyle(
                    color: Color(0xffe8b8ff), fontWeight: FontWeight.w700)),
            TextSpan(text: text)
          ])));
}

class FateMatchPage extends StatefulWidget {
  const FateMatchPage({super.key});
  @override
  State<FateMatchPage> createState() => _FateMatchPageState();
}

class _FateMatchPageState extends State<FateMatchPage> {
  bool matching = false;
  bool matched = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff191019),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('缘分匹配'),
        ),
        body: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.4,
                  colors: [Color(0xffff6f9a), Color(0xff191019)],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('缘分匹配为 UI 演示，未接入真实匹配服务',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 36),
                    Stack(alignment: Alignment.center, children: [
                      for (final size in [250.0, 190.0, 132.0])
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    Colors.pinkAccent.withValues(alpha: .36)),
                          ),
                        ),
                      CircleAvatar(
                        radius: 53,
                        backgroundColor: const Color(0xffff5f8f),
                        child: Icon(
                          matched ? Icons.favorite : Icons.auto_awesome,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 36),
                    Text(
                      matched
                          ? '遇见了 林小满'
                          : (matching ? '正在寻找有缘人…' : '开启一段新的缘分'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      matched ? '音乐 · 旅行 · 聊得来' : '填写兴趣后，寻找默契的聊天伙伴',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 32),
                    if (matched)
                      Wrap(spacing: 10, children: [
                        FilledButton(
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                                  const SnackBar(content: Text('私聊服务暂未接入'))),
                          child: const Text('开始聊天'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            matched = false;
                            matching = false;
                          }),
                          child: const Text('重新匹配'),
                        ),
                      ])
                    else
                      FilledButton.icon(
                        onPressed: matching
                            ? null
                            : () => setState(() {
                                  matching = true;
                                  matched = true;
                                }),
                        icon: const Icon(Icons.favorite_outline),
                        label: Text(matching ? '匹配中…' : '开始匹配'),
                      ),
                  ]),
            ),
          ),
        ]),
      );
}

class _GameFilterRow extends StatelessWidget {
  const _GameFilterRow(
      {required this.labels,
      required this.selected,
      required this.onSelected,
      this.icon});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView(
            scrollDirection: Axis.horizontal,
            children: labels
                .asMap()
                .entries
                .map((entry) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: icon != null && entry.key == selected
                            ? Icon(icon, size: 15)
                            : null,
                        label: Text(entry.value),
                        selected: selected == entry.key,
                        onSelected: (_) => onSelected(entry.key),
                      ),
                    ))
                .toList()),
      );
}

class _GameProfileStat extends StatelessWidget {
  const _GameProfileStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _GameProfileServiceRow extends StatelessWidget {
  const _GameProfileServiceRow(
      {required this.game, required this.title, required this.price});
  final String game;
  final String title;
  final String price;
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        leading: const Icon(Icons.sports_esports_outlined),
        title: Text(title),
        subtitle: Text(game),
        trailing: Text('¥$price 起',
            style: const TextStyle(
                color: Color(0xffff4d6a), fontWeight: FontWeight.w800)),
      ));
}

class _GameReview extends StatelessWidget {
  const _GameReview({required this.name, required this.text});
  final String name;
  final String text;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(name),
        subtitle: Text(text),
        trailing: const Text('★ 5.0'),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TIcons.location,
              size: 13,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 3),
            Text(
              '${distanceKm.toStringAsFixed(2)} km',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
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
