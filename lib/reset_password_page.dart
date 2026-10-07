part of 'main.dart';

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
