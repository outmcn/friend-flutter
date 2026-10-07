part of 'main.dart';

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
