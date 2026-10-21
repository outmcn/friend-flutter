part of 'main.dart';

final Map<String, ImageProvider> _avatarProviderCache = {};

/// Shows recoverable chat errors at the top of the current page instead of
/// placing them over the composer as a bottom SnackBar.
void _showTopErrorBanner(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(
    MaterialBanner(
      leading: const Icon(Icons.error_outline, color: Colors.redAccent),
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

ImageProvider _cachedAvatarProvider(String url) =>
    _avatarProviderCache.putIfAbsent(url, () => NetworkImage(url));

Future<void> _sendSharedPostMessage({
  required String conversationId,
  required int postId,
  required String text,
  required String author,
  required String content,
  required String thumbnailUrl,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final accountId = prefs.getString('friend.auth.userId') ?? '';
  if (accountId.isEmpty) throw Exception('登录状态已失效，请重新登录');
  final clientId = 'share-$postId-${DateTime.now().microsecondsSinceEpoch}';
  final result = await MessageSendCoordinator.instance.send(
    accountId: accountId,
    message: {
      'id': 'local:$clientId',
      'clientId': clientId,
      'conversationId': conversationId,
      'senderId': accountId,
      'text': text.trim().isEmpty ? '分享了一条动态' : text.trim(),
      'kind': 'text',
      'metadata': {
        'postId': postId,
        'type': 'post_share',
        'author': author,
        'content': content,
        'thumbnailUrl': thumbnailUrl,
      },
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    },
  );
  if ('${result['status'] ?? ''}' == 'failed') {
    throw Exception('${result['lastError'] ?? '动态发送失败'}');
  }
}

void _dismissIncomingDialog(BuildContext? dialogContext) {
  if (dialogContext == null || !dialogContext.mounted) return;
  final route = ModalRoute.of(dialogContext);
  if (route?.isCurrent == true) Navigator.of(dialogContext).pop();
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  int? selectedChat;
  final messageController = TextEditingController();
  final userSearchController = TextEditingController();
  List<_ChatPreview> conversations = [];
  StreamSubscription<Map<String, dynamic>>? listEvents;
  Timer? incomingPoll;
  bool incomingRequestRunning = false;
  bool loading = true;
  bool conversationCacheLoaded = false;
  String? loadError;
  final Map<String, String> _avatarPaths = {};
  final Set<String> _pinnedConversationIds = <String>{};
  final Set<String> _mutedConversationIds = <String>{};
  bool callDialogShowing = false;
  BuildContext? incomingDialogContext;
  bool outgoingCallStarting = false;
  String? activeCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadConversations(showLoading: false));
    listEvents = ImSession.instance.events.listen(_handleListEvent);
    incomingPoll = Timer.periodic(const Duration(seconds: 3),
        (_) => unawaited(_loadCurrentRingingCall()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadConversations(showLoading: false));
      // 仅在恢复前台时读取当前响铃来电，不读取历史通话记录。
      unawaited(_loadCurrentRingingCall());
    }
  }

  void _handleListEvent(Map<String, dynamic> event) {
    if (event['type'] == 'message:new' || event['type'] == 'message:recalled') {
      unawaited(_loadConversations(showLoading: false));
    }
    if (event['type'] == 'call:update' || event['type'] == 'call:incoming') {
      final call = event['call'];
      if (call is Map) {
        if ('${call['id']}' == activeCallId && call['status'] != 'ringing') {
          _dismissIncomingDialog(incomingDialogContext);
        }
        unawaited(_refreshCallPreview(call.cast<String, dynamic>()));
      }
    }
    if (event['type'] == 'call:incoming') {
      final call = event['call'];
      if (call is Map) {
        final item = call.cast<String, dynamic>();
        final callerId = '${item['callerId'] ?? item['caller_id'] ?? ''}';
        final calleeId = '${item['calleeId'] ?? item['callee_id'] ?? ''}';
        final selfId = ImSession.instance.userId ?? '';
        if (callerId.isNotEmpty &&
            (calleeId.isEmpty || calleeId == selfId) &&
            callerId != selfId) {
          unawaited(_showIncomingCall(item));
        }
      }
    }
  }

  Future<void> _refreshCallPreview(Map<String, dynamic> call) async {
    final accountId = ImSession.instance.userId;
    final conversationId = '${call['conversationId'] ?? ''}';
    if (accountId == null) return;
    final latest = await ImLocalStore.latestMessage(
        accountId: accountId, conversationId: conversationId);
    if (!mounted || latest == null) return;
    final index = conversations
        .indexWhere((chat) => chat.conversationId == conversationId);
    if (index < 0) return;
    final chat = conversations[index];
    final preview = _localMessagePreview(latest) ?? chat.preview;
    if (preview == chat.preview) return;
    setState(() {
      conversations[index] = _ChatPreview(
          chat.name,
          preview,
          chat.avatarUrl,
          chat.avatarKey,
          chat.peerUserId,
          chat.conversationId,
          chat.unreadCount,
          chat.peerReadMessageId,
          chat.updatedAt,
          chat.kind);
    });
    await ImLocalStore.saveConversations(
        accountId: accountId,
        conversations: conversations.map((chat) => chat.toCache()).toList());
  }

  Future<void> _loadCurrentRingingCall() async {
    if (incomingRequestRunning || !mounted || callDialogShowing) return;
    incomingRequestRunning = true;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty || !mounted) return;
    final service = DDPostService();
    try {
      final calls = await service.fetchPendingImCalls(token);
      final selfId = ImSession.instance.userId ??
          prefs.getString('friend.auth.userId') ??
          '';
      final incoming = calls.where((call) {
        final callerId = '${call['callerId'] ?? call['caller_id'] ?? ''}';
        final calleeId = '${call['calleeId'] ?? call['callee_id'] ?? ''}';
        return callerId.isNotEmpty &&
            (calleeId.isEmpty || calleeId == selfId) &&
            callerId != selfId;
      }).toList();
      for (final call in incoming) {
        await ImSession.instance.saveCall(call, eventType: 'call:incoming');
      }
    } catch (_) {
      // 当前响铃来电读取失败不影响聊天页面。
    } finally {
      incomingRequestRunning = false;
      service.dispose();
    }
  }

  Future<void> _showIncomingCall(Map<String, dynamic> call) async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        call['status'] != 'ringing') {
      return;
    }
    final callId = '${call['id'] ?? ''}';
    if (callId.isNotEmpty && activeCallId != null) return;
    activeCallId = callId;
    final selfId = ImSession.instance.userId ?? '';
    final callerId = '${call['callerId'] ?? call['caller_id'] ?? ''}';
    final calleeId = '${call['calleeId'] ?? call['callee_id'] ?? ''}';
    if (callerId.isEmpty ||
        (calleeId.isNotEmpty && calleeId != selfId) ||
        callerId == selfId) {
      activeCallId = null;
      return;
    }
    if (!mounted || callId.isEmpty || callDialogShowing) {
      activeCallId = null;
      return;
    }
    callDialogShowing = true;
    try {
      final accepted = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          incomingDialogContext = dialogContext;
          return AlertDialog(
            title: const Text('来电'),
            content: Text(
                '${call['callerName'] ?? call['nickname'] ?? '对方'} 邀请您进行语音通话'),
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
          );
        },
      );
      if (!mounted || accepted == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) return;
      if (accepted == 'answer') {
        if (mounted) _showTopErrorBanner(context, '实时语音通话暂未开放');
        return;
      }      final service = DDPostService();
      try {
        final result =
            await ImSession.instance.updateCall(token, callId, accepted);
        if (accepted == 'answer' && mounted) {
          final answeredCall =
              (result['call'] as Map?)?.cast<String, dynamic>() ?? call;
          final rtc = (result['rtc'] as Map?)?.cast<String, dynamic>() ?? {};
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _AudioCallPage(
              call: answeredCall,
              rtc: rtc,
              token: token,
            ),
          ));
        }
      } finally {
        service.dispose();
      }
    } finally {
      incomingDialogContext = null;
      callDialogShowing = false;
      activeCallId = null;
    }
  }

  Future<void> _cacheAvatar(_ChatPreview chat) async {
    final key = chat.avatarKey ?? '';
    if (key.isEmpty || _avatarPaths.containsKey(key)) return;
    final local = await ImLocalStore.avatarPath(key);
    if (local != null && mounted) {
      setState(() => _avatarPaths[key] = local);
    }
    // 聊天页面只读取本地头像，不在这里联网刷新。
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
      _pinnedConversationIds
        ..clear()
        ..addAll(cachedRows
            .where((row) => row['pinned'] == true)
            .map((row) => '${row['conversationId'] ?? ''}'));
      _mutedConversationIds
        ..clear()
        ..addAll(cachedRows
            .where((row) => row['muted'] == true)
            .map((row) => '${row['conversationId'] ?? ''}'));
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
      final latest = accountId.isEmpty
          ? <String, Map<String, dynamic>>{}
          : await ImLocalStore.latestMessages(accountId);
      final locallyDeleted = <String>{};
      if (accountId.isNotEmpty) {
        for (final row in rows) {
          final lastMessageId = row.lastMessage?.id ?? '';
          if (lastMessageId.isNotEmpty &&
              await ImLocalStore.isLocalMessageDeleted(
                accountId: accountId,
                conversationId: row.id,
                messageId: lastMessageId,
              )) {
            locallyDeleted.add(row.id);
          }
        }
      }
      for (final row in rows) {
        final local = latest[row.id];
        final localPreview = local == null
            ? null
            : _localMessagePreview({
                ...local,
                'kind': '${local['kind'] ?? 'text'}',
                'status': '${local['status'] ?? 'sent'}',
                'metadata': local['metadata'] is Map
                    ? local['metadata']
                    : (local['metadata'] is String
                        ? _decodeConversationMetadata(local['metadata'])
                        : null),
                'localDurationSeconds': local['local_duration_seconds'] ??
                    local['localDurationSeconds'],
              });
        // Local SQLite wins after a local delete; only fall back to the server
        // preview when no local message is available.
        final preview = localPreview ??
            (locallyDeleted.contains(row.id)
                ? '开始一段新的聊天'
                : _conversationLastMessagePreview(row.lastMessage) ??
                    '开始一段新的聊天');
        mapped.add(_ChatPreview(
          row.peer?.nickname ?? '会话 ${row.id}',
          preview,
          row.peer?.avatarUrl,
          row.peer?.avatarKey,
          row.peer?.id,
          row.id,
          _mutedConversationIds.contains(row.id) ? 0 : row.unreadCount,
          row.peerReadMessageId,
          row.updatedAt,
          row.kind,
          _pinnedConversationIds.contains(row.id),
        ));
      }
      mapped.sort((a, b) {
        final ap = _pinnedConversationIds.contains(a.conversationId);
        final bp = _pinnedConversationIds.contains(b.conversationId);
        if (ap != bp) return ap ? -1 : 1;
        return 0;
      });
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
    incomingPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
            tooltip: '通讯录',
            onPressed: _openContacts,
            icon: const Icon(TIcons.user_list),
          ),
          IconButton(
            tooltip: '搜索',
            onPressed: _openUserSearch,
            icon: _tdIcon('search'),
          ),
          IconButton(
            tooltip: '添加',
            onPressed: _openNewChat,
            icon: _tdIcon('add'),
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
        orElse: () => _ChatPreview('${selected['nickname'] ?? '用户'}',
            '开始一段新的聊天', null, null, '${selected['id'] ?? ''}', id, 0),
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
        _showTopErrorBanner(context, '$error');
      }
    }
  }

  Future<void> _openUserSearch() async {
    userSearchController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewChatSheet(controller: userSearchController),
    );
  }

  Future<void> _openContacts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ContactsPage(
          conversations: conversations,
          avatarFor: _avatarFor,
          onOpen: _openConversation,
        ),
      ),
    );
  }

  Future<void> _pushChatDetail(_ChatPreview chat, String currentUserId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatDetailPage(
          chat: chat,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  Future<void> _openConversation(_ChatPreview chat) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('friend.auth.userId') ?? '';
    if (!mounted) return;
    await _stopListSocket();
    if (!mounted) return;
    await _pushChatDetail(chat, currentUserId);
    if (mounted) {
      unawaited(_loadConversations(showLoading: false));
      unawaited(_restartListSocket());
    }
  }

  Widget _conversationList(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
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
      return _neutralAvatar();
    }
    return _cachedAvatarProvider(url);
  }

  Future<void> _togglePinnedConversation(_ChatPreview chat) async {
    final pinned = !_pinnedConversationIds.contains(chat.conversationId);
    setState(() {
      if (pinned) {
        _pinnedConversationIds.add(chat.conversationId);
      } else {
        _pinnedConversationIds.remove(chat.conversationId);
      }
      final index = conversations.indexWhere(
          (item) => item.conversationId == chat.conversationId);
      if (index >= 0) {
        conversations[index] = chat.copyWith(pinned: pinned);
      }
      conversations.sort((a, b) {
        final ap = _pinnedConversationIds.contains(a.conversationId);
        final bp = _pinnedConversationIds.contains(b.conversationId);
        if (ap != bp) return ap ? -1 : 1;
        return 0;
      });
    });
    final accountId = ImSession.instance.userId ??
        (await SharedPreferences.getInstance()).getString('friend.auth.userId') ?? '';
    if (accountId.isNotEmpty) {
      await ImLocalStore.saveConversations(
        accountId: accountId,
        conversations: conversations.map((item) => item.toCache()).toList(),
      );
    }
  }

  Future<void> _toggleMutedConversation(_ChatPreview chat) async {
    final muted = !_mutedConversationIds.contains(chat.conversationId);
    setState(() {
      if (muted) {
        _mutedConversationIds.add(chat.conversationId);
      } else {
        _mutedConversationIds.remove(chat.conversationId);
      }
      final index = conversations.indexWhere(
          (item) => item.conversationId == chat.conversationId);
      if (index >= 0) {
        conversations[index] = chat.copyWith(
          muted: muted,
          unreadCount: muted ? 0 : chat.unreadCount,
        );
      }
    });
    final accountId = ImSession.instance.userId ??
        (await SharedPreferences.getInstance()).getString('friend.auth.userId') ?? '';
    if (accountId.isNotEmpty) {
      await ImLocalStore.saveConversations(
        accountId: accountId,
        conversations: conversations.map((item) => item.toCache()).toList(),
      );
    }
  }

  Future<void> _hideConversationPreview(_ChatPreview chat) async {
    setState(() => conversations.removeWhere(
        (item) => item.conversationId == chat.conversationId));
    final accountId = ImSession.instance.userId ??
        (await SharedPreferences.getInstance()).getString('friend.auth.userId') ?? '';
    if (accountId.isNotEmpty) {
      await ImLocalStore.saveConversations(
        accountId: accountId,
        conversations: conversations.map((item) => item.toCache()).toList(),
      );
    }
  }

  Future<void> _deleteConversationPreview(_ChatPreview chat) async {
    await _hideConversationPreview(chat);
    final accountId = ImSession.instance.userId ??
        (await SharedPreferences.getInstance()).getString('friend.auth.userId') ?? '';
    if (accountId.isNotEmpty) {
      await ImLocalStore.clearConversation(
        accountId: accountId,
        conversationId: chat.conversationId,
      );
    }
  }

  Widget _chatPreviewTile(BuildContext context, _ChatPreview chat, int index) {
    return Slidable(
      key: ValueKey('conversation-${chat.conversationId}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 2 / 3,
        children: [
          SlidableAction(
            onPressed: (_) => _togglePinnedConversation(chat),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            icon: _pinnedConversationIds.contains(chat.conversationId)
                ? Icons.push_pin_outlined
                : Icons.push_pin,
            label: _pinnedConversationIds.contains(chat.conversationId)
                ? '取消置顶'
                : '置顶',
          ),
          SlidableAction(
            onPressed: (_) => _deleteConversationPreview(chat),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '删除',
          ),
        ],
      ),
      child: Container(
        color: _pinnedConversationIds.contains(chat.conversationId)
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.28)
              : Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getString('friend.auth.userId') ?? '';
          if (!context.mounted) return;
          await _stopListSocket();
          if (!context.mounted) return;
          await _pushChatDetail(chat, currentUserId);
          if (mounted) {
            unawaited(_loadConversations(showLoading: false));
            unawaited(_restartListSocket());
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(radius: 24, backgroundImage: _avatarFor(chat)),
                  if (chat.online) Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 48 * .30,
                      height: 48 * .30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759),
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(chat.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyLarge),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatDDTime(chat.updatedAt ?? ''),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).hintColor)),
                          ],
                        ),
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
                              chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(chat.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Theme.of(context).hintColor)),
                        ),
                        if (_pinnedConversationIds.contains(chat.conversationId))
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.lock_outline,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary,
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
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _chatDetail(BuildContext context, _ChatPreview chat) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                    onPressed: () => setState(() => selectedChat = null),
                    icon: const Icon(TIcons.rollback)),
                CircleAvatar(radius: 20, backgroundImage: _neutralAvatar()),
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

String _callPreviewStatus(Map<String, dynamic> row) => ImCall.statusText(row);

Map<String, dynamic>? _decodeConversationMetadata(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is! String || value.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } catch (_) {
    return null;
  }
}

String? _localMessagePreview(Map<String, dynamic>? row) {
  if (row == null) return null;
  final status = '${row['status'] ?? 'sent'}';
  if (status == 'recalled') return '消息已撤回';
  if (status == 'deleted') return '消息已删除';
  final metadata = row['metadata'];
  if (metadata is Map && '${metadata['type'] ?? ''}' == 'post_share') {
    final author = '${metadata['author'] ?? ''}'.trim();
    return author.isEmpty ? '分享' : '分享：$author 的动态';
  }
  final kind = '${row['kind'] ?? 'text'}';
  if (kind == 'call') {
    return '语音通话 · ${_callPreviewStatus(row)}';
  }
  if (kind == 'image') return '[图片]';
  if (kind == 'audio') return '[语音]';
  return '${row['text'] ?? ''}';
}

String? _conversationLastMessagePreview(DDImLastMessage? message) {
  if (message == null) return null;
  if (message.recalledAt != null) return '消息已撤回';
  if (message.deletedAt != null) return '消息已删除';
  if (message.metadata?['type'] == 'post_share') {
    final author = '${message.metadata?['author'] ?? ''}'.trim();
    return author.isEmpty ? '分享' : '分享：$author 的动态';
  }
  switch (message.kind) {
    case 'audio':
      return '[语音]';
    case 'image':
      return '[图片]';
    case 'location':
      return '[位置]';
    case 'call':
      return '[语音通话]';
    default:
      final text = message.text.trim();
      if (text.startsWith('分享：')) return text;
      return text.isEmpty ? null : text;
  }
}

class _ConversationSwipeButton extends StatelessWidget {
  const _ConversationSwipeButton({
    required this.color,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final Color color;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        height: double.infinity,
        child: Material(
          color: color,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}

class _ChatPreview {
  _ChatPreview(this.name, this.preview, this.avatarUrl, this.avatarKey,
      this.peerUserId, this.conversationId, this.unreadCount,
      [this.peerReadMessageId, this.updatedAt, this.kind = 'dm', this.pinned = false, this.muted = false, this.online = false, this.peerLatitude, this.peerLongitude]);
  final String name;
  final String preview;
  final String? avatarUrl;
  final String? avatarKey;
  final String? peerUserId;
  final String conversationId;
  final int unreadCount;
  final String? peerReadMessageId;
  final String? updatedAt;
  final String kind;
  final bool pinned;
  final bool muted;
  final bool online;
  final double? peerLatitude;
  final double? peerLongitude;

  factory _ChatPreview.fromCache(Map<String, dynamic> row) => _ChatPreview(
        '${row['name'] ?? '用户'}',
        '${row['preview'] ?? ''}',
        row['avatarUrl'] as String?,
        row['avatarKey'] as String?,
        row['peerUserId']?.toString() ?? row['userId']?.toString(),
        '${row['conversationId'] ?? ''}',
        (row['unreadCount'] as num?)?.toInt() ?? 0,
        row['peerReadMessageId']?.toString(),
        row['updatedAt']?.toString(),
        '${row['kind'] ?? 'dm'}',
        row['pinned'] == true,
        row['muted'] == true,
        row['online'] == true,
        (row['peerLatitude'] as num?)?.toDouble(),
        (row['peerLongitude'] as num?)?.toDouble(),
      );

  _ChatPreview copyWith({bool? pinned, bool? muted, int? unreadCount}) => _ChatPreview(
        name,
        preview,
        avatarUrl,
        avatarKey,
        peerUserId,
        conversationId,
        unreadCount ?? this.unreadCount,
        peerReadMessageId,
        updatedAt,
        kind,
        pinned ?? this.pinned,
        muted ?? this.muted,
        online,
      );

  Map<String, dynamic> toCache() => {
        'name': name,
        'preview': preview,
        'avatarUrl': avatarUrl,
        'avatarKey': avatarKey,
        'peerUserId': peerUserId,
        'conversationId': conversationId,
        'unreadCount': unreadCount,
        'peerReadMessageId': peerReadMessageId,
        'updatedAt': updatedAt,
        'kind': kind,
        'pinned': pinned,
        'muted': muted,
        'online': online,
        'peerLatitude': peerLatitude,
        'peerLongitude': peerLongitude,
      };
}

ImageProvider _chatAvatarFor(_ChatPreview chat) {
  final url = chat.avatarUrl;
  if (url == null || url.isEmpty) return _neutralAvatar();
  return _cachedAvatarProvider(url);
}

ImageProvider _neutralAvatar() =>
    const AssetImage('assets/figma/avatar-placeholder.png');

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
  ImageProvider get avatar => _chatAvatarFor(chat);
  @override
  State<_ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatRadarPanel extends StatefulWidget {
  const _ChatRadarPanel({required this.avatar, required this.peerLatitude, required this.peerLongitude});
  final ImageProvider avatar;
  final double? peerLatitude;
  final double? peerLongitude;
  @override State<_ChatRadarPanel> createState() => _ChatRadarPanelState();
}

class _ChatRadarPanelState extends State<_ChatRadarPanel> {
  double heading = 0;
  double? myLatitude;
  double? myLongitude;
  StreamSubscription<MagnetometerEvent>? _magnetometer;
  @override
  void initState() { super.initState(); _loadLocation(); _magnetometer = magnetometerEvents.listen((e) { final v=math.atan2(e.y,e.x)*180/math.pi; if(mounted)setState(()=>heading=v); }); }
  Future<void> _loadLocation() async { final p=await SharedPreferences.getInstance(); if(!mounted)return; setState(() { myLatitude=p.getDouble('dd.location.latitude'); myLongitude=p.getDouble('dd.location.longitude'); }); }
  @override void dispose(){_magnetometer?.cancel();super.dispose();}
  double? get distance { if(myLatitude==null||myLongitude==null||widget.peerLatitude==null||widget.peerLongitude==null)return null; const r=6371.0; final a1=myLatitude!*math.pi/180,a2=widget.peerLatitude!*math.pi/180, da=(widget.peerLatitude!-myLatitude!)*math.pi/180,dl=(widget.peerLongitude!-myLongitude!)*math.pi/180; final h=math.sin(da/2)*math.sin(da/2)+math.cos(a1)*math.cos(a2)*math.sin(dl/2)*math.sin(dl/2); return 2*r*math.asin(math.sqrt(h)); }
  double? get bearing { if(myLatitude==null||myLongitude==null||widget.peerLatitude==null||widget.peerLongitude==null)return null; final a1=myLatitude!*math.pi/180,a2=widget.peerLatitude!*math.pi/180, dl=(widget.peerLongitude!-myLongitude!)*math.pi/180; return (math.atan2(math.sin(dl)*math.cos(a2),math.cos(a1)*math.sin(a2)-math.sin(a1)*math.cos(a2)*math.cos(dl))*180/math.pi+360)%360; }
  @override Widget build(BuildContext context)=>SizedBox(width:100,height:160,child:DecoratedBox(decoration:BoxDecoration(color:const Color(0xE6101020),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0x554C4CFF))),child:Stack(alignment:Alignment.center,children:[Positioned(top:6,child:Text(distance==null?'位置未知':'相距 ${distance!.toStringAsFixed(1)}km',style:const TextStyle(color:Colors.white,fontSize:11))),CustomPaint(size:const Size(86,108),painter:_RadarPainter(bearing:bearing==null?null:bearing!-heading,avatar:widget.avatar)),const Positioned(top:28,child:Text('北',style:TextStyle(color:Colors.white54,fontSize:9))),const Positioned(bottom:8,child:Text('南',style:TextStyle(color:Colors.white54,fontSize:9))),const Positioned(left:5,child:Text('西',style:TextStyle(color:Colors.white54,fontSize:9))),const Positioned(right:5,child:Text('东',style:TextStyle(color:Colors.white54,fontSize:9)))])));
}

class _RadarPainter extends CustomPainter { _RadarPainter({required this.bearing,required this.avatar}); final double? bearing; final ImageProvider avatar; @override void paint(Canvas c,Size s){final o=Offset(s.width/2,s.height/2+8),r=s.shortestSide*.42,ring=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=const Color(0x664C4CFF);for(final k in [1.0,.72,.44])c.drawCircle(o,r*k,ring);c.drawCircle(o,4,Paint()..color=const Color(0xFF34C759));if(bearing==null)return;final a=bearing!*math.pi/180;final sector=Path()..moveTo(o.dx,o.dy)..lineTo(o.dx+math.sin(-.22)*r,o.dy-math.cos(-.22)*r)..arcTo(Rect.fromCircle(center:o,radius:r),-.22-math.pi/2,.44,false)..close();c.drawPath(sector,Paint()..color=const Color(0x334CFFD9));final p=Offset(o.dx+math.sin(a)*r,o.dy-math.cos(a)*r);c.drawCircle(p,5,Paint()..color=const Color(0xFF59D9FF));} @override bool shouldRepaint(covariant _RadarPainter old)=>old.bearing!=bearing;}

class _ChatDetailPageState extends State<_ChatDetailPage> {
  final messageController = TextEditingController();
  final messageFocusNode = FocusNode();
  StreamSubscription<Map<String, dynamic>>? eventSubscription;
  final messages = <Map<String, dynamic>>[];
  final callRecords = <Map<String, dynamic>>[];
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
  bool outgoingCallStarting = false;
  bool callDialogShowing = false;
  BuildContext? incomingDialogContext;
  String? activeCallId;
  final Map<String, String> imageFiles = {};
  String? playingAudioKey;
  Timer? typingTimer;
  bool voiceMode = false;
  AudioRecorder? holdRecorder;
  String? holdRecordingPath;
  bool recordingVoice = false;
  bool cancelVoice = false;
  Offset? holdStartPosition;
  bool sendingLocation = false;
  bool moreExpanded = false;
  bool emojiExpanded = false;
  bool avatarsReady = false;
  ImageProvider? myAvatarProvider;
  ImageProvider? peerAvatarProvider;
  String? myAvatarPath;
  String? peerAvatarPath;

  @override
  void initState() {
    super.initState();
    messageScrollController.addListener(_handleMessageScroll);
    unawaited(_loadChatAvatars());
    unawaited(_connectIm());
  }

  Future<void> _loadChatAvatars() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final myKey = prefs.getString('friend.profile.avatarKey')?.trim() ?? '';
      final myUrl = prefs.getString('friend.profile.avatarUrl')?.trim() ?? '';
      final peerKey = (widget.chat.avatarKey ?? '').trim();
      final cachedMy = myKey.isNotEmpty
          ? await ImLocalStore.avatarPath(myKey)
          : (myUrl.isNotEmpty
              ? await _PermanentImageCache.localPath(myUrl)
              : null);
      final cachedPeer =
          peerKey.isEmpty ? null : await ImLocalStore.avatarPath(peerKey);
      if (!mounted) return;
      setState(() {
        myAvatarPath = cachedMy;
        peerAvatarPath = cachedPeer;
        if (cachedMy != null) myAvatarProvider = FileImage(File(cachedMy));
        if (cachedPeer != null) {
          peerAvatarProvider = FileImage(File(cachedPeer));
        }
        avatarsReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => avatarsReady = true);
    }
  }

  ImageProvider _stableAvatar(ImageProvider? provider) =>
      provider ?? _neutralAvatar();

  void _scrollToLatest({bool force = false}) {
    // 详情列表使用 reverse=true，最新消息天然位于底部，不需要手动跳转。
  }

  bool _isNearBottom({double threshold = 96}) {
    if (!messageScrollController.hasClients) return true;
    final position = messageScrollController.position;
    return position.maxScrollExtent - position.pixels <= threshold;
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
    peerReadMessageId = widget.chat.peerReadMessageId;
    eventSubscription = ImSession.instance.events.listen(_handleImEvent);
    try {
      await ImLocalStore.migrateLegacyAudioKeys();
      final cached = await ImLocalStore.messages(
        accountId: currentUserId,
        conversationId: widget.chat.conversationId,
      );
      for (final state in MessageSendCoordinator.instance
          .snapshot(currentUserId, widget.chat.conversationId)) {
        final index = cached.indexWhere((row) =>
            row['clientId'] == state['clientId'] &&
            ['pending', 'failed'].contains(row['status']));
        if (index >= 0) cached[index] = state;
      }
      for (final item in cached) {
        if ('${item['kind'] ?? ''}' == 'call') {
          item['_timelineKind'] = 'call';
        }
      }
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
      cached.removeWhere((item) =>
          !ImCall.isCall(item) && deletedIds.contains('${item['id']}'));
      final normalized = <String, Map<String, dynamic>>{};
      for (final item in cached) {
        final key =
            '${ImCall.isCall(item) ? 'call' : 'message'}:${item['clientId'] ?? item['id'] ?? ''}';
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToLatest(force: true);
      });
    } catch (_) {
      if (mounted) setState(() => initialSyncCompleted = true);
    }
    final ringing = messages.where((call) {
      final started = DateTime.tryParse('${call['createdAt'] ?? ''}');
      return ImCall.isCall(call) &&
          call['status'] == 'ringing' &&
          '${call['calleeId']}' == currentUserId &&
          started != null &&
          DateTime.now().difference(started).inSeconds < 30;
    }).toList();
    if (ringing.isNotEmpty) unawaited(_showIncomingCall(ringing.last));
    unawaited(_restoreRingingCalls(token));
  }

  // Unread-only sync is represented by the live IM session events.
  Future<void> _redialCall(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('语音通话'),
        content: const Text('是否拨打语音通话？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('拨打'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final result = await ImSession.instance.startCall(
        token,
        widget.chat.conversationId,
      );
      if (!mounted) return;
      final call = (result['call'] as Map?)?.cast<String, dynamic>() ?? {};
      activeCallId = '${call['id'] ?? ''}';
      final rtc = (result['rtc'] as Map?)?.cast<String, dynamic>() ?? {};
      if (call.isNotEmpty) {
        await _saveCallEvent(call);
      }
      if (!mounted) return;
      final page = MaterialPageRoute(
        builder: (_) => _AudioCallPage(call: call, rtc: rtc, token: token),
      );
      await Navigator.of(context).push(page);
      activeCallId = null;
    } catch (error) {
      if (mounted) {
        _showTopErrorBanner(context, '$error');
      }
    } finally {
      service.dispose();
    }
  }

  List<Map<String, dynamic>> get _timeline {
    final combined = <Map<String, dynamic>>[...messages];
    combined.sort((a, b) => _messageTime(b).compareTo(_messageTime(a)));
    return combined;
  }

  Future<void> _saveCallEvent(Map<String, dynamic> call) async {
    if (!mounted ||
        '${call['conversationId'] ?? ''}' != widget.chat.conversationId) {
      return;
    }
    final normalizedCall = {
      ...call,
      if (call['callerId'] == null && call['caller_id'] != null)
        'callerId': '${call['caller_id']}',
      if (call['calleeId'] == null && call['callee_id'] != null)
        'calleeId': '${call['callee_id']}',
    };
    final index = messages.indexWhere(
        (item) => ImCall.isCall(item) && '${item['id']}' == '${call['id']}');
    setState(() {
      if (index >= 0) {
        messages[index] = ImCall.merge(messages[index], normalizedCall);
      } else {
        messages.add(ImCall.merge({}, normalizedCall));
      }
      messages.sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
    });
  }

  Future<void> _restoreRingingCalls(String token) async {
    final service = DDPostService();
    try {
      final pending = await service.fetchPendingImCalls(token);
      for (final call in pending) {
        if ('${call['conversationId']}' == widget.chat.conversationId &&
            call['status'] == 'ringing') {
          await ImSession.instance.saveCall(call, eventType: 'call:incoming');
        }
      }
    } catch (_) {
      // Keep the local timeline available while offline.
    } finally {
      service.dispose();
    }
  }

  Future<void> _showIncomingCall(Map<String, dynamic> call) async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        call['status'] != 'ringing') {
      return;
    }
    final callId = '${call['id'] ?? ''}';
    if (callId.isEmpty || activeCallId != null || callDialogShowing) return;
    final callerId = '${call['callerId'] ?? call['caller_id'] ?? ''}';
    final calleeId = '${call['calleeId'] ?? call['callee_id'] ?? ''}';
    if (callerId.isEmpty ||
        callerId == currentUserId ||
        (calleeId.isNotEmpty && calleeId != currentUserId)) {
      return;
    }
    activeCallId = callId;
    callDialogShowing = true;
    try {
      final accepted = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          incomingDialogContext = dialogContext;
          return AlertDialog(
            title: const Text('来电'),
            content: Text(
              '${call['callerName'] ?? call['nickname'] ?? '对方'} 邀请您进行语音通话',
            ),
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
          );
        },
      );
      if (!mounted || accepted == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) return;
      final service = DDPostService();
      try {
        final result =
            await ImSession.instance.updateCall(token, callId, accepted);
        if (accepted == 'answer' && mounted) {
          final answeredCall =
              (result['call'] as Map?)?.cast<String, dynamic>() ?? call;
          final rtc = (result['rtc'] as Map?)?.cast<String, dynamic>() ?? {};
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _AudioCallPage(
              call: answeredCall,
              rtc: rtc,
              token: token,
            ),
          ));
        }
      } finally {
        service.dispose();
      }
    } finally {
      incomingDialogContext = null;
      callDialogShowing = false;
      activeCallId = null;
    }
  }

  Future<void> _handleImEvent(Map<String, dynamic> event) async {
    if (!mounted) return;
    final type = event['type'];
    if (type == 'call:incoming') {
      final raw = event['call'];
      if (raw is Map) {
        final call = raw.cast<String, dynamic>();
        if ('${call['conversationId']}' != widget.chat.conversationId) return;
        await _saveCallEvent(call);
        final callerId = '${call['callerId'] ?? call['caller_id'] ?? ''}';
        final calleeId = '${call['calleeId'] ?? call['callee_id'] ?? ''}';
        final selfId = currentUserId;
        if (callerId.isNotEmpty &&
            callerId != selfId &&
            (calleeId.isEmpty || calleeId == selfId)) {
          unawaited(_showIncomingCall(call));
        }
      }
      return;
    }
    if (type == 'session:replaced') {
      if (mounted) {
        _showTopNotice(
          context,
          const SnackBar(content: Text('账号已在其他设备登录')),
        );
      }
      return;
    }
    if (type == 'call:update') {
      final call = event['call'];
      if (call is Map &&
          '${call['conversationId']}' == widget.chat.conversationId &&
          '${call['id'] ?? ''}' == activeCallId) {
        if (call['status'] != 'ringing') {
          _dismissIncomingDialog(incomingDialogContext);
        }
        final status = '${call['status'] ?? ''}';
        if (status == 'ended' ||
            status == 'cancelled' ||
            status == 'rejected') {
          activeCallId = null;
        }
      }
      if (call is Map) {
        await _saveCallEvent(call.cast<String, dynamic>());
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
          if (ImCall.isCall(existing)) return false;
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
      return;
    }
    if (type == 'message:failed' || type == 'message:pending') {
      if (event['conversationId'] != widget.chat.conversationId) return;
      final item = event['message'];
      if (item is Map) {
        _mergeMessage(Map<String, dynamic>.from(item),
            status: '${item['status']}');
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

  void _markPendingAccepted(Map<String, dynamic> item) {
    if ('${item['clientId'] ?? ''}'.isEmpty) return;
    _mergeMessage(item, status: 'sent');
  }

  bool _mergeMessage(Map<String, dynamic> item, {String? status}) {
    if (!mounted ||
        (item['conversationId'] != null &&
            item['conversationId'] != widget.chat.conversationId)) {
      return false;
    }
    final id = '${item['id'] ?? ''}';
    final clientId = '${item['clientId'] ?? ''}';
    final index = messages.indexWhere((existing) {
      if (ImCall.isCall(existing)) return false;
      return (clientId.isNotEmpty &&
              '${existing['clientId'] ?? ''}' == clientId) ||
          (id.isNotEmpty && '${existing['id'] ?? ''}' == id);
    });
    if (index >= 0 &&
        !['pending', 'failed'].contains(messages[index]['status']) &&
        ['pending', 'failed'].contains(status ?? item['status'])) {
      return false;
    }
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
      final follow = _isNearBottom();
      setState(() {});
      if (follow) _scrollToLatest(force: true);
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
        _showTopErrorBanner(context, '没有麦克风权限');
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
        _showTopNotice(
          context,
          const SnackBar(content: Text('已取消录音')),
        );
      }
      return;
    }
    await _sendRecordedAudio(output);
  }

  Future<void> _startAudioCall() async {
    if (mounted) _showTopErrorBanner(context, '实时语音通话暂未开放');
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
      await _sendMessagePayload(text: key, kind: 'audio', durationMs: 1000);
    } catch (error) {
      if (mounted) {
        _showTopErrorBanner(context, '$error');
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
        _showTopErrorBanner(context, '网络未连接，图片未发送');
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
      await _sendMessagePayload(text: objectKey, kind: 'image');
    } catch (error) {
      if (mounted) {
        _showTopErrorBanner(context, '$error');
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
      if (!mounted) return;
      _showTopNotice(
        context,
        const Text('举报已提交'),
      );
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
      if (shouldBlock == true && mounted) {
        final peerId = int.tryParse(widget.chat.peerUserId ?? '');
        if (peerId != null) {
          final blockService = DDPostService();
          try {
            await blockService.toggleUserBlock(token, peerId);
            if (mounted) {
              _showTopNotice(context, const Text('已举报并拉黑对方'));
            }
          } finally {
            blockService.dispose();
          }
        }
      }
    } catch (error) {
      if (mounted) {
        _showTopErrorBanner(context, '$error');
      }
    } finally {
      service.dispose();
    }
  }

  Future<void> _openChatSettings() async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ChatSettingsPage(
          chatName: widget.chat.name,
          peerUserId: widget.chat.peerUserId,
          initiallyBlocked: blockedConversation,
          initiallyPinned: widget.chat.pinned,
          initiallyMuted: widget.chat.muted,
          onTogglePinned: () async {
            final accountId = currentUserId;
            final prefs = await SharedPreferences.getInstance();
            final cached = await ImLocalStore.conversations(accountId);
            final rows = cached.map((row) {
              if ('${row['conversationId'] ?? ''}' == widget.chat.conversationId) {
                return {...row, 'pinned': !(row['pinned'] == true)};
              }
              return row;
            }).toList();
            await ImLocalStore.saveConversations(
                accountId: accountId, conversations: rows);
          },
          onToggleMuted: () async {
            final accountId = currentUserId;
            final cached = await ImLocalStore.conversations(accountId);
            final rows = cached.map((row) {
              if ('${row['conversationId'] ?? ''}' == widget.chat.conversationId) {
                return {...row, 'muted': !(row['muted'] == true)};
              }
              return row;
            }).toList();
            await ImLocalStore.saveConversations(
                accountId: accountId, conversations: rows);
          },
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'clear') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('清空当前聊天记录'),
          content: const Text('清空后仅删除本机当前聊天记录，无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ImLocalStore.clearConversation(
          accountId: currentUserId,
          conversationId: widget.chat.conversationId,
        );
        if (mounted) setState(() => messages.clear());
      }
    } else if (action == 'search') {
      await showSearch<String?>(
        context: context,
        delegate: _ChatSearchDelegate(messages),
      );
    } else if (action == 'report' && messages.isNotEmpty) {
      final chatMessages =
          messages.where((item) => !ImCall.isCall(item)).toList();
      if (chatMessages.isNotEmpty) await _reportImMessage(chatMessages.last);
    } else if (action == 'blacklist' || action == 'unblacklist') {
      if (mounted) {
        setState(() => blockedConversation = action == 'blacklist');
        _showTopNotice(
          context,
          SnackBar(
            content: Text(action == 'blacklist' ? '已加入黑名单' : '已取消黑名单'),
          ),
        );
      }
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
      final index = messages.indexWhere(
          (item) => !ImCall.isCall(item) && '${item['id'] ?? ''}' == id);
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
          _showTopNotice(
            context,
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
            !ImCall.isCall(item) &&
            ('${item['id'] ?? ''}' == id ||
                '${item['clientId'] ?? ''}' == '${message['clientId'] ?? ''}'));
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
          _showTopNotice(context, SnackBar(content: Text('$error')));
        }
      } finally {
        service.dispose();
      }
    }
  }


  bool _isSharedPost(Map<String, dynamic> message) {
    final metadata = message['metadata'];
    if (metadata is! Map) return false;
    final type = '${metadata['type'] ?? ''}';
    final postId = int.tryParse('${metadata['postId'] ?? metadata['post_id'] ?? ''}');
    return type == 'post_share' && postId != null && postId > 0;
  }

  Widget _sharedPostBody(Map<String, dynamic> message) {
    final metadata = Map<String, dynamic>.from(message['metadata'] as Map);
    final postId = '${metadata['postId'] ?? metadata['post_id'] ?? ''}';
    final text = '${metadata['content'] ?? message['text'] ?? '分享了一条动态'}'.trim();
    final author = '${metadata['author'] ?? ''}'.trim();
    final thumbnailUrl = '${metadata['thumbnailUrl'] ?? ''}'.trim();
    return InkWell(
      onTap: () => _openSharedPost(message),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbnailUrl.isEmpty
                  ? Container(
                      width: 52,
                      height: 52,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(TIcons.browse,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary),
                    )
                  : _PermanentCachedImage(
                      url: thumbnailUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: 52,
                        height: 52,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(TIcons.browse,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(author.isEmpty ? '动态分享' : '$author 的动态',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 3),
                  Text(text.isEmpty ? '分享了一条动态' : text,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  const Text('点击查看动态',
                      style: TextStyle(fontSize: 11, color: Colors.blue)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSharedPost(Map<String, dynamic> message) async {
    final metadata = message['metadata'];
    if (metadata is! Map) return;
    final postId = int.tryParse('${metadata['postId'] ?? metadata['post_id'] ?? ''}');
    if (postId == null || postId <= 0 || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) return;
    final service = DDPostService();
    try {
      final post = await service.fetchPost(token, postId);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => DynamicDetailPage(postId: postId, initialPost: post),
      ));
    } catch (error) {
      if (mounted) _showTopErrorBanner(context, '动态加载失败：$error');
    } finally {
      service.dispose();
    }
  }

  Future<void> _sendMessagePayload({
    required String text,
    String kind = 'text',
    Map<String, dynamic>? metadata,
    int durationMs = 0,
  }) async {
    if (text.trim().isEmpty || !mounted) return;
    if (blockedConversation) {
      _showTopErrorBanner(context, '当前会话不可发送');
      return;
    }
    final clientId = DateTime.now().microsecondsSinceEpoch.toString();
    final pending = <String, dynamic>{
      'id': 'local:$clientId',
      'clientId': clientId,
      'senderId': currentUserId,
      'conversationId': widget.chat.conversationId,
      'text': text.trim(),
      'kind': kind,
      'metadata': metadata,
      'durationMs': durationMs,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    };
    _mergeMessage(pending);
    final result = await MessageSendCoordinator.instance
        .send(accountId: currentUserId, message: pending);
    if (!mounted) return;
    _mergeMessage(result, status: '${result['status']}');
    if (result['status'] == 'failed') {
      _showTopErrorBanner(context, '${result['lastError'] ?? '消息发送失败'}');
    }
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    messageController.clear();
    if (typing) {
      typing = false;
      typingTimer?.cancel();
      ImSession.instance.socket?.sendTyping(
          conversationId: widget.chat.conversationId, typing: false);
    }
    await _sendMessagePayload(text: text);
  }

  Future<void> _retryMessage(Map<String, dynamic> message) async {
    if ('${message['clientId'] ?? ''}'.isEmpty) return;
    final result = await MessageSendCoordinator.instance.send(
        accountId: currentUserId,
        message: {...message, 'conversationId': widget.chat.conversationId},
        retry: true,
        recover: false);
    if (mounted) _mergeMessage(result, status: '${result['status']}');
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
    final chatMessages =
        messages.where((item) => !ImCall.isCall(item)).toList();
    if (chatMessages.isEmpty) return;
    final messageId = '${chatMessages.last['id'] ?? ''}';
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

  Future<void> _openPeerProfile() async {
    final peerId = int.tryParse(widget.chat.peerUserId ?? '');
    if (peerId == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OtherProfilePage(
        userId: peerId,
        name: widget.chat.name,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: GestureDetector(
            onTap: _openPeerProfile,
            child: Row(children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(radius: 15, backgroundImage: _chatAvatarFor(widget.chat)),
                  if (widget.chat.online)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 30 * .30,
                          height: 30 * .30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759),
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Text(widget.chat.name,
                  style: Theme.of(context).textTheme.bodyLarge),
            ]),
          ),
          actions: [
            IconButton(
              tooltip: '语音通话',
              onPressed: _startAudioCall,
              icon: const Icon(Icons.phone_in_talk_outlined),
            ),
            IconButton(
              tooltip: '聊天设置',
              onPressed: _openChatSettings,
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _timeline.isEmpty
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
                              reverse: true,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.manual,
                              padding: const EdgeInsets.all(16),
                              itemCount:
                                  _timeline.length + (peerTyping ? 1 : 0),
                              itemBuilder: (_, index) {
                                if (index >= _timeline.length) {
                                  return _TypingBubble();
                                }
                                final message = _timeline[index];
                                final isCall =
                                    message['_timelineKind'] == 'call';
                                final isMine = currentUserId.isNotEmpty &&
                                    (isCall
                                        ? '${message['callerId'] ?? message['caller_id'] ?? ''}' ==
                                            currentUserId
                                        : '${message['senderId'] ?? ''}' ==
                                            currentUserId);
                                final status = '${message['status'] ?? 'sent'}';
                                final isRecalled = status == 'recalled';
                                final isDeleted = status == 'deleted';
                                final isReadByPeer = isMine &&
                                    !isCall &&
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
                                final previousCreatedAt = index + 1 <
                                        _timeline.length
                                    ? DateTime.tryParse(
                                            '${_timeline[index + 1]['createdAt'] ?? ''}')
                                        ?.toLocal()
                                    : null;
                                final showTime = createdAt != null &&
                                    (previousCreatedAt == null ||
                                        createdAt
                                                .difference(previousCreatedAt)
                                                .inMinutes >=
                                            5);
                                final peerTopBarAvatar =
                                    _chatAvatarFor(widget.chat);
                                final bubbleAvatar = isMine
                                    ? _stableAvatar(myAvatarProvider)
                                    : peerTopBarAvatar;
                                if (isCall) {
                                  return Column(
                                    children: [
                                      if (showTime)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
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
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Align(
                                          alignment: isMine
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: GestureDetector(
                                            onTap: () => _redialCall(message),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                if (!isMine) ...[
                                                  CircleAvatar(
                                                      radius: 15,
                                                      backgroundImage:
                                                          bubbleAvatar),
                                                  const SizedBox(width: 6),
                                                ],
                                                Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Container(
                                                      constraints: BoxConstraints(
                                                          maxWidth:
                                                              MediaQuery.sizeOf(
                                                                          context)
                                                                      .width *
                                                                  0.72),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: isMine
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primaryContainer
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius.only(
                                                          topLeft: const Radius
                                                              .circular(16),
                                                          topRight: const Radius
                                                              .circular(16),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                  isMine
                                                                      ? 16
                                                                      : 4),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  isMine
                                                                      ? 4
                                                                      : 16),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons.phone,
                                                                  size: 16,
                                                                  color: isMine
                                                                      ? Colors
                                                                          .green
                                                                      : Colors
                                                                          .blue,
                                                                ),
                                                                const SizedBox(
                                                                    width: 6),
                                                                Flexible(
                                                                  child: Text(
                                                                    ImCall.statusText(
                                                                        message),
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyLarge,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (status ==
                                                              'pending') ...[
                                                            const SizedBox(
                                                                width: 6),
                                                            const SizedBox(
                                                                width: 12,
                                                                height: 12,
                                                                child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        1.5)),
                                                          ],
                                                          if (status ==
                                                              'failed')
                                                            GestureDetector(
                                                              onTap: () =>
                                                                  _retryMessage(
                                                                      message),
                                                              child: const Icon(
                                                                  Icons
                                                                      .error_outline,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .orange),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (isMine) ...[
                                                  const SizedBox(width: 6),
                                                  CircleAvatar(
                                                      radius: 15,
                                                      backgroundImage:
                                                          bubbleAvatar),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    if (showTime)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
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
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Align(
                                        alignment: isMine
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (!isMine) ...[
                                              CircleAvatar(
                                                  radius: 15,
                                                  backgroundImage:
                                                      bubbleAvatar),
                                              const SizedBox(width: 6),
                                            ],
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Container(
                                                  constraints: BoxConstraints(
                                                    maxWidth: MediaQuery.sizeOf(
                                                                context)
                                                            .width *
                                                        0.72,
                                                  ),
                                                  margin: const EdgeInsets.only(
                                                      bottom: 0),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isMine
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primaryContainer
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          const Radius.circular(
                                                              16),
                                                      topRight:
                                                          const Radius.circular(
                                                              16),
                                                      bottomLeft:
                                                          Radius.circular(
                                                              isMine ? 16 : 4),
                                                      bottomRight:
                                                          Radius.circular(
                                                              isMine ? 4 : 16),
                                                    ),
                                                  ),
                                                  child: GestureDetector(
                                                    onLongPress: () =>
                                                        _showMessageMenu(
                                                            message),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Flexible(
                                                          child: isRecalled ||
                                                                  isDeleted
                                                              ? Text(
                                                                  isRecalled
                                                                      ? '消息已撤回'
                                                                      : '消息已删除',
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .grey),
                                                                )
                                                              : _isSharedPost(message)
                                                                  ? _sharedPostBody(message)
                                                                  : message['kind'] ==
                                                                      'image'
                                                                      ? _imageMessageBody(
                                                                          message)
                                                                      : message['kind'] ==
                                                                              'audio'
                                                                          ? InkWell(
                                                                              onTap: () => _playAudioMessage('${message['text'] ?? ''}'),
                                                                              child: SizedBox(
                                                                                height: 24,
                                                                                child: Align(
                                                                                  alignment: Alignment.centerLeft,
                                                                                  child: Text(
                                                                                    playingAudioKey == '${message['text'] ?? ''}' ? '⏸ 播放中' : '🔊 播放语音',
                                                                                    style: Theme.of(context).textTheme.bodyLarge,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            )
                                                                          : Text(
                                                                              '${message['text'] ?? ''}',
                                                                              style: Theme.of(context).textTheme.bodyLarge,
                                                                            ),
                                                        ),
                                                        if (status ==
                                                            'pending') ...[
                                                          const SizedBox(
                                                              width: 6),
                                                          const SizedBox(
                                                            width: 12,
                                                            height: 12,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        1.5),
                                                          ),
                                                        ],
                                                        if (status == 'failed')
                                                          GestureDetector(
                                                            onTap: () =>
                                                                _retryMessage(
                                                                    message),
                                                            child: const Icon(
                                                              Icons
                                                                  .error_outline,
                                                              size: 16,
                                                              color:
                                                                  Colors.orange,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (isReadByPeer)
                                                  const Positioned(
                                                    left: -8,
                                                    bottom: 0,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: SizedBox(
                                                          width: 4, height: 4),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (isMine) ...[
                                              const SizedBox(width: 6),
                                              CircleAvatar(
                                                  radius: 15,
                                                  backgroundImage:
                                                      bubbleAvatar),
                                            ],
                                          ],
                                        ),
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
                            icon: Icon(
                                voiceMode ? Icons.keyboard : TIcons.microphone_1),
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
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
                                    minLines: 1,
                                    maxLines: 3,
                                    keyboardType: TextInputType.multiline,
                                    scrollPhysics:
                                        const ClampingScrollPhysics(),
                                    contextMenuBuilder: (context, state) {
                                      final allowed = <ContextMenuButtonType>{
                                        ContextMenuButtonType.copy,
                                        ContextMenuButtonType.cut,
                                        ContextMenuButtonType.paste,
                                        ContextMenuButtonType.selectAll,
                                      };
                                      final items = state.contextMenuButtonItems
                                          .where((item) =>
                                              allowed.contains(item.type))
                                          .map(
                                            (item) => ContextMenuButtonItem(
                                              onPressed: item.onPressed,
                                              type: item.type,
                                              label: _chineseContextMenuLabel(
                                                item.type,
                                                item.label,
                                              ),
                                            ),
                                          )
                                          .toList();
                                      return AdaptiveTextSelectionToolbar
                                          .buttonItems(
                                        anchors: state.contextMenuAnchors,
                                        buttonItems: items,
                                      );
                                    },
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
                              moreExpanded
                                  ? Icons.close
                                  : Icons.add_circle_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            Positioned(
              top: 8,
              right: 8,
              child: _ChatRadarPanel(avatar: _chatAvatarFor(widget.chat), peerLatitude: widget.chat.peerLatitude, peerLongitude: widget.chat.peerLongitude),
            ),
            if (moreExpanded)
              Positioned(
                right: 8,
                bottom: 132,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ComposerAction(
                        icon: Icons.camera_alt_outlined,
                        label: '拍摄',
                        onPressed: () {
                          setState(() => moreExpanded = false);
                          unawaited(
                              _pickAndSendImage(source: ImageSource.camera));
                        },
                      ),
                      _ComposerAction(
                        icon: Icons.photo_outlined,
                        label: '照片',
                        onPressed: () {
                          setState(() => moreExpanded = false);
                          unawaited(_pickAndSendImage());
                        },
                      ),

                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

String _chineseContextMenuLabel(ContextMenuButtonType type, String? fallback) {
  switch (type) {
    case ContextMenuButtonType.cut:
      return '剪切';
    case ContextMenuButtonType.copy:
      return '复制';
    case ContextMenuButtonType.paste:
      return '粘贴';
    case ContextMenuButtonType.selectAll:
      return '全选';
    default:
      return '';
  }
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

class _ChatSettingsPage extends StatefulWidget {
  const _ChatSettingsPage({
    required this.chatName,
    required this.peerUserId,
    required this.initiallyBlocked,
    required this.initiallyPinned,
    required this.initiallyMuted,
    required this.onTogglePinned,
    required this.onToggleMuted,
  });
  final String chatName;
  final String? peerUserId;
  final bool initiallyBlocked;
  final bool initiallyPinned;
  final bool initiallyMuted;
  final Future<void> Function() onTogglePinned;
  final Future<void> Function() onToggleMuted;

  @override
  State<_ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<_ChatSettingsPage> {
  bool pinned = false;
  bool muted = false;
  late bool blocked = widget.initiallyBlocked;
  bool changingBlock = false;

  @override
  void initState() {
    super.initState();
    pinned = widget.initiallyPinned;
    muted = widget.initiallyMuted;
  }

  Future<void> _toggleBlock() async {
    final peerId = int.tryParse(widget.peerUserId ?? '');
    if (peerId == null || changingBlock) return;
    setState(() => changingBlock = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      final service = DDPostService();
      final next = await service.toggleUserBlock(token, peerId);
      service.dispose();
      if (mounted) {
        setState(() {
          blocked = next;
          changingBlock = false;
        });
        Navigator.pop(context, next ? 'blacklist' : 'unblacklist');
      }
    } catch (error) {
      if (mounted) {
        setState(() => changingBlock = false);
        _showTopErrorBanner(context, '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('聊天设置')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(TIcons.ai_search),
              title: const Text('查找聊天记录'),
              onTap: () => Navigator.pop(context, 'search'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.push_pin_outlined),
              title: const Text('置顶聊天'),
              value: pinned,
              onChanged: (value) async {
                setState(() => pinned = value);
                await widget.onTogglePinned();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_off_outlined),
              title: const Text('消息免打扰'),
              value: muted,
              onChanged: (value) async {
                setState(() => muted = value);
                await widget.onToggleMuted();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                  blocked ? Icons.person_add_outlined : Icons.block_outlined),
              title: Text(blocked ? '取消黑名单' : '加入黑名单'),
              onTap: changingBlock ? null : _toggleBlock,
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('投诉/举报'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                '清空当前聊天记录',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
          ],
        ),
      );
}

class _ChatSearchDelegate extends SearchDelegate<String?> {
  _ChatSearchDelegate(this.items);
  final List<Map<String, dynamic>> items;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(TIcons.rollback),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final keyword = query.trim().toLowerCase();
    final results = items.where((item) {
      final text = '${item['text'] ?? ''}'.toLowerCase();
      return keyword.isEmpty || text.contains(keyword);
    }).toList();
    if (results.isEmpty) return const Center(child: Text('没有找到聊天记录'));
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, index) => ListTile(
        title: Text('${results[index]['text'] ?? ''}'),
        subtitle: Text('${results[index]['createdAt'] ?? ''}'),
      ),
    );
  }
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
  bool speakerEnabled = false;
  bool joined = false;
  StreamSubscription<Map<String, dynamic>>? imEvents;
  bool _ending = false;
  Timer? callTimer;
  Timer? durationTimer;
  DateTime? localTimerStartedAt;
  int localElapsedSeconds = 0;
  int localElapsedBase = 0;
  bool rtcJoined = false;
  late String callStatus;
  Route<dynamic>? callRoute;
  bool minimized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    callRoute = ModalRoute.of(context);
  }

  void _closeCallRoute() {
    if (!mounted) return;
    final route = callRoute;
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void initState() {
    super.initState();
    callStatus = '${widget.call['status'] ?? 'ringing'}';
    if (callStatus == 'answered') {
      _startLocalTimer();
    }
    if (callStatus == 'ringing') {
      callTimer = Timer(const Duration(seconds: 30), _cancelAfterTimeout);
    }
    AliyunRtcBridge.setEventHandler(_handleRtcEvent);
    imEvents = ImSession.instance.events.listen(_handleImEvent);
    unawaited(_joinRtc());
  }

  void _startLocalTimer() {
    if (localTimerStartedAt != null) return;
    localTimerStartedAt = DateTime.now();
    localElapsedBase =
        ImCall.duration(widget.call['localDurationSeconds']) ?? 0;
    localElapsedSeconds = localElapsedBase;
    unawaited(_checkpointDuration());
    durationTimer?.cancel();
    durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || localTimerStartedAt == null) return;
      setState(() {
        localElapsedSeconds = localElapsedBase +
            DateTime.now().difference(localTimerStartedAt!).inSeconds;
      });
      if (localElapsedSeconds % 5 == 0) unawaited(_checkpointDuration());
    });
  }

  Future<void> _checkpointDuration() async {
    try {
      await ImSession.instance.saveCall({
        ...widget.call,
        'status': 'answered',
        'answered': true,
        'localDurationSeconds': localElapsedSeconds
      }, notify: false);
    } catch (_) {
      // Finalization retries persistence before closing the call route.
    }
  }

  void _stopLocalTimer() {
    if (localTimerStartedAt != null) {
      localElapsedSeconds = localElapsedBase +
          DateTime.now().difference(localTimerStartedAt!).inSeconds;
    }
    durationTimer?.cancel();
    durationTimer = null;
  }

  Future<void> _finishRemoteHangup([Map<String, dynamic>? finalCall]) async {
    if (_ending) return;
    setState(() => _ending = true);
    _stopLocalTimer();
    await _persistCallLocally(
        finalCall ?? {if (localTimerStartedAt != null) 'status': 'ended'});
    try {
      await AliyunRtcBridge.leave().timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (mounted) {
      _closeCallRoute();
    }
  }

  Future<void> _cancelAfterTimeout() async {
    if (!mounted || _ending || callStatus != 'ringing') return;
    setState(() => _ending = true);
    callStatus = 'cancelled';
    await _persistCallLocally({'status': 'cancelled'});
    try {
      await AliyunRtcBridge.leave().timeout(const Duration(seconds: 2));
      await ImSession.instance
          .updateCall(widget.token, '${widget.call['id'] ?? ''}', 'cancel');
    } catch (_) {}
    if (mounted) _closeCallRoute();
  }

  void _handleRtcEvent(String method, dynamic args) {
    if (method == 'remoteLeft') {
      // 远端挂断只结束 RTC 页面，不显示提示。
      unawaited(_finishRemoteHangup());
    } else if (method == 'bye') {
      callStatus = 'bye';
      if (mounted) setState(() {});
      unawaited(_finishRemoteHangup());
    } else if (method == 'joined') {
      rtcJoined = true;
      if (mounted) setState(() {});
    } else if (method == 'remoteJoined' ||
        method == 'audioPublishState' ||
        method == 'audioSubscribeState' ||
        method == 'connectionStatus' ||
        method == 'warning' ||
        method == 'networkQuality' ||
        method == 'firstAudioSent' ||
        method == 'firstAudioReceived' ||
        method == 'remoteMuted') {
      if (mounted) setState(() {});
    } else if (method == 'error' && mounted) {
      _showTopErrorBanner(
          context, 'RTC 连接失败：${args is Map ? args['code'] : ''}');
    }
  }

  void _handleImEvent(Map<String, dynamic> event) {
    if (event['type'] != 'call:update') return;
    final call = event['call'];
    if (call is! Map || '${call['id'] ?? ''}' != '${widget.call['id'] ?? ''}') {
      return;
    }
    final status = '${call['status'] ?? ''}';
    callStatus = status;
    if (status == 'answered') {
      callTimer?.cancel();
      callStatus = 'answered';
      _startLocalTimer();
      if (mounted) setState(() {});
    }
    if (status == 'ended' || status == 'cancelled' || status == 'rejected') {
      callStatus = status;
      _stopLocalTimer();
      final finalCall = {
        ...call.cast<String, dynamic>(),
        if (localTimerStartedAt != null)
          'localDurationSeconds': localElapsedSeconds,
      };
      unawaited(_finishRemoteHangup(finalCall));
    }
  }

  Future<void> _joinRtc() async {
    try {
      await AliyunRtcBridge.subscribeRemoteAudio(true);
      await AliyunRtcBridge.join(widget.rtc);
      if (mounted) setState(() => joined = true);
    } catch (error) {
      if (mounted) {
        _showTopErrorBanner(context, '$error');
      }
    }
  }

  Future<void> _leave() async {
    if (!mounted || _ending) return;
    setState(() => _ending = true);
    _stopLocalTimer();
    await _persistCallLocally(
        {'status': localTimerStartedAt == null ? 'cancelled' : 'ended'});
    if (!mounted) return;
    try {
      await AliyunRtcBridge.leave().timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (!mounted) return;
    _closeCallRoute();
    unawaited(_finishCallOnServer());
  }

  Future<void> _persistCallLocally(Map<String, dynamic> raw) async {
    await ImSession.instance.saveCall({
      ...widget.call,
      ...raw,
      if (localTimerStartedAt != null)
        'localDurationSeconds': localElapsedSeconds,
      if (localTimerStartedAt != null) 'answered': true,
    });
  }

  Future<void> _finishCallOnServer() async {
    try {
      await ImSession.instance
          .updateCall(widget.token, '${widget.call['id'] ?? ''}',
              localTimerStartedAt == null ? 'cancel' : 'hangup')
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // The locally saved final state remains available while offline.
    }
  }

  @override
  void dispose() {
    callTimer?.cancel();
    durationTimer?.cancel();
    imEvents?.cancel();
    AliyunRtcBridge.setEventHandler(null);
    super.dispose();
  }

  String _elapsedText() {
    final seconds = localElapsedSeconds.clamp(0, 86400);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _ending,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_leave());
        },
        child: Scaffold(
          backgroundColor: minimized ? Colors.transparent : null,
          appBar: minimized
              ? null
              : AppBar(
                  title: const Text('语音通话'),
                  actions: [
                    IconButton(
                      tooltip: '最小化',
                      onPressed: () => setState(() => minimized = true),
                      icon: _tdIcon('minus'),
                    ),
                  ],
                ),
          body: minimized
              ? SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(18),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() => minimized = false),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _tdIcon('phone'),
                                const SizedBox(width: 8),
                                Text(callStatus == 'answered'
                                    ? '通话中 ${_elapsedText()}'
                                    : '等待接听'),
                                const SizedBox(width: 8),
                                _tdIcon('chevron-right'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                          radius: 42, child: Icon(Icons.person, size: 42)),
                      const SizedBox(height: 16),
                      Text(
                        callStatus == 'answered' ? _elapsedText() : '等待接听',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
                            onPressed: () async {
                              final next = !speakerEnabled;
                              await AliyunRtcBridge.setSpeakerEnabled(next);
                              if (mounted) {
                                setState(() => speakerEnabled = next);
                              }
                            },
                            icon: Icon(
                              speakerEnabled
                                  ? Icons.volume_up
                                  : Icons.phone_in_talk,
                            ),
                          ),
                          const SizedBox(width: 28),
                          IconButton.filled(
                            onPressed: _leave,
                            icon: const Icon(Icons.call_end),
                          ),
                        ],
                      ),
                    ],
                  ),
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
              icon: Icon(TIcons.highlight_1),
              selectedIcon: Icon(TIcons.highlight_1_filled),
              label: '主页',
            ),
            NavigationDestination(
              icon: Icon(TIcons.gps),
              selectedIcon: Icon(TIcons.gps_filled),
              label: '发现',
            ),
            NavigationDestination(
              icon: Icon(TIcons.chat_bubble),
              selectedIcon: Icon(TIcons.chat_bubble_filled),
              label: '聊天',
            ),
            NavigationDestination(
              icon: Icon(TIcons.fingerprint_3),
              selectedIcon: Icon(TIcons.fingerprint_3),
              label: '我的',
            ),
          ],
        ),
      );
}

class _PageErrorState extends StatefulWidget {
  const _PageErrorState({required this.title, required this.subtitle, this.onRetry});
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  State<_PageErrorState> createState() => _PageErrorStateState();
}

class _PageErrorStateState extends State<_PageErrorState> {
  String? _shown;

  @override
  void initState() {
    super.initState();
    _showAfterBuild();
  }

  @override
  void didUpdateWidget(covariant _PageErrorState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.subtitle != widget.subtitle) {
      _showAfterBuild();
    }
  }

  void _showAfterBuild() {
    final message = '${widget.title}：${widget.subtitle}';
    if (_shown == message) return;
    _shown = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTopNotice(
        context,
        Row(
          children: [
            Expanded(child: Text(widget.title)),
            if (widget.onRetry != null)
              TextButton(onPressed: widget.onRetry, child: const Text('重试')),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
