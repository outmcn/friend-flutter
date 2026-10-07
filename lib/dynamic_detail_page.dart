part of 'main.dart';

class DynamicDetailPage extends StatefulWidget {
  const DynamicDetailPage({
    super.key,
    required this.postId,
    this.focusComment = false,
    this.initialPost,
    this.onChanged,
  });
  final int postId;
  final DDPost? initialPost;
  final ValueChanged<DDPost>? onChanged;
  final bool focusComment;
  @override
  State<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DynamicDetailPageState extends State<DynamicDetailPage> {
  final DDPostService service = DDPostService();
  final commentController = TextEditingController();
  final commentFocusNode = FocusNode();
  DDComment? replyingTo;
  DDPost? post;
  List<DDComment> comments = const [];
  bool loading = true;
  bool deleting = false;
  bool submitting = false;
  bool refreshing = false;
  final pendingActions = <String>{};
  final scroll = ScrollController();
  // 默认只显示每个父评论的 1 条直接回复，点击“显示更多”后每次增加 3 条。
  int visibleRootCount = 30;
  final Map<int, int> visibleReplyCounts = <int, int>{};
  final Set<int> expandedThirdLevelParents = <int>{};
  String? error;
  int? currentUserId;
  bool ownerResolved = false;
  bool get isOwner =>
      ownerResolved && post?.userId != null && currentUserId == post!.userId;

  @override
  void initState() {
    super.initState();
    post = widget.initialPost;
    load();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(commentFocusNode);
      });
    }
  }

  @override
  void dispose() {
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
        expandedThirdLevelParents.clear();
      });
    }
    return value;
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
        () async {
          if (cached != null) {
            try {
              _publish(await service.resolvePostMedia(t, cached));
            } catch (_) {}
          }
          final fresh = await service.fetchPost(t, widget.postId);
          final resolved = await service.resolvePostMedia(t, fresh);
          _publish(resolved);
          await _saveDetailCache(fresh);
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
      final visible =
          depth >= 2 && !expandedThirdLevelParents.contains(parent.id)
              ? 0
              : (visibleReplyCounts[parent.id] ?? 1);
      for (final reply in replies.take(visible)) {
        result.add(Padding(
          padding: EdgeInsets.only(left: depth >= 2 ? 84.0 : 42.0),
          child: _commentTile(
            reply,
            depth: depth,
            // 只有回复三级评论时显示“某某 回复 某某”。
            replyTo: depth >= 2 ? parent.nickname : null,
          ),
        ));
        appendReplies(reply, depth + 1);
      }
      if (replies.isNotEmpty &&
          ((depth >= 2 && !expandedThirdLevelParents.contains(parent.id)) ||
              visible < replies.length)) {
        result.add(Padding(
          padding: EdgeInsets.only(left: depth >= 2 ? 84.0 : 42.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                if (depth >= 2) {
                  expandedThirdLevelParents.add(parent.id);
                  visibleReplyCounts[parent.id] = replies.length;
                } else {
                  visibleReplyCounts[parent.id] = visible + 3;
                }
              }),
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
              leading: Icon(
                  comment.liked ? Icons.thumb_up : Icons.thumb_up_outlined),
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
        ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('举报已提交')),
          );
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
              child: const CircleAvatar(
                radius: 20,
                child: Icon(Icons.person_outline, size: 18),
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
                      if (comment.city.trim().isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _ProfileTag(text: comment.city.trim()),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(comment.content),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _toggleCommentLike(comment),
                            child: Icon(
                              comment.liked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              size: 16,
                              color: comment.liked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).hintColor,
                            ),
                          ),
                          Text('${comment.likes}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatDDTime(comment.createdAt),
                    style: const TextStyle(fontSize: 11),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('举报已提交')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('动态内容已复制，可粘贴分享')),
        );
      }
    }
  }

  Widget _composer(DDPost item) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              8, 8, 8, 8 + MediaQuery.of(context).viewInsets.bottom),
          child: Row(
            children: [
              _DetailAction(
                icon: TIcons.thumb_up_1,
                label: '${item.likes}',
                active: item.liked,
                onTap: _toggleLike,
              ),
              _DetailAction(
                icon: TIcons.bookmark,
                label: '${item.favorites}',
                active: item.favorited,
                onTap: _toggleFavorite,
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

  @override
  Widget build(BuildContext context) {
    final item = post;
    return Scaffold(
      appBar: AppBar(
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
            onPressed:
                item == null || deleting ? null : () => _openShareMenu(item),
            icon: Icon(TIcons.share_1),
          ),
        ],
      ),
      body: item == null && loading
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(item.content,
                            style: const TextStyle(fontSize: 18, height: 1.5)),
                      ),
                    const SizedBox(height: 16),
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text('评论',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(width: 6),
                          Text(
                            '${item.comments}',
                            style: Theme.of(context).textTheme.titleMedium,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: _buildCommentTree(comments),
                        ),
                      ),
                  ],
                ],
              )),
      bottomNavigationBar: item == null ? null : _composer(item),
    );
  }
}
