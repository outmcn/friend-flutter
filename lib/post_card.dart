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
                icon: Icon(TIcons.thumb_up_1),
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
                    icon: Icon(TIcons.thumb_up_1),
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
    // ignore: unused_element_parameter
    super.key,
    required this.post,
    required this.onLike,
    required this.onOpen,
  });
  final DDPost post;
  final VoidCallback onLike;
  final VoidCallback onOpen;

  // ignore: unused_element
  double _mediaRatio({required bool thumbnail}) {
    final width = thumbnail ? post.thumbnailWidth : post.imageWidth;
    final height = thumbnail ? post.thumbnailHeight : post.imageHeight;
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 4 / 3;
  }

  Widget _stableMedia({required String url, required bool thumbnail}) =>
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: thumbnail ? 400 : 300),
        child: _PermanentCachedImage(
          url: url,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final image = post.imageUrl?.trim();
    final video = post.videoUrl?.trim();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null && image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _stableMedia(url: image, thumbnail: false),
                )
              else if (video != null && video.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      post.thumbnailUrl?.isNotEmpty == true
                          ? _stableMedia(
                              url: post.thumbnailUrl!,
                              thumbnail: true,
                            )
                          : const SizedBox(
                              height: 96,
                              child: ColoredBox(color: Colors.transparent),
                            ),
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 96),
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff6556d9), Color(0xffdf76b8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      post.content.trim(),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (post.content.trim().isNotEmpty &&
                  (image != null && image.isNotEmpty ||
                      video != null && video.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                  child: Text(
                    post.content.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, height: 1.35),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    ClipOval(
                      child: post.avatar.trim().isEmpty
                          ? const Icon(Icons.person_outline, size: 22)
                          : SizedBox(
                              width: 22,
                              height: 22,
                              child: _PermanentCachedImage(
                                url: post.avatar,
                                width: 22,
                                height: 22,
                                fit: BoxFit.cover,
                                placeholder:
                                    const Icon(Icons.person_outline, size: 22),
                              ),
                            ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        post.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onLike,
                      iconSize: 17,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 24, height: 24),
                      color: post.liked ? Colors.red : null,
                      icon: Icon(TIcons.thumb_up_1),
                    ),
                    Text('${post.likes}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
