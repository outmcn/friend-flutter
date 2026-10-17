part of 'main.dart';


String _formatProfilePostDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || raw.trim().isEmpty) return '2026.01.01';
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

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

class _MyProfileGrid extends StatefulWidget {
  const _MyProfileGrid({
    required this.posts,
    this.onChanged,
    this.emptyLabel = '暂无内容',
    this.onEmptyAction,
    this.emptyActionLabel,
  });
  final List<DDPost> posts;
  final VoidCallback? onChanged;
  final String emptyLabel;
  final VoidCallback? onEmptyAction;
  final String? emptyActionLabel;

  @override
  State<_MyProfileGrid> createState() => _MyProfileGridState();
}

class _MyProfileGridState extends State<_MyProfileGrid> {
  final mediaKeys = <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emptyLabel),
              if (widget.onEmptyAction != null &&
                  widget.emptyActionLabel != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: widget.onEmptyAction,
                  child: Text(widget.emptyActionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final mediaKey = mediaKeys.putIfAbsent(post.id, GlobalKey.new);
        return _MyProfilePostCard(
          post: post,
          mediaKey: mediaKey,
          onTap: () async {
            final box =
                mediaKey.currentContext?.findRenderObject() as RenderBox?;
            final topLeft = box?.localToGlobal(Offset.zero);
            final initialRect =
                box == null || topLeft == null ? null : topLeft & box.size;
            final changed = await Navigator.push<bool>(
              context,
              PageRouteBuilder<bool>(
                opaque: false,
                barrierColor: Colors.transparent,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => DynamicDetailPage(
                  postId: post.id,
                  initialPost: post,
                  initialRect: initialRect,
                  mediaKey: mediaKey,
                ),
                transitionsBuilder: (_, __, ___, child) => child,
              ),
            );
            if (changed == true) widget.onChanged?.call();
          },
        );
      },
    );
  }
}

class _MyProfilePostCard extends StatelessWidget {
  const _MyProfilePostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.mediaKey,
  });
  final DDPost post;
  final VoidCallback onTap;
  final GlobalKey? mediaKey;

  Widget _media(String url, {bool video = false}) {
    final width = video ? post.thumbnailWidth : post.imageWidth;
    final height = video ? post.thumbnailHeight : post.imageHeight;
    final aspect = width != null && height != null && width > 0 && height > 0
        ? width / height
        : 4 / 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final naturalHeight = maxWidth / aspect;
        final actualHeight = naturalHeight.clamp(0.0, 400.0).toDouble();
        final actualWidth = naturalHeight > 400
            ? actualHeight * aspect
            : maxWidth;
        return Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: actualWidth,
              height: actualHeight,
              child: _PermanentCachedImage(
                url: url,
                width: actualWidth,
                height: actualHeight,
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

  @override
  Widget build(BuildContext context) {
    final image = post.imageUrl?.trim();
    final video = post.videoUrl?.trim();
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatProfilePostDate(post.createdAt),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                Icon(Icons.visibility_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${post.views}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                const Icon(TIcons.more, size: 20),
              ],
            ),
            if (post.content.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: Text(post.content.trim(),
                    style: const TextStyle(fontSize: 18, height: 1.4)),
              ),
            if (image != null && image.isNotEmpty)
              _media(image)
            else if (video != null && video.isNotEmpty)
              Stack(
                alignment: Alignment.center,
                children: [
                  _media(post.thumbnailUrl?.trim().isNotEmpty == true
                      ? post.thumbnailUrl!.trim()
                      : video),
                  const Icon(Icons.play_circle_outline,
                      size: 48, color: Colors.white),
                ],
              ),
          ],
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
        SizedBox(
          height: 22,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: valueFontSize,
            ),
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
              child: SizedBox(
                height: 48,
                child: child,
              ),
            ),
          );
  }
}
