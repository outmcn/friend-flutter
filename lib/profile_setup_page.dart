part of 'main.dart';

class ProfileSetupPage extends StatelessWidget {
  const ProfileSetupPage({super.key});

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: '完善资料',
        subtitle: '让大家更快认识你',
        child: Column(
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: const AssetImage(
                'assets/figma/profile-portrait-1.jpg',
              ),
              onBackgroundImageError: (_, __) {},
              child: const Icon(Icons.add_a_photo_outlined, size: 30),
            ),
            const SizedBox(height: 20),
            const _AuthField(label: '昵称', icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            const _AuthField(label: '一句话介绍自己', icon: Icons.edit_outlined),
            const SizedBox(height: 14),
            const _AuthField(label: '选择兴趣标签', icon: Icons.local_offer_outlined),
            const SizedBox(height: 24),
            _PrimaryAuthButton(
              label: '完成',
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
