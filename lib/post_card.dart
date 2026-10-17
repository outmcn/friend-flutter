part of 'main.dart';

class _DiscoverMediaPreview extends StatelessWidget {
  const _DiscoverMediaPreview({required this.url, this.width, this.height});
  final String url;
  final int? width;
  final int? height;

  @override
  Widget build(BuildContext context) =>
      _DiscoverMediaImage(url: url, width: width, height: height);
}

class _DiscoverMediaImage extends StatefulWidget {
  const _DiscoverMediaImage({required this.url, this.width, this.height});
  final String url;
  final int? width;
  final int? height;

  @override
  State<_DiscoverMediaImage> createState() => _DiscoverMediaImageState();
}

class _DiscoverMediaImageState extends State<_DiscoverMediaImage> {
  double? _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = _sourceRatio;
  }

  double? get _sourceRatio =>
      widget.width != null && widget.height != null &&
              widget.width! > 0 && widget.height! > 0
          ? widget.width! / widget.height!
          : null;

  @override
  void didUpdateWidget(covariant _DiscoverMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _ratio = _sourceRatio;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _ratio ?? 1.0;
        final width = constraints.maxWidth;
        final naturalHeight = width / ratio;
        final limited = naturalHeight > 500;
        const maxPreviewHeight = 500.0;
        final height = naturalHeight > maxPreviewHeight
            ? maxPreviewHeight
            : naturalHeight;
        final displayWidth = naturalHeight > maxPreviewHeight
            ? height * ratio
            : width;
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: displayWidth,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.url,
                width: displayWidth,
                height: height,
                fit: naturalHeight > maxPreviewHeight
                    ? BoxFit.cover
                    : BoxFit.contain,
                alignment: Alignment.topLeft,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0x22111111),
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
                loadingBuilder: (context, child, progress) =>
                    progress == null
                        ? child
                        : const ColoredBox(
                            color: Color(0x22111111),
                            child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}


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
    return _DiscoverMediaPreview(
      url: url,
      width: thumbnail ? post.thumbnailWidth : post.imageWidth,
      height: thumbnail ? post.thumbnailHeight : post.imageHeight,
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
