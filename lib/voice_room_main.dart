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
              final navigator = _appNavigatorKey.currentState;
              if (navigator != null) {
                navigator.push(
                  MaterialPageRoute(builder: (_) => VoiceRoomPage(room: room)),
                );
              }
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

class _VoiceRoomShareSheet extends StatefulWidget {
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
  State<_VoiceRoomShareSheet> createState() => _VoiceRoomShareSheetState();
}

class _VoiceRoomShareSheetState extends State<_VoiceRoomShareSheet> {
  final service = DDPostService();
  List<DDConversation> conversations = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConversations());
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final rows = await service.fetchImConversations(token);
      if (mounted)
        setState(() {
          conversations = rows.take(10).toList();
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = '最近聊天加载失败';
        });
    }
  }

  String _roomTitle() => widget.room?['title']?.toString() ?? '语音频道';

  Future<void> _sendTo(DDConversation conversation) async {
    final peer = conversation.peer;
    if (peer == null) return;
    widget.onDirectChat();
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
                  child: Text('分享频道',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
              const SizedBox(height: 16),
              SizedBox(
                height: 92,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : error != null
                        ? Center(child: Text(error!))
                        : conversations.isEmpty
                            ? const Center(child: Text('暂无最近聊天'))
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: conversations.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, index) {
                                  final conversation = conversations[index];
                                  final peer = conversation.peer;
                                  final name =
                                      peer?.nickname?.trim().isNotEmpty == true
                                          ? peer!.nickname!
                                          : '好友';
                                  final avatar =
                                      peer?.avatarUrl ?? peer?.avatarKey ?? '';
                                  return InkWell(
                                    onTap: () => _sendTo(conversation),
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 64,
                                      child: Column(children: [
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundImage: avatar.isEmpty
                                              ? null
                                              : NetworkImage(avatar),
                                          child: avatar.isEmpty
                                              ? const Icon(Icons.person_outline)
                                              : null,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      ]),
                                    ),
                                  );
                                },
                              ),
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _VoiceRoomShareAction(
                      label: '私聊',
                      icon: TIcons.chat,
                      onTap: widget.onDirectChat),
                  _VoiceRoomShareAction(
                      label: '关注',
                      icon: TIcons.user_add,
                      onTap: widget.onFollow),
                  _VoiceRoomShareAction(
                      label: '送礼', icon: TIcons.gift, onTap: widget.onGift),
                  _VoiceRoomShareAction(
                      label: '举报',
                      icon: TIcons.bug_report,
                      onTap: widget.onReport),
                ],
              ),
            ],
          ),
        ),
      );
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
  const _VoiceRoomSeats({required this.room, this.state, this.onAction});
  final Map<String, dynamic>? room;
  final Map<String, dynamic>? state;
  final Future<void> Function(String action, [String? userId])? onAction;

  String _text(Map member, String key) => member[key]?.toString() ?? '';

  Widget _memberTile(Map member, {required bool owner, required bool manager}) {
    final avatar = _text(member, 'avatar');
    final name = _text(member, 'nickname').isEmpty
        ? (_text(member, 'name').isEmpty ? '用户' : _text(member, 'name'))
        : _text(member, 'nickname');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: owner ? 30 : 23,
          backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
          child: avatar.isEmpty ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              if (manager)
                const Text('管理',
                    style: TextStyle(color: Color(0xffd3b5ff), fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _applySeatButton(BuildContext context) {
    final requested = state?['requested'] == true;
    final onSeat = state?['onSeat'] == true;
    final label = onSeat
        ? '下麦'
        : requested
            ? '取消申请'
            : '申请上麦';
    return GestureDetector(
      onTap: onAction == null
          ? null
          : () => onAction!(onSeat
              ? 'leave'
              : requested
                  ? 'cancel'
                  : 'request'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xff493365),
            child: Icon(onSeat ? Icons.mic_off : Icons.add,
                color: Colors.white70)),
        const SizedBox(height: 4),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawSeats = state?['seats'];
    final seats = rawSeats is List
        ? rawSeats
            .whereType<Map>()
            .map((x) => x.cast<String, dynamic>())
            .toList()
        : <Map<String, dynamic>>[];
    final owner = <String, dynamic>{
      'user_id': state?['owner']?['userId'] ??
          room?['owner_user_id'] ??
          room?['ownerUserId'],
      'nickname': state?['owner']?['nickname'] ??
          room?['owner_nickname'] ??
          room?['ownerNickname'] ??
          room?['nickname'],
      'avatar': state?['owner']?['avatar'] ??
          room?['owner_avatar'] ??
          room?['ownerAvatar'] ??
          room?['avatar'],
      'role': 'owner',
    };
    final hasOwner = owner['user_id'] != null ||
        owner['nickname'] != null ||
        owner['avatar'] != null;
    final online =
        state?['onlineCount'] ?? room?['online_count'] ?? room?['onlineCount'];
    final onlineText = online == null ? '在线人数暂无' : '$online人在线';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('频道ID：${room?['id'] ?? room?['roomId'] ?? '暂无资料'}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(onlineText,
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Expanded(
          child: !hasOwner && seats.isEmpty
              ? const Center(
                  child:
                      Text('暂无麦上成员资料', style: TextStyle(color: Colors.white54)))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (hasOwner)
                      _memberTile(owner, owner: true, manager: false),
                    if (seats.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('麦上成员',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: seats.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 72,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (_, index) => _memberTile(seats[index],
                            owner: false, manager: false),
                      ),
                    ],
                    if (state?['isOwner'] == true &&
                        state?['requests'] is List &&
                        (state?['requests'] as List).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('上麦申请',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 6),
                      ...(state?['requests'] as List)
                          .whereType<Map>()
                          .map((request) {
                        final id = '${request['userId'] ?? ''}';
                        return Row(children: [
                          Expanded(
                              child: Text('${request['nickname'] ?? '用户'}',
                                  style:
                                      const TextStyle(color: Colors.white70))),
                          TextButton(
                              onPressed: () => onAction?.call('reject', id),
                              child: const Text('拒绝')),
                          FilledButton(
                              onPressed: () => onAction?.call('approve', id),
                              child: const Text('同意')),
                        ]);
                      }),
                    ],
                    const SizedBox(height: 14),
                    Center(child: _applySeatButton(context)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _VoiceRoomMessages extends StatelessWidget {
  const _VoiceRoomMessages({required this.messages});
  final List<String> messages;

  static const _platformNotice =
      '平台将24小时巡查违规内容，对私下交易、发布广告信息、从事任何金融违法犯罪活动等违规行为予以严肃处理，并上报相关部门。如您发现上述不正当行为，请及时向平台举报。让我们共同营造善意、平等、真实的氛围。';

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.zero,
        children: [
          const Text('平台公告：$_platformNotice',
              style: TextStyle(color: Colors.white70, height: 1.45)),
          ...messages.map((message) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message,
                    style: const TextStyle(color: Colors.white70)),
              )),
        ],
      );
}

class _VoiceGiftSheet extends StatefulWidget {
  const _VoiceGiftSheet({
    required this.room,
    required this.roomId,
    required this.service,
    required this.token,
  });
  final Map<String, dynamic> room;
  final String roomId;
  final DDPostService service;
  final String token;

  @override
  State<_VoiceGiftSheet> createState() => _VoiceGiftSheetState();
}

class _VoiceGiftSheetState extends State<_VoiceGiftSheet> {
  static const _names = [
    '聊天泡泡',
    '游戏时光',
    '星愿纸飞机',
    '梦幻故事书',
    '观影入场券',
    '欢乐爆米花',
    '聚光时刻',
    '泡泡派对',
    '彩虹风车',
    '旋转彩星',
    '缤纷拼图',
    '环球旅行',
    '灵感笔尖',
    '彩虹键盘',
    '游戏摇杆',
    '星光风铃',
    '快乐悠悠',
    '星空望远镜',
    '闪耀滑板',
    '爱情信封',
  ];
  late final List<Map<String, dynamic>> recipients;
  List<Map<String, dynamic>> gifts = const [];
  int? selectedRecipient;
  bool loading = true;
  bool sending = false;
  int _giftPage = 0;

  @override
  void initState() {
    super.initState();
    final owner = <String, dynamic>{
      'user_id': widget.room['owner_user_id'] ?? widget.room['ownerUserId'],
      'nickname': widget.room['owner_nickname'] ??
          widget.room['ownerNickname'] ??
          widget.room['nickname'] ??
          '房主',
      'avatar': widget.room['owner_avatar'] ??
          widget.room['ownerAvatar'] ??
          widget.room['avatar'],
    };
    final raw = widget.room['members'] ??
        widget.room['participants'] ??
        widget.room['speakers'];
    final all = <Map<String, dynamic>>[owner];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final member = item.cast<String, dynamic>();
        final id = member['user_id'] ?? member['userId'];
        if (id != null && !all.any((x) => '${x['user_id']}' == '$id')) {
          all.add(member);
        }
      }
    }
    recipients = all
        .where((x) => int.tryParse('${x['user_id'] ?? x['userId']}') != null)
        .toList();
    selectedRecipient = recipients.isEmpty
        ? null
        : int.tryParse(
            '${recipients.first['user_id'] ?? recipients.first['userId']}');
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final rows =
          await widget.service.fetchVoiceRoomGifts(widget.token, widget.roomId);
      if (mounted) setState(() => gifts = rows);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _showTopNotice(context, Text('$e'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send(Map<String, dynamic> gift) async {
    final receiver = selectedRecipient;
    if (receiver == null || sending) return;
    final name = gift['name']?.toString() ?? '礼物';
    final price = gift['coinPrice'] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认送礼'),
        content: Text('送出$name（$price金币）？'),
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
    if (ok != true) return;
    setState(() => sending = true);
    try {
      await widget.service.sendVoiceRoomGift(
        token: widget.token,
        roomId: widget.roomId,
        receiverUserId: receiver,
        giftIndex: int.parse('${gift['index']}'),
      );
      if (mounted) {
        Navigator.pop(context);
        _showTopNotice(context, const Text('送礼成功'));
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 78,
              child: recipients.isEmpty
                  ? const Center(child: Text('暂无麦上成员资料'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recipients.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, index) {
                        final member = recipients[index];
                        final id = int.parse(
                            '${member['user_id'] ?? member['userId']}');
                        final avatar = member['avatar']?.toString() ?? '';
                        final name = member['nickname']?.toString() ??
                            member['name']?.toString() ??
                            '用户';
                        return GestureDetector(
                          onTap: () => setState(() => selectedRecipient = id),
                          child: Column(children: [
                            CircleAvatar(
                              radius: selectedRecipient == id ? 27 : 23,
                              backgroundImage:
                                  avatar.isEmpty ? null : NetworkImage(avatar),
                              child: avatar.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(height: 3),
                            SizedBox(
                                width: 58,
                                child: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center)),
                          ]),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            if (loading)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator())
            else
              Column(children: [
                SizedBox(
                  height: 230,
                  child: PageView.builder(
                    itemCount: (gifts.length / 10).ceil(),
                    onPageChanged: (page) => setState(() => _giftPage = page),
                    itemBuilder: (_, page) {
                      final pageGifts = gifts.skip(page * 10).take(10).toList();
                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: pageGifts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 4,
                          mainAxisExtent: 108,
                        ),
                        itemBuilder: (_, index) {
                          final gift = pageGifts[index];
                          final giftIndex = int.tryParse('${gift['index']}') ??
                              page * 10 + index + 1;
                          return GestureDetector(
                            onTap: () => _send(gift),
                            child: Column(children: [
                              Image.asset(
                                  'assets/voice_gifts/gift_$giftIndex.png',
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.contain),
                              Text(
                                  gift['name']?.toString() ??
                                      _names[giftIndex - 1],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                              Text('${gift['coinPrice'] ?? 0}金币',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.orange)),
                            ]),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (gifts.length > 10) ...[
                  const SizedBox(height: 4),
                  Text('${_giftPage + 1}/${(gifts.length / 10).ceil()}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ]),
          ]),
        ),
      );
}

class VoiceRoomPage extends StatefulWidget {
  const VoiceRoomPage({super.key, this.room});
  final Map<String, dynamic>? room;
  Map<String, dynamic> get roomData {
    final nested = room?['room'];
    return nested is Map
        ? nested.cast<String, dynamic>()
        : (room ?? const <String, dynamic>{});
  }

  Map<String, dynamic>? get rtcData {
    final rtc = room?['rtc'];
    return rtc is Map ? rtc.cast<String, dynamic>() : null;
  }

  String get roomTitle => '${roomData['title'] ?? '语音频道'}';
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  final messageService = DDPostService();
  Map<String, dynamic> seatState = const {};
  Timer? _seatRefreshTimer;
  StreamSubscription<Map<String, dynamic>>? _imEvents;
  bool muted = true;
  bool _leaving = false;
  bool _rtcJoined = false;
  final List<String> _roomMessages = <String>[];
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _joinRtc();
    _loadSeats();
    _imEvents = ImSession.instance.events.listen(_handleImEvent);
  }

  String? get _roomId => widget.roomData['id']?.toString();

  void _handleImEvent(Map<String, dynamic> event) {
    if ('${event['roomId'] ?? ''}' == (_roomId ?? '')) {
      if (event['type'] == 'voice_room:system' && event['kind'] == 'join') {
        _appendRoomMessage('${event['nickname'] ?? '用户'} 进入了频道');
      } else if (event['type'] == 'voice_room:chat') {
        _appendRoomMessage(
            '${event['nickname'] ?? '用户'}：${event['text'] ?? ''}');
      } else if (event['type'] == 'voice_room:gift') {
        _appendRoomMessage(
            '${event['sender'] ?? '用户'} 送给 ${event['receiver'] ?? '用户'} ${event['giftName'] ?? '礼物'}');
      }
    }
    if (event['type'] == 'voice_room:owner_left' &&
        '${event['roomId'] ?? ''}' == (_roomId ?? '')) {
      unawaited(_handleOwnerLeft());
      return;
    }
    if (event['type'] == 'voice_room:left' &&
        '${event['roomId'] ?? ''}' == (_roomId ?? '') &&
        '${event['userId'] ?? ''}' == (ImSession.instance.userId ?? '')) {
      unawaited(_handleOwnerLeft());
      return;
    }
    if (event['type'] != 'voice_room:ended' ||
        '${event['roomId'] ?? ''}' != (_roomId ?? '')) return;
    unawaited(_handleRoomEnded());
  }

  void _appendRoomMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    setState(() {
      _roomMessages.add(message);
      if (_roomMessages.length > 100) _roomMessages.removeAt(0);
    });
  }

  Future<void> _sendRoomMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null) return;
    _messageController.clear();
    try {
      await messageService.sendVoiceRoomMessage(
          await _authToken(), _roomId!, text);
    } catch (e) {
      if (mounted) _showRoomNotice('$e');
    }
  }

  Future<void> _handleOwnerLeft() async {
    if (_leaving) return;
    _leaving = true;
    if (_rtcJoined) {
      try {
        await AliyunRtcBridge.leave().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (mounted) {
      _showRoomNotice('房主已退出，频道在线用户已被移出');
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleRoomEnded() async {
    if (_leaving) return;
    _leaving = true;
    _seatRefreshTimer?.cancel();
    if (_rtcJoined) {
      try {
        await AliyunRtcBridge.leave().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (!mounted) return;
    _showRoomNotice('房主已解散频道');
    Navigator.of(context).pop();
  }

  bool get _seatOn => seatState['onSeat'] == true;

  Future<void> _loadSeats() async {
    final id = _roomId;
    if (id == null) return;
    try {
      final data =
          await messageService.fetchVoiceRoomSeats(await _authToken(), id);
      if (mounted) setState(() => seatState = data);
    } catch (e) {
      if (mounted) _showRoomNotice('$e');
    }
  }

  Future<void> _seatAction(String action, [String? userId]) async {
    final id = _roomId;
    if (id == null) return;
    try {
      final token = await _authToken();
      if (action == 'request')
        await messageService.requestVoiceRoomSeat(token, id);
      if (action == 'cancel')
        await messageService.cancelVoiceRoomSeatRequest(token, id);
      if (action == 'approve' && userId != null) {
        await messageService.approveVoiceRoomSeat(token, id, userId);
        await _setRtcMuted(false);
      }
      if (action == 'reject' && userId != null) {
        await messageService.rejectVoiceRoomSeat(token, id, userId);
        await _setRtcMuted(true);
      }
      if (action == 'leave') {
        await messageService.leaveVoiceRoomSeat(token, id);
        await _setRtcMuted(true);
      }
      await _loadSeats();
      if (action == 'approve' || action == 'reject') await _loadSeats();
    } catch (e) {
      if (mounted) _showRoomNotice('$e');
    }
  }

  Future<void> _setRtcMuted(bool next) async {
    if (_rtcJoined) {
      try {
        await AliyunRtcBridge.setMuted(next);
      } catch (_) {}
    }
    if (mounted) setState(() => muted = next);
  }

  Future<void> _joinRtc() async {
    final rtc = widget.rtcData;
    if (rtc == null || '${rtc['token'] ?? ''}'.isEmpty) return;
    try {
      await AliyunRtcBridge.join(rtc);
      await AliyunRtcBridge.subscribeRemoteAudio(true);
      _rtcJoined = true;
      await _setRtcMuted(true);
    } catch (_) {}
  }

  String? _pendingGiftToken;

  Future<void> _showVoiceGiftSheet() async {
    final roomId = _roomId;
    if (roomId == null || roomId.isEmpty) {
      _showRoomNotice('频道资料暂不可用');
      return;
    }
    _pendingGiftToken = await _authToken();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VoiceGiftSheet(
        room: widget.roomData,
        roomId: roomId,
        service: messageService,
        token: _pendingGiftToken!,
      ),
    );
    _pendingGiftToken = null;
  }

  Future<void> _shareRoom() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VoiceRoomShareSheet(
        room: widget.roomData,
        onDirectChat: _openOwnerChat,
        onFollow: _followOwner,
        onGift: _showGiftUnavailable,
        onReport: _showReportUnavailable,
      ),
    );
  }

  int? get _ownerId {
    final ownerId = widget.roomData['owner_user_id'] ??
        widget.roomData['ownerUserId'] ??
        widget.roomData['owner_id'];
    return int.tryParse('$ownerId');
  }

  String get _ownerName =>
      widget.roomData['owner_nickname']?.toString() ??
      widget.roomData['ownerNickname']?.toString() ??
      widget.roomData['nickname']?.toString() ??
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
    _showVoiceGiftSheet();
  }

  void _showReportUnavailable() {
    Navigator.pop(context);
    _showRoomNotice('举报语音房（频道）暂未接入');
  }

  void _showRoomNotice(String message) {
    if (!mounted) return;
    _showTopNotice(context, Text(message.replaceFirst('Exception: ', '')));
  }

  Future<void> _exitRoom() async {
    if (_leaving) return;
    _leaving = true;
    _seatRefreshTimer?.cancel();
    _VoiceRoomFloatingOverlay.remove();
    try {
      await messageService
          .leaveVoiceRoom(await _authToken(), _roomId ?? '')
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      if (mounted) {
        _leaving = false;
        _showRoomNotice('退出频道失败，请重试');
        return;
      }
    }
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
    _seatRefreshTimer?.cancel();
    _imEvents?.cancel();
    messageService.dispose();
    _messageController.dispose();
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
            toolbarHeight: 56,
            centerTitle: true,
            backgroundColor: const Color(0xff24152f),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: Colors.white,
            title: Text(widget.roomTitle,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actionsPadding: const EdgeInsets.only(right: 8),
            actions: [
              IconButton(
                constraints:
                    const BoxConstraints.tightFor(width: 40, height: 40),
                padding: EdgeInsets.zero,
                tooltip: '分享',
                onPressed: _shareRoom,
                icon: const Icon(TIcons.share_1, size: 21),
              ),
              IconButton(
                constraints:
                    const BoxConstraints.tightFor(width: 40, height: 40),
                padding: EdgeInsets.zero,
                tooltip: '关闭',
                onPressed: _confirmExit,
                icon: const Icon(Icons.close, size: 22),
              ),
            ],
          ),
          body: Stack(children: [
            Positioned.fill(
                child: DecoratedBox(
                    decoration: const BoxDecoration(
                        gradient: RadialGradient(
                            center: Alignment.topRight,
                            radius: 1.4,
                            colors: [Color(0xff673a8c), Color(0xff1a1224)])))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: _VoiceRoomSeats(
                        room: widget.roomData,
                        state: seatState,
                        onAction: _seatAction),
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
                            child: _VoiceRoomMessages(messages: _roomMessages)),
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
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendRoomMessage(),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '说点什么…',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                        tooltip: '发送',
                        onPressed: _sendRoomMessage,
                        icon: const Icon(Icons.send, color: Colors.white)),
                    IconButton(
                        tooltip: muted ? '开启语音输入' : '关闭语音输入',
                        onPressed: () async {
                          final next = !muted;
                          if (!_seatOn) {
                            _showRoomNotice('房主批准上麦后才能开启麦克风');
                            return;
                          }
                          await _setRtcMuted(next);
                        },
                        icon: Icon(muted ? Icons.mic_off : TIcons.microphone_1,
                            color: Colors.white)),
                    IconButton(
                        tooltip: '送礼',
                        onPressed: _showVoiceGiftSheet,
                        icon: const Icon(TIcons.gift, color: Colors.white)),
                  ]))),
        ),
      );
}
