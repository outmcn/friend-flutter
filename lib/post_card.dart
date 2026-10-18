part of 'main.dart';

class _DiscoverPostContent extends StatefulWidget {
  const _DiscoverPostContent({required this.text, required this.maxLines});
  final String text;
  final int maxLines;

  @override
  State<_DiscoverPostContent> createState() => _DiscoverPostContentState();
}

class _DiscoverPostContentState extends State<_DiscoverPostContent> {
  bool expanded = false;

  static const bodyStyle = TextStyle(
    fontSize: 16,
    height: 1.4,
    textBaseline: TextBaseline.alphabetic,
  );
  static const actionStyle = TextStyle(
    color: Color(0xFF1677FF),
    fontSize: 16,
    height: 1.4,
    textBaseline: TextBaseline.alphabetic,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final bodyStyle = TextStyle(
          fontSize: 16,
          height: 1.4,
          textBaseline: TextBaseline.alphabetic,
          color: Theme.of(context).colorScheme.onSurface,
        );
        final full = TextPainter(
          text: TextSpan(text: widget.text, style: bodyStyle),
          textDirection: direction,
        )..layout(maxWidth: constraints.maxWidth);
        final metrics = full.computeLineMetrics();
        final truncated = metrics.length > widget.maxLines;
        if (!truncated) {
          return RichText(
            textAlign: TextAlign.left,
            softWrap: true,
            text: TextSpan(text: widget.text, style: bodyStyle),
          );
        }
        if (expanded) {
          return RichText(
            textAlign: TextAlign.left,
            softWrap: true,
            text: TextSpan(
              children: [
                TextSpan(text: widget.text, style: bodyStyle),
                TextSpan(
                  text: '  收起',
                  style: actionStyle,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => setState(() => expanded = false),
                ),
              ],
            ),
          );
        }
        final action = TextPainter(
          text: TextSpan(text: '展开全部', style: bodyStyle),
          textDirection: direction,
        )..layout();
        var low = 0;
        var high = widget.text.length;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          final probe = TextPainter(
            text: TextSpan(
              text: '${widget.text.substring(0, mid)}… 展开全部',
              style: bodyStyle,
            ),
            textDirection: direction,
            maxLines: widget.maxLines,
          )..layout(maxWidth: constraints.maxWidth);
          if (!probe.didExceedMaxLines) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        final prefix = widget.text.substring(0, low).trimRight();
        return RichText(
          textAlign: TextAlign.left,
          softWrap: true,
          maxLines: widget.maxLines,
          overflow: TextOverflow.clip,
          text: TextSpan(children: [
            TextSpan(text: '$prefix… ', style: bodyStyle),
                TextSpan(
                  text: '展开全部',
                  style: actionStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => setState(() => expanded = true),
            ),
          ]),
        );
      },
    );
  }
}

class _DiscoverMediaImage extends StatefulWidget {
  const _DiscoverMediaImage({required this.url});
  final String url;

  @override
  State<_DiscoverMediaImage> createState() => _DiscoverMediaImageState();
}

class _DiscoverMediaImageState extends State<_DiscoverMediaImage> {
  ImageStream? _stream;
  ImageStreamListener? _streamListener;
  ImageInfo? _imageInfo;
  ImageProvider<Object>? _provider;
  bool _loading = true;
  bool _failed = false;
  String? _failureMessage;
  DateTime? _loadStartedAt;

  @override
  void initState() {
    super.initState();
    _loadAuthenticatedImage();
  }

  @override
  void didUpdateWidget(covariant _DiscoverMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _loadAuthenticatedImage();
  }

  Future<void> _loadAuthenticatedImage() async {
    _loadStartedAt = DateTime.now();
    await _DiscoverMetrics.record('image.attempt');
    setState(() {
      _imageInfo = null;
      _provider = null;
      _loading = true;
      _failed = false;
      _failureMessage = null;
    });
    final path = await _PermanentImageCache.get(widget.url);
    if (!mounted) return;
    if (path == null) {
      setState(() {
        _loading = false;
        _failed = true;
        _failureMessage = '图片下载失败，请检查网络后点击重试';
        unawaited(_DiscoverMetrics.record('image.failure', _loadStartedAt == null ? null : DateTime.now().difference(_loadStartedAt!).inMilliseconds));
      });
      return;
    }
    final provider = FileImage(File(path));
    _PermanentImageCache.rememberProvider(widget.url, provider);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _streamListener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _provider = provider;
          _imageInfo = info;
          _loading = false;
          _failed = false;
        });
        unawaited(_DiscoverMetrics.record(
          'image.success',
          _loadStartedAt == null
              ? null
              : DateTime.now().difference(_loadStartedAt!).inMilliseconds,
        ));
      },
      onError: (_, __) {
        if (mounted) {
          setState(() {
            _loading = false;
            _failed = true;
            _failureMessage = '图片解码失败，请点击重试';
          });
        }
      },
    );
    _stream = stream;
    stream.addListener(_streamListener!);
  }

  @override
  void dispose() {
    final stream = _stream;
    final listener = _streamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_imageInfo == null || _provider == null) {
          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: const Color(0x22111111),
                  child: GestureDetector(
                    onTap: _failed ? _loadAuthenticatedImage : null,
                    child: Center(
                      child: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh),
                                const SizedBox(height: 2),
                                Text(
                                  _failureMessage ?? '图片加载失败，点击重试',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final ratio = _imageInfo!.image.width / _imageInfo!.image.height;
        final availableWidth = constraints.maxWidth;
        final naturalHeight = availableWidth / ratio;
        final displayHeight = naturalHeight > 400 ? 400.0 : naturalHeight;
        final displayWidth = naturalHeight > 400 ? displayHeight * ratio : availableWidth;
        return Align(
          alignment: Alignment.topLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: _provider!,
              width: displayWidth,
              height: displayHeight,
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
            ),
          ),
        );
      },
    );
  }
}


String _formatDiscoverDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final value = parsed.toUtc().add(const Duration(hours: 8));
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return value.year == now.year
      ? '${value.month}月${value.day}日'
      : '${value.year}年${value.month}月${value.day}日';
}

class _DiscoverShareSheet extends StatefulWidget {
  const _DiscoverShareSheet({
    required this.post,
    this.onSendToFriend,
    required this.onShare,
    required this.onReport,
    this.onDirectChat,
    this.onFollow,
    this.onGift,
  });
  final DDPost post;
  final Future<void> Function(String peerId)? onSendToFriend;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback? onDirectChat;
  final VoidCallback? onFollow;
  final VoidCallback? onGift;

  @override
  State<_DiscoverShareSheet> createState() => _DiscoverShareSheetState();
}

class _DiscoverShareSheetState extends State<_DiscoverShareSheet> {
  List<DDConversation> conversations = const [];
  List<Map<String, dynamic>> mutualFriends = const [];
  bool loading = true;
  String? error;
  bool sending = false;
  final service = DDPostService();

  @override
  void initState() {
    super.initState();
    unawaited(_loadConversations());
    unawaited(_loadMutualFriends());
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) throw Exception('请先登录');
    return token;
  }

  Future<void> _loadConversations() async {
    try {
      final values = await service.fetchImConversations(await _token());
      if (!mounted) return;
      setState(() {
        conversations = values.take(10).toList();
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  Future<void> _loadMutualFriends() async {
    try {
      final values = await service.fetchMutualFriends(await _token());
      if (mounted) setState(() => mutualFriends = values);
    } catch (_) {}
  }

  Future<void> _sendTo(DDConversation conversation) async {
    final peer = conversation.peer;
    if (peer == null || sending) return;
    try {
      setState(() => sending = true);
      await service.sendImMessage(
        await _token(),
        conversation.id,
        text: widget.post.content.trim().isEmpty
            ? '分享了一条动态'
            : widget.post.content.trim(),
        clientId: 'share-${widget.post.id}-${DateTime.now().microsecondsSinceEpoch}',
        metadata: {'postId': widget.post.id, 'type': 'post_share'},
      );
      if (mounted) {
        Navigator.pop(context);
        _showTopNotice(context, const Text('已发送给好友'));
      }
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('分享动态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : error != null
                        ? Center(child: Text(error!))
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final conversation in conversations)
                                _ConversationShareTile(
                                  conversation: conversation,
                                  sending: sending,
                                  onSend: () => _sendTo(conversation),
                                ),
                              _ShareFriendTile(
                                label: '更多好友',
                                icon: TIcons.more,
                                onTap: () => _showAllMutualFriends(context),
                              ),
                            ],
                          ),
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  _ShareAction(label: '微信', icon: TIcons.logo_wechat_stroke, onTap: widget.onShare),
                  _ShareAction(label: 'QQ', icon: TIcons.logo_qq, onTap: widget.onShare),
                  _ShareAction(label: '复制链接', icon: TIcons.link, onTap: () => _copyPostLink(context)),
                  _ShareAction(label: '更多', icon: TIcons.more, onTap: widget.onShare),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  _ShareAction(label: '私聊', icon: TIcons.chat, onTap: widget.onDirectChat ?? () => _openDirectChat(context)),
                  _ShareAction(label: '关注', icon: TIcons.user_add, onTap: widget.onFollow ?? () => _toggleFollow(context)),
                  _ShareAction(label: '送礼', icon: TIcons.gift, onTap: widget.onGift ?? () => _openGift(context)),
                  _ShareAction(label: '举报', icon: TIcons.bug_report, onTap: widget.onReport),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> _copyPostLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '动态 ${widget.post.id}'));
    if (context.mounted) {
      Navigator.pop(context);
      _showTopNotice(context, const Text('链接已复制'));
    }
  }

  Future<void> _openDirectChat(BuildContext context) async {
    Navigator.pop(context);
    _showTopNotice(context, const Text('请点击上方好友发送私聊'));
  }

  Future<void> _toggleFollow(BuildContext context) async {
    Navigator.pop(context);
    _showTopNotice(context, const Text('请从用户主页关注作者'));
  }

  Future<void> _openGift(BuildContext context) async {
    Navigator.pop(context);
    _showTopNotice(context, const Text('请打开动态详情送礼'));
  }

  void _showAllMutualFriends(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: mutualFriends.length,
          itemBuilder: (_, index) {
            final friend = mutualFriends[index];
            return ListTile(
              leading: SizedBox(
                width: 40,
                height: 40,
                child: ClipOval(
                  child: _PermanentCachedImage(
                    url: '${friend['avatar'] ?? ''}',
                    fit: BoxFit.cover,
                    placeholder: const Icon(Icons.person_outline, size: 18),
                  ),
                ),
              ),
              title: Text('${friend['nickname'] ?? '好友'}'),
              trailing: FilledButton(
                onPressed: () async {
                  await onSendToFriend?.call('${friend['id'] ?? ''}');
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('发送'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConversationShareTile extends StatelessWidget {
  const _ConversationShareTile({required this.conversation, required this.sending, required this.onSend});
  final DDConversation conversation;
  final bool sending;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) {
    final peer = conversation.peer;
    final avatar = peer?.avatarUrl ?? peer?.avatarKey ?? '';
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: ClipOval(
              child: _PermanentCachedImage(
                url: avatar,
                fit: BoxFit.cover,
                placeholder: const Icon(Icons.person_outline, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(peer?.nickname ?? '好友', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          SizedBox(
            height: 24,
            child: TextButton(
              onPressed: sending ? null : onSend,
              child: const Text('发送', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFriendTile extends StatelessWidget {
  const _ShareFriendTile({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(children: [Icon(icon, size: 32), const SizedBox(height: 4), Text(label, overflow: TextOverflow.ellipsis)],),
        ),
      );
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap);
}

class _DiscoverProfileCard extends StatelessWidget {
  const _DiscoverProfileCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onFavorite,
    this.onSendToFriend,
    required this.onShare,
    required this.onReport,
    required this.onOpen,
  });

  final DDPost post;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final Future<void> Function(String peerId)? onSendToFriend;
  final VoidCallback? onDirectChat;
  final VoidCallback? onFollow;
  final VoidCallback? onGift;
  final VoidCallback onReport;
  final VoidCallback onOpen;

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
      builder: (sheetContext) => _DiscoverShareSheet(
        post: post,
        onShare: onShare,
        onSendToFriend: onSendToFriend,
        onReport: onReport,
        onDirectChat: onDirectChat,
        onFollow: onFollow,
        onGift: onGift,
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(post.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
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
                        onTap: onLike,
                        active: post.liked,
                      ),
                      _action(
                        context: context,
                        icon: post.favorited ? TIcons.star_1_filled : TIcons.star_1,
                        label: '${post.favorites}',
                        onTap: onFavorite,
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
