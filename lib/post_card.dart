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
        unawaited(_DiscoverMetrics.record(
            'image.failure',
            _loadStartedAt == null
                ? null
                : DateTime.now().difference(_loadStartedAt!).inMilliseconds));
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
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
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
        final displayWidth =
            naturalHeight > 400 ? displayHeight * ratio : availableWidth;
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

String _formatMyPostDateTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final value = parsed.toUtc().add(const Duration(hours: 8));
  final hour24 = value.hour;
  final period = hour24 >= 12 ? 'pm' : 'am';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final two = (int value) => value.toString().padLeft(2, '0');
  return '${value.year}.${two(value.month)}.${two(value.day)} '
      '${two(hour12)}:${two(value.minute)} $period';
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
    this.onDelete,
  });
  final DDPost post;
  final Future<void> Function(String peerId)? onSendToFriend;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback? onDirectChat;
  final VoidCallback? onFollow;
  final VoidCallback? onGift;
  final VoidCallback? onDelete;

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
      if (mounted)
        setState(() {
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

  Future<void> _sendToFriend(String peerId) async {
    await widget.onSendToFriend?.call(peerId);
  }

  Future<void> _sendTo(DDConversation conversation) async {
    final peer = conversation.peer;
    if (peer == null || sending) return;
    try {
      setState(() => sending = true);
      await _sendSharedPostMessage(
        conversationId: conversation.id,
        postId: widget.post.id,
        text: widget.post.content,
        author: widget.post.nickname,
        content: widget.post.content,
        thumbnailUrl: widget.post.thumbnailUrl ?? widget.post.imageUrl ?? '',
      );
      if (mounted) {
        Navigator.pop(context);
        _showTopNotice(context, const Text('已发送给好友'));
      }
    } catch (e) {
      if (mounted) _showTopNotice(context, const Text('操作失败'));
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
              const Center(
                child: Text('更多操作',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 88,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
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
                                label: '更多',
                                icon: TIcons.ellipsis,
                                onTap: () => _showAllMutualFriends(context),
                              ),
                            ],
                          ),
              ),
              const Divider(height: 24),
              if (widget.post.reviewStatus == 'rejected' &&
                  widget.onDelete != null)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ShareAction(
                        label: '删除',
                        icon: TIcons.delete,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onDelete!.call();
                        }),
                    _ShareAction(
                        label: '申诉',
                        icon: TIcons.shield_error,
                        onTap: widget.onReport),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (widget.onDelete != null) ...[
                      _ShareAction(
                          label: '置顶',
                          icon: Icons.push_pin_outlined,
                          onTap: () => Navigator.pop(context)),
                      _ShareAction(
                          label: '权限',
                          icon: TIcons.browse,
                          onTap: () => Navigator.pop(context)),
                      _ShareAction(
                          label: '私密',
                          icon: Icons.lock_outline,
                          onTap: () => Navigator.pop(context)),
                      _ShareAction(
                          label: '删除',
                          icon: Icons.delete_outline,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onDelete!.call();
                          }),
                    ] else ...[
                      _ShareAction(
                          label: '私聊',
                          icon: TIcons.chat,
                          onTap: widget.onDirectChat ??
                              () => _openDirectChat(context)),
                      _ShareAction(
                        label: widget.post.following ? '已关注' : '关注',
                        icon: widget.post.following
                            ? TIcons.user_checked
                            : TIcons.user_add,
                        onTap: widget.onFollow ?? () => _toggleFollow(context),
                      ),
                      _ShareAction(
                          label: '送礼',
                          icon: TIcons.gift,
                          onTap: widget.onGift ?? () => _openGift(context)),
                      _ShareAction(
                          label: '举报',
                          icon: TIcons.bug_report,
                          onTap: widget.onReport),
                    ],
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
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _PostGiftSheet(
        post: widget.post,
        onSent: () {
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  Future<void> _showAllMutualFriends(BuildContext context) async {
    await showModalBottomSheet<void>(
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
                  await widget.onSendToFriend?.call('${friend['id'] ?? ''}');
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
  const _ConversationShareTile(
      {required this.conversation,
      required this.sending,
      required this.onSend});
  final DDConversation conversation;
  final bool sending;
  final VoidCallback onSend;

  Future<void> _confirmSend(BuildContext context) async {
    if (sending) return;
    final peerName = conversation.peer?.nickname ?? '好友';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认分享'),
        content: Text('确定把这条动态发送给 $peerName 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    if (confirmed == true) onSend();
  }

  @override
  Widget build(BuildContext context) {
    final peer = conversation.peer;
    final avatar = peer?.avatarUrl ?? peer?.avatarKey ?? '';
    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: () => _confirmSend(context),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: ClipOval(
                child: _PermanentCachedImage(
                  url: avatar,
                  fit: BoxFit.cover,
                  placeholder: const Icon(Icons.person_outline, size: 23),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              peer?.nickname ?? '好友',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareFriendTile extends StatelessWidget {
  const _ShareFriendTile(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(icon, size: 23),
              ),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

Future<void> _openApp(BuildContext context, String scheme) async {
  final uri = Uri.parse(scheme);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    _showTopNotice(context, const Text('未安装对应应用'));
  }
}

class _PostGiftSheet extends StatefulWidget {
  const _PostGiftSheet({required this.post, required this.onSent});
  final DDPost post;
  final VoidCallback onSent;
  @override
  State<_PostGiftSheet> createState() => _PostGiftSheetState();
}

class _PostGiftSheetState extends State<_PostGiftSheet> {
  final service = DDPostService();
  List<Map<String, dynamic>> gifts = const [];
  bool loading = true;
  bool sending = false;
  int _page = 0;

  String _asset(int index) => 'assets/dynamic_gifts/gift_${index + 1}.png';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  Future<void> _load() async {
    try {
      final value = await service.fetchGiftItems(await _token(), scope: 'post');
      if (mounted) setState(() => gifts = value);
    } catch (error) {
      if (mounted) _showTopNotice(context, Text('$error'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send(Map<String, dynamic> gift) async {
    if (sending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认送礼'),
        content: Text('确定送出 ${gift['name'] ?? '这份礼物'} 吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('送出')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      setState(() => sending = true);
      await service.sendPostGift(
        token: await _token(),
        postId: widget.post.id,
        giftId: int.parse('${gift['id']}'),
      );
      if (mounted) {
        _showTopNotice(context, const Text('礼物已送出'));
        widget.onSent();
      }
    } catch (error) {
      if (mounted) _showTopNotice(context, Text('$error'));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: loading
              ? const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()))
              : gifts.isEmpty
                  ? const SizedBox(
                      height: 120, child: Center(child: Text('暂无可送出的礼物')))
                  : SizedBox(
                      height: 220,
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              itemCount: (gifts.length / 10).ceil(),
                              onPageChanged: (page) =>
                                  setState(() => _page = page),
                              itemBuilder: (_, page) {
                                final pageGifts =
                                    gifts.skip(page * 10).take(10).toList();
                                return GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: pageGifts.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 5,
                                          childAspectRatio: .78),
                                  itemBuilder: (_, index) => InkWell(
                                    onTap: sending
                                        ? null
                                        : () => _send(pageGifts[index]),
                                    child: Column(children: [
                                      Image.asset(_asset(page * 10 + index),
                                          width: 48, height: 48),
                                      Text(
                                          '${pageGifts[index]['name'] ?? '礼物'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11)),
                                      Text(
                                          '${pageGifts[index]['coin_price'] ?? pageGifts[index]['coinPrice'] ?? 0}金币',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange))
                                    ]),
                                  ),
                                );
                              },
                            ),
                          ),
                          Text('${_page + 1}/${(gifts.length / 10).ceil()}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
        ),
      );
}

class _ShareAction extends StatelessWidget {
  const _ShareAction(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(icon, size: 23),
              ),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

String _maskViolationText(String text) =>
    text.characters.map((_) => '*').join();

class _ViolationMediaPlaceholder extends StatelessWidget {
  const _ViolationMediaPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(TIcons.error_triangle_filled, color: Colors.red, size: 36),
          SizedBox(height: 8),
          Text('图片涉嫌违规'),
        ]),
      );
}

class _DiscoverProfileCard extends StatelessWidget {
  const _DiscoverProfileCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onFavorite,
    this.onSendToFriend,
    required this.onShare,
    this.onDirectChat,
    this.onFollow,
    this.onGift,
    this.onDelete,
    required this.onReport,
    required this.onOpen,
    this.hideAuthorRow = false,
    this.showViews = false,
  });

  final DDPost post;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final Future<void> Function(String peerId)? onSendToFriend;
  final VoidCallback? onDirectChat;
  final VoidCallback? onFollow;
  final VoidCallback? onGift;
  final VoidCallback? onDelete;
  final VoidCallback onReport;
  final VoidCallback onOpen;
  final bool hideAuthorRow;
  final bool showViews;

  Widget _media({required String url, required bool thumbnail}) {
    return _DiscoverMediaImage(url: url);
  }

  Widget _action({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
  }) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 20,
                    color:
                        active ? Theme.of(context).colorScheme.primary : null),
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
        onDelete: onDelete,
      ),
    );
  }

  Widget _avatarFrame(
      {required Widget child,
      required String gender,
      double size = 40,
      String? frameAsset}) {
    final explicitFrame = normalizeAvatarFrameAsset(frameAsset);
    final normalizedFrame = explicitFrame.isNotEmpty
        ? explicitFrame
        : defaultAvatarFrameForGender(gender);
    final color = isMaleGender(gender)
        ? const Color(0xFF1677FF)
        : isFemaleGender(gender)
            ? const Color(0xFFFF6FAE)
            : Colors.transparent;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(color == Colors.transparent ? 0 : 2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: color == Colors.transparent
                    ? null
                    : Border.all(color: color, width: 2)),
            child: ClipOval(child: child)),
        if (normalizedFrame.isNotEmpty)
          Positioned.fill(
              child: IgnorePointer(
                  child: Image.asset(normalizedFrame, fit: BoxFit.contain))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final violation = post.reviewStatus == 'rejected' && onDelete != null;
    final hasMedia = (post.imageUrl?.trim().isNotEmpty == true) ||
        (post.videoUrl?.trim().isNotEmpty == true);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hideAuthorRow) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _avatarFrame(
                    gender: post.gender,
                    frameAsset: post.authorAvatarFrameAsset,
                    child: SizedBox.expand(
                      child: post.avatar.trim().isEmpty
                          ? const Icon(Icons.person_outline)
                          : _PermanentCachedImage(
                              url: post.avatar,
                              fit: BoxFit.cover,
                              placeholder: const Icon(Icons.person_outline),
                            ),
                    ),
                  ),
                  if (post.authorOnline)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 40 * .30,
                        height: 40 * .30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hideAuthorRow)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatMyPostDateTime(post.createdAt),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55)),
                          ),
                        ),
                        IconButton(
                          tooltip: '分享',
                          onPressed: () => _showDiscoverMore(context),
                          icon: Icon(
                              violation
                                  ? TIcons.error_triangle_filled
                                  : TIcons.share_1,
                              color: violation ? Colors.red : null),
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 32, height: 32),
                        ),
                      ],
                    )
                  else
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
                                          borderRadius:
                                              BorderRadius.circular(6),
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
                          icon: Icon(
                              violation
                                  ? TIcons.error_triangle_filled
                                  : TIcons.share_1,
                              color: violation ? Colors.red : null),
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
                      padding: const EdgeInsets.only(top: 1, bottom: 5),
                      child: _DiscoverPostContent(
                        text: violation
                            ? _maskViolationText(post.content)
                            : post.content.trim(),
                        maxLines: hasMedia ? 3 : 10,
                      ),
                    ),
                  if (post.imageUrl?.trim().isNotEmpty == true &&
                      violation) ...[
                    const SizedBox(height: 10),
                    _ViolationMediaPlaceholder(),
                  ] else if (post.imageUrl?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    _media(url: post.imageUrl!.trim(), thumbnail: false),
                  ] else if (post.videoUrl?.trim().isNotEmpty == true &&
                      violation) ...[
                    const SizedBox(height: 10),
                    _ViolationMediaPlaceholder(),
                  ] else if (post.videoUrl?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        _media(
                            url: post.thumbnailUrl?.trim().isNotEmpty == true
                                ? post.thumbnailUrl!.trim()
                                : post.videoUrl!.trim(),
                            thumbnail:
                                post.thumbnailUrl?.trim().isNotEmpty == true),
                        const Icon(Icons.play_circle_outline,
                            size: 48, color: Colors.white),
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
                        icon: post.favorited
                            ? TIcons.bookmark_filled
                            : TIcons.bookmark,
                        label: '${post.favorites}',
                        onTap: onFavorite,
                        active: post.favorited,
                      ),
                      _action(
                          context: context,
                          icon: TIcons.chat_bubble_1,
                          label: '${post.comments}',
                          onTap: onOpen),
                      if (showViews)
                        _action(
                            context: context,
                            icon: TIcons.browse,
                            label: '${post.views}',
                            onTap: onOpen),
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
