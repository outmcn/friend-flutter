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
              ? _iconFor(icon)
              : CircleAvatar(backgroundImage: AssetImage(imageAsset!)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
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
        trailing: Icon(Icons.chevron_right),
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

class _ProfileTagEditorPage extends StatefulWidget {
  const _ProfileTagEditorPage({required this.selectedTags});
  final List<String> selectedTags;

  @override
  State<_ProfileTagEditorPage> createState() => _ProfileTagEditorPageState();
}

class _ProfileTagEditorPageState extends State<_ProfileTagEditorPage> {
  static const allTags = [
    'INTJ',
    'INTP',
    'ENTJ',
    'ENTP',
    'INFJ',
    'INFP',
    'ENFJ',
    'ENFP',
    'ISTJ',
    'ISFJ',
    'ESTJ',
    'ESFJ',
    'ISTP',
    'ISFP',
    'ESTP',
    'ESFP',
  ];
  late String? selected = widget.selectedTags.isEmpty
      ? null
      : widget.selectedTags.firstWhere(
          allTags.contains,
          orElse: () => widget.selectedTags.first,
        );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('标签编辑'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                selected == null ? <String>[] : <String>[selected!],
              ),
              child: const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('选择你的兴趣标签'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((tag) {
                return ChoiceChip(
                  label: Text(tag),
                  selected: selected == tag,
                  onSelected: (value) => setState(() {
                    selected = value ? tag : null;
                  }),
                );
              }).toList(),
            ),
          ],
        ),
      );
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}
