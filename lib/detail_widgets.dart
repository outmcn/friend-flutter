part of 'main.dart';

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PostImageHolder extends StatelessWidget {
  const _PostImageHolder({required this.url, this.unlimitedHeight = false});
  final String url;
  final bool unlimitedHeight;

  Future<void> _showViewer(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: _PermanentCachedImage(
              url: url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _showViewer(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: unlimitedHeight
                ? const BoxConstraints()
                : const BoxConstraints(maxHeight: 400),
            child: _PermanentCachedImage(
              url: url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
}

class _DetailAction extends StatelessWidget {
  const _DetailAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? Colors.pinkAccent : null),
              const SizedBox(width: 5),
              Text(label),
            ],
          ),
        ),
      );
}
