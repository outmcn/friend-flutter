part of 'main.dart';

class RecommendationFeedPage extends StatelessWidget {
  const RecommendationFeedPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('为你推荐')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _ContentPreviewCard(
              title: '推荐动态 01',
              subtitle: '静态推荐内容',
              icon: Icons.auto_awesome,
              imageAsset: 'assets/figma/post-thumbnail-4.jpg',
            ),
            const _ContentPreviewCard(
              title: '推荐动态 02',
              subtitle: '更多生活方式分享',
              icon: Icons.photo_outlined,
              imageAsset: 'assets/figma/post-thumbnail-5.jpg',
            ),
            const _EmptyStateCard(
              icon: Icons.play_circle_outline,
              title: '推荐动态',
              subtitle: '登录后显示真实推荐动态',
            ),
          ],
        ),
      );
}

class _ContentPreviewCard extends StatelessWidget {
  const _ContentPreviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    // ignore: unused_element_parameter
    this.onTap,
    this.imageAsset,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 3,
          ),
          leading: imageAsset == null
              ? Icon(icon)
              : CircleAvatar(backgroundImage: AssetImage(imageAsset!)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(TIcons.chevron_right),
        ),
      ),
    );
  }
}

// Kept for the reference-detail routes.
// ignore: unused_element
class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow();
  @override
  Widget build(BuildContext context) => const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text('推荐用户'),
        subtitle: Text('分享了新的生活动态'),
        trailing: const Icon(TIcons.chevron_right),
      );
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distanceKm});
  final double distanceKm;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TIcons.location,
              size: 13,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 3),
            Text(
              '${distanceKm.toStringAsFixed(2)} km',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      );
}
