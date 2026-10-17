part of 'main.dart';

class _DynamicPostCard extends StatelessWidget {
  const _DynamicPostCard({
    required this.post,
    required this.onLike,
    required this.onFavorite,
    required this.onOpen,
    this.onComment,
    // ignore: unused_element_parameter
    this.onFollow,
    // ignore: unused_element_parameter
    this.onChat,
    this.onDelete,
    this.authorNavigation = true,
    // ignore: unused_element_parameter
    this.listMode = false,
  });
  final DDPost post;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;
  final VoidCallback? onComment;
  final VoidCallback? onFollow;
  final VoidCallback? onChat;
  final VoidCallback? onDelete;
  final bool authorNavigation;
  final bool listMode;

  bool _isOwnPost() => post.userId == null || post.userId == 1;

  // ignore: unused_element
  bool get _isTextOnly =>
      post.content.trim().isNotEmpty &&
      (post.imageUrl == null || post.imageUrl!.trim().isEmpty) &&
      (post.videoUrl == null || post.videoUrl!.trim().isEmpty);

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: !authorNavigation || post.userId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtherProfilePage(
                            userId: post.userId,
                            name: post.nickname,
                          ),
                        ),
                      ),
              borderRadius: BorderRadius.circular(24),
              child: post.avatar.trim().isEmpty
                  ? const Icon(Icons.person_outline)
                  : ClipOval(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: _PermanentCachedImage(
                          url: post.avatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: const Icon(Icons.person_outline),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: !authorNavigation || post.userId == null
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OtherProfilePage(
                                      userId: post.userId,
                                      name: post.nickname,
                                    ),
                                  ),
                                ),
                        child: Text(post.nickname,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (post.distanceKm != null &&
                          post.distanceKm! <= 100) ...[
                        const SizedBox(width: 7),
                        _DistanceBadge(distanceKm: post.distanceKm!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatDDTime(post.createdAt),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .52),
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: '删除动态',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              )
            else if (onFollow != null && post.userId != null && !_isOwnPost())
              OutlinedButton(
                onPressed: post.following ? onChat : onFollow,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  fixedSize: const Size(78, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity:
                      const VisualDensity(horizontal: -1, vertical: -1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  textStyle: const TextStyle(fontSize: 13, height: 1.15),
                  foregroundColor: post.following
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.white,
                  side: BorderSide(
                    color: post.following
                        ? Theme.of(context).colorScheme.outlineVariant
                        : Colors.red,
                  ),
                  backgroundColor:
                      post.following ? Colors.transparent : Colors.red,
                ),
                child: Text(post.following ? '私聊' : '关注'),
              ),
          ],
        ),
        if (post.content.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(post.content,
                  style: const TextStyle(fontSize: 16, height: 1.4)),
            ),
          ),
        ],
        if (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: _PermanentCachedImage(
                  url: post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
        if (post.videoUrl != null && post.videoUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onTap: onOpen,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (post.thumbnailUrl != null &&
                      post.thumbnailUrl!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: _PermanentCachedImage(
                          url: post.thumbnailUrl!,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                        height: 225,
                        child: ColoredBox(color: Colors.transparent)),
                  const Icon(
                    Icons.play_circle_outline,
                    size: 56,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (!listMode)
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                style: TextButton.styleFrom(
                  foregroundColor: post.liked ? Colors.red : null,
                ),
                icon: Icon(TIcons.thumb_up_2),
                label: Text('${post.likes}'),
              ),
              TextButton.icon(
                onPressed: onComment ?? onOpen,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('${post.comments}'),
              ),
              TextButton.icon(
                onPressed: onFavorite,
                style: TextButton.styleFrom(
                  foregroundColor: post.favorited ? Colors.red : null,
                ),
                icon: Icon(TIcons.bookmark),
                label: Text('${post.favorites}'),
              ),
            ],
          )
        else ...[
          if (post.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Text(
                post.content.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, height: 1.35),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipOval(
                child: post.avatar.trim().isEmpty
                    ? const Icon(Icons.person_outline, size: 22)
                    : _PermanentCachedImage(
                        url: post.avatar,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  post.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onLike,
                    iconSize: 17,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    color: post.liked ? Colors.red : null,
                    icon: Icon(TIcons.thumb_up_2),
                  ),
                  const SizedBox(width: 2),
                  Text('${post.likes}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ],
    );
    if (!listMode) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: content,
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(top: 0),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: content,
        ),
      ),
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

  double _mediaAspect({required bool thumbnail}) {
    final width = thumbnail ? post.thumbnailWidth : post.imageWidth;
    final height = thumbnail ? post.thumbnailHeight : post.imageHeight;
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 4 / 3;
  }

  Widget _media({required String url, required bool thumbnail}) {
    final aspect = _mediaAspect(thumbnail: thumbnail);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth < 360
            ? constraints.maxWidth
            : 360.0;
        final naturalHeight = maxWidth / aspect;
        final height = naturalHeight.clamp(0.0, 400.0).toDouble();
        final width = naturalHeight > 400 ? height * aspect : maxWidth;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _PermanentCachedImage(
                url: url,
                width: width,
                height: height,
                fit: BoxFit.cover,
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
