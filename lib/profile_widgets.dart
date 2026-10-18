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
    this.onOpen,
  });
  final List<DDPost> posts;
  final VoidCallback onChanged;
  final ValueChanged<DDPost>? onOpen;
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
            onTap: widget.onOpen == null ? () {} : () => widget.onOpen!(post),
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
              if (widget.onEmptyAction != null && widget.emptyActionLabel != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: widget.onEmptyAction, child: Text(widget.emptyActionLabel!)),
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
          onLike: () {},
          onFavorite: () {},
          onShare: () {},
          onReport: () {},
          onOpen: () {},
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => DynamicDetailPage(
                  postId: post.id,
                  initialPost: post,
                  cardKey: mediaKey,
                ),
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
    this.onLike,
    this.onFavorite,
    this.onSendToFriend,
    this.onShare,
    this.onDirectChat,
    this.onFollow,
    this.onGift,
    this.onReport,
    this.onOpen,
    this.onTap,
  });

  final DDPost post;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final Future<void> Function(String peerId)? onSendToFriend;
  final VoidCallback? onDirectChat;
  final VoidCallback? onFollow;
  final VoidCallback? onGift;
  final VoidCallback? onReport;
  final VoidCallback? onOpen;
  final VoidCallback? onTap;

  Widget _media({required String url, required bool thumbnail}) {
    return _DiscoverMediaImage(url: url);
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
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: Text('更多操作', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ShareAction(label: '置顶', icon: Icons.push_pin_outlined, onTap: () => Navigator.pop(sheetContext)),
                  _ShareAction(label: '权限', icon: TIcons.browse, onTap: () => _showVisibility(sheetContext)),
                  _ShareAction(label: '私密', icon: Icons.lock_outline, onTap: () => _setPrivate(sheetContext)),
                  _ShareAction(label: '删除', icon: Icons.delete_outline, onTap: () => _deleteOwnPost(sheetContext)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisibility(BuildContext context) {
    Navigator.pop(context);
    _showTopNotice(context, const Text('当前权限：所有人可见'));
  }

  void _setPrivate(BuildContext context) {
    Navigator.pop(context);
    _showTopNotice(context, const Text('已设为仅自己可见'));
  }

  void _deleteOwnPost(BuildContext context) {
    Navigator.pop(context);
    onOpen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = (post.imageUrl?.trim().isNotEmpty == true) ||
        (post.videoUrl?.trim().isNotEmpty == true);
    return InkWell(
      onTap: onTap ?? onOpen,
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(post.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ),
                                if (post.distanceKm != null &&
                                    post.distanceKm! <= 30)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0x2234C759),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        child: Text(
                                          '${post.distanceKm!.toStringAsFixed(2)}km',
                                          style: const TextStyle(
                                            color: Color(0xFF34C759),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${_formatDiscoverDate(post.createdAt)}${(post.authorCity ?? '').trim().isNotEmpty ? ' · ${post.authorCity!.trim()}' : ''}',
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
                        tooltip: '分享',
                        onPressed: () => _showDiscoverMore(context),
                        icon: const Icon(TIcons.share_1),
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
                      child: _DiscoverPostContent(
                        text: post.content.trim(),
                        maxLines: hasMedia ? 3 : 10,
                      ),
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
                      _action(
                        context: context,
                        icon: post.liked ? TIcons.heart_filled : TIcons.heart,
                        label: '${post.likes}',
                        onTap: onLike ?? () {},
                        active: post.liked,
                      ),
                      _action(
                        context: context,
                        icon: post.favorited ? Icons.favorite : Icons.favorite_border,
                        label: '${post.favorites}',
                        onTap: onFavorite ?? () {},
                        active: post.favorited,
                      ),
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
