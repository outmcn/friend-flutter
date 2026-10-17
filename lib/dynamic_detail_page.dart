part of 'main.dart';

class DynamicDetailPage extends StatefulWidget {
  const DynamicDetailPage({
    super.key,
    required this.postId,
    this.focusComment = false,
    this.initialPost,
    this.initialRect,
    this.mediaKey,
    this.cardKey,
    this.onChanged,
  });
  final int postId;
  final GlobalKey? mediaKey;
  final DDPost? initialPost;
  final Rect? initialRect;
  final GlobalKey? cardKey;
  final ValueChanged<DDPost>? onChanged;
  final bool focusComment;
  @override
  State<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DetailChromeClipper extends CustomClipper<Rect> {
  const _DetailChromeClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) {
    // Reverse transition: remove AppBar, bottom composer and comments first;
    // the media/text content then follows the source-image straight-line scale.
    final chromeT = (progress * 2.0 - 1.0).clamp(0.0, 1.0);
    final topInset = kToolbarHeight * chromeT;
    final bottomInset = 80.0 * chromeT;
    final top = topInset.clamp(0.0, size.height);
    final bottom = (size.height - bottomInset).clamp(top, size.height);
    return Rect.fromLTRB(0, top, size.width, bottom);
  }

  @override
  bool shouldReclip(_DetailChromeClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _DynamicDetailPageState extends State<DynamicDetailPage>
    with SingleTickerProviderStateMixin {
  final DDPostService service = DDPostService();
  final commentController = TextEditingController();
  final commentFocusNode = FocusNode();
  DDComment? replyingTo;
  DDPost? post;
  List<DDComment> comments = const [];
  List<Map<String, dynamic>> receivedGifts = const [];
  int dynamicCharmCoins = 0;
  bool loading = true;
  bool deleting = false;
  bool submitting = false;
  bool giftSubmitting = false;
  bool refreshing = false;
  final pendingActions = <String>{};
  final scroll = ScrollController();
  late final AnimationController _rectController;
  double _startScale = 0.92;
  Offset _startOffset = Offset.zero;
  bool _dragging = false;
  bool _closing = false;
  bool _geometryReady = false;

  void _onDragStart(DragStartDetails details) {
    _dragging = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    return;
    final width = MediaQuery.sizeOf(context).width;
    setState(() {
      final value =
          (_rectController.value - details.delta.dx / width).clamp(0.0, 1.0);
      _rectController.value = value;
    });
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    return;
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final shouldClose = _rectController.value < .65 || velocity > 500;
    if (!shouldClose) {
      await _rectController.animateTo(
        1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
      return;
    }
    _closing = true;
    final liveBox =
        widget.mediaKey?.currentContext?.findRenderObject() as RenderBox?;
    final liveTopLeft = liveBox?.localToGlobal(Offset.zero);
    final liveRect = liveBox == null || liveTopLeft == null
        ? null
        : liveTopLeft & liveBox.size;
    if (liveRect != null && liveRect.width > 0) {
      final screen = MediaQuery.sizeOf(context);
      _startScale = (liveRect.width / screen.width).clamp(0.05, 1.0).toDouble();
      _startOffset =
          liveRect.center - Offset(screen.width / 2, screen.height / 2);
    }
    await _rectController.animateTo(
      0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.linear,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _closeWithTransition() async {
    if (mounted) Navigator.pop(context);
  }

  int visibleRootCount = 30;
  final Map<int, int> visibleReplyCounts = <int, int>{};
  String? error;
  int? currentUserId;
  bool ownerResolved = false;
  bool get isOwner =>
      ownerResolved && post?.userId != null && currentUserId == post!.userId;

  @override
  void initState() {
    super.initState();
    _rectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    post = widget.initialPost;
    final screen = MediaQuery.sizeOf(context);
    final rect = widget.initialRect;
    if (rect != null && rect.width > 0) {
      final scaleX = rect.width / screen.width;
      final scaleY = rect.height / screen.height;
      _startScale = scaleX < scaleY ? scaleX : scaleY;
      final screenCenter = Offset(screen.width / 2, screen.height / 2);
      _startOffset = rect.center - screenCenter;
    }
    if (widget.initialRect == null) {
      _startScale = 1;
      _startOffset = Offset.zero;
    }
    _geometryReady = true;
    load();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(commentFocusNode);
      });
    }
  }

  @override
  void dispose() {
    _rectController.dispose();
    scroll.dispose();
    commentFocusNode.dispose();
    commentController.dispose();
    service.dispose();
    super.dispose();
  }

  Future<String> token() async {
    final p = await SharedPreferences.getInstance();
    final value = p.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  String _detailCacheKey(int postId) => 'dd.detail.v2.$currentAccount.$postId';
  String currentAccount = '';

  Future<DDPost?> _readDetailCache(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_detailCacheKey(postId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return DDPost.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
        preserveMediaKeys: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDetailCache(DDPost value) async {
    final prefs = await SharedPreferences.getInstance();
    // 详情缓存只保留业务数据；签名 URL 会过期，不能作为长期媒体身份保存。
    final json = value.toJson();
    for (final key in <String>[
      'avatar',
      'imageUrl',
      'videoUrl',
      'thumbnailUrl'
    ]) {
      final raw = json[key];
      if (raw is String && raw.startsWith('http')) {
        json[key] = DDPostService.mediaKey(raw);
      }
    }
    await prefs.setString(_detailCacheKey(value.id), jsonEncode(json));
  }

  Future<List<DDComment>> _loadComments(String t) async {
    final value = await service.fetchComments(t, widget.postId);
    if (mounted) {
      setState(() {
        comments = value;
        visibleRootCount = 30;
        visibleReplyCounts.clear();
      });
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> _loadReceivedGifts(String t) async {
    final value = await service.fetchObjectList(
      t,
      '/api/posts/${widget.postId}/gifts',
      'gifts',
    );
    final totals = <String, Map<String, dynamic>>{};
    for (final gift in value) {
      final key =
          '${gift['gift_item_id'] ?? gift['giftItemId'] ?? gift['name']}';
      final current = totals[key];
      final quantity = int.tryParse('${gift['quantity'] ?? 1}') ?? 1;
      if (current == null) {
        totals[key] = {
          ...gift,
          'quantity': quantity,
        };
      } else {
        current['quantity'] = (current['quantity'] as int) + quantity;
      }
    }
    final aggregated = totals.values.toList();
    final charm = value.fold<num>(
      0,
      (sum, gift) =>
          sum +
          (num.tryParse('${gift['coin_amount'] ?? gift['coinAmount'] ?? 0}') ??
              0),
    );
    if (mounted) {
      setState(() {
        receivedGifts = aggregated;
        dynamicCharmCoins = charm.toInt();
      });
    }
    return aggregated;
  }

  void _publish(DDPost value) {
    if (!mounted) return;
    setState(() => post = value);
    widget.onChanged?.call(value);
  }

  Future<void> load() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final t = await token();
      currentAccount = base64Url.encode(utf8.encode(t));
      final cached = post ?? await _readDetailCache(widget.postId);
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          post = cached;
          loading = false;
        });
      }
      // 身份、评论与动态各自加载，任何一路失败都不抹掉已展示内容。
      await Future.wait([
        () async {
          final me = await service.fetchMe(t);
          if (mounted) {
            setState(() {
              currentUserId = _intValue(me['id']);
              ownerResolved = true;
            });
          }
        }(),
        _loadComments(t),
        _loadReceivedGifts(t),
        () async {
          if (cached != null) {
            try {
              _publish(await service.resolvePostMedia(t, cached));
            } catch (_) {}
          }
          final fresh = await service.fetchPost(t, widget.postId);
          final resolved = await service.resolvePostMedia(t, fresh);
          final current = post;
          final merged = current == null
              ? resolved
              : resolved.copyWith(
                  nickname: resolved.nickname.trim().isEmpty
                      ? current.nickname
                      : resolved.nickname,
                  avatar: resolved.avatar.trim().isEmpty
                      ? current.avatar
                      : resolved.avatar,
                );
          _publish(merged);
          await _saveDetailCache(merged);
        }(),
      ]);
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submitComment() async {
    final value = commentController.text.trim();
    if (value.isEmpty || submitting) return;
    setState(() => submitting = true);
    try {
      await service.createComment(
        token: await token(),
        postId: widget.postId,
        content: value,
        parentId: replyingTo?.id,
      );
      if (!mounted) return;
      commentController.clear();
      if (mounted) setState(() => replyingTo = null);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  List<Widget> _buildCommentTree(List<DDComment> source) {
    final repliesByParent = <int, List<DDComment>>{};
    for (final comment in source.where((c) => c.parentId != null)) {
      repliesByParent.putIfAbsent(comment.parentId!, () => []).add(comment);
    }
    final result = <Widget>[];
    final roots = source.where((c) => c.parentId == null).toList();

    void appendReplies(DDComment parent, int depth) {
      final replies = repliesByParent[parent.id] ?? const <DDComment>[];
      final visible = visibleReplyCounts[parent.id] ?? 1;
      for (final reply in replies.take(visible)) {
        result.add(Padding(
          padding: const EdgeInsets.only(left: 42),
          child: _commentTile(
            reply,
            depth: depth,
            replyTo: null,
          ),
        ));
      }
      if (replies.isNotEmpty && visible < replies.length) {
        result.add(Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => visibleReplyCounts[parent.id] = visible + 3),
              child: const Text('显示更多'),
            ),
          ),
        ));
      }
    }

    for (final root in roots.take(visibleRootCount)) {
      result.add(_commentTile(root, depth: 0, replyTo: null));
      appendReplies(root, 1);
    }
    if (visibleRootCount < roots.length) {
      result.add(Padding(
        padding: const EdgeInsets.only(left: 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => visibleRootCount += 30),
            child: const Text('显示更多'),
          ),
        ),
      ));
    }
    return result;
  }

  Future<void> _toggleCommentLike(DDComment comment) async {
    try {
      final liked = await service.toggleCommentLike(await token(), comment.id);
      final index = comments.indexWhere((item) => item.id == comment.id);
      if (index == -1 || !mounted) return;
      setState(() {
        comments[index] = DDComment(
          id: comment.id,
          userId: comment.userId,
          parentId: comment.parentId,
          nickname: comment.nickname,
          content: comment.content,
          createdAt: comment.createdAt,
          likes:
              comment.likes + (liked == comment.liked ? 0 : (liked ? 1 : -1)),
          liked: liked,
          city: comment.city,
          avatar: comment.avatar,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _commentMenu(DDComment comment) async {
    final isMine = currentUserId != null && comment.userId == currentUserId;
    final canDelete = isMine || isOwner;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(TIcons.thumb_up_2),
              title: const Text('点赞'),
              onTap: () => Navigator.pop(context, 'like'),
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('举报'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == 'like') {
      await _toggleCommentLike(comment);
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: comment.content));
      if (mounted) {
        _showTopNotice(
          context,
          const SnackBar(content: Text('已复制')),
        );
      }
    } else if (action == 'delete') {
      try {
        await service.deleteComment(await token(), comment.id);
        await load();
      } catch (e) {
        if (mounted) {
          setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        }
      }
    } else if (action == 'report') {
      if (!mounted) return;
      final reason = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _ReportPostPageState.reportReasons
                .map((item) => ListTile(
                      title: Text(item),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, item),
                    ))
                .toList(),
          ),
        ),
      );
      if (reason == null) return;
      try {
        await service.reportComment(
          token: await token(),
          commentId: comment.id,
          reason: reason,
        );
        if (mounted) {
          _showTopNotice(context, const Text('评论举报已提交'));
          await _askBlockAfterReport(comment.userId);
        }
      } catch (e) {
        if (mounted) {
          setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  Widget _commentTile(
    DDComment comment, {
    required int depth,
    required String? replyTo,
  }) {
    final isMine = currentUserId != null && comment.userId == currentUserId;
    final isPostAuthor = post?.userId != null && comment.userId == post!.userId;
    final displayName = isMine ? '我' : comment.nickname;
    final displayColor = isMine
        ? Colors.red
        : isPostAuthor
            ? Colors.green
            : null;
    return InkWell(
      onTap: () {
        setState(() => replyingTo = comment);
        FocusScope.of(context).requestFocus(commentFocusNode);
      },
      onLongPress: () => _commentMenu(comment),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: comment.userId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtherProfilePage(
                            userId: comment.userId,
                            name: comment.nickname,
                          ),
                        ),
                      ),
              borderRadius: BorderRadius.circular(20),
              child: _PermanentCachedImage(
                url: comment.avatar.trim(),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: const Icon(Icons.person_outline),
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
                      Text(
                        depth >= 2
                            ? '$displayName 回复 ${replyTo ?? (isPostAuthor ? '作者' : comment.nickname)}'
                            : displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: displayColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(comment.content),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        formatDDTime(comment.createdAt),
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (comment.city.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          comment.city.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '回复',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _toggleCommentLike(comment),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              TIcons.thumb_up_2,
                              size: 16,
                              color: comment.liked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).hintColor,
                            ),
                            const SizedBox(width: 4),
                            Text('${comment.likes}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
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

  Future<void> _mutate(
      String action, Future<DDPost> Function(String, DDPost) run) async {
    if (post == null || refreshing || !pendingActions.add(action)) return;
    try {
      final next = await run(await token(), post!);
      _publish(next);
      await _saveDetailCache(next);
      await DDPostService.clearProfileTabCaches();
    } catch (e) {
      if (mounted) {
        _showTopNotice(context, SnackBar(content: Text('$e')));
      }
    } finally {
      pendingActions.remove(action);
    }
  }

  Future<void> _toggleLike() => _mutate('like', (token, item) async {
        await service.toggleLike(token, item.id);
        return post!.copyWith(
            liked: !item.liked, likes: item.likes + (item.liked ? -1 : 1));
      });

  Future<void> _toggleFavorite() => _mutate('favorite', (token, item) async {
        await service.toggleFavorite(token, item.id);
        return post!.copyWith(
            favorited: !item.favorited,
            favorites: item.favorites + (item.favorited ? -1 : 1));
      });

  Future<void> _delete() async {
    if (deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除动态'),
        content: const Text('删除后动态及其媒体文件将无法恢复，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      setState(() => deleting = true);
      await service.deletePost(await token(), widget.postId);
      await DDPostService.clearProfileTabCaches();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  Future<void> _askBlockAfterReport(int? userId) async {
    if (!mounted || userId == null || userId == currentUserId) return;
    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('举报成功'),
        content: const Text('是否同时拉黑对方？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('暂不拉黑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('拉黑对方'),
          ),
        ],
      ),
    );
    if (shouldBlock != true || !mounted) return;
    final blockService = DDPostService();
    try {
      await blockService.toggleUserBlock(await token(), userId);
      if (mounted) {
        _showTopNotice(context, const Text('已举报并拉黑对方'));
      }
    } finally {
      blockService.dispose();
    }
  }

  Future<void> _openReportPage() async {
    if (isOwner) return;
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPostPage(
          postId: widget.postId,
          service: service,
          token: token,
        ),
      ),
    );
    if (submitted == true && mounted) {
      _showTopNotice(context, const Text('举报已提交'));
      await _askBlockAfterReport(post?.userId);
    }
  }

  Future<void> _openShareMenu(DDPost item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('分享动态'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('举报动态'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除动态'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'report') {
      await _openReportPage();
    } else if (action == 'delete') {
      await _delete();
    } else if (action == 'share') {
      await Clipboard.setData(
        ClipboardData(text: '动态 ${item.id}：${item.content}'),
      );
      if (mounted) {
        _showTopNotice(
          context,
          const SnackBar(content: Text('动态内容已复制，可粘贴分享')),
        );
      }
    }
  }

  Future<void> _openGiftMenu() async {
    try {
      final gifts = await service.fetchGiftItems(await token(), scope: 'post');
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: const Text(
                  '动态礼物',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ...gifts.map((gift) => ListTile(
                    leading: Text('${gift['icon'] ?? '🎁'}',
                        style: const TextStyle(fontSize: 24)),
                    title: Text('${gift['name'] ?? '礼物'}'),
                    subtitle: Text('${gift['coin_price'] ?? 0} 金币'),
                    onTap: giftSubmitting
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            try {
                              if (mounted) {
                                setState(() => giftSubmitting = true);
                              }
                              await service.sendPostGift(
                                  token: await token(),
                                  postId: widget.postId,
                                  giftId: int.parse('${gift['id']}'));
                              if (!mounted) return;
                              await _loadReceivedGifts(await token());
                              if (!mounted) return;
                              _showTopNotice(context, const Text('送礼成功'));
                            } catch (e) {
                              if (mounted) {
                                _showTopNotice(context, Text('$e'));
                              }
                            } finally {
                              if (mounted) {
                                setState(() => giftSubmitting = false);
                              }
                            }
                          },
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showTopNotice(context, SnackBar(content: Text('$e')));
    }
  }

  Widget _composer(DDPost item) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              8, 8, 8, 8 + MediaQuery.of(context).viewInsets.bottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DetailAction(
                icon: item.liked ? TIcons.heart_filled : TIcons.heart,
                label: '${item.likes}',
                active: item.liked,
                onTap: _toggleLike,
              ),
              _DetailAction(
                icon: item.favorited ? TIcons.star_1_filled : TIcons.star_1,
                label: '${item.favorites}',
                active: item.favorited,
                onTap: _toggleFavorite,
              ),
              IconButton(
                tooltip: '送礼',
                onPressed: _openGiftMenu,
                icon: const Icon(Icons.card_giftcard_outlined),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: commentController,
                  focusNode: commentFocusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => submitComment(),
                  decoration: InputDecoration(
                    hintText: replyingTo == null
                        ? '写下你的评论…'
                        : '回复 ${replyingTo!.nickname}…',
                    prefixIcon: replyingTo == null
                        ? null
                        : IconButton(
                            tooltip: '取消回复',
                            onPressed: () => setState(() => replyingTo = null),
                            icon: const Icon(Icons.close)),
                    suffixIcon: IconButton(
                        onPressed: submitting ? null : submitComment,
                        icon: const Icon(Icons.send)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _detailPayload(Widget child) {
    final item = post;
    if (item == null) return child;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.imageUrl?.isNotEmpty == true)
            _PostImageHolder(url: item.imageUrl!, unlimitedHeight: true)
          else if (item.videoUrl?.isNotEmpty == true)
            _NetworkVideoPreview(
              url: item.videoUrl!,
              thumbnailUrl: item.thumbnailUrl,
              unlimitedHeight: true,
            ),
          if (item.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(item.content,
                  style: const TextStyle(fontSize: 18, height: 1.5)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_geometryReady) {
      return const SizedBox.expand();
    }
    final item = post;
    return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: kToolbarHeight,
              titleSpacing: 16,
              automaticallyImplyLeading: false,
              leadingWidth: 56,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  tooltip: '返回',
                  onPressed: _closeWithTransition,
                  icon: const Icon(TIcons.rollback),
                ),
              ),
              title: item == null
                  ? const Text('动态详情')
                  : InkWell(
                      onTap: item.userId == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OtherProfilePage(
                                    userId: item.userId,
                                    name: item.nickname,
                                  ),
                                ),
                              ),
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: _PermanentCachedImage(
                                url: item.avatar,
                                fit: BoxFit.cover,
                                placeholder: const Icon(Icons.person_outline),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(item.nickname,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
              actions: [
                IconButton(
                  tooltip: '分享',
                  onPressed: item == null || deleting
                      ? null
                      : () => _openShareMenu(item),
                  icon: Icon(TIcons.share_1),
                ),
              ],
            ),
            body: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: item == null && loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        controller: scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          if (error != null)
                            _PageErrorState(
                                title: '加载失败', subtitle: error!, onRetry: load),
                          if (item != null) ...[
                            if (item.imageUrl?.isNotEmpty == true) ...[
                              _PostImageHolder(
                                url: item.imageUrl!,
                                unlimitedHeight: true,
                              ),
                            ],
                            if (item.videoUrl?.isNotEmpty == true) ...[
                              _NetworkVideoPreview(
                                url: item.videoUrl!,
                                thumbnailUrl: item.thumbnailUrl,
                                unlimitedHeight: true,
                              ),
                            ],
                            if (item.content.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                child: Text(item.content,
                                    style: const TextStyle(
                                        fontSize: 18, height: 1.5)),
                              ),
                            if (receivedGifts.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: receivedGifts
                                          .map((gift) => Chip(
                                                avatar: Text(
                                                    '${gift['icon'] ?? '🎁'}'),
                                                label: Text(
                                                    '${gift['name'] ?? '礼物'} ×${gift['quantity'] ?? 1}'),
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      formatDDTime(item.createdAt),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Text(
                                  formatDDTime(item.createdAt),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 1),
                            const Divider(height: 32),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Text('评论',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item.comments}条',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                            if (comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                                child: Text('暂无评论'),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                                child: Column(
                                  children: _buildCommentTree(comments),
                                ),
                              ),
                          ],
                        ],
                      )),
            ),
            bottomNavigationBar: item == null ? null : _composer(item),
          ),
    );
  }
}
