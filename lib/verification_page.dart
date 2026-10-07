part of 'main.dart';

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: title,
        subtitle: '验证码已发送，请输入验证码',
        child: Column(
          children: [
            const _AuthField(label: '验证码', icon: Icons.verified_outlined),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () {}, child: const Text('重新获取验证码')),
            ),
            const SizedBox(height: 18),
            _PrimaryAuthButton(
                label: '确认', onTap: () => Navigator.pop(context)),
          ],
        ),
      );
}
