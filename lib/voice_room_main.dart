part of 'main.dart';

class _VoiceRoomFloatingOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, Map<String, dynamic>? room) {
    if (_entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        right: 16,
        bottom: 112,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              entry.remove();
              _entry = null;
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => VoiceRoomPage(room: room)),
              );
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xff7c4dff),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 12)
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void remove() {
    _entry?.remove();
    _entry = null;
  }
}

class _VoiceRoomShareSheet extends StatelessWidget {
  const _VoiceRoomShareSheet({
    required this.room,
    required this.onDirectChat,
    required this.onFollow,
    required this.onGift,
    required this.onReport,
  });

  final Map<String, dynamic>? room;
  final VoidCallback onDirectChat;
  final VoidCallback onFollow;
  final VoidCallback onGift;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final title = room?['title']?.toString() ?? '语音频道';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('更多操作',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 88,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic, color: Color(0xff9b6cff), size: 34),
                    const SizedBox(height: 6),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _VoiceRoomShareAction(
                    label: '私聊', icon: TIcons.chat, onTap: onDirectChat),
                _VoiceRoomShareAction(
                    label: '关注', icon: TIcons.user_add, onTap: onFollow),
                _VoiceRoomShareAction(
                    label: '送礼', icon: TIcons.gift, onTap: onGift),
                _VoiceRoomShareAction(
                    label: '举报', icon: TIcons.bug_report, onTap: onReport),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceRoomShareAction extends StatelessWidget {
  const _VoiceRoomShareAction(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(icon),
              ),
              const SizedBox(height: 6),
              Text(label),
            ],
          ),
        ),
      );
}

class _VoiceRoomSeats extends StatelessWidget {
  const _VoiceRoomSeats({required this.room});
  final Map<String, dynamic>? room;

  String _text(Map member, String key) => member[key]?.toString() ?? '';

  Widget _memberTile(Map member, {required bool owner, required bool manager}) {
    final avatar = _text(member, 'avatar');
    final name = _text(member, 'nickname').isEmpty
        ? (_text(member, 'name').isEmpty ? '用户' : _text(member, 'name'))
        : _text(member, 'nickname');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: owner ? 30 : 23,
          backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
          child: avatar.isEmpty ? const Icon(Icons.person) : null,
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (owner || manager)
          Text(
            owner ? '房主' : '管理',
            style: const TextStyle(color: Color(0xffd3b5ff), fontSize: 10),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = room?['members'] ?? room?['participants'] ?? room?['speakers'];
    final members = raw is List ? raw.whereType<Map>().toList() : <Map>[];
    final owner = <String, dynamic>{
      'user_id': room?['owner_user_id'] ?? room?['ownerUserId'],
      'nickname': room?['owner_nickname'] ??
          room?['ownerNickname'] ??
          room?['nickname'],
      'avatar':
          room?['owner_avatar'] ?? room?['ownerAvatar'] ?? room?['avatar'],
      'role': 'owner',
    };
    final ownerId = owner['user_id'];
    final others = members.where((member) {
      final id = member['user_id'] ?? member['userId'];
      return id == null || ownerId == null || '$id' != '$ownerId';
    }).toList();
    final managers = others.where((member) {
      final role =
          '${member['role'] ?? member['user_role'] ?? member['userRole']}'
              .toLowerCase();
      return role == 'admin' ||
          role == 'manager' ||
          role == '管理员' ||
          role == '管理';
    }).toList();
    final normal =
        others.where((member) => !managers.contains(member)).toList();
    final hasOwner = owner['user_id'] != null ||
        owner['nickname'] != null ||
        owner['avatar'] != null;
    final online = room?['online_count'] ?? room?['onlineCount'];
    final onlineText = online == null ? '在线人数暂无' : '$online人在线';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(onlineText,
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Expanded(
          child: !hasOwner && members.isEmpty
              ? const Center(
                  child:
                      Text('暂无在线成员资料', style: TextStyle(color: Colors.white54)))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _memberTile(owner, owner: true, manager: false),
                    if (managers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('管理',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: managers.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 78,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (_, index) => _memberTile(managers[index],
                            owner: false, manager: true),
                      ),
                    ],
                    if (normal.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('成员',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: normal.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 72,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (_, index) => _memberTile(normal[index],
                            owner: false, manager: false),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _VoiceRoomMessages extends StatelessWidget {
  const _VoiceRoomMessages({required this.room});
  final Map<String, dynamic>? room;

  @override
  Widget build(BuildContext context) {
    final raw = room?['messages'];
    final messages = raw is List ? raw.whereType<Map>().toList() : const [];
    if (messages.isEmpty) {
      return const Center(
        child: Text('暂无房间消息', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: messages.length,
      itemBuilder: (_, index) {
        final message = messages[index];
        final name = message['nickname']?.toString() ?? '用户';
        final text = message['text']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('$name：$text',
              style: const TextStyle(color: Colors.white70)),
        );
      },
    );
  }
}

class VoiceRoomPage extends StatefulWidget {
  const VoiceRoomPage({super.key, this.room});
  final Map<String, dynamic>? room;
  String get roomTitle =>
      '${room?['room']?['title'] ?? room?['title'] ?? '语音频道'}';
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  final messageController = TextEditingController();
  bool muted = false;
  bool joined = false;
  bool _leaving = false;
  bool _rtcJoined = false;

  @override
  void initState() {
    super.initState();
    _joinRtc();
  }

  Future<void> _joinRtc() async {
    final rtc = widget.room?['rtc'];
    if (rtc is! Map || '${rtc['token'] ?? ''}'.isEmpty) return;
    try {
      await AliyunRtcBridge.join(rtc.cast<String, dynamic>());
      await AliyunRtcBridge.subscribeRemoteAudio(true);
      _rtcJoined = true;
    } catch (_) {}
  }

  Future<void> _shareRoom() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VoiceRoomShareSheet(
        room: widget.room,
        onDirectChat: _openOwnerChat,
        onFollow: _followOwner,
        onGift: _showGiftUnavailable,
        onReport: _showReportUnavailable,
      ),
    );
  }

  int? get _ownerId {
    final raw = widget.room?['owner_user_id'] ??
        widget.room?['ownerUserId'] ??
        widget.room?['owner_id'];
    return int.tryParse('$raw');
  }

  String get _ownerName =>
      widget.room?['owner_nickname']?.toString() ??
      widget.room?['ownerNickname']?.toString() ??
      widget.room?['nickname']?.toString() ??
      '房主';

  Future<String> _authToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) throw Exception('请先登录');
    return token;
  }

  Future<void> _openOwnerChat() async {
    final ownerId = _ownerId;
    if (ownerId == null) {
      if (mounted) _showRoomNotice('房主资料暂不可用');
      return;
    }
    try {
      final service = DDPostService();
      final conversationId = await service.createDirectConversation(
          await _authToken(), '$ownerId');
      service.dispose();
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ChatDetailPage(
            chat: _ChatPreview(_ownerName, '开始聊天', null, null, '$ownerId',
                conversationId, 0, null, null, 'dm', false, false),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showRoomNotice('$e');
    }
  }

  Future<void> _followOwner() async {
    final ownerId = _ownerId;
    if (ownerId == null) {
      if (mounted) _showRoomNotice('房主资料暂不可用');
      return;
    }
    try {
      final service = DDPostService();
      final followed = await service.toggleFollow(await _authToken(), ownerId);
      service.dispose();
      if (mounted) {
        Navigator.pop(context);
        _showRoomNotice(followed ? '已关注房主' : '已取消关注房主');
      }
    } catch (e) {
      if (mounted) _showRoomNotice('$e');
    }
  }

  void _showGiftUnavailable() {
    Navigator.pop(context);
    _showRoomNotice('语音房送礼暂未接入');
  }

  void _showReportUnavailable() {
    Navigator.pop(context);
    _showRoomNotice('举报语音房（频道）暂未接入');
  }

  void _showRoomNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _exitRoom() async {
    if (_leaving) return;
    _leaving = true;
    _VoiceRoomFloatingOverlay.remove();
    if (_rtcJoined) {
      try {
        await AliyunRtcBridge.leave().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出频道'),
        content: const Text('退出后将停止接收频道声音，确定退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (exit == true) await _exitRoom();
  }

  void _minimize() {
    _VoiceRoomFloatingOverlay.show(context, widget.room);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    messageController.dispose();
    if (!_leaving) {
      // 返回或右滑进入浮窗时保留 RTC，不在此处离开频道。
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _minimize();
        },
        child: Scaffold(
          backgroundColor: const Color(0xff1a1224),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: Colors.white,
            title: Text(widget.roomTitle),
            actions: [
              IconButton(
                tooltip: '分享',
                onPressed: _shareRoom,
                icon: const Icon(TIcons.share_1),
              ),
              IconButton(
                  onPressed: _confirmExit, icon: const Icon(Icons.close)),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: Stack(children: [
            Positioned.fill(
                child: DecoratedBox(
                    decoration: const BoxDecoration(
                        gradient: RadialGradient(
                            center: Alignment.topRight,
                            radius: 1.4,
                            colors: [Color(0xff673a8c), Color(0xff1a1224)])))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 78, 16, 12),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.purpleAccent, width: 2),
                              ),
                            ),
                            const CircleAvatar(
                                radius: 41, child: Icon(Icons.mic, size: 38)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.room?['room']?['title']?.toString() ??
                              widget.room?['title']?.toString() ??
                              '暂无频道名称',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _VoiceRoomSeats(room: widget.room),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('房间消息',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Expanded(
                                  child: _VoiceRoomMessages(room: widget.room)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                  color: const Color(0xff21172e),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Row(children: [
                    IconButton(
                        tooltip: muted ? '开启语音输入' : '关闭语音输入',
                        onPressed: () async {
                          final next = !muted;
                          if (_rtcJoined) {
                            try {
                              await AliyunRtcBridge.setMuted(next);
                            } catch (_) {}
                          }
                          if (mounted) setState(() => muted = next);
                        },
                        icon: Icon(muted ? Icons.mic_off : TIcons.microphone_1,
                            color: Colors.white)),
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '输入消息',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xff342347),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(62, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(joined ? '已上麦' : '申请上麦'),
                    ),
                  ]))),
        ),
      );
}
