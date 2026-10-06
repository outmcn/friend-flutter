import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tdesign_flutter_icons/tdesign_flutter_icons.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;

import 'auth_client.dart';
import 'avatar_crop_page.dart';
import 'post_service.dart';

class _PermanentImageCache {
  static final Map<String, String> _localPaths = <String, String>{};
  static final Map<String, Future<String?>> _pending = <String, Future<String?>>{};

  static Future<String?> get(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return null;
    final existing = _localPaths[normalized];
    if (existing != null && await File(existing).exists()) return existing;
    return _pending.putIfAbsent(normalized, () async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final cacheDirectory = Directory('${directory.path}/friend_media_cache');
        await cacheDirectory.create(recursive: true);
        final fileName = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
        final file = File('${cacheDirectory.path}/$fileName');
        if (await file.exists() && await file.length() > 0) {
          _localPaths[normalized] = file.path;
          return file.path;
        }
        if (await file.exists()) {
          await file.delete();
        }
        {
          final response = await http.get(Uri.parse(normalized));
          if (response.statusCode < 200 || response.statusCode >= 300) return null;
          if (response.bodyBytes.isEmpty) return null;
          final temporary = File('${file.path}.part');
          await temporary.writeAsBytes(response.bodyBytes, flush: true);
          await temporary.rename(file.path);
        }
        _localPaths[normalized] = file.path;
        return file.path;
      } catch (_) {
        return null;
      } finally {
        _pending.remove(normalized);
      }
    });
  }
}

class _PermanentCachedImage extends StatefulWidget {
  const _PermanentCachedImage({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  State<_PermanentCachedImage> createState() => _PermanentCachedImageState();
}

class _PermanentCachedImageState extends State<_PermanentCachedImage> {
  String? localPath;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PermanentCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      localPath = null;
      failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final path = await _PermanentImageCache.get(widget.url);
    if (mounted) setState(() {
      localPath = path;
      failed = path == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    return path == null
        ? const ColoredBox(
            color: Colors.transparent,
            child: Icon(Icons.person_outline),
          )
        : Image.file(File(path), fit: widget.fit);
  }
}
int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int? _signedUrlExpiryMillis(String raw) {
  try {
    final uri = Uri.parse(raw);
    final query = <String, String>{
      for (final entry in uri.queryParameters.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final absolute = int.tryParse(query['expires'] ?? '');
    if (absolute != null) return absolute < 10000000000 ? absolute * 1000 : absolute;
    final duration = int.tryParse(query['x-oss-expires'] ?? '');
    final signedAt = query['x-oss-date'] ?? query['date'];
    if (duration != null && signedAt != null) {
      final compact = signedAt.length >= 15
          ? '${signedAt.substring(0, 8)}T${signedAt.substring(8)}Z'
          : signedAt;
      final parsed = DateTime.tryParse(compact);
      if (parsed != null) return parsed.millisecondsSinceEpoch + duration * 1000;
    }
  } catch (_) {}
  return null;
}

int? _postMediaExpiryMillis(Map<String, dynamic> json) {
  final values = [json['avatar'], json['imageUrl'], json['videoUrl'], json['thumbnailUrl']]
      .whereType<String>()
      .map(_signedUrlExpiryMillis)
      .whereType<int>()
      .toList();
  return values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
}

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
    try {
      final geocoder = Geocoding();
      final marks = await geocoder.placemarkFromCoordinates(latitude, longitude);
      final mark = marks.isNotEmpty ? marks.first : null;
      final resolvedCity = (mark?.locality ?? mark?.subAdministrativeArea ?? '')
          .replaceAll('市', '')
          .trim();
      if (resolvedCity.isNotEmpty) {
        await prefs.setString('dd.location.city', resolvedCity);
        await service.updateLocation(
          token: token,
          latitude: latitude,
          longitude: longitude,
          city: resolvedCity,
        );
      }
    } catch (_) {
      // Reverse geocoding is optional; coordinates remain usable if unavailable.
    }
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
  // Always read the server city after coordinate synchronization so stale cached
  // city names cannot override the current device location.
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
      builder: (context, child) =>
          _KeyboardDismissBehavior(child: child ?? const SizedBox.shrink()),
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
      home: const AuthGate(),
    );
  }
}

class _KeyboardDismissBehavior extends StatefulWidget {
  const _KeyboardDismissBehavior({required this.child});
  final Widget child;

  @override
  State<_KeyboardDismissBehavior> createState() =>
      _KeyboardDismissBehaviorState();
}

class _KeyboardDismissBehaviorState extends State<_KeyboardDismissBehavior> {
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
            return false;
          },
          child: widget.child,
        ),
      );
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
      return const DDShell();
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
  String? token;
  late final FriendAuthClient auth;

  @override
  void initState() {
    super.initState();
    auth = FriendAuthClient();
    _restore();
  }

  Future<void> _restore() async {
    final restored = await auth.restoreToken();
    if (!mounted) return;
    setState(() {
      token = restored;
      loading = false;
    });
  }

  @override
  void dispose() {
    auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return token == null
        ? AuthPage(auth: auth, onAuthenticated: (value) => setState(() => token = value))
        : const DDShell();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth, required this.onAuthenticated});
  final FriendAuthClient auth;
  final ValueChanged<String> onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = '请输入账号和密码');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final value = await widget.auth.login(
        username: username.text,
        password: password.text,
      );
      if (mounted) widget.onAuthenticated(value);
    } on FriendAuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = '无法连接新后端');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '密码登录',
        subtitle: '使用手机号和密码登录 DD',
        child: Column(
          children: [
            _AuthFieldController(label: '手机号码', icon: Icons.phone_outlined, controller: username),
            const SizedBox(height: 14),
            _AuthFieldController(label: '密码', icon: Icons.lock_outline, controller: password, obscureText: true),
            if (error != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: Colors.orange))),
            ],
            const SizedBox(height: 18),
            _PrimaryAuthButton(label: loading ? '登录中…' : '登录', onTap: loading ? () {} : _login),
            TextButton(onPressed: () {}, child: const Text('没有账号？注册')),
          ],
        ),
      );
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
              onTap: () {},
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

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SizedBox.shrink(),
      );
}

class DDShell extends StatefulWidget {
  const DDShell({super.key});
  @override
  State<DDShell> createState() => _DDShellState();
}

class _DDShellState extends State<DDShell> {
  int index = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = const [
      HomePage(),
      DiscoverPage(),
      ChatPage(),
      DDProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) {
            HapticFeedback.selectionClick();
            _VideoPlaybackRegistry.stopAll();
            setState(() => index = value);
          },
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

  void _unavailable(BuildContext context, String feature) {}

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _HomeFolderCard(
                        icon: Icons.auto_awesome,
                        title: '缘分匹配',
                        subtitle: '遇见聊得来的人',
                        meta: 'FATE',
                        tabLabel: 'FATE',
                        colors: const [Color(0xffff6b9d), Color(0xffa855f7)],
                        tabAlignment: Alignment.topRight,
                        borderRadius: BorderRadius.circular(28),
                        height: 140,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FateMatchPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 9,
                      child: Column(
                        children: [
                          Expanded(
                            child: _HomeFolderCard(
                              icon: Icons.mic_none,
                              title: '语音匹配',
                              subtitle: '遇见懂你的人',
                              meta: '',
                              tabLabel: 'VOICE',
                              colors: const [
                                Color(0xff6e4fe0),
                                Color(0xffd46bc8)
                              ],
                              tabAlignment: Alignment.topLeft,
                              borderRadius: BorderRadius.circular(24),
                              height: 63,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VoiceMatchPage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _HomeNormalCard(
                              icon: Icons.sports_esports_outlined,
                              title: 'Game 俱乐部',
                              colors: const [
                                Color(0xffff9a5a),
                                Color(0xffff5f8f),
                              ],
                              height: 63,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const GameCompanionPlazaPage(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                      subtitle: '52局等待中',
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
              const SizedBox(height: 12),
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

class _LegacyHomePage extends StatelessWidget {
  const _LegacyHomePage({super.key});

  void _unavailable(BuildContext context, String feature) {}

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
                      title: 'Game 俱乐部',
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
    this.onChat,
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
  final VoidCallback? onChat;
  final VoidCallback? onDelete;
  final bool authorNavigation;
  final bool listMode;

  bool _isOwnPost() => post.userId == null || post.userId == 1;

  bool get _isTextOnly =>
      post.content.trim().isNotEmpty &&
      (post.imageUrl == null || post.imageUrl!.trim().isEmpty) &&
      (post.videoUrl == null || post.videoUrl!.trim().isEmpty);

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
              child: post.avatar.trim().isEmpty
                  ? const Icon(Icons.person_outline)
                  : ClipOval(
                      child: Image.network(
                        post.avatar,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person_outline),
                      ),
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
            else if (onFollow != null && post.userId != null && !_isOwnPost())
              OutlinedButton(
                onPressed: post.following ? onChat : onFollow,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  fixedSize: const Size(78, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  textStyle: const TextStyle(fontSize: 13, height: 1.15),
                  foregroundColor: post.following ? Theme.of(context).colorScheme.onSurface : Colors.white,
                  side: BorderSide(
                    color: post.following
                        ? Theme.of(context).colorScheme.outlineVariant
                        : Colors.red,
                  ),
                  backgroundColor: post.following ? Colors.transparent : Colors.red,
                ),
                child: Text(post.following ? '私聊' : '关注'),
              ),
          ],
        ),
        if (post.content.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onTap: onOpen,
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onTap: onOpen,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: Image.network(
                          post.thumbnailUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 225, child: ColoredBox(color: Colors.black26)),
                  const Icon(
                    Icons.play_circle_outline,
                    size: 56,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: onLike,
              style: TextButton.styleFrom(
                foregroundColor: post.liked ? Colors.red : null,
              ),
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
              style: TextButton.styleFrom(
                foregroundColor: post.favorited ? Colors.red : null,
              ),
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: content,
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(top: 0),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: content,
        ),
      ),
    );
  }
}

class _VideoPlaybackRegistry {
  static final Set<_NetworkVideoPreviewState> _players = <_NetworkVideoPreviewState>{};

  static void register(_NetworkVideoPreviewState player) => _players.add(player);
  static void unregister(_NetworkVideoPreviewState player) => _players.remove(player);

  static void stopAll() {
    for (final player in List<_NetworkVideoPreviewState>.from(_players)) {
      player.stopPlayback();
    }
  }
}

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({
    required this.url,
    this.thumbnailUrl,
    this.unlimitedHeight = false,
  });
  final String url;
  final String? thumbnailUrl;
  final bool unlimitedHeight;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  VideoPlayerController? controller;
  bool loading = false;
  bool ended = false;

  void _onVideoChanged() {
    final active = controller;
    if (!mounted || active == null || !active.value.isInitialized) return;
    final duration = active.value.duration;
    final position = active.value.position;
    final isEnded = duration > Duration.zero && position >= duration;
    if (ended != isEnded) setState(() => ended = isEnded);
  }

  Future<void> _replay() async {
    final active = controller;
    if (active == null) return;
    await active.seekTo(Duration.zero);
    setState(() => ended = false);
    await active.play();
  }

  @override
  void initState() {
    super.initState();
    _VideoPlaybackRegistry.register(this);
  }

  Future<void> _play() async {
    if (loading) return;
    setState(() => loading = true);
    final next = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await next.initialize();
      await next.play();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        loading = false;
        ended = false;
      });
      next.addListener(_onVideoChanged);
    } catch (_) {
      await next.dispose();
      if (mounted) setState(() => loading = false);
    }
  }

  void stopPlayback() {
    controller?.pause();
  }

  @override
  void dispose() {
    _VideoPlaybackRegistry.unregister(this);
    controller?.removeListener(_onVideoChanged);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    if (active == null || !active.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: _play,
          child: Stack(
            alignment: Alignment.center,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Container(
                  width: double.infinity,
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: widget.thumbnailUrl?.isNotEmpty == true
                      ? ConstrainedBox(
                          constraints: widget.unlimitedHeight
                              ? const BoxConstraints()
                              : const BoxConstraints(maxHeight: 400),
                          child: Image.network(
                            widget.thumbnailUrl!,
                            width: constraints.maxWidth,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        )
                      : const SizedBox(height: 225),
                ),
              ),
              loading
                  ? const CircularProgressIndicator()
                  : const Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.white,
                    ),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = widget.unlimitedHeight
                  ? width / active.value.aspectRatio
                  : math.min(400.0, width / active.value.aspectRatio);
              return SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(active),
              );
            },
          ),
          if (ended)
            GestureDetector(
              onTap: _replay,
              child: const Icon(Icons.replay_circle_filled, size: 64, color: Colors.white),
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

class _DiscoverPageState extends State<DiscoverPage>
    with WidgetsBindingObserver {
  final DDPostService service = DDPostService();
  static const _cacheDuration = Duration(hours: 1);
  static const _discoverCacheVersion = 'v4';
  final List<List<DDPost>> _postsByTab = [<DDPost>[], <DDPost>[], <DDPost>[]];
  List<DDPost> get _currentPosts => _postsByTab[selectedTab];
  bool loading = true;
  bool _refreshing = false;
  int selectedTab = 0;
  bool tabLoading = false;
  String? cityLabel;
  String? error;
  DateTime? _backgroundedAt;
  final List<bool> _loadingMoreByTab = [false, false, false];
  final List<bool> _hasMoreByTab = [true, true, true];
  int _activeLoadGeneration = 0;
  final List<ScrollController> _discoverScrollControllers =
      List<ScrollController>.generate(3, (_) => ScrollController());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final controller in _discoverScrollControllers) {
      controller.addListener(_handleDiscoverScroll);
    }
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切到后台再回来不刷新；只有进程被系统结束后重新创建页面，initState 才会加载。
  }

  void _handleDiscoverScroll() {
    final controller = _discoverScrollControllers[selectedTab];
    if (controller.hasClients && controller.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final tabAtRequest = selectedTab;
    if (_loadingMoreByTab[tabAtRequest] || !_hasMoreByTab[tabAtRequest]) return;
    _loadingMoreByTab[tabAtRequest] = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      final controller = _discoverScrollControllers[tabAtRequest];
      if (!controller.hasClients || controller.position.extentAfter >= 500) return;
      final postsAtRequest = List<DDPost>.from(_postsByTab[tabAtRequest]);
      final batch = tabAtRequest == 0
          ? await service.fetchRecommendedPosts(token, offset: postsAtRequest.length)
          : tabAtRequest == 1
              ? await service.fetchNearbyPosts(token, offset: postsAtRequest.length)
              : await service.fetchFollowingPosts(token, offset: postsAtRequest.length);
      if (!mounted || selectedTab != tabAtRequest) return;
      final ids = _postsByTab[tabAtRequest].map((item) => item.id).toSet();
      final additions = batch.where((item) => ids.add(item.id)).toList();
      setState(() {
        _postsByTab[tabAtRequest] = [
          ..._postsByTab[tabAtRequest],
          ...additions,
        ];
        _hasMoreByTab[tabAtRequest] = batch.length >= 30;
      });
      await _saveDiscoverCache(tabAtRequest);
    } finally {
      _loadingMoreByTab[tabAtRequest] = false;
    }
  }

  Future<void> _saveDiscoverCache(int tab) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'dd.discover.cache.$_discoverCacheVersion.$tab';
    await prefs.setString(key, jsonEncode(_postsByTab[tab].map((item) => item.toJson()).toList()));
    final expiries = _postsByTab[tab]
        .map((item) => _signedUrlExpiryMillis(item.avatar))
        .whereType<int>()
        .toList();
    await prefs.setInt('$key.at', DateTime.now().millisecondsSinceEpoch);
    if (expiries.isNotEmpty) await prefs.setInt('$key.urlExpiresAt', expiries.reduce((a, b) => a < b ? a : b));
  }

  @override
  void dispose() {
    for (final controller in _discoverScrollControllers) {
      controller.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    service.dispose();
    super.dispose();
  }
  Future<void> _refreshInBackground() async {
    // 保留显式入口，当前不由 AppLifecycleState 自动调用。
  }

  Future<void> load({
    int? tab,
    bool fromRefresh = false,
    bool backgroundRefresh = false,
  }) async {
    if (fromRefresh) HapticFeedback.mediumImpact();
    final generation = ++_activeLoadGeneration;
    final targetTab = tab ?? selectedTab;
    final switchingTab = tab != null && !fromRefresh && !loading;
    if (switchingTab) {
      setState(() {
        selectedTab = targetTab;
        tabLoading = false;
        error = null;
      });
    }
    if (fromRefresh) {
      if (_refreshing) return;
      _refreshing = true;
    } else if (!switchingTab && !backgroundRefresh) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('friend.auth.token') ?? '';
      if (t.isEmpty) throw Exception('登录后加载发现内容');
      final cacheKey = 'dd.discover.cache.$_discoverCacheVersion.$targetTab';
      final cacheAtKey = '$cacheKey.at';
      final cachedAt = p.getInt(cacheAtKey);
      final cachedJson = p.getString(cacheKey);
      final cacheHasData = cachedJson != null && cachedJson.isNotEmpty;
      final cachedUrlExpiry = p.getInt('$cacheKey.urlExpiresAt');
      final cacheFresh = !fromRefresh &&
          !backgroundRefresh &&
          cacheHasData &&
          (cachedUrlExpiry == null || DateTime.now().millisecondsSinceEpoch < cachedUrlExpiry);
      final cachedPosts = cacheFresh
          ? (jsonDecode(cachedJson!) as List)
              .whereType<Map<String, dynamic>>()
              .map(DDPost.fromJson)
              .toList()
          : <DDPost>[];
      if (!mounted || generation != _activeLoadGeneration) return;
      if (cacheFresh) {
        setState(() {
          _postsByTab[targetTab] = cachedPosts;
          loading = false;
          tabLoading = false;
        });
        if (!backgroundRefresh) return;
      }
      final cachedCity = (p.getString('dd.location.city') ?? '').trim();
      if (mounted && cachedCity.isNotEmpty && cityLabel != cachedCity) {
        setState(() => cityLabel = cachedCity);
      }
      await syncCachedLocation(service, t);
      final city = await cachedCityLabel(service, t);
      if (mounted && cityLabel != city) setState(() => cityLabel = city);
      final shouldFetch = fromRefresh || backgroundRefresh || switchingTab || !cacheFresh;
      if (!mounted || generation != _activeLoadGeneration) return;
      final loaded = shouldFetch
          ? (targetTab == 0
              ? await service.fetchRecommendedPosts(t, offset: 0)
              : targetTab == 1
                  ? await service.fetchNearbyPosts(t)
                  : await service.fetchFollowingPosts(t))
          : cachedPosts;
      if (!mounted || generation != _activeLoadGeneration) return;
      if (shouldFetch) {
        await p.setString(
          cacheKey,
          jsonEncode(loaded
              .map((item) => {
                    'id': item.id,
                    'userId': item.userId,
                    'content': item.content,
                    'createdAt': item.createdAt,
                    'nickname': item.nickname,
                    'avatar': item.avatar,
                    'likes': item.likes,
                    'favorites': item.favorites,
                    'comments': item.comments,
                    'following': item.following,
                    'distanceKm': item.distanceKm,
                    'liked': item.liked,
                    'favorited': item.favorited,
                    'imageUrl': item.imageUrl,
                    'videoUrl': item.videoUrl,
                    'thumbnailUrl': item.thumbnailUrl,
                    'views': item.views,
                  })
              .toList()),
        );
        await p.setInt(cacheAtKey, DateTime.now().millisecondsSinceEpoch);
      }
      if (!mounted || generation != _activeLoadGeneration) return;
      if (mounted) {
        setState(() {
          _postsByTab[targetTab] = loaded;
          selectedTab = targetTab;
        });
      }
      } catch (e) {
        if (mounted && generation == _activeLoadGeneration) {
          setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        }
      } finally {
        if (mounted && generation == _activeLoadGeneration) {
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

  Widget _buildDiscoverList(int tab) {
    return ListView(
                controller: _discoverScrollControllers[tab],
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    18, 0, 18, 28 + MediaQuery.of(context).padding.bottom),
                children: [
                  const SizedBox(height: 6),
                  if (loading)
                    const _PageLoadState(
                      title: '动态加载中',
                      subtitle: '正在读取发现内容',
                    ),
                  if (!loading && error != null)
                    _PageErrorState(
                      title: '发现加载失败',
                      subtitle: error!,
                      onRetry: () => load(tab: tab),
                    ),
                  if (tabLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 36),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!loading && error == null && _postsByTab[tab].isEmpty)
                    _EmptyStateCard(
                      icon: tab == 1
                          ? Icons.location_off_outlined
                          : tab == 2
                              ? Icons.person_outline
                              : Icons.article_outlined,
                      title: tab == 1
                          ? '暂无附近动态'
                          : tab == 2
                              ? '暂无关注动态'
                              : '暂无动态',
                      subtitle: tab == 1
                          ? '授权定位并等待附近用户发布动态'
                          : tab == 2
                              ? '关注用户后，他们的动态会显示在这里'
                              : '暂时没有可发现的真实动态',
                    ),
                  if (!loading && !tabLoading && error == null)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _postsByTab[tab]
                          .map(
                            (post) => SizedBox(
                              width: (MediaQuery.of(context).size.width - 54) / 2,
                              child: _DynamicPostCard(
                          post: post,
                          listMode: true,
                          onLike: () async {
                            try {
                              final p = await SharedPreferences.getInstance();
                              final t = p.getString('friend.auth.token') ?? '';
                              if (t.isEmpty) throw Exception('请先登录');
                              await service.toggleLike(t, post.id);
                              if (mounted) {
                                setState(() {
                                  final index = _postsByTab[tab]
                                      .indexWhere((item) => item.id == post.id);
                                  if (index >= 0) {
                                    final current = _postsByTab[tab][index];
                                    _postsByTab[tab][index] = current.copyWith(
                                      liked: !current.liked,
                                      likes: current.likes +
                                          (current.liked ? -1 : 1),
                                    );
                                  }
                                });
                                await DDPostService.clearProfileTabCaches();
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
                              final t = p.getString('friend.auth.token') ?? '';
                              if (t.isEmpty) throw Exception('请先登录');
                              await service.toggleFavorite(t, post.id);
                              if (mounted) {
                                setState(() {
                                  final index = _postsByTab[tab]
                                      .indexWhere((item) => item.id == post.id);
                                  if (index >= 0) {
                                    final current = _postsByTab[tab][index];
                                    _postsByTab[tab][index] = current.copyWith(
                                      favorited: !current.favorited,
                                      favorites: current.favorites +
                                          (current.favorited ? -1 : 1),
                                    );
                                  }
                                });
                                await DDPostService.clearProfileTabCaches();
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
                          onFollow: post.userId == null || post.userId == 1
                              ? null
                              : () async {
                                  if (!mounted) return;
                                  try {
                                    final p = await SharedPreferences.getInstance();
                                    final t = p.getString('friend.auth.token') ?? '';
                                    if (t.isEmpty) throw Exception('请先登录');
                                    await service.toggleFollow(t, post.userId!);
                                    await load(tab: tab, fromRefresh: true);
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => error = e
                                          .toString()
                                          .replaceFirst('Exception: ', ''));
                                    }
                                  }
                                },
                          onChat: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('私聊功能暂未接入')),
                          ),
                          ),
                            ),
                          )
                          .toList(),
                    ),
                ]);
  }

  Widget _avatarWidget(String url, {double radius = 20}) {
    if (url.trim().isEmpty) {
      return CircleAvatar(radius: radius, child: const Icon(Icons.person_outline));
    }
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: _PermanentCachedImage(url: url, fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            children: ['推荐', (cityLabel ?? '').trim().isEmpty ? '本地' : cityLabel!, '关注']
                .asMap()
                .entries
                .map((entry) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        load(tab: entry.key);
                      },
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
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
              icon: const Icon(TIcons.notification, size: 21),
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
        body: IndexedStack(
              index: selectedTab,
              children: List<Widget>.generate(
                3,
                (tab) => RefreshIndicator(
                  onRefresh: () => load(tab: tab, fromRefresh: true),
                  child: _buildDiscoverList(tab),
                ),
              ),
            ),
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
          height: 96,
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
  Widget build(BuildContext context) {
    final shape = _FolderShape(borderRadius: borderRadius);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Ink(
              height: height,
              decoration: ShapeDecoration(
                gradient: LinearGradient(colors: colors),
                shape: shape,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 24, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, color: Colors.white, size: 27),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: tabAlignment,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: colors.first.withValues(alpha: .96),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .14),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              tabLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeNormalCard extends StatelessWidget {
  const _HomeNormalCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.colors,
    required this.height,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Color> colors;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(icon, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      );
}

class _FolderShape extends ShapeBorder {
  const _FolderShape({required this.borderRadius});
  final BorderRadius borderRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = borderRadius.resolve(textDirection);
    final path = Path();
    path.moveTo(rect.left + 20, rect.top);
    path.lineTo(rect.left + 82, rect.top);
    path.quadraticBezierTo(
        rect.left + 92, rect.top, rect.left + 99, rect.top + 9);
    path.lineTo(rect.right - 24, rect.top + 9);
    path.quadraticBezierTo(rect.right, rect.top + 9, rect.right, rect.top + 33);
    path.lineTo(rect.right, rect.bottom - r.bottomRight.y);
    path.quadraticBezierTo(
        rect.right, rect.bottom, rect.right - r.bottomRight.x, rect.bottom);
    path.lineTo(rect.left + r.bottomLeft.x, rect.bottom);
    path.quadraticBezierTo(
        rect.left, rect.bottom, rect.left, rect.bottom - r.bottomLeft.y);
    path.lineTo(rect.left, rect.top + r.topLeft.y);
    path.quadraticBezierTo(rect.left, rect.top, rect.left + 20, rect.top);
    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _FolderShape(borderRadius: borderRadius * t);
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
          const SizedBox(height: 10),
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
  XFile? selectedVideo;
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

  Future<void> _pickVideo() async {
    try {
      final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        final bytes = await video.length();
        if (bytes > 50 * 1024 * 1024) throw Exception('视频不能超过 50MB');
        setState(() {
          selectedVideo = video;
          selectedImage = null;
          mediaType = '视频';
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '视频选择失败：$e');
    }
  }
  Future<void> _pickMedia() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('添加图片'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('添加视频'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (type == 'image') await _pickImage();
    if (type == 'video') await _pickVideo();
  }

  Future<String?> _imageObjectKey(String token) async {
    if (selectedImage == null) return null;
    final bytes = await selectedImage!.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) throw Exception('图片不能超过 8MB');
    final decoded = img.decodeImage(bytes);
    final resized = decoded == null
        ? null
        : (decoded.width > 1600 ? img.copyResize(decoded, width: 1600) : decoded);
    final compressed = resized == null ? bytes : img.encodeJpg(resized, quality: 82);
    final signed = await _service.postMediaUploadUrl(
      token: token,
      fileName: selectedImage!.name,
      contentType: 'image/jpeg',
      kind: 'image',
    );
    final url = signed['url'];
    final key = signed['objectKey'];
    if (url is! String || key is! String) throw Exception('图片上传地址格式错误');
    if (!await _service.uploadAvatar(url: url, bytes: compressed, contentType: 'image/jpeg')) {
      throw Exception('图片上传失败');
    }
    return key;
  }

  Future<String?> _videoObjectKey(String token) async {
    if (selectedVideo == null) return null;
    final bytes = await selectedVideo!.readAsBytes();
    if (bytes.length > 50 * 1024 * 1024) throw Exception('视频不能超过 50MB');
    final signed = await _service.postMediaUploadUrl(
      token: token,
      fileName: selectedVideo!.name,
      contentType: 'video/mp4',
      kind: 'video',
    );
    final url = signed['url'];
    final key = signed['objectKey'];
    if (url is! String || key is! String) throw Exception('视频上传地址格式错误');
    if (!await _service.uploadAvatar(url: url, bytes: bytes, contentType: 'video/mp4')) {
      throw Exception('视频上传失败');
    }
    return key;
  }


  Future<String?> _videoThumbnailKey(String token) async {
    if (selectedVideo == null) return null;
    final bytes = await VideoThumbnail.thumbnailData(
      video: selectedVideo!.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 720,
      quality: 82,
    );
    if (bytes == null || bytes.isEmpty) throw Exception('视频预览图生成失败');
    final signed = await _service.postMediaUploadUrl(
      token: token,
      fileName: 'thumbnail.jpg',
      contentType: 'image/jpeg',
      kind: 'image',
    );
    final url = signed['url'];
    final key = signed['objectKey'];
    if (url is! String || key is! String) throw Exception('视频预览图上传地址格式错误');
    if (!await _service.uploadAvatar(url: url, bytes: bytes, contentType: 'image/jpeg')) {
      throw Exception('视频预览图上传失败');
    }
    return key;
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
        selectedVideo = null;
        mediaType = null;
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
                      final token = prefs.getString('friend.auth.token') ?? '';
                      if (token.isEmpty) {
                        setState(() => error = '请先登录后发布动态');
                        return;
                      }
                      if (_content.text.trim().isEmpty &&
          selectedImage == null &&
          selectedVideo == null) {
                        setState(() => error = '请输入动态内容或选择图片');
                        return;
                      }
                      setState(() {
                        publishing = true;
                        error = null;
                      });
                      try {
                        final location = await _locationForPost(token);
                        final videoKey = await _videoObjectKey(token);
                        final thumbnailKey = await _videoThumbnailKey(token);
                        await _service.createPost(
                          token: token,
                          content: _content.text.trim(),
                          imageDataUrl: await _imageObjectKey(token),
                          videoUrl: videoKey,
                          thumbnailUrl: thumbnailKey,
                          visibility: visibility == '仅好友可见'
                              ? 'friends'
                              : visibility == '仅自己可见'
                                  ? 'private'
                                  : 'public',
                          latitude: location?.latitude,
                          longitude: location?.longitude,
                        );
                        await DDPostService.clearProfileTabCaches();
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
              autofocus: true,
              maxLines: 7,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '发一条动态吧～',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                alignLabelWithHint: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, size: 28),
                ),
              ),
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
            if (selectedVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Stack(
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: VideoThumbnail.thumbnailData(
                        video: selectedVideo!.path,
                        imageFormat: ImageFormat.JPEG,
                        maxWidth: 720,
                        quality: 82,
                      ),
                      builder: (context, snapshot) => ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: snapshot.data == null
                              ? const ColoredBox(color: Colors.black26)
                              : Image.memory(snapshot.data!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 56,
                          color: Colors.white,
                        ),
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
                    children: ['所有人可见', '仅主页可见', '仅陌生人可见', '仅自己可见']
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

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DDPostService service = DDPostService();
  List<DDNotification> notifications = const [];
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

  Future<String> token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final t = await token();
      final items = await service.fetchNotifications(t);
      await service.markNotificationsRead(t);
      if (mounted) setState(() => notifications = items);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String titleFor(DDNotification item) {
    switch (item.type) {
      case 'like':
        return '点赞了你的动态';
      case 'favorite':
        return '收藏了你的动态';
      case 'comment':
        return '评论了你的动态';
      case 'comment_reply':
        return '回复了你的评论';
      case 'comment_deleted':
        return '你的评论被系统删除';
      case 'post_deleted':
        return '你的动态被系统删除';
      case 'follow':
        return '关注了你';
      default:
        return item.content;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('通知'),
          actions: [
            IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _PageErrorState(
                    title: '通知加载失败', subtitle: error!, onRetry: load)
                : RefreshIndicator(
                    onRefresh: load,
                    child: notifications.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(child: Text('暂无通知')),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, index) {
                              final item = notifications[index];
                              final actor =
                                  item.nickname?.trim().isNotEmpty == true
                                      ? item.nickname!
                                      : '系统';
                              return Card(
                                margin: EdgeInsets.zero,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: item.postId == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => DynamicDetailPage(
                                                postId: item.postId!,
                                                focusComment:
                                                    item.commentId != null,
                                              ),
                                            ),
                                          ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          child: item.avatar?.isNotEmpty == true
                                              ? ClipOval(
                                                  child: _PermanentCachedImage(
                                                    url: item.avatar!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Icon(item.nickname == null
                                                  ? Icons.shield_outlined
                                                  : Icons.person_outline),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('$actor ${titleFor(item)}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              if (item.postContent
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 5),
                                                  child: Text(
                                                    '动态：${item.postContent}',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (item.commentContent
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 3),
                                                  child: Text(
                                                    '评论：${item.commentContent}',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 5),
                                                child: Text(
                                                  '${item.content} · ${item.createdAt}',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (item.postId != null)
                                          const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
  // 默认只显示每个父评论的 1 条直接回复，点击“显示更多”后每次增加 3 条。
  int visibleRootCount = 30;
  final Map<int, int> visibleReplyCounts = <int, int>{};
  final Set<int> expandedThirdLevelParents = <int>{};
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
    final value = p.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  String _detailCacheKey(int postId) => 'dd.detail.post.cache.$postId';
  String _detailCacheAtKey(int postId) => 'dd.detail.post.cache.$postId.at';

  Future<DDPost?> _readDetailCache(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_detailCacheKey(postId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return DDPost.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
        preserveMediaKeys: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDetailCache(DDPost value) async {
    final prefs = await SharedPreferences.getInstance();
    // 详情缓存只保留业务数据；签名 URL 会过期，不能作为长期媒体身份保存。
    final json = value.toJson();
    for (final key in <String>['avatar', 'imageUrl', 'videoUrl', 'thumbnailUrl']) {
      final raw = json[key];
      if (raw is String && raw.startsWith('http')) {
        json[key] = Uri.parse(raw).pathSegments.join('/');
      }
    }
    await prefs.setString(_detailCacheKey(value.id), jsonEncode(json));
    await prefs.setInt(_detailCacheAtKey(value.id), DateTime.now().millisecondsSinceEpoch);
    await prefs.remove('${_detailCacheAtKey(value.id)}.urlExpiresAt');
  }

  Future<List<DDComment>> _loadComments(String t) async {
    final value = await service.fetchComments(t, widget.postId);
    if (mounted) {
      setState(() {
        comments = value;
        visibleRootCount = 30;
        visibleReplyCounts.clear();
        expandedThirdLevelParents.clear();
      });
    }
    return value;
  }

  Future<DDPost> _resignDetailMedia(String t, DDPost value) async {
    Future<String> sign(String raw, {required bool avatar}) async {
      final source = raw.trim();
      if (source.isEmpty) return '';
      final key = source.startsWith('http')
          ? Uri.parse(source).pathSegments.join('/')
          : source;
      if (key.isEmpty) return '';
      if (avatar) return (await service.resolveAvatarUrl(t, key)) ?? '';
      return service.mediaUrlForKey(t, key);
    }

    return DDPost(
      id: value.id, userId: value.userId, content: value.content,
      createdAt: value.createdAt, nickname: value.nickname,
      avatar: await sign(value.avatar, avatar: true), likes: value.likes,
      favorites: value.favorites, comments: value.comments,
      following: value.following, followedByViewer: value.followedByViewer,
      distanceKm: value.distanceKm, liked: value.liked, favorited: value.favorited,
      imageUrl: value.imageUrl == null ? null : await sign(value.imageUrl!, avatar: false),
      videoUrl: value.videoUrl == null ? null : await sign(value.videoUrl!, avatar: false),
      thumbnailUrl: value.thumbnailUrl == null ? null : await sign(value.thumbnailUrl!, avatar: false),
      views: value.views,
    );
  }

  Future<void> load() async {
    try {
      final t = await token();
      final me = await service.fetchMe(t);
      currentUserId = _intValue(me['id']);
      final cached = await _readDetailCache(widget.postId);
      if (cached != null && mounted) {
        final resigned = await _resignDetailMedia(t, cached);
        post = resigned;
        loading = false;
        setState(() {});
        await _loadComments(t);
        return;
      }
      final freshPost = await service.fetchPost(t, widget.postId);
      final resigned = await _resignDetailMedia(t, freshPost);
      post = resigned;
      await _saveDetailCache(freshPost);
      await _loadComments(t);
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
    final roots = source.where((c) => c.parentId == null).toList();

    void appendReplies(DDComment parent, int depth) {
      final replies = repliesByParent[parent.id] ?? const <DDComment>[];
      final visible = depth >= 2 && !expandedThirdLevelParents.contains(parent.id)
          ? 0
          : (visibleReplyCounts[parent.id] ?? 1);
      for (final reply in replies.take(visible)) {
        result.add(Padding(
          padding: EdgeInsets.only(left: depth >= 2 ? 84.0 : 42.0),
          child: _commentTile(
            reply,
            depth: depth,
            // 只有回复三级评论时显示“某某 回复 某某”。
            replyTo: depth >= 2 ? parent.nickname : null,
          ),
        ));
        appendReplies(reply, depth + 1);
      }
      if (replies.isNotEmpty &&
          ((depth >= 2 && !expandedThirdLevelParents.contains(parent.id)) ||
              visible < replies.length)) {
        result.add(Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() {
              if (depth >= 2) {
                expandedThirdLevelParents.add(parent.id);
                visibleReplyCounts[parent.id] = replies.length;
              } else {
                visibleReplyCounts[parent.id] = visible + 3;
              }
            }),
            child: Text(depth >= 2 && !expandedThirdLevelParents.contains(parent.id)
                ? '显示更多'
                : '显示更多'),
          ),
        ));
      }
    }

    for (final root in roots.take(visibleRootCount)) {
      result.add(_commentTile(root, depth: 0, replyTo: null));
      appendReplies(root, 1);
    }
    if (visibleRootCount < roots.length) {
      result.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => visibleRootCount += 30),
          child: const Text('显示更多'),
        ),
      ));
    }
    return result;
  }

  Future<void> _toggleCommentLike(DDComment comment) async {
    try {
      final liked = await service.toggleCommentLike(await token(), comment.id);
      final index = comments.indexWhere((item) => item.id == comment.id);
      if (index == -1 || !mounted) return;
      setState(() {
        comments[index] = DDComment(
          id: comment.id,
          userId: comment.userId,
          parentId: comment.parentId,
          nickname: comment.nickname,
          content: comment.content,
          createdAt: comment.createdAt,
          likes: comment.likes + (liked == comment.liked ? 0 : (liked ? 1 : -1)),
          liked: liked,
          city: comment.city,
        );
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _commentMenu(DDComment comment) async {
    final isMine = currentUserId != null && comment.userId == currentUserId;
    final canDelete = isMine || isOwner;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(comment.liked ? Icons.thumb_up : Icons.thumb_up_outlined),
              title: const Text('点赞'),
              onTap: () => Navigator.pop(context, 'like'),
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('举报'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == 'like') {
      await _toggleCommentLike(comment);
    } else if (action == 'copy') {
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

  Widget _commentTile(
    DDComment comment, {
    required int depth,
    required String? replyTo,
  }) {
    final isMine = currentUserId != null && comment.userId == currentUserId;
    final isPostAuthor = post?.userId != null && comment.userId == post!.userId;
    final displayName = isMine ? '我' : comment.nickname;
    final displayColor = isMine
        ? Colors.red
        : isPostAuthor
            ? Colors.green
            : null;
    return InkWell(
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          depth >= 2
                              ? '${displayName} 回复 ${replyTo ?? (isPostAuthor ? '作者' : comment.nickname)}'
                              : displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: displayColor,
                          ),
                        ),
                        if (comment.city.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _ProfileTag(text: comment.city.trim()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(comment.content),
                    const SizedBox(height: 5),
                    Text(
                      formatDDTime(comment.createdAt),
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _toggleCommentLike(comment),
                          child: Icon(
                            comment.liked
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 16,
                            color: comment.liked
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('${comment.likes}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _toggleLike() async {
    try {
      await service.toggleLike(await token(), widget.postId);
      await DDPostService.clearProfileTabCaches();
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
      await DDPostService.clearProfileTabCaches();
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
    if (deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除动态'),
        content: const Text('删除后动态及其媒体文件将无法恢复，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      setState(() => deleting = true);
      await service.deletePost(await token(), widget.postId);
      await DDPostService.clearProfileTabCaches();
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
                              child: item.avatar.trim().isEmpty
                                  ? const Icon(Icons.person_outline)
                                  : ClipOval(
                                      child: Image.network(
                                        item.avatar,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.person_outline),
                                      ),
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
                            onPressed: followLoading
                                ? null
                                : item.following
                                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('私聊功能暂未接入')),
                                        )
                                    : _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: item.following
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.white,
                              backgroundColor:
                                  item.following ? Colors.transparent : Colors.red,
                              side: BorderSide(
                                color: item.following
                                    ? Theme.of(context).colorScheme.outlineVariant
                                    : Colors.red,
                              ),
                            ),
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
                        _PostImageHolder(url: item.imageUrl!, unlimitedHeight: true)
                      ],
          if (item.videoUrl != null &&
                          item.videoUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _NetworkVideoPreview(
                          url: item.videoUrl!,
                          thumbnailUrl: item.thumbnailUrl,
                          unlimitedHeight: true,
                        ),
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
  const _PostImageHolder({required this.url, this.unlimitedHeight = false});
  final String url;
  final bool unlimitedHeight;

  Future<void> _showViewer(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _showViewer(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: unlimitedHeight
                ? const BoxConstraints()
                : const BoxConstraints(maxHeight: 400),
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
  final ScrollController _profileScrollController = ScrollController();
  final AudioPlayer _sonicPlayer = AudioPlayer();
  Map<String, dynamic>? profile;
  List<DDPost> posts = const [];
  bool loading = true;
  bool actionLoading = false;
  bool isFollowing = false;
  bool isProfileLiked = false;
  bool isSelfProfile = false;
  int profileLikes = 0;
  int selectedContentTab = 0;
  bool _showStickyNickname = false;
  bool _sonicPlaying = false;
  String? _sonicUrl;
  String? _avatarUrl;
  String? error;

  @override
  void initState() {
    super.initState();
    _profileScrollController.addListener(_handleProfileScroll);
    load();
  }

  void _handleProfileScroll() {
    final show = _profileScrollController.hasClients &&
        _profileScrollController.offset >= 58;
    if (show != _showStickyNickname && mounted) {
      setState(() => _showStickyNickname = show);
    }
  }

  @override
  void dispose() {
    _profileScrollController.removeListener(_handleProfileScroll);
    _profileScrollController.dispose();
    _sonicPlayer.dispose();
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
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) {
        throw Exception('请先登录');
      }
      if (widget.userId == null) {
        throw Exception('用户信息不存在');
      }
      final data = await service.fetchUserProfile(token, widget.userId!);
      final me = await service.fetchMe(token);
      final avatarKey = '${data['avatarKey'] ?? data['avatar'] ?? ''}'.trim();
      final signedAvatar = avatarKey.isEmpty
          ? null
          : await service.resolveAvatarUrl(token, avatarKey);
      final loadedPosts = (data['posts'] is List)
          ? (data['posts'] as List)
              .whereType<Map>()
              .map((item) => DDPost.fromJson(item.cast<String, dynamic>()))
              .toList()
          : <DDPost>[];
      if (mounted) {
        setState(() {
          profile = data;
          posts = loadedPosts;
          isFollowing = data['followingByViewer'] == true;
          isProfileLiked = data['likedByViewer'] == true;
          isSelfProfile = '${data['id']}' == '${me['id']}';
          profileLikes = int.tryParse('${data['receivedLikes'] ?? 0}') ?? 0;
          _sonicUrl = DDPostService.mediaUrl(data['voiceUrl']?.toString());
          _avatarUrl = signedAvatar;
        });
      }
    } on UnsupportedError catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleSonic() async {
    final url = _sonicUrl;
    if (url == null || url.isEmpty || actionLoading) return;
    try {
      setState(() => actionLoading = true);
      if (_sonicPlaying) {
        await _sonicPlayer.pause();
      } else {
        await _sonicPlayer.play(UrlSource(url));
      }
      if (mounted) setState(() => _sonicPlaying = !_sonicPlaying);
    } catch (_) {
      if (mounted) setState(() => error = '声音播放失败');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> toggleFollow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
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
    final userId = widget.userId;
    if (userId == null || actionLoading) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      setState(() => actionLoading = true);
      final result = await service.toggleProfileLike(token, userId);
      if (mounted) {
        setState(() {
          isProfileLiked = result['liked'] == true;
          profileLikes += isProfileLiked ? 1 : -1;
          if (profileLikes < 0) profileLikes = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
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
        title: _showStickyNickname
            ? Text(
                '${p?['nickname'] ?? widget.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : const SizedBox.shrink(),
        actions: [
          if (!loading && !isSelfProfile)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ProfileLikePill(
                liked: isProfileLiked,
                onTap: actionLoading ? null : toggleProfileLike,
              ),
            ),
          IconButton(
            onPressed: () => _showProfileMenu(context),
            icon: _tdIcon('more'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                controller: _profileScrollController,
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                  child: _avatarUrl == null || _avatarUrl!.isEmpty
                                      ? const Icon(Icons.person_outline, size: 34)
                                      : ClipOval(
                                          child: Image.network(
                                            _avatarUrl!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.person_outline, size: 34),
                                          ),
                                        ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: -12,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: _ProfileTag(
                                        text: '${p?['city'] ?? '未知'}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 80,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '${p?['nickname'] ?? widget.name}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 25,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _SonicProfileButton(
                                                playing: _sonicPlaying,
                                                enabled: _sonicUrl?.isNotEmpty == true,
                                                onTap: _toggleSonic,
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              _InlineProfileStat(
                                                label: '关注',
                                                value: '${p?['following'] ?? 0}',
                                                valueFontSize: 18,
                                                labelFontSize: 14,
                                              ),
                                              const SizedBox(width: 18),
                                              _InlineProfileStat(
                                                label: '粉丝',
                                                value: '${p?['followers'] ?? 0}',
                                                valueFontSize: 18,
                                                labelFontSize: 14,
                                              ),
                                              const SizedBox(width: 18),
                                              _InlineProfileStat(
                                                label: '获赞',
                                                value: '${p?['receivedLikes'] ?? 0}',
                                                valueFontSize: 18,
                                                labelFontSize: 14,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 32,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _ProfileTag(text: '声优'),
                                            const SizedBox(width: 6),
                                            _ProfileTag(text: '御姐'),
                                            const SizedBox(width: 6),
                                            _ProfileTag(text: '忧郁'),
                                            const SizedBox(width: 6),
                                            _ProfileTag(text: '旅游'),
                                            const SizedBox(width: 6),
                                            _ProfileTag(text: '电影'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: actionLoading ? null : toggleFollow,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: following
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Colors.white,
                                    backgroundColor:
                                        following ? Colors.transparent : Colors.red,
                                    side: BorderSide(
                                      color: following
                                          ? Theme.of(context).colorScheme.outlineVariant
                                          : Colors.red,
                                    ),
                                  ),
                                  icon: Icon(
                                    following ? Icons.person_remove_outlined : Icons.person_add_alt_1_outlined,
                                  ),
                                    label: Text(
                                      actionLoading
                                          ? '处理中…'
                                          : following
                                              ? (p?['followedByViewer'] == true ? '好友' : '已关注')
                                              : (p?['followedByViewer'] == true ? '回关' : '关注'),
                                    ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('私聊功能暂未接入')),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('私聊'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MyProfileIconTabs(
                    selectedTab: 0,
                    onSelect: (_) {},
                    postsOnly: true,
                  ),
                  const SizedBox(height: 12),
                  if (posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 42),
                      child: Center(child: Text('暂无内容')),
                    )
                  else
                    _MyProfileGrid(posts: posts),
                  const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 12),
                    child: Center(
                      child: Text(
                        '暂时没有更多了',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
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
  int selectedTab = 0;
  bool loading = true;
  bool tabLoading = false;
  final Map<int, List<DDPost>> tabPosts = {};
  final AudioPlayer _sonicPlayer = AudioPlayer();
  final ScrollController _profileScrollController = ScrollController();
  bool _showStickyNickname = false;

  bool _sonicPlaying = false;
  String? _sonicUrl;
  String? _avatarUrl;
  String? error;
  List<String> _tags = <String>[];

  @override
  void initState() {
    super.initState();
    _profileScrollController.addListener(_handleProfileScroll);
    load();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  void _handleProfileScroll() {
    final shouldShow = _profileScrollController.hasClients &&
        _profileScrollController.offset >= 58;
    if (shouldShow != _showStickyNickname && mounted) {
      setState(() => _showStickyNickname = shouldShow);
    }

  }

  @override
  void dispose() {
    _profileScrollController.removeListener(_handleProfileScroll);
    _profileScrollController.dispose();
    _sonicPlayer.dispose();
    service.dispose();
    super.dispose();
  }

  Future<void> _toggleSonic() async {
    final url = _sonicUrl;
    if (url == null || url.isEmpty) return;
    if (_sonicPlaying) {
      await _sonicPlayer.pause();
    } else {
      await _sonicPlayer.play(UrlSource(url));
    }
    if (mounted) setState(() => _sonicPlaying = !_sonicPlaying);
  }

  static const _profileTabCachePrefix = 'dd.profile.tab.cache.v2.';
  static const _profileTabCacheAtPrefix = 'dd.profile.tab.cache.at.';
  static const _profileMediaRefreshAge = Duration(hours: 1);

  Future<void> _saveTabCache(int tab, List<DDPost> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_profileTabCachePrefix$tab',
      jsonEncode(value.map((post) => post.toJson()).toList()),
    );
    await prefs.setInt(
      '$_profileTabCacheAtPrefix$tab',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<DDPost>?> _readTabCache(int tab) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_profileTabCachePrefix$tab';
    final expiry = prefs.getInt('$key.urlExpiresAt');
    if (expiry != null && DateTime.now().millisecondsSinceEpoch >= expiry) return null;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as List;
      return data
          .whereType<Map>()
          .map((item) => DDPost.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      await prefs.remove('$_profileTabCachePrefix$tab');
      return null;
    }
  }

  Future<void> _invalidateProfileCacheAndReload() async {
    await DDPostService.clearProfileTabCaches();
    tabPosts.clear();
    await load(tab: selectedTab, forceRefresh: true);
  }

  Future<void> load({int? tab, bool forceRefresh = false}) async {
    final targetTab = tab ?? selectedTab;
    final isTabSwitch = tab != null && !loading && !forceRefresh;
    if (mounted) {
      setState(() {
        error = null;
        if (isTabSwitch) {
          selectedTab = targetTab;
          tabLoading = false;
          final cached = tabPosts[targetTab];
          if (cached != null) posts = cached;
        } else {
          loading = true;
        }
      });
    }
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('friend.auth.token') ?? '';
      if (t.isEmpty) throw Exception('请先登录');
      final needProfile = profile == null || !isTabSwitch;
      Map<String, dynamic> loadedProfile = profile ?? {};
      if (needProfile) {
        loadedProfile = await service.fetchMe(t);
        _sonicUrl =
            DDPostService.mediaUrl(loadedProfile['voiceUrl']?.toString());
        final avatarKey = '${loadedProfile['avatarKey'] ?? ''}'.trim();
        _avatarUrl = avatarKey.isEmpty ? null : await service.resolveAvatarUrl(t, avatarKey);
        final profileTags = loadedProfile['tags'];
        _tags = profileTags is List
            ? profileTags.map((value) => '$value').where((value) => value.trim().isNotEmpty).toList()
            : <String>[];
      }
      final cached = forceRefresh
          ? null
          : await _readTabCache(targetTab);
      if (cached != null && !forceRefresh) {
        tabPosts[targetTab] = cached;
        if (mounted) {
          setState(() {
            profile = loadedProfile;
            posts = cached;
            selectedTab = targetTab;
          });
        }
        return;
      }
      final loadedPosts = targetTab == 0
          ? await service.fetchMyPosts(t)
          : targetTab == 1
              ? await service.fetchFavoritedPosts(t)
              : await service.fetchLikedPosts(t);
      tabPosts[targetTab] = loadedPosts;
      await _saveTabCache(targetTab, loadedPosts);
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
      appBar: AppBar(
        centerTitle: true,
        title: _showStickyNickname
            ? Text(
                '${p?['nickname'] ?? 'DD 用户'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : const SizedBox.shrink(),
        actions: [
          IconButton(
            tooltip: '浏览记录',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _HistoryRecordsPage()),
            ),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('分享主页'),
                    ),
                    ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('设置'),
                    ),
                  ],
                ),
              ),
            ),
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => load(forceRefresh: true),
              child: CustomScrollView(
                controller: _profileScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                  if (error != null)
                    _PageErrorState(
                      title: '资料加载失败',
                      subtitle: error!,
                      onRetry: load,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 80,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 25 * 5,
                                  child: Text(
                                    '${p?['nickname'] ?? 'DD 用户'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: '编辑资料',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EditProfilePage(),
                                      ),
                                    );
                                    if (mounted) load();
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SonicProfileButton(
                                  playing: _sonicPlaying,
                                  enabled: _sonicUrl?.isNotEmpty == true,
                                  onTap: () async {
                                    await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => _VoiceRecordPage(
                                          currentUrl: _sonicUrl,
                                        ),
                                      ),
                                    );
                                    if (mounted) load();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  width: 68,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _InlineProfileStat(
                                      label: '关注',
                                      value: '${p?['following'] ?? 0}',
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const _UserRelationListPage(
                                            relation: 'following',
                                            title: '关注',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 68,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _InlineProfileStat(
                                      label: '粉丝',
                                      value: '${p?['followers'] ?? 0}',
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const _UserRelationListPage(
                                            relation: 'followers',
                                            title: '粉丝',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 68,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _InlineProfileStat(
                                      label: '获赞',
                                      value: '${p?['receivedLikes'] ?? p?['likes'] ?? 0}',
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const _UserRelationListPage(
                                            relation: 'likers',
                                            title: '获赞',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: _avatarUrl == null || _avatarUrl!.isEmpty
                                  ? const ColoredBox(
                                      color: Colors.black12,
                                      child: Icon(Icons.person, size: 42),
                                    )
                                  : Image.network(
                                      _avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const ColoredBox(
                                        color: Colors.black12,
                                        child: Icon(Icons.person, size: 42),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -12,
                            child: Align(
                              alignment: Alignment.center,
                              child: _ProfileTag(
                                text: '${p?['city'] ?? '未知'}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 32,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final selected =
                                  await Navigator.push<List<String>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _ProfileTagEditorPage(
                                    selectedTags: _tags,
                                  ),
                                ),
                              );
                              if (selected != null && mounted) {
                                try {
                                  final t = await _token();
                                  final updated = await service.updateMe(
                                    token: t,
                                    tags: selected,
                                  );
                                  setState(() {
                                    _tags = selected;
                                    profile = {
                                      ...(profile ?? <String, dynamic>{}),
                                      ...updated,
                                      'tags': selected,
                                    };
                                  });
                                } catch (e) {
                                  setState(() => error = e.toString().replaceFirst('Exception: ', ''));
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '+',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                          ..._tags.map((tag) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _ProfileTag(text: tag),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ]),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabsHeaderDelegate(
                      child: _MyProfileIconTabs(
                        selectedTab: selectedTab,
                        onSelect: (tab) => load(tab: tab),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                  _MyProfileGrid(
                    posts: posts,
                    onChanged: _invalidateProfileCacheAndReload,
                  ),
                  if (!tabLoading && error == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 24, bottom: 12),
                      child: Center(
                        child: Text(
                          '暂时没有更多了',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabsHeaderDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        elevation: overlapsContent ? 2 : 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: child,
        ),
      );

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _HistoryRecordsPage extends _UserRelationListPage {
  const _HistoryRecordsPage() : super(relation: 'history', title: '历史访客');
}

class _UserRelationListPage extends StatefulWidget {
  const _UserRelationListPage({required this.relation, required this.title});
  final String relation;
  final String title;

  @override
  State<_UserRelationListPage> createState() => _UserRelationListPageState();
}

class _UserRelationListPageState extends State<_UserRelationListPage> {
  final DDPostService service = DDPostService();
  List<Map<String, dynamic>> users = const [];
  bool loading = true;
  String? error;

  String _relationLabel(Map<String, dynamic> user) {
    final followingByViewer = user['followingByViewer'] == true;
    final followedByViewer = user['followedByViewer'] == true;
    if (followingByViewer && followedByViewer) return '好友';
    if (followingByViewer) return '已关注';
    if (followedByViewer) return '回关';
    return '关注';
  }

  Future<void> _toggleRelation(int index) async {
    final userId = _intValue(users[index]['id']);
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final followed = await service.toggleFollow(token, userId);
      if (!mounted) return;
      setState(() {
        final current = Map<String, dynamic>.from(users[index]);
        current['followingByViewer'] = followed;
        current['followedByViewer'] =
            current['followedByViewer'] == true;
        users[index] = current;
        error = null;
      });
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final loaded = await service.fetchUsers(token, relation: widget.relation);
      if (mounted) setState(() => users = loaded);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _PageErrorState(
                    title: '加载失败', subtitle: error!, onRetry: load)
                : RefreshIndicator(
                    onRefresh: load,
                    child: users.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(child: Text('暂无用户')),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            itemCount: users.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final userId = _intValue(user['id']);
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  onTap: userId == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OtherProfilePage(
                                                userId: userId,
                                                name:
                                                    '${user['nickname'] ?? '用户'}',
                                              ),
                                            ),
                                          ),
                                  leading: '${user['avatar'] ?? ''}'.isEmpty
                                      ? const CircleAvatar(child: Icon(Icons.person_outline))
                                      : ClipOval(
                                          child: _PermanentCachedImage(
                                            url: DDPostService.mediaUrl('${user['avatar']}'),
                                            fit: BoxFit.cover,
                                          ),
                                      ),
                                  title: Text('${user['nickname'] ?? '用户'}'),
                                  subtitle: Text(
                                      widget.relation == 'history'
                                          ? '${user['city'] ?? '未知地区'} · 访问 ${user['visitCount'] ?? 1} 次'
                                          : '${user['city'] ?? '未知地区'}'),
                                  trailing: OutlinedButton(
                                    onPressed: userId == null
                                        ? null
                                        : () => _toggleRelation(index),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ),
                                    child: Text(_relationLabel(user)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      );
}

class _VoiceRecordPage extends StatefulWidget {
  const _VoiceRecordPage({required this.currentUrl});
  final String? currentUrl;

  @override
  State<_VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<_VoiceRecordPage> {
  final AudioRecorder recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();
  final DDPostService service = DDPostService();
  bool recording = false;
  bool saving = false;
  bool playing = false;
  Timer? _recordingTimer;
  int recordingSeconds = 0;
  String? recordingPath;
  String? error;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    recorder.dispose();
    player.dispose();
    service.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    try {
      final active = await recorder.isRecording();
      if (active) {
        final path = await recorder.stop();
        if (path == null || path.isEmpty) throw Exception('停止录音失败，未生成音频文件');
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) throw Exception('录音文件为空');
        if (mounted) setState(() { recording = false; recordingPath = path; error = null; });
        _recordingTimer?.cancel();
        return;
      }
      final permission = await recorder.hasPermission();
      if (!permission) throw Exception('没有麦克风权限，请在设置中允许 DD 使用麦克风');
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/friend_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 128000,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      if (!await recorder.isRecording()) throw Exception('录音启动失败');
      recordingSeconds = 0;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        recordingSeconds++;
        if (recordingSeconds >= 15) {
          _recordingTimer?.cancel();
          await _record();
        } else {
          setState(() {});
        }
      });
      if (mounted) setState(() { recording = true; error = null; });
    } catch (e) {
      if (mounted) setState(() { recording = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _preview() async {
    final localPath = recordingPath;
    final url = widget.currentUrl;
    if ((localPath == null || localPath.isEmpty) && (url == null || url.isEmpty)) {
      setState(() => error = '请先录制声音');
      return;
    }
    if (playing) {
      await player.pause();
    } else {
      if (localPath != null && localPath.isNotEmpty) {
        await player.play(DeviceFileSource(localPath));
      } else {
        await player.play(UrlSource(url!));
      }
    }
    if (mounted) setState(() => playing = !playing);
  }

  Future<void> _toggleSonic() async {
    final url = widget.currentUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => error = '还没有保存的声音');
      return;
    }
    if (playing) {
      await player.pause();
    } else {
      await player.play(UrlSource(url));
    }
    if (mounted) setState(() => playing = !playing);
  }

  Future<void> _deleteCloudVoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除云端声音'),
        content: const Text('删除后将无法恢复，确定删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      setState(() {
        saving = true;
        error = null;
      });
      await player.stop();
      await service.updateMe(token: await _token(), voiceKey: '');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _save() async {
    final localPath = recordingPath;
    if (localPath == null || localPath.isEmpty) {
      setState(() => error = '请先录制声音');
      return;
    }
    try {
      setState(() { saving = true; error = null; });
      final token = await _token();
      final bytes = await File(localPath).readAsBytes();
      final signed = await service.voiceUploadUrl(
        token: token,
        fileName: 'voice.m4a',
        contentType: 'audio/mp4',
      );
      final url = signed['url'];
      final key = signed['objectKey'];
      if (url is! String || key is! String) throw Exception('声音上传地址格式错误');
      if (!await service.uploadAvatar(url: url, bytes: bytes, contentType: 'audio/mp4')) {
        throw Exception('声音上传失败');
      }
      await service.updateMe(token: token, voiceKey: key);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('声音录制')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(TIcons.sonic,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(recording ? '正在录音… ${recordingSeconds}s / 15s' : '录制你的声音名片'),
              const SizedBox(height: 24),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.orange)),
              const Spacer(),
              if (widget.currentUrl?.trim().isNotEmpty == true) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _toggleSonic,
                        icon: Icon(playing ? Icons.pause : Icons.cloud_outlined),
                        label: const Text('云端声音'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _deleteCloudVoice,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除云端'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : _record,
                      icon: Icon(recording ? Icons.stop : Icons.mic),
                      label: Text(recording ? '停止录音' : '开始录音'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : _preview,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      label: const Text('本地试听'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(saving ? '保存中…' : '保存声音'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SonicProfileButton extends StatelessWidget {
  const _SonicProfileButton({
    required this.playing,
    required this.enabled,
    required this.onTap,
  });
  final bool playing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: enabled ? .14 : .07),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Icon(
            playing ? Icons.pause : TIcons.sonic,
            size: 18,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor,
          ),
        ),
      );
}

class _MyProfileIconTabs extends StatelessWidget {
  const _MyProfileIconTabs({required this.selectedTab, required this.onSelect, this.postsOnly = false});
  final int selectedTab;
  final ValueChanged<int> onSelect;
  final bool postsOnly;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _tab(context, 0, Icons.blur_on),
          if (!postsOnly) ...[
            _tab(context, 1, Icons.bookmark_border),
            _tab(context, 2, Icons.favorite_border),
          ],
        ],
      );

  Widget _tab(BuildContext context, int index, IconData icon) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selectedTab == index
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).hintColor,
                ),
                const SizedBox(height: 7),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: selectedTab == index ? 28 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MyProfileGrid extends StatelessWidget {
  const _MyProfileGrid({required this.posts, this.onChanged});
  final List<DDPost> posts;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: Text('暂无内容')),
      );
    }
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 18,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _MyProfilePostCard(
          post: post,
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => DynamicDetailPage(postId: post.id),
              ),
            );
            if (changed == true) onChanged?.call();
          },
        );
      },
    );
  }
}

class _MyProfilePostCard extends StatelessWidget {
  const _MyProfilePostCard({required this.post, required this.onTap});
  final DDPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = post.imageUrl?.trim();
    final video = post.videoUrl?.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null && image.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: Image.network(
                      DDPostService.mediaUrl(image),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                )
              else if (video != null && video.isNotEmpty)
                InkWell(
                  onTap: onTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: Image.network(
                              post.thumbnailUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 225,
                          child: ColoredBox(color: Colors.black26),
                        ),
                  const Icon(
                    Icons.play_circle_outline,
                    size: 56,
                    color: Colors.white,
                  ),
                    ],
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      post.content.trim().isEmpty ? '暂无动态内容' : post.content.trim(),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (post.content.trim().isNotEmpty &&
                  ((image != null && image.isNotEmpty) ||
                      (video != null && video.isNotEmpty)))
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    post.content.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Icon(TIcons.thumb_up_1,
                        size: 16,
                        color: post.liked ? Colors.red : scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.likes}'),
                    const SizedBox(width: 12),
                    Icon(Icons.bookmark_border,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.favorites}'),
                    const Spacer(),
                    Icon(Icons.visibility_outlined,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.views}'),
                  ],
                ),
              ),
            ],
          ),
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
          subtitle: const Text('声音名片 · ，'),
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
      children: posts
          .map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MyProfilePostCard(
                  post: post,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DynamicDetailPage(postId: post.id),
                    ),
                  ),
                ),
              ))
          .toList(),
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
      children: posts
          .map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MyProfilePostCard(
                  post: post,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DynamicDetailPage(postId: post.id),
                    ),
                  ),
                ),
              ))
          .toList(),
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
              if (post.imageUrl?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _PostImageHolder(url: DDPostService.mediaUrl(post.imageUrl)),
                ),
              if (post.videoUrl?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (post.thumbnailUrl?.trim().isNotEmpty == true)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: Image.network(
                            DDPostService.mediaUrl(post.thumbnailUrl),
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        const SizedBox(
                          height: 225,
                          child: ColoredBox(color: Colors.black26),
                        ),
                  const Icon(
                    Icons.play_circle_outline,
                    size: 56,
                    color: Colors.white,
                  ),
                    ],
                  ),
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

class _ProfileLikePill extends StatelessWidget {
  const _ProfileLikePill({
    required this.liked,
    required this.onTap,
  });
  final bool liked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.pinkAccent : null,
              size: 24,
            ),
          ),
        ),
      );
}

class _InlineProfileStat extends StatelessWidget {
  const _InlineProfileStat({
    required this.label,
    required this.value,
    this.onTap,
    this.valueFontSize = 16,
    this.labelFontSize = 13,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final double valueFontSize;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: valueFontSize,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: .65),
            fontSize: labelFontSize,
          ),
        ),
      ],
    );
    return onTap == null
        ? child
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: child,
            ),
          );
  }
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
          subtitle: const Text('声音名片 · ，'),
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
                  const SizedBox(height: 10),
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
        const Text('通话 00:03', style: TextStyle(color: Colors.white70)),
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

class _VoiceUiNotice extends StatelessWidget {
  const _VoiceUiNotice();
  @override
  Widget build(BuildContext context) => const Text('语音匹配',
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
                data: c, onTap: () => _open(c), onOrder: _showFakeOrderDialog)),
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
  Future<void> _showFakeOrderDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('胡进正在伪装，请稍后……'),
        content: const Text('当前进度：正在插入变声器'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _notice(String feature) {}
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
                                  Positioned(
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
                                      Text('在线5 分钟内响应',
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
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text(''))),
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
      child: Text('陪玩广场', style: Theme.of(context).textTheme.labelSmall));
}

class _VoiceRoomNotice extends StatelessWidget {
  const _VoiceRoomNotice();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('语音房、麦位和房间消息',
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

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
        ),
      );
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
                  Positioned(right: 0, bottom: 0, child: _OnlineDot()),
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
          subtitle: const Text('声音名片 · '),
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
                    const Text('缘分匹配',
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
                              .showSnackBar(const SnackBar(content: Text(''))),
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
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      posts = const [];
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
          (await SharedPreferences.getInstance()).getString('friend.auth.token') ??
              '';
      if (token.isEmpty) throw Exception('请先登录');
      await service.deletePost(token, post.id);
      await DDPostService.clearProfileTabCaches();
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
                        title: '动态为空',
                        subtitle: '新后端暂未提供动态接口',
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
                                          .getString('friend.auth.token') ??
                                      '';
                              if (token.isNotEmpty) {
                                await service.toggleLike(token, post.id);
                                await load();
                              }
                            },
                            onFavorite: () async {
                              final token =
                                  (await SharedPreferences.getInstance())
                                          .getString('friend.auth.token') ??
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
  XFile? image;
  List<int>? croppedAvatar;
  bool loading = true;
  bool saving = false;
  String? _avatarPreviewUrl;
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
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final token = p.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final data = await service.fetchMe(token);
      final profile = data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : data;
      nickname.text = '${profile['nickname'] ?? ''}';
      if (profile['avatarKey'] is String &&
          (profile['avatarKey'] as String).trim().isNotEmpty) {
        final signed = await service.resolveAvatarUrl(
          token,
          profile['avatarKey'],
        );
        if (mounted) {
          setState(() => _avatarPreviewUrl = signed);
        }
      }
    } catch (e) {
      if (mounted) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickAvatar() async {
    try {
      final value = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (value == null || !mounted) return;
      final cropped = await Navigator.push<List<int>>(
        context,
        MaterialPageRoute(builder: (_) => AvatarCropPage(file: value)),
      );
      if (cropped != null && mounted) {
        setState(() {
          croppedAvatar = cropped;
          image = null;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '头像选择失败：$e');
    }
  }

  Future<String?> _avatarObjectKey(String token) async {
    if (croppedAvatar == null) return null;
    final response = await service.avatarUploadUrl(
      token: token,
      fileName: 'avatar.jpg',
      contentType: 'image/jpeg',
    );
    final url = response['url'];
    final objectKey = response['objectKey'];
    if (url is! String || objectKey is! String) throw Exception('头像上传地址格式错误');
    final upload = await service.uploadAvatar(
      url: url,
      bytes: croppedAvatar!,
      contentType: 'image/jpeg',
    );
    if (!upload) throw Exception('头像上传失败');
    return objectKey;
  }

  Future<void> save() async {
    try {
      setState(() => saving = true);
      final p = await SharedPreferences.getInstance();
      final token = p.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final avatarKey = await _avatarObjectKey(token);
      await service.updateMe(
        token: token,
        nickname: nickname.text.trim(),
        avatarKey: avatarKey,
      );
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
                  child: Center(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: ClipPath(
                        clipper: _FixedCircleClipper(),
                        child: ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: croppedAvatar != null
                              ? Image.memory(
                                  Uint8List.fromList(croppedAvatar!),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                )
                              : (_avatarPreviewUrl == null
                                  ? const Icon(Icons.add_a_photo_outlined, size: 30)
                                  : Image.network(
                                      _avatarPreviewUrl!,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image_outlined),
                                    )),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.orange)),
                TextField(
                    controller: nickname,
                    maxLength: 5,
                    decoration: const InputDecoration(labelText: '昵称')),
              ]),
      );
}

class _FixedCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final diameter = size.shortestSide;
    final left = (size.width - diameter) / 2;
    final top = (size.height - diameter) / 2;
    return Path()..addOval(Rect.fromLTWH(left, top, diameter, diameter));
  }

  @override
  bool shouldReclip(covariant _FixedCircleClipper oldClipper) => false;
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
              subtitle: const Text('内容'),
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

class _ProfileTagEditorPage extends StatefulWidget {
  const _ProfileTagEditorPage({required this.selectedTags});
  final List<String> selectedTags;

  @override
  State<_ProfileTagEditorPage> createState() => _ProfileTagEditorPageState();
}

class _ProfileTagEditorPageState extends State<_ProfileTagEditorPage> {
  static const allTags = [
    'INTJ',
    'INTP',
    'ENTJ',
    'ENTP',
    'INFJ',
    'INFP',
    'ENFJ',
    'ENFP',
    'ISTJ',
    'ISFJ',
    'ESTJ',
    'ESFJ',
    'ISTP',
    'ISFP',
    'ESTP',
    'ESFP',
  ];
  late String? selected = widget.selectedTags.isEmpty
      ? null
      : widget.selectedTags.firstWhere(
          allTags.contains,
          orElse: () => widget.selectedTags.first,
        );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('标签编辑'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                selected == null ? <String>[] : <String>[selected!],
              ),
              child: const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('选择你的兴趣标签'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((tag) {
                return ChoiceChip(
                  label: Text(tag),
                  selected: selected == tag,
                  onSelected: (value) => setState(() {
                    selected = value ? tag : null;
                  }),
                );
              }).toList(),
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
                    onTap: entry['label'] == '个性商城' ? onEdit : () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(entry['icon'] as IconData, size: 23),
                        const SizedBox(height: 10),
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
