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
