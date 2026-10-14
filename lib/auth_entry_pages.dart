part of 'main.dart';

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
              const Text('DD',
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('发现有趣的人，分享真实生活。',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 18)),
              const SizedBox(height: 34),
              const Spacer(),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LoginPage())),
                      child: const Text('开始使用'))),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phone = TextEditingController();
  final code = TextEditingController();
  final auth = FriendAuthClient();
  Timer? timer;
  int seconds = 0;
  bool loading = false;
  bool sendingCode = false;
  String? error;

  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    code.dispose();
    auth.dispose();
    super.dispose();
  }

  Future<void> sendCode() async {
    if (sendingCode || seconds > 0) return;
    if (!RegExp(r'^1\d{10}$').hasMatch(phone.text.trim())) {
      setState(() => error = '请输入正确的手机号');
      return;
    }
    setState(() {
      sendingCode = true;
      error = null;
    });
    try {
      await auth.sendSmsCode(phone.text.trim());
      setState(() {
        seconds = 60;
        error = null;
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            if (seconds > 0) seconds--;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sendingCode = false);
    }
  }

  Future<void> login() async {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone.text.trim())) {
      setState(() => error = '请输入正确的手机号');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = '请输入手机号和验证码');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await auth.loginBySms(phone: phone.text, code: code.text);
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const DDShell()));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '登录 / 注册',
        subtitle: '使用阿里云短信验证码',
        child: Column(children: [
          _AuthFieldController(
              label: '手机号码', icon: Icons.phone_outlined, controller: phone),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _AuthFieldController(
                    label: '验证码',
                    icon: Icons.verified_outlined,
                    controller: code)),
            const SizedBox(width: 8),
            TextButton(
                onPressed: seconds == 0 && !sendingCode ? sendCode : null,
                child: Text(sendingCode
                    ? '发送中…'
                    : seconds == 0
                        ? '获取验证码'
                        : '${seconds}s'))
          ]),
          if (error != null)
            Align(
                alignment: Alignment.centerLeft,
                child:
                    Text(error!, style: const TextStyle(color: Colors.orange))),
          const SizedBox(height: 24),
          _PrimaryAuthButton(
              label: loading ? '登录中…' : '登录 / 注册',
              onTap: loading ? () {} : login),
          TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PasswordLoginPage())),
              child: const Text('密码登录')),
        ]),
      );
}
