part of 'main.dart';

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
