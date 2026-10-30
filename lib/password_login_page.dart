part of 'main.dart';

class PasswordLoginPage extends StatefulWidget {
  const PasswordLoginPage({super.key, this.initialPhone = ''});
  final String initialPhone;

  @override
  State<PasswordLoginPage> createState() => _PasswordLoginPageState();
}

class _PasswordLoginPageState extends State<PasswordLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _service = DDPostService();
  final _auth = FriendAuthClient();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _username.text = widget.initialPhone;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _service.dispose();
    _auth.dispose();
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
        final raw = error.toString().replaceFirst('Exception: ', '');
        if (raw.startsWith('账号已被封禁|')) {
          final parts = raw.split('|');
          final until = parts.length > 1 ? parts[1] : '永久';
          final reason = parts.length > 2 ? parts[2] : '';
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('账号已被封禁'),
              content: Text(
                  '您已封禁（${until == '永久' ? '永久' : _banDurationText(until)}）${reason.isEmpty ? '' : '\\n原因：$reason'}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('关闭')),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openAppeal();
                    },
                    child: const Text('申诉')),
              ],
            ),
          );
        } else {
          setState(() => _error = raw);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAppeal() async {
    final controller = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('封禁申诉'),
                content: TextField(
                    controller: controller,
                    maxLines: 5,
                    decoration: const InputDecoration(hintText: '请填写申诉内容')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(c);
                        _showTopNotice(context, const Text('申诉已提交'));
                      },
                      child: const Text('提交'))
                ]));
    controller.dispose();
  }

  String _banDurationText(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final days = date.difference(DateTime.now()).inDays + 1;
    return '${days < 1 ? 1 : days}天';
  }

  Future<void> _openSmsFlow(String purpose) async {
    final phone = _username.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      setState(() => _error = '请输入正确的手机号');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmsPasswordFlowPage(phone: phone, purpose: purpose),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '密码登录',
        subtitle: '使用手机号或密码登录',
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
                onPressed: () => _openSmsFlow('recover'),
                child: const Text('忘记密码'),
              ),
            ),
            _PrimaryAuthButton(
                label: _loading ? '登录中…' : '登录',
                onTap: _loading ? () {} : _login),
            TextButton(
                onPressed: () => _openSmsFlow('register'),
                child: const Text('注册账号')),
          ],
        ),
      );
}

class SmsPasswordFlowPage extends StatefulWidget {
  const SmsPasswordFlowPage({
    super.key,
    required this.phone,
    required this.purpose,
    this.titleOverride,
  });
  final String phone;
  final String purpose;
  final String? titleOverride;
  @override
  State<SmsPasswordFlowPage> createState() => _SmsPasswordFlowPageState();
}

class _SmsPasswordFlowPageState extends State<SmsPasswordFlowPage> {
  final code = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final auth = FriendAuthClient();
  Timer? timer;
  int seconds = 0;
  bool sending = false;
  bool submitting = false;
  bool showRecover = false;
  String? error;

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    password.dispose();
    confirm.dispose();
    auth.dispose();
    super.dispose();
  }

  Future<void> sendCode() async {
    if (sending || seconds > 0) return;
    setState(() {
      sending = true;
      error = null;
      showRecover = false;
    });
    try {
      await auth.sendSmsCodeFor(phone: widget.phone, purpose: widget.purpose);
      if (!mounted) return;
      setState(() => seconds = 60);
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (seconds > 0) seconds--;
        });
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> complete() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = '请输入6位验证码');
      return;
    }
    if (password.text.length < 6) {
      setState(() => error = '密码至少6位');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = '两次密码不一致');
      return;
    }
    setState(() {
      submitting = true;
      error = null;
      showRecover = false;
    });
    try {
      final result = await auth.completeSmsFlow(
        phone: widget.phone,
        code: code.text,
        password: password.text,
        purpose: widget.purpose,
      );
      if (!mounted) return;
      final token = result['token'];
      if (token is String && token.isNotEmpty) {
        await ImSession.instance.start(token);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DDShell()),
            (_) => false,
          );
        }
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          showRecover = widget.purpose == 'register' && error!.contains('已注册');
        });
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: widget.titleOverride ??
            (widget.purpose == 'register' ? '注册账号' : '找回密码'),
        subtitle: '验证码验证后设置密码',
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('手机号：${widget.phone}'),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _AuthFieldController(
                  label: '验证码',
                  icon: Icons.verified_outlined,
                  controller: code,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: seconds == 0 && !sending ? sendCode : null,
                child: Text(sending
                    ? '发送中…'
                    : seconds == 0
                        ? '获取验证码'
                        : '${seconds}s'),
              ),
            ]),
            const SizedBox(height: 14),
            _AuthFieldController(
              label: '设置密码',
              icon: Icons.lock_outline,
              controller: password,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            _AuthFieldController(
              label: '确认密码',
              icon: Icons.lock_reset_outlined,
              controller: confirm,
              obscureText: true,
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child:
                    Text(error!, style: const TextStyle(color: Colors.orange)),
              ),
            ],
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: submitting ? '处理中…' : '验证并设置密码',
              onTap: submitting ? () {} : complete,
            ),
            if (showRecover)
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SmsPasswordFlowPage(
                      phone: widget.phone,
                      purpose: 'recover',
                    ),
                  ),
                ),
                child: const Text('忘记密码'),
              ),
            if (!showRecover && widget.purpose == 'register')
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回密码登录'),
              ),
          ],
        ),
      );
}

class _AuthFieldController extends StatelessWidget {
  const _AuthFieldController({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
  });
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
