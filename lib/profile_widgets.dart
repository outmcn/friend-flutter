part of 'main.dart';

class _SonicProfileButton extends StatelessWidget {
  const _SonicProfileButton({
    required this.playing,
    required this.enabled,
    required this.onTap,
  });
  final bool playing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: enabled ? .14 : .07),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Icon(
            playing ? Icons.pause : TIcons.sonic,
            size: 18,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor,
          ),
        ),
      );
}

class _MyProfileIconTabs extends StatelessWidget {
  const _MyProfileIconTabs(
      {required this.selectedTab,
      required this.onSelect,
      this.postsOnly = false});
  final int selectedTab;
  final ValueChanged<int> onSelect;
  final bool postsOnly;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _tab(context, 0, Icons.blur_on),
          if (!postsOnly) ...[
            _tab(context, 1, Icons.bookmark_border),
            _tab(context, 2, Icons.favorite_border),
          ],
        ],
      );

  Widget _tab(BuildContext context, int index, IconData icon) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selectedTab == index
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).hintColor,
                ),
                const SizedBox(height: 7),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: selectedTab == index ? 28 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProfilePostFeed extends StatefulWidget {
  const _ProfilePostFeed({
    required this.posts,
    required this.onChanged,
    required this.onOpen,
  });
  final List<DDPost> posts;
  final VoidCallback onChanged;
  final ValueChanged<DDPost> onOpen;
  @override
  State<_ProfilePostFeed> createState() => _ProfilePostFeedState();
}

class _ProfilePostFeedState extends State<_ProfilePostFeed> {
  late List<DDPost> posts;
  @override
  void initState() {
    super.initState();
    posts = List<DDPost>.of(widget.posts);
  }

  @override
  void didUpdateWidget(covariant _ProfilePostFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.posts, widget.posts)) {
      posts = List<DDPost>.of(widget.posts);
    }
  }

  @override
  Widget build(BuildContext context) => MasonryGridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return _MyProfilePostCard(
            key: ValueKey(post.id),
            post: post,
            onTap: () => widget.onOpen(post),
          );
        },
      );
}

class _MyProfileGrid extends StatelessWidget {
  const _MyProfileGrid({required this.posts, this.onChanged});
  final List<DDPost> posts;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: Text('暂无内容')),
      );
    }
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _MyProfilePostCard(
          post: post,
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => DynamicDetailPage(postId: post.id),
              ),
            );
            if (changed == true) onChanged?.call();
          },
        );
      },
    );
  }
}

class _MyProfilePostCard extends StatelessWidget {
  const _MyProfilePostCard(
      {super.key, required this.post, required this.onTap});
  final DDPost post;
  final VoidCallback onTap;

  Widget _profileMedia({required String url, required bool thumbnail}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: thumbnail ? 400 : 300),
      child: _PermanentCachedImage(
        url: url,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = post.imageUrl?.trim();
    final video = post.videoUrl?.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null && image.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: _profileMedia(url: image, thumbnail: false),
                  ),
                )
              else if (video != null && video.isNotEmpty)
                InkWell(
                  onTap: onTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (post.thumbnailUrl != null &&
                          post.thumbnailUrl!.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: _profileMedia(
                              url: post.thumbnailUrl!,
                              thumbnail: true,
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 225,
                          child: ColoredBox(color: Colors.transparent),
                        ),
                      const Icon(
                        Icons.play_circle_outline,
                        size: 56,
                        color: Colors.white,
                      ),
                    ],
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      post.content.trim().isEmpty
                          ? '暂无动态内容'
                          : post.content.trim(),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (post.content.trim().isNotEmpty &&
                  ((image != null && image.isNotEmpty) ||
                      (video != null && video.isNotEmpty)))
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Text(
                    post.content.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(TIcons.thumb_up_1,
                            size: 16,
                            color: post.liked
                                ? Colors.red
                                : scheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text('${post.likes}'),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.bookmark_border,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.favorites}'),
                    const Spacer(),
                    Icon(Icons.visibility_outlined,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.views}'),
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

class _ProfileLikePill extends StatelessWidget {
  const _ProfileLikePill({
    required this.liked,
    required this.onTap,
  });
  final bool liked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.pinkAccent : null,
              size: 24,
            ),
          ),
        ),
      );
}

class _InlineProfileStat extends StatelessWidget {
  const _InlineProfileStat({
    required this.label,
    required this.value,
    this.onTap,
    this.valueFontSize = 16,
    this.labelFontSize = 13,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final double valueFontSize;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: valueFontSize,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: .65),
            fontSize: labelFontSize,
          ),
        ),
      ],
    );
    return onTap == null
        ? child
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: child,
            ),
          );
  }
}
