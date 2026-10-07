part of 'main.dart';

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
