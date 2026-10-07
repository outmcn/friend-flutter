part of 'main.dart';

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
