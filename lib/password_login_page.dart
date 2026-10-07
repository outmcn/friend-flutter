part of 'main.dart';

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
