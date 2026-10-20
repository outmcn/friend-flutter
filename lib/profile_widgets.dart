part of 'main.dart';


class _ExpandableProfileSignature extends StatefulWidget {
  const _ExpandableProfileSignature({required this.value});
  final String value;
  @override
  State<_ExpandableProfileSignature> createState() => _ExpandableProfileSignatureState();
}

class _ExpandableProfileSignatureState extends State<_ExpandableProfileSignature> {
  bool expanded = false;
  String get normalized => widget.value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  List<String> _wrap(String value) {
    final result = <String>[];
    for (final source in value.split('\n')) {
      final chars = source.characters.toList();
      if (chars.isEmpty) {
        result.add('');
      } else {
        for (var i = 0; i < chars.length; i += 20) {
          result.add(chars.skip(i).take(20).join());
        }
      }
    }
    return result;
  }
  @override
  Widget build(BuildContext context) {
    if (normalized.isEmpty) return const Text('设置个性签名');
    final lines = _wrap(normalized);
    final hasMore = lines.length > 3;
    final shown = expanded ? lines.join('\n') : lines.take(3).join('\n');
    if (expanded) {
      return RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          children: [
            TextSpan(text: shown),
            if (hasMore) TextSpan(text: '  收起', style: TextStyle(color: Theme.of(context).colorScheme.primary), recognizer: TapGestureRecognizer()..onTap = () => setState(() => expanded = false)),
          ],
        ),
      );
    }
    final visible = lines.take(3).toList();
    final tail = hasMore ? '...更多' : '';
    if (hasMore) {
      final last = visible.isEmpty ? '' : visible.removeLast();
      visible.add(last.characters.take((last.characters.length - tail.characters.length).clamp(0, 20)).toList().join() + tail);
    }
    return RichText(
      maxLines: 3,
      overflow: TextOverflow.clip,
      text: TextSpan(
        style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        children: [
          TextSpan(text: visible.join('\n')),
          if (hasMore) TextSpan(style: TextStyle(color: Theme.of(context).colorScheme.primary), recognizer: TapGestureRecognizer()..onTap = () => setState(() => expanded = true)),
        ],
      ),
    );
  }
}

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing ? Icons.pause : TIcons.sonic,
                size: 18,
                color: enabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 4),
              Text('声音', style: TextStyle(fontSize: 14, color: enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor)),
            ],
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
          _tab(context, 0, TIcons.highlight_1),
          if (!postsOnly) ...[
            _tab(context, 1, TIcons.bookmark),
            _tab(context, 2, TIcons.heart),
            _tab(context, 3, TIcons.lock_on),
          ],
        ],
      );

  Widget _tab(BuildContext context, int index, IconData icon) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(
                  selectedTab == index
                      ? (index == 0
                          ? TIcons.highlight_1_filled
                          : index == 1
                              ? TIcons.bookmark_filled
                              : index == 2
                              ? TIcons.heart_filled
                              : TIcons.lock_on)
                      : icon,
                  size: 24,
                  color: selectedTab == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).hintColor,
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
    this.onDelete,
    this.onTap,
  });
  final DDPost post;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _DiscoverProfileCard(
        post: post,
        onLike: onLike ?? () {},
        onFavorite: onFavorite ?? () {},
        onShare: onTap ?? () {},
        onDelete: onDelete,
        onReport: () {},
        onOpen: onTap ?? () {},
      );
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
              liked ? TIcons.heart_filled : TIcons.heart,
              color: liked ? Theme.of(context).colorScheme.primary : null,
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
    this.valueFontSize = 18,
    this.labelFontSize = 16,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final double valueFontSize;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    final child = Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        SizedBox(
          height: 22,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
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
      ),
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
