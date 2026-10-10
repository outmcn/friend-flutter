part of 'main.dart';

final Map<String, ImageProvider> _avatarProviderCache = {};

ImageProvider _cachedAvatarProvider(String url) =>
    _avatarProviderCache.putIfAbsent(url, () => NetworkImage(url));

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int? selectedChat;
  final messageController = TextEditingController();
  final userSearchController = TextEditingController();
  List<_ChatPreview> conversations = [];
  StreamSubscription<Map<String, dynamic>>? listEvents;
  bool loading = true;
  bool conversationCacheLoaded = false;
  String? loadError;
  final Map<String, String> _avatarPaths = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadConversations());
    listEvents = ImSession.instance.events.listen(_handleListEvent);
  }

  void _handleListEvent(Map<String, dynamic> event) {
    if (event['type'] == 'message:new' || event['type'] == 'message:recalled') {
      unawaited(_loadConversations(showLoading: false));
    }
    if (event['type'] == 'call:incoming') {
      final call = event['call'];
      if (call is Map) {
        unawaited(_showIncomingCall(call.cast<String, dynamic>()));
      }
    }
  }

  Future<void> _showIncomingCall(Map<String, dynamic> call) async {
    final callId = '${call['id'] ?? ''}';
    if (!mounted || callId.isEmpty) return;
    final accepted = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('来电'),
        content: const Text('对方发起了一次语音通话'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'reject'),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'answer'),
            child: const Text('接听'),
          ),
        ],
      ),
    );
    if (!mounted || accepted == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final result = await service.updateImCall(token, callId, accepted);
      if (accepted == 'answer' && mounted) {
        final answeredCall =
            (result['call'] as Map?)?.cast<String, dynamic>() ?? call;
        final rtc = (result['rtc'] as Map?)?.cast<String, dynamic>() ?? {};
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _AudioCallPage(
              call: answeredCall,
              rtc: rtc,
              token: token,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      service.dispose();
    }
  }

  Future<void> _cacheAvatar(_ChatPreview chat) async {
    final key = chat.avatarKey ?? '';
    if (key.isEmpty || _avatarPaths.containsKey(key)) return;
    final local = await ImLocalStore.avatarPath(key);
    if (local != null && mounted) {
      setState(() => _avatarPaths[key] = local);
      return;
    }
    final url = chat.avatarUrl;
    if (url == null || url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final saved = await ImLocalStore.saveAvatar(key, response.bodyBytes);
        if (mounted) setState(() => _avatarPaths[key] = saved);
      }
    } catch (_) {}
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) {
      if (mounted) setState(() => loadError = '登录状态尚未恢复，请重试');
      return;
    }
    final accountId = prefs.getString('friend.auth.userId') ?? '';
    if (accountId.isNotEmpty) {
      final cachedRows = await ImLocalStore.conversations(accountId);
      if (cachedRows.isNotEmpty && mounted) {
        setState(() {
          conversations =
              cachedRows.map((row) => _ChatPreview.fromCache(row)).toList();
          conversationCacheLoaded = true;
          loading = false;
        });
      }
    }
    if (mounted && showLoading && !conversationCacheLoaded) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    final service = DDPostService();
    try {
      final rows = await service.fetchImConversations(token);
      if (!mounted) return;
      final mapped = <_ChatPreview>[];
      for (final row in rows) {
        final local = accountId.isEmpty
            ? null
            : await ImLocalStore.latestMessage(
                accountId: accountId,
                conversationId: row.id,
              );
        final preview =
            _localMessagePreview(local) ?? row.lastMessage?.text ?? '开始一段新的聊天';
        mapped.add(_ChatPreview(
          row.peer?.nickname ?? '会话 ${row.id}',
          preview,
          row.peer?.avatarUrl,
          row.peer?.avatarKey,
          row.id,
          row.unreadCount,
          row.peerReadMessageId,
          row.updatedAt,
        ));
      }
      if (mounted) {
        setState(() {
          conversations = mapped;
          conversationCacheLoaded = true;
          loading = false;
        });
      }
      if (accountId.isNotEmpty) {
        await ImLocalStore.saveConversations(
          accountId: accountId,
          conversations: mapped.map((chat) => chat.toCache()).toList(),
        );
      }
      for (final chat in conversations) {
        unawaited(_cacheAvatar(chat));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = conversations.isEmpty ? '会话加载失败，请重试' : null;
        });
      }
    } finally {
      service.dispose();
    }
  }

  Future<void> _stopListSocket() async {
    await listEvents?.cancel();
    listEvents = null;
  }

  Future<void> _restartListSocket() async {
    await _stopListSocket();
    if (mounted) {
      listEvents = ImSession.instance.events.listen(_handleListEvent);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loading && conversations.isEmpty && loadError == null) {
      unawaited(_loadConversations(showLoading: false));
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    userSearchController.dispose();
    listEvents?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () {},
            icon: Icon(TIcons.setting),
          ),
          IconButton(
            tooltip: '新建聊天',
            onPressed: _openNewChat,
            icon: Icon(TIcons.add_circle),
          ),
          IconButton(
            tooltip: '好友申请',
            onPressed: () {},
            icon: Icon(TIcons.user_add),
          ),
        ],
      ),
      body: loading && !conversationCacheLoaded
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _loadConversations,
                    icon: const Icon(Icons.refresh),
                    label: Text(loadError!),
                  ),
                )
              : _conversationList(context),
    );
  }

  /*
   * 聊天列表页统一使用 AppBar；此处只保留会话列表内容，避免自定义顶栏
   * 与其他页面的系统安全区、标题高度和操作按钮间距产生差异。
   */
  Future<void> _openNewChat() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewChatSheet(controller: userSearchController),
    );
    if (selected == null || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      final service = DDPostService();
      final id =
          await service.createDirectConversation(token, '${selected['id']}');
      final currentUserId = '${(await service.fetchMe(token))['id'] ?? ''}';
      service.dispose();
      await _loadConversations();
      if (!mounted) return;
      final chat = conversations.firstWhere(
        (item) => item.conversationId == id,
        orElse: () => _ChatPreview(
            '${selected['nickname'] ?? '用户'}', '开始一段新的聊天', null, null, id, 0),
      );
      await _stopListSocket();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ChatDetailPage(
            chat: chat,
            currentUserId: currentUserId,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Widget _conversationList(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (_, index) {
            final chat = conversations[index];
            return _chatPreviewTile(context, chat, index);
          },
        ),
      );

  ImageProvider _avatarFor(_ChatPreview chat) {
    final local = _avatarPaths[chat.avatarKey];
    if (local != null) return FileImage(File(local));
    final url = chat.avatarUrl;
    if (url == null || url.isEmpty) {
      return const AssetImage('assets/figma/profile-portrait-2.jpg');
    }
    return _cachedAvatarProvider(url);
  }

  Widget _chatPreviewTile(BuildContext context, _ChatPreview chat, int index) =>
      InkWell(
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getString('friend.auth.userId') ?? '';
          if (!context.mounted) return;
          await _stopListSocket();
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ChatDetailPage(
                chat: chat,
                currentUserId: currentUserId,
              ),
            ),
          );
          if (mounted) {
            unawaited(_loadConversations(showLoading: false));
            unawaited(_restartListSocket());
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: _avatarFor(chat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(chat.name,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ),
                        Text(formatDDTime(chat.updatedAt ?? ''),
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor)),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              chat.unreadCount > 99
                                  ? '99+'
                                  : '${chat.unreadCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(chat.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  // ignore: unused_element
  Widget _chatDetail(BuildContext context, _ChatPreview chat) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                    onPressed: () => setState(() => selectedChat = null),
                    icon: const Icon(Icons.arrow_back)),
                CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        (chat.avatarUrl == null || chat.avatarUrl!.isEmpty)
                            ? (const AssetImage(
                                    'assets/figma/profile-portrait-2.jpg')
                                as ImageProvider)
                            : _cachedAvatarProvider(chat.avatarUrl!)),
                const SizedBox(width: 8),
                Text(chat.name, style: Theme.of(context).textTheme.bodyLarge),
                const Spacer(),
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.more_horiz)),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('选择一个聊天开始交流', style: TextStyle(color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 12),
            child: Row(
              children: [
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.attach_file)),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: '输入消息',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22)),
                    ),
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      );
}

String? _localMessagePreview(Map<String, dynamic>? row) {
  if (row == null) return null;
  final status = '${row['status'] ?? 'sent'}';
  if (status == 'recalled') return '消息已撤回';
  if (status == 'deleted') return '消息已删除';
  final kind = '${row['kind'] ?? 'text'}';
  if (kind == 'image') return '[图片]';
  if (kind == 'audio') return '[语音]';
  return '${row['text'] ?? ''}';
}

class _ChatPreview {
  _ChatPreview(this.name, this.preview, this.avatarUrl, this.avatarKey,
      this.conversationId, this.unreadCount,
      [this.peerReadMessageId, this.updatedAt]);
  final String name;
  final String preview;
  final String? avatarUrl;
  final String? avatarKey;
  final String conversationId;
  final int unreadCount;
  final String? peerReadMessageId;
  final String? updatedAt;

  factory _ChatPreview.fromCache(Map<String, dynamic> row) => _ChatPreview(
        '${row['name'] ?? '用户'}',
        '${row['preview'] ?? ''}',
        row['avatarUrl'] as String?,
        row['avatarKey'] as String?,
        '${row['conversationId'] ?? ''}',
        (row['unreadCount'] as num?)?.toInt() ?? 0,
        row['peerReadMessageId']?.toString(),
        row['updatedAt']?.toString(),
      );

  Map<String, dynamic> toCache() => {
        'name': name,
        'preview': preview,
        'avatarUrl': avatarUrl,
        'avatarKey': avatarKey,
        'conversationId': conversationId,
        'unreadCount': unreadCount,
        'peerReadMessageId': peerReadMessageId,
        'updatedAt': updatedAt,
      };
}

ImageProvider _chatAvatarFor(_ChatPreview chat) {
  final url = chat.avatarUrl;
  if (url == null || url.isEmpty) {
    return const AssetImage('assets/figma/profile-portrait-2.jpg');
  }
  return _cachedAvatarProvider(url);
}

class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final phase = (_controller.value + index / 3) % 1;
                    final opacity = 0.35 + (phase < 0.5 ? phase : 1 - phase);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity.clamp(0.35, 0.95),
                        child: const Text('•', style: TextStyle(fontSize: 18)),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ChatDetailPage extends StatefulWidget {
  const _ChatDetailPage({required this.chat, this.currentUserId = ''});
  final _ChatPreview chat;
  final String currentUserId;
  @override
  State<_ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<_ChatDetailPage> {
  final messageController = TextEditingController();
  final messageFocusNode = FocusNode();
  StreamSubscription<Map<String, dynamic>>? eventSubscription;
  final messages = <Map<String, dynamic>>[];
  final messageScrollController = ScrollController();
  bool loadingOlder = false;
  bool hasOlder = true;
  bool blockedConversation = false;
  String currentUserId = '';
  bool typing = false;
  bool peerTyping = false;
  String? peerReadMessageId;
  bool syncing = false;
  bool initialSyncCompleted = false;
  final AudioPlayer audioPlayer = AudioPlayer();
  final Map<String, String> imageFiles = {};
  String? playingAudioKey;
  Timer? typingTimer;
  bool voiceMode = false;
  AudioRecorder? holdRecorder;
  String? holdRecordingPath;
  bool recordingVoice = false;
  bool cancelVoice = false;
  Offset? holdStartPosition;
  bool moreExpanded = false;
  bool emojiExpanded = false;

  @override
  void initState() {
    super.initState();
    messageScrollController.addListener(_handleMessageScroll);
    unawaited(_connectIm());
  }

  void _scrollToLatest() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !messageScrollController.hasClients) return;
      messageScrollController.jumpTo(
        messageScrollController.position.maxScrollExtent,
      );
    });
  }

  void _handleMessageScroll() {
    if (!messageScrollController.hasClients) return;
  }

  @override
  void dispose() {
    if (typing) {
      typing = false;
      ImSession.instance.socket?.sendTyping(
          conversationId: widget.chat.conversationId, typing: false);
    }
    messageController.dispose();
    messageFocusNode.dispose();
    messageScrollController.removeListener(_handleMessageScroll);
    messageScrollController.dispose();
    typingTimer?.cancel();
    unawaited(holdRecorder?.dispose());
    audioPlayer.dispose();
    eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _connectIm() async {
    try {
      await _connectImInternal();
    } catch (_) {}
  }

  Future<void> _connectImInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) throw Exception('请先登录');
    currentUserId = widget.currentUserId;
    peerReadMessageId = widget.chat.peerReadMessageId;
    if (currentUserId.isEmpty) {
      currentUserId = ImSession.instance.userId ??
          prefs.getString('friend.auth.userId') ??
          '';
    }
    if (currentUserId.isEmpty) {
      final service = DDPostService();
      try {
        final profile = await service.fetchMe(token);
        currentUserId = '${profile['id'] ?? ''}';
        await prefs.setString('friend.auth.userId', currentUserId);
      } finally {
        service.dispose();
      }
    }
    eventSubscription = ImSession.instance.events.listen(_handleImEvent);
    try {
      await ImLocalStore.migrateLegacyAudioKeys();
      final cached = await ImLocalStore.messages(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
      );
      if (mounted) {
        setState(() {
          messages
            ..clear()
            ..addAll(cached);
          initialSyncCompleted = true;
        });
      }
      final deletedIds = await ImLocalStore.localDeletedMessageIds(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
      );
      cached.removeWhere((item) => deletedIds.contains('${item['id']}'));
      final normalized = <String, Map<String, dynamic>>{};
      for (final item in cached) {
        final key = '${item['clientId'] ?? item['id'] ?? ''}';
        final old = normalized[key];
        if (old == null ||
            '${old['id'] ?? ''}'.startsWith('local:') &&
                !'${item['id'] ?? ''}'.startsWith('local:')) {
          normalized[key] = item;
        }
      }
      cached
        ..clear()
        ..addAll(normalized.values);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(cached);
        initialSyncCompleted = true;
      });
      unawaited(_markLatestRead());
      _scrollToLatest();
      unawaited(_refreshDetailFromServer(token));
    } catch (_) {}
  }

  Future<void> _refreshDetailFromServer(String token) async {
    if (!mounted) return;
    final service = DDPostService();
    try {
      final afterMutationId = await ImLocalStore.mutationId(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
      );
      final sync = await service.syncImMessages(
        token,
        widget.chat.conversationId,
        afterMutationId,
      );
      final latest = (sync['messages'] as List).cast<DDImMessage>();
      final nextMutationId = '${sync['nextMutationId'] ?? afterMutationId}';
      final merged = <String, Map<String, dynamic>>{};
      for (final current in messages) {
        final key = '${current['clientId'] ?? current['id'] ?? ''}';
        if (key.isNotEmpty) merged[key] = current;
      }
      for (final item in latest) {
        final row = <String, dynamic>{
          'id': item.id,
          'conversationId': item.conversationId,
          'senderId': item.senderId,
          'text': item.text,
          'kind': item.kind,
          'durationMs': item.durationMs,
          'clientId': item.clientId,
          'createdAt': item.createdAt,
          'recalledAt': item.recalledAt,
          'deletedAt': item.deletedAt,
          'updatedAt': item.updatedAt,
          'mutationId': item.mutationId,
          'status': item.recalledAt != null
              ? 'recalled'
              : item.deletedAt != null
                  ? 'deleted'
                  : 'sent',
        };
        final key =
            item.clientId?.isNotEmpty == true ? item.clientId! : item.id;
        final local = merged[key];
        final isLocalPending = local != null &&
            local['status'] == 'pending' &&
            '${local['id'] ?? ''}'.startsWith('local:');
        if (isLocalPending && item.id.isEmpty) continue;
        merged[key] = {
          ...?local,
          ...row,
          if (isLocalPending &&
              item.recalledAt == null &&
              item.deletedAt == null)
            'status': 'pending',
        };
      }
      final next = merged.values.toList()
        ..sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
      await ImLocalStore.saveMessages(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
        messages: next,
      );
      await ImLocalStore.saveMutationId(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
        mutationId: nextMutationId,
      );
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      // 已显示 SQLite；后台刷新失败不覆盖当前聊天内容。
    } finally {
      service.dispose();
    }
  }

  void _markPendingMessagesFailed(String reason) {
    final changed = <Map<String, dynamic>>[];
    for (final message in messages) {
      if (message['status'] == 'pending') {
        changed.add({...message, 'status': 'failed', 'error': reason});
      }
    }
    if (changed.isEmpty) return;
    setState(() {
      for (final message in changed) {
        final index = messages
            .indexWhere((item) => item['clientId'] == message['clientId']);
        if (index >= 0) messages[index] = message;
      }
    });
    unawaited(ImLocalStore.saveMessages(
      accountId: currentUserId,
      conversationId: widget.chat.conversationId,
      messages: messages,
    ));
  }

  Future<void> _handleImEvent(Map<String, dynamic> event) async {
    if (!mounted) return;
    final type = event['type'];
    if (type == 'session:replaced') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账号已在其他设备登录')),
        );
      }
      return;
    }
    if (type == 'call:update') {
      final call = event['call'];
      if (call is Map && '${call['status'] ?? ''}' == 'ended') {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
      return;
    }
    if (type == 'typing:start' || type == 'typing:stop') {
      final eventConversationId = '${event['conversationId'] ?? ''}';
      if (eventConversationId != widget.chat.conversationId ||
          '${event['userId'] ?? ''}' == currentUserId) {
        return;
      }
      setState(() => peerTyping = type == 'typing:start');
      return;
    }
    if (type == 'read:update') {
      final eventConversationId = '${event['conversationId'] ?? ''}';
      final nextReadId = '${event['messageId'] ?? ''}';
      if (eventConversationId == widget.chat.conversationId &&
          '${event['userId'] ?? ''}' != currentUserId &&
          int.tryParse(nextReadId) != null &&
          (peerReadMessageId == null ||
              int.tryParse(peerReadMessageId!) == null ||
              int.parse(nextReadId) > int.parse(peerReadMessageId!))) {
        setState(() => peerReadMessageId = nextReadId);
      }
      return;
    }
    if (type == 'message:recalled') {
      final message = event['message'];
      if (message is Map) {
        final item = message.cast<String, dynamic>();
        final messageId = '${item['id'] ?? ''}';
        final clientId = '${item['clientId'] ?? ''}';
        final index = messages.indexWhere((existing) {
          return (messageId.isNotEmpty &&
                  '${existing['id'] ?? ''}' == messageId) ||
              (clientId.isNotEmpty &&
                  '${existing['clientId'] ?? ''}' == clientId);
        });
        if (index >= 0) {
          setState(() => messages[index] = {
                ...messages[index],
                'status': 'recalled',
                'text': '',
                'recalledAt':
                    item['recalledAt'] ?? DateTime.now().toIso8601String(),
              });
          await ImLocalStore.saveMessages(
            accountId: currentUserId,
            conversationId: widget.chat.conversationId,
            messages: messages,
          );
        }
      }
      return;
    }
    if (type == 'im:socket' || type == 'im:state' || type == 'ready') {
      return;
    }
    if (type == 'auth:invalid') {
      _markPendingMessagesFailed('登录状态已失效');
      return;
    }
    if (type == 'error' || type == 'message:failed') {
      if (event['retrying'] == true) return;
      final pendingId =
          '${event['clientId'] ?? event['message']?['clientId'] ?? ''}';
      if (pendingId.isNotEmpty) {
        final index = messages
            .indexWhere((item) => '${item['clientId'] ?? ''}' == pendingId);
        if (index >= 0) {
          setState(() => messages[index] = {
                ...messages[index],
                'status': 'failed',
                'lastError': 'retry_expired',
              });
          await ImLocalStore.saveMessages(
            accountId: currentUserId,
            conversationId: widget.chat.conversationId,
            messages: messages,
          );
        }
      }
      if (event['code'] == 'conversation_blocked') {
        if (mounted) setState(() => blockedConversation = true);
      }
      return;
    }

    if (type == 'closed' || type == 'connect_failed') {
      return;
    }
    if (type != 'message:new' && type != 'message:accepted') return;
    final message = event['message'];
    if (message is! Map) return;
    final item = message.cast<String, dynamic>();
    if (type == 'message:accepted') {
      _markPendingAccepted(item);
      return;
    }
    if (type == 'message:new') {
      if (_mergeMessage(item, status: 'sent')) {
        await ImLocalStore.saveMessages(
          accountId: currentUserId,
          conversationId: widget.chat.conversationId,
          messages: messages,
        );
        final id = '${item['id'] ?? ''}';
        await _confirmDurableMessages(<String>[id]);
        unawaited(_markLatestRead());
      }
    }
  }

  Future<void> _markPendingAccepted(Map<String, dynamic> item) async {
    final clientId = '${item['clientId'] ?? ''}';
    if (clientId.isEmpty) return;
    _mergeMessage(item, status: 'sent');

    await ImLocalStore.saveMessages(
      accountId: currentUserId,
      conversationId: widget.chat.conversationId,
      messages: messages,
    );
  }

  bool _mergeMessage(Map<String, dynamic> item, {String? status}) {
    final id = '${item['id'] ?? ''}';
    final clientId = '${item['clientId'] ?? ''}';
    final index = messages.indexWhere((existing) {
      return (clientId.isNotEmpty &&
              '${existing['clientId'] ?? ''}' == clientId) ||
          (id.isNotEmpty && '${existing['id'] ?? ''}' == id);
    });
    final merged = <String, dynamic>{
      ...(index >= 0 ? messages[index] : const <String, dynamic>{}),
      ...item,
      if (status != null) 'status': status,
      if (status == null && index >= 0) 'status': messages[index]['status'],
    };
    if (index >= 0) {
      setState(() => messages[index] = merged);
      _sortMessagesFrom(index);
      return true;
    }
    setState(() => messages.add(merged));
    _sortMessagesFrom(messages.length - 1);
    return true;
  }

  void _sortMessagesFrom(int startIndex) {
    if (messages.length < 2) return;
    var index = startIndex;
    while (index > 0 &&
        _messageTime(messages[index])
            .isBefore(_messageTime(messages[index - 1]))) {
      final current = messages[index];
      messages[index] = messages[index - 1];
      messages[index - 1] = current;
      index--;
    }
    while (index + 1 < messages.length &&
        _messageTime(messages[index + 1])
            .isBefore(_messageTime(messages[index]))) {
      final current = messages[index];
      messages[index] = messages[index + 1];
      messages[index + 1] = current;
      index++;
    }
    if (mounted) {
      setState(() {});
      _scrollToLatest();
    }
  }

  DateTime _messageTime(Map<String, dynamic> message) =>
      DateTime.tryParse('${message['createdAt'] ?? ''}') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  void _handleTypingChanged(String value) {
    final shouldType = value.trim().isNotEmpty;
    if (shouldType != typing) {
      typing = shouldType;
      ImSession.instance.socket?.sendTyping(
          conversationId: widget.chat.conversationId, typing: shouldType);
    }
    typingTimer?.cancel();
    if (shouldType) {
      typingTimer = Timer(const Duration(seconds: 2), () {
        typing = false;
        ImSession.instance.socket?.sendTyping(
            conversationId: widget.chat.conversationId, typing: false);
      });
    }
  }

  Future<void> _playAudioMessage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    if (playingAudioKey == key) {
      await audioPlayer.pause();
      if (mounted) setState(() => playingAudioKey = null);
      return;
    }
    final service = DDPostService();
    try {
      final url = await service.mediaUrlForKey(token, key);
      await audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => playingAudioKey = key);
    } finally {
      service.dispose();
    }
  }

  Widget _imageMessageBody(Map<String, dynamic> message) {
    final key = '${message['text'] ?? ''}';
    final filePath = imageFiles[key];
    if (filePath == null) {
      unawaited(_resolveImage(key));
      return const SizedBox(
        width: 120,
        height: 90,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(child: Image.file(File(filePath))),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(filePath),
          width: 180,
          height: 140,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<void> _resolveImage(String key) async {
    if (key.isEmpty || imageFiles.containsKey(key)) return;
    final cached = await ImLocalStore.imagePath(key);
    if (cached != null && mounted) {
      setState(() => imageFiles[key] = cached);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final url = await service.mediaUrlForKey(token, key);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final filePath = await ImLocalStore.saveImage(key, response.bodyBytes);
        if (mounted) setState(() => imageFiles[key] = filePath);
      }
    } catch (_) {
      // A later rebuild can retry a transient signed URL or network failure.
    } finally {
      service.dispose();
    }
  }

  Future<void> _startHoldRecording(LongPressStartDetails details) async {
    if (!voiceMode || recordingVoice) return;
    holdStartPosition = details.localPosition;
    cancelVoice = false;
    final recorder = AudioRecorder();
    holdRecorder = recorder;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) {
      await recorder.dispose();
      holdRecorder = null;
      return;
    }
    if (!await recorder.hasPermission()) {
      await recorder.dispose();
      holdRecorder = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有麦克风权限')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/im_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
    holdRecordingPath = path;
    if (mounted) setState(() => recordingVoice = true);
  }

  void _updateHoldRecording(LongPressMoveUpdateDetails details) {
    if (!recordingVoice || holdStartPosition == null) return;
    final dx = details.localPosition.dx - holdStartPosition!.dx;
    final dy = details.localPosition.dy - holdStartPosition!.dy;
    if (dx.abs() > 80 || dy < -60) {
      cancelVoice = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _finishHoldRecording(LongPressEndDetails details) async {
    final recorder = holdRecorder;
    final path = holdRecordingPath;
    final cancelled = cancelVoice;
    holdRecorder = null;
    holdRecordingPath = null;
    if (!recordingVoice || recorder == null || path == null) return;
    if (mounted) setState(() => recordingVoice = false);
    final output = await recorder.stop();
    await recorder.dispose();
    if (cancelled || output == null) {
      if (mounted && cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消录音')),
        );
      }
      return;
    }
    await _sendRecordedAudio(output);
  }

  Future<void> _startAudioCall() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final result =
          await service.startImCall(token, widget.chat.conversationId);
      if (!mounted) return;
      final call = (result['call'] as Map?)?.cast<String, dynamic>() ?? {};
      final rtc = (result['rtc'] as Map?)?.cast<String, dynamic>() ?? {};
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AudioCallPage(call: call, rtc: rtc, token: token),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      service.dispose();
    }
  }

  Future<void> _sendRecordedAudio(String pathValue) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final upload = await service.voiceUploadUrl(
        token: token,
        fileName: 'voice.m4a',
        contentType: 'audio/mp4',
      );
      final url = '${upload['url'] ?? upload['uploadUrl'] ?? ''}';
      final key = '${upload['objectKey'] ?? upload['key'] ?? ''}';
      if (url.isEmpty || key.isEmpty) throw Exception('语音上传地址无效');
      final bytes = await File(pathValue).readAsBytes();
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'audio/mp4'},
        body: bytes,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('语音上传失败');
      }
      final clientId = DateTime.now().microsecondsSinceEpoch.toString();
      final sent = await service.sendImMessage(
        token,
        widget.chat.conversationId,
        text: key,
        clientId: clientId,
        kind: 'audio',
        durationMs: 1000,
      );
      _mergeMessage(sent, status: 'sent');
      await ImLocalStore.saveMessages(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
        messages: messages,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      service.dispose();
    }
  }

  Future<void> _pickAndSendImage(
      {ImageSource source = ImageSource.gallery}) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    final connected = ImSession.instance.isConnected;
    if (token.isEmpty || !connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络未连接，图片未发送')),
        );
      }
      return;
    }
    try {
      final service = DDPostService();
      final upload = await service.postMediaUploadUrl(
        token: token,
        fileName: picked.name,
        contentType: 'image/${picked.name.split('.').last.toLowerCase()}',
        kind: 'image',
      );
      final uploadUrl = '${upload['uploadUrl'] ?? upload['url'] ?? ''}';
      final objectKey = '${upload['objectKey'] ?? upload['key'] ?? ''}';
      if (uploadUrl.isEmpty || objectKey.isEmpty) {
        throw Exception('图片上传地址无效');
      }
      final bytes = await picked.readAsBytes();
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': 'image/${picked.name.split('.').last.toLowerCase()}'
        },
        body: bytes,
      );
      service.dispose();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('图片上传失败');
      }
      final clientId = DateTime.now().microsecondsSinceEpoch.toString();
      final createdAt = DateTime.now().toIso8601String();
      final pending = <String, dynamic>{
        'id': 'local:$clientId',
        'clientId': clientId,
        'senderId': currentUserId,
        'text': objectKey,
        'kind': 'image',
        'createdAt': createdAt,
        'status': 'pending',
      };
      _mergeMessage(pending);
      await ImLocalStore.saveMessages(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
        messages: messages,
      );
      final sent = await service.sendImMessage(
        token,
        widget.chat.conversationId,
        text: objectKey,
        clientId: clientId,
        kind: 'image',
      );
      _mergeMessage(sent, status: 'sent');
      await ImLocalStore.saveMessages(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
        messages: messages,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _reportImMessage(Map<String, dynamic> message) async {
    final id = '${message['id'] ?? ''}';
    if (id.isEmpty || id.startsWith('local:')) return;
    const reasons = [
      '色情低俗',
      '政治敏感',
      '诈骗信息',
      '种族歧视',
      '攻击谩骂',
      '导流到站外',
      '违法违规',
      '涉未成年人',
    ];
    final reason = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _ChatReportPage(reasons: reasons)),
    );
    if (!mounted || reason == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    final service = DDPostService();
    try {
      await service.reportImMessage(
          token, widget.chat.conversationId, id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('举报已提交')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      service.dispose();
    }
  }

  Future<void> _showMessageMenu(Map<String, dynamic> message) async {
    final isMine = currentUserId.isNotEmpty &&
        '${message['senderId'] ?? ''}' == currentUserId;
    final status = '${message['status'] ?? 'sent'}';
    final createdAt = DateTime.tryParse('${message['createdAt'] ?? ''}');
    final canRecall = isMine &&
        status != 'recalled' &&
        status != 'deleted' &&
        createdAt != null &&
        DateTime.now().difference(createdAt).inSeconds <= 180;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (!isMine)
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('举报'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            if (canRecall)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('撤回'),
                onTap: () => Navigator.pop(context, 'recall'),
              ),
            if (status != 'deleted')
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: '${message['text'] ?? ''}'));
      return;
    }
    if (choice == 'report') {
      await _reportImMessage(message);
      return;
    }
    final id = '${message['id'] ?? ''}';
    if (choice == 'delete') {
      final index = messages.indexWhere((item) => '${item['id'] ?? ''}' == id);
      if (index >= 0) {
        final messageId = '${messages[index]['id'] ?? ''}';
        setState(() => messages.removeAt(index));
        await ImLocalStore.deleteLocalMessage(
          accountId: currentUserId,
          conversationId: widget.chat.conversationId,
          messageId: messageId,
        );
      }
      return;
    }
    if (id.isEmpty || id.startsWith('local:')) {
      if (choice == 'recall') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('消息尚未发送成功，无法撤回')),
          );
        }
      }
      return;
    }
    if (choice == 'recall') {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      final service = DDPostService();
      try {
        final recalled = await service.recallImMessage(
          token,
          widget.chat.conversationId,
          id,
        );
        final index = messages.indexWhere((item) =>
            '${item['id'] ?? ''}' == id ||
            '${item['clientId'] ?? ''}' == '${message['clientId'] ?? ''}');
        if (index >= 0) {
          setState(() => messages[index] = {
                ...messages[index],
                ...recalled,
                'status': 'recalled',
                'text': '',
                'recalledAt':
                    recalled['recalledAt'] ?? DateTime.now().toIso8601String(),
              });
          await ImLocalStore.saveMessages(
            accountId: currentUserId,
            conversationId: widget.chat.conversationId,
            messages: messages,
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$error')));
        }
      } finally {
        service.dispose();
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    if (blockedConversation) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前会话不可发送')),
        );
      }
      return;
    }
    final clientId = DateTime.now().microsecondsSinceEpoch.toString();
    messageController.clear();
    if (typing) {
      typing = false;
      typingTimer?.cancel();
      ImSession.instance.socket?.sendTyping(
          conversationId: widget.chat.conversationId, typing: false);
    }
    final pending = <String, dynamic>{
      'id': 'local:$clientId',
      'clientId': clientId,
      'senderId': currentUserId,
      'conversationId': widget.chat.conversationId,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
      'retryStartedAt': DateTime.now().toIso8601String(),
      'retryUntil':
          DateTime.now().add(const Duration(minutes: 1)).toIso8601String(),
    };
    _mergeMessage(pending);
    await ImLocalStore.saveMessages(
      accountId: currentUserId,
      conversationId: widget.chat.conversationId,
      messages: messages,
    );
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    final service = DDPostService();
    try {
      final sent = await service.sendImMessage(
        token,
        widget.chat.conversationId,
        text: text,
        clientId: clientId,
      );
      _mergeMessage(sent, status: 'sent');
      await ImLocalStore.saveMessages(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
        messages: messages,
      );
    } catch (_) {
      if (!mounted) return;
      final index = messages
          .indexWhere((item) => '${item['clientId'] ?? ''}' == clientId);
      if (index >= 0) {
        setState(() => messages[index] = {
              ...messages[index],
              'status': 'pending',
              'lastError': 'send_failed',
            });
        await ImLocalStore.saveMessages(
          accountId: currentUserId,
          conversationId: widget.chat.conversationId,
          messages: messages,
        );
      }
      unawaited(_retryTextViaApi(
        token: token,
        conversationId: widget.chat.conversationId,
        text: text,
        clientId: clientId,
      ));
    } finally {
      service.dispose();
    }
  }

  Future<void> _retryMessage(Map<String, dynamic> message) async {
    final clientId = '${message['clientId'] ?? ''}';
    final conversationId = widget.chat.conversationId;
    final text = '${message['text'] ?? ''}';
    if (clientId.isEmpty || text.isEmpty) return;
    setState(() {
      message['status'] = 'pending';
      message['lastError'] = null;
    });
    unawaited(ImLocalStore.saveMessages(
      accountId: currentUserId,
      conversationId: conversationId,
      messages: messages,
    ));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    unawaited(_retryTextViaApi(
      token: token,
      conversationId: conversationId,
      text: text,
      clientId: clientId,
    ));
  }

  Future<void> _retryTextViaApi({
    required String token,
    required String conversationId,
    required String text,
    required String clientId,
  }) async {
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final sent = await service.sendImMessage(
        token,
        conversationId,
        text: text,
        clientId: clientId,
      );
      if (!mounted) return;
      _mergeMessage(sent, status: 'sent');
      await ImLocalStore.saveMessages(
        accountId: currentUserId,
        conversationId: conversationId,
        messages: messages,
      );
    } catch (_) {
      // 全局 ImSession 负责继续重试并在窗口到期后发出失败事件。
    } finally {
      service.dispose();
    }
  }

  Future<void> _confirmDurableMessages(List<String> messageIds) async {
    if (messageIds.isEmpty || currentUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final durable = await ImLocalStore.durableMessages(
      accountId: currentUserId,
      conversationId: widget.chat.conversationId,
      messageIds: messageIds,
    );
    final confirmedIds = durable.map((row) => '${row['message_id']}').toList();
    if (confirmedIds.isEmpty) return;
    final service = DDPostService();
    try {
      await service.confirmImMessagesSynced(
        token,
        widget.chat.conversationId,
        confirmedIds,
      );
    } finally {
      service.dispose();
    }
  }

  Future<void> _markLatestRead() async {
    if (messages.isEmpty || currentUserId.isEmpty) return;
    final messageId = '${messages.last['id'] ?? ''}';
    if (messageId.isEmpty || messageId.startsWith('local:')) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      await service.markImConversationRead(
        token,
        widget.chat.conversationId,
        messageId,
      );
    } finally {
      service.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _chatAvatarFor(widget.chat),
            ),
            const SizedBox(width: 8),
            Text(widget.chat.name,
                style: Theme.of(context).textTheme.bodyLarge),
          ]),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
          ],
        ),
        body: Column(children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 42,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                initialSyncCompleted
                                    ? '选择一个聊天开始交流'
                                    : '暂无本地聊天记录',
                                style: TextStyle(
                                    color: Theme.of(context).hintColor),
                              ),
                              if (peerTyping && messages.isEmpty)
                                _TypingBubble(),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: messageScrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          reverse: false,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length + (peerTyping ? 1 : 0),
                          itemBuilder: (_, index) {
                            if (peerTyping && index == messages.length) {
                              return _TypingBubble();
                            }
                            final message = messages[index];
                            final isMine = currentUserId.isNotEmpty &&
                                '${message['senderId'] ?? ''}' == currentUserId;
                            final status = '${message['status'] ?? 'sent'}';
                            final isRecalled = status == 'recalled';
                            final isDeleted = status == 'deleted';
                            final isReadByPeer = isMine &&
                                peerReadMessageId != null &&
                                !'${message['id'] ?? ''}'
                                    .startsWith('local:') &&
                                int.tryParse('${message['id'] ?? ''}') !=
                                    null &&
                                int.tryParse(peerReadMessageId!) != null &&
                                int.parse('${message['id']}') <=
                                    int.parse(peerReadMessageId!);
                            final createdAt = DateTime.tryParse(
                                    '${message['createdAt'] ?? ''}')
                                ?.toLocal();
                            final timeText = createdAt == null
                                ? ''
                                : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
                            final previousCreatedAt = index > 0
                                ? DateTime.tryParse(
                                        '${messages[index - 1]['createdAt'] ?? ''}')
                                    ?.toLocal()
                                : null;
                            final showTime = createdAt != null &&
                                (previousCreatedAt == null ||
                                    createdAt
                                            .difference(previousCreatedAt)
                                            .inMinutes >=
                                        5);
                            return Column(
                              children: [
                                if (showTime)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Center(
                                      child: Text(
                                        timeText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        margin: EdgeInsets.only(
                                          bottom: 8,
                                          left: isMine ? 64 : 0,
                                          right: isMine ? 0 : 64,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isMine
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: Radius.circular(
                                                isMine ? 16 : 4),
                                            bottomRight: Radius.circular(
                                                isMine ? 4 : 16),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isMine
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onLongPress: () =>
                                                  _showMessageMenu(message),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  isRecalled || isDeleted
                                                      ? Text(
                                                          isRecalled
                                                              ? '消息已撤回'
                                                              : '消息已删除',
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .grey))
                                                      : message['kind'] ==
                                                              'image'
                                                          ? _imageMessageBody(
                                                              message)
                                                          : message['kind'] ==
                                                                  'audio'
                                                              ? InkWell(
                                                                  onTap: () =>
                                                                      _playAudioMessage(
                                                                          '${message['text'] ?? ''}'),
                                                                  child: Text(
                                                                    playingAudioKey ==
                                                                            '${message['text'] ?? ''}'
                                                                        ? '⏸ 播放中'
                                                                        : '🔊 播放语音',
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyLarge,
                                                                  ),
                                                                )
                                                              : Text(
                                                                  '${message['text'] ?? ''}',
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodyLarge,
                                                                ),
                                                  if (status == 'pending') ...[
                                                    const SizedBox(width: 6),
                                                    const SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 1.5),
                                                    ),
                                                  ],
                                                  if (status == 'failed')
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _retryMessage(
                                                              message),
                                                      child: const Icon(
                                                        Icons.error_outline,
                                                        size: 16,
                                                        color: Colors.orange,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (timeText.isNotEmpty)
                                              const SizedBox.shrink(),
                                          ],
                                        ),
                                      ),
                                      if (isReadByPeer)
                                        Positioned(
                                          left: isMine ? 60 : -1,
                                          bottom: 7,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: SizedBox(
                                                width: 3.5, height: 3.5),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (moreExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ComposerAction(
                          icon: Icons.camera_alt_outlined,
                          label: '拍摄',
                          onPressed: () => _pickAndSendImage(
                            source: ImageSource.camera,
                          ),
                        ),
                        _ComposerAction(
                          icon: Icons.photo_outlined,
                          label: '照片',
                          onPressed: _pickAndSendImage,
                        ),
                        _ComposerAction(
                          icon: Icons.phone_in_talk_outlined,
                          label: '语音通话',
                          onPressed: _startAudioCall,
                        ),
                        _ComposerAction(
                          icon: Icons.location_on_outlined,
                          label: '位置',
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('位置消息暂未接入')),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (emojiExpanded && !voiceMode)
                  SizedBox(
                    height: 180,
                    child: GridView.count(
                      crossAxisCount: 8,
                      padding: const EdgeInsets.all(10),
                      children: [
                        for (final emoji in [
                          '😀',
                          '😂',
                          '🤣',
                          '😊',
                          '😍',
                          '😘',
                          '😎',
                          '🤔',
                          '😭',
                          '😡',
                          '👍',
                          '👏',
                          '🙏',
                          '❤️',
                          '🎉',
                          '🔥',
                        ])
                          InkWell(
                            onTap: () {
                              final value = messageController.value;
                              final text = value.text;
                              final start = value.selection.start < 0
                                  ? text.length
                                  : value.selection.start;
                              final end = value.selection.end < 0
                                  ? start
                                  : value.selection.end;
                              messageController.value = value.copyWith(
                                text: text.replaceRange(start, end, emoji),
                                selection: TextSelection.collapsed(
                                  offset: start + emoji.length,
                                ),
                              );
                            },
                            child: Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 18, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() {
                          voiceMode = !voiceMode;
                          emojiExpanded = false;
                        }),
                        icon: Icon(voiceMode ? Icons.keyboard : Icons.mic_none),
                      ),
                      Expanded(
                        child: voiceMode
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPressStart: _startHoldRecording,
                                onLongPressMoveUpdate: _updateHoldRecording,
                                onLongPressEnd: _finishHoldRecording,
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    color: recordingVoice
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : null,
                                  ),
                                  child: recordingVoice
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _VoiceWave(
                                              active: !cancelVoice,
                                              color: cancelVoice
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .error
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              cancelVoice ? '松开取消' : '松开发送',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                          ],
                                        )
                                      : Text(
                                          '按住说话',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                ),
                              )
                            : TextField(
                                focusNode: messageFocusNode,
                                controller: messageController,
                                onChanged: _handleTypingChanged,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: InputDecoration(
                                  hintText: '输入消息',
                                  suffixIcon: IconButton(
                                    tooltip: '表情',
                                    onPressed: () => setState(() {
                                      emojiExpanded = !emojiExpanded;
                                      moreExpanded = false;
                                    }),
                                    icon: const Icon(
                                        Icons.sentiment_satisfied_alt),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                      ),
                      IconButton(
                        tooltip: '更多',
                        onPressed: () => setState(() {
                          moreExpanded = !moreExpanded;
                          emojiExpanded = false;
                        }),
                        icon: Icon(
                          moreExpanded ? Icons.close : Icons.add_circle_outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ]),
      );
}

class _ChatReportPage extends StatefulWidget {
  const _ChatReportPage({required this.reasons});
  final List<String> reasons;

  @override
  State<_ChatReportPage> createState() => _ChatReportPageState();
}

class _ChatReportPageState extends State<_ChatReportPage> {
  String? selected;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('举报聊天内容')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                child: Text(
                  '请选择最符合的举报原因，帮助我们准确处理',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.reasons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final reason = widget.reasons[index];
                    return RadioListTile<String>(
                      value: reason,
                      // ignore: deprecated_member_use
                      groupValue: selected,
                      title: Text(reason),
                      // ignore: deprecated_member_use
                      onChanged: (value) => setState(() => selected = value),
                      activeColor: Theme.of(context).colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                child: Column(
                  children: [
                    Text(
                      '聊天消息将发送给平台审核',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selected == null
                            ? null
                            : () => Navigator.pop(context, selected),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('提交'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _VoiceWave extends StatefulWidget {
  const _VoiceWave({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  State<_VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<_VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => SizedBox(
          width: 38,
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(5, (index) {
              final distance = (index - 2).abs();
              final value = widget.active
                  ? 0.35 + (1 - distance / 2) * _controller.value * 0.65
                  : 0.28;
              return Container(
                width: 3,
                height: 8 + value * 16,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      );
}

class _AudioCallPage extends StatefulWidget {
  const _AudioCallPage(
      {required this.call, required this.rtc, required this.token});
  final Map<String, dynamic> call;
  final Map<String, dynamic> rtc;
  final String token;

  @override
  State<_AudioCallPage> createState() => _AudioCallPageState();
}

class _AudioCallPageState extends State<_AudioCallPage> {
  bool muted = false;
  bool joined = false;
  bool remoteLeft = false;
  StreamSubscription<Map<String, dynamic>>? imEvents;

  @override
  void initState() {
    super.initState();
    AliyunRtcBridge.setEventHandler(_handleRtcEvent);
    imEvents = ImSession.instance.events.listen(_handleImEvent);
    unawaited(_joinRtc());
  }

  void _handleRtcEvent(String method, dynamic args) {
    if (!mounted) return;
    if (method == 'remoteLeft') {
      setState(() => remoteLeft = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('对方已挂断')),
      );
      unawaited(_finishRemoteHangup());
    } else if (method == 'error') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('RTC 连接失败：${args is Map ? args['code'] : ''}')),
      );
    }
  }

  void _handleImEvent(Map<String, dynamic> event) {
    if (event['type'] != 'call:update') return;
    final call = event['call'];
    if (call is! Map || '${call['id'] ?? ''}' != '${widget.call['id'] ?? ''}') {
      return;
    }
    final status = '${call['status'] ?? ''}';
    if (status == 'ended' || status == 'cancelled' || status == 'rejected') {
      if (mounted) {
        setState(() => remoteLeft = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对方已挂断')),
        );
      }
      unawaited(_finishRemoteHangup());
    }
  }

  Future<void> _finishRemoteHangup() async {
    await AliyunRtcBridge.leave();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _joinRtc() async {
    try {
      await AliyunRtcBridge.subscribeRemoteAudio(true);
      await AliyunRtcBridge.join(widget.rtc);
      if (mounted) setState(() => joined = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _leave() async {
    try {
      await AliyunRtcBridge.leave();
      final service = DDPostService();
      try {
        await service.updateImCall(
            widget.token, '${widget.call['id'] ?? ''}', 'hangup');
      } finally {
        service.dispose();
      }
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    imEvents?.cancel();
    AliyunRtcBridge.setEventHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('语音通话')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                  radius: 42, child: Icon(Icons.person, size: 42)),
              const SizedBox(height: 16),
              Text(joined ? '通话中' : '正在连接',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: () async {
                      final next = !muted;
                      await AliyunRtcBridge.setMuted(next);
                      if (mounted) setState(() => muted = next);
                    },
                    icon: Icon(muted ? Icons.mic_off : Icons.mic),
                  ),
                  const SizedBox(width: 28),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _leave,
                    icon: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}

class DDShell extends StatefulWidget {
  const DDShell({super.key});
  @override
  State<DDShell> createState() => _DDShellState();
}

class _DDShellState extends State<DDShell> {
  int index = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = const [
      HomePage(),
      DiscoverPage(),
      ChatPage(),
      DDProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          height: 60,
          selectedIndex: index,
          onDestinationSelected: (value) {
            HapticFeedback.selectionClick();
            _VideoPlaybackRegistry.stopAll();
            setState(() => index = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '主页',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: '聊天',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      );
}

class _PageErrorState extends StatelessWidget {
  const _PageErrorState(
      {required this.title, required this.subtitle, this.onRetry});
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
        ),
      );
}
