part of 'main.dart';

class _DiscoverProfileCard extends StatelessWidget {
  const _DiscoverProfileCard({
    super.key,
    required this.post,
    this.mediaKey,
    required this.onLike,
    required this.onFavorite,
    required this.onShare,
    required this.onReport,
    required this.onOpen,
  });

  final DDPost post;
  final GlobalKey? mediaKey;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onOpen;

  Widget _media({required String url, required bool thumbnail}) {
    final sourceWidth = thumbnail ? post.thumbnailWidth : post.imageWidth;
    final sourceHeight = thumbnail ? post.thumbnailHeight : post.imageHeight;
    final ratio = sourceWidth != null && sourceHeight != null &&
            sourceWidth > 0 && sourceHeight > 0
        ? sourceWidth / sourceHeight
        : 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayWidth = constraints.maxWidth;
        final naturalHeight = displayWidth / ratio;
        final displayHeight = naturalHeight <= 500 ? naturalHeight : 500.0;
        final actualWidth = naturalHeight <= 500
            ? displayWidth
            : displayHeight * ratio;
        return Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: actualWidth,
              height: displayHeight,
              child: _PermanentCachedImage(
                url: url,
                width: actualWidth,
                height: displayHeight,
                fit: BoxFit.contain,
                placeholder: const ColoredBox(
                  color: Color(0x22111111),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _action({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
  }) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 20,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : null),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
          ),
        ),
      );

  void _showDiscoverMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(TIcons.share_1),
              title: const Text('分享动态'),
              onTap: () {
                Navigator.pop(sheetContext);
                onShare();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('举报动态'),
              onTap: () {
                Navigator.pop(sheetContext);
                onReport();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = (post.imageUrl?.trim().isNotEmpty == true) ||
        (post.videoUrl?.trim().isNotEmpty == true);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: post.avatar.trim().isEmpty
                    ? const Icon(Icons.person_outline)
                    : _PermanentCachedImage(
                        url: post.avatar,
                        fit: BoxFit.cover,
                        placeholder: const Icon(Icons.person_outline),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post.nickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                )),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                formatDDTime(post.createdAt),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '更多',
                        onPressed: () => _showDiscoverMore(context),
                        icon: const Icon(TIcons.more),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                      ),
                    ],
                  ),
                  if (post.content.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 5),
                      child: Text(post.content.trim(),
                          style: const TextStyle(fontSize: 18, height: 1.4)),
                    ),
                  if (post.imageUrl?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    _media(url: post.imageUrl!.trim(), thumbnail: false),
                  ] else if (post.videoUrl?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        _media(url: post.thumbnailUrl?.trim().isNotEmpty == true ? post.thumbnailUrl!.trim() : post.videoUrl!.trim(), thumbnail: post.thumbnailUrl?.trim().isNotEmpty == true),
                        const Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _action(context: context, icon: TIcons.thumb_up_2,
                          label: '${post.likes}', onTap: onLike, active: post.liked),
                      _action(context: context, icon: TIcons.bookmark,
                          label: '${post.favorites}', onTap: onFavorite,
                          active: post.favorited),
                      _action(context: context, icon: TIcons.chat_bubble_1,
                          label: '${post.comments}', onTap: onOpen),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
