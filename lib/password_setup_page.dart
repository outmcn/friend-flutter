part of 'main.dart';

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
