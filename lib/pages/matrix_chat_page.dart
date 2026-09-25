import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter/services.dart';
import '../pages/other_profile_page.dart';
import '../services/api_client.dart';
import '../services/matrix_session.dart';
import '../widgets/post_card.dart';

class MatrixChatPage extends StatefulWidget {
  const MatrixChatPage({
    super.key,
    required this.session,
    required this.room,
    required this.token,
  });

  final MatrixSession session;
  final Room room;
  final String token;

  @override
  State<MatrixChatPage> createState() => _MatrixChatPageState();
}

class _MatrixChatPageState extends State<MatrixChatPage> {
  StreamSubscription<void>? _updates;
  Timeline? timeline;
  final composer = TextEditingController();
  final scrollController = ScrollController();

  String? error;
  bool loading = true;
  bool sending = false;
  String? sendError;
  String? failedText;
  Event? failedReplyTo;
  bool loadingHistory = false;
  String? roomTitle;
  Event? replyingTo;
  final Map<String, String> replyLabels = {};
  Map<String, dynamic>? peerProfile;
  Map<String, dynamic>? ownProfile;
  bool followLoading = false;
  final Map<String, Future<Widget>> _messageContentFutures = {};
  Timer? _draftTimer;
  bool _draftLoaded = false;

  @override
  void initState() {
    super.initState();
    _updates = widget.session.updates.listen((_) {
      if (mounted) setState(() {});
    });
    composer.addListener(_scheduleDraftSave);
    _loadPeerProfile();
    _loadRoomTitle();
    _loadDraft();
    _loadTimeline();
  }

  Future<void> _loadDraft() async {
    if (_draftLoaded) return;
    _draftLoaded = true;
    final draft = await widget.session.loadRoomDraft(widget.room.id);
    if (!mounted || draft == null || composer.text.isNotEmpty) return;
    composer.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  void _scheduleDraftSave() {
    if (!_draftLoaded) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), () {
      widget.session.saveRoomDraft(widget.room.id, composer.text);
    });
  }

  Future<void> _loadRoomTitle() async {
    try {
      await widget.room.loadHeroUsers();
      final title = MatrixSession.sanitizeDisplayName(
        widget.room.getLocalizedDisplayname(),
      );
      if (mounted) setState(() => roomTitle = title);
    } catch (_) {}
  }

  int? get _peerFriendId {
    final peer = widget.room.directChatMatrixID;
    if (peer == null) return null;
    return int.tryParse(peer.split(':').first.replaceFirst('@friend_', ''));
  }

  Future<void> _loadPeerProfile() async {
    final id = _peerFriendId;
    if (id == null || widget.token.isEmpty) return;
    try {
      final cachedPeer = widget.session.cachedFriendProfile(id);
      final cachedOwn = widget.session.cachedOwnProfile;
      if (mounted && (cachedPeer != null || cachedOwn != null)) {
        setState(() {
          if (cachedPeer != null) peerProfile = cachedPeer;
          if (cachedOwn != null) ownProfile = cachedOwn;
        });
      }
      final profile =
          cachedPeer ??
          await widget.session.loadFriendProfile(
            token: widget.token,
            friendId: id,
          );
      var own = cachedOwn;
      if (own == null) {
        final response = await ApiClient(token: widget.token).get('/api/me');
        own = Map<String, dynamic>.from(response['data'] as Map);
        widget.session.cacheOwnProfile(own);
      }
      if (mounted && profile != null) {
        setState(() {
          peerProfile = profile;
          ownProfile = own;
        });
      }
    } catch (_) {}
  }

  Future<void> _openPeerProfile() async {
    final id = _peerFriendId;
    if (id == null || widget.token.isEmpty || !mounted) return;
    try {
      final response = await ApiClient(
        token: widget.token,
      ).get('/api/users/$id');
      final data = Map<String, dynamic>.from(response['data'] as Map);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => OtherProfilePage(
            data: data,
            dataToken: widget.token,
            isSelf: false,
          ),
        ),
      );
      await _loadPeerProfile();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('搜索聊天记录'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
          decoration: const InputDecoration(hintText: '输入关键词'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || query == null || query.isEmpty) return;
    try {
      final results = await widget.session.searchRoomEvents(widget.room, query);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text('没有找到匹配消息')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) => ListTile(
                    title: Text(
                      results[index].messageType == MessageTypes.Image
                          ? '[图片]'
                          : results[index].body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_timeLabel(results[index].originServerTs)),
                  ),
                ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _toggleFollow() async {
    final id = _peerFriendId;
    if (id == null || followLoading || widget.token.isEmpty) return;
    setState(() => followLoading = true);
    try {
      final response = await ApiClient(
        token: widget.token,
      ).post('/api/users/$id/follow');
      if (mounted && peerProfile != null) {
        setState(
          () => peerProfile = {
            ...peerProfile!,
            'following': response['data']['following'] == true,
          },
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => followLoading = false);
    }
  }

  Widget _avatarFor(Event event) {
    final mine = event.senderId == widget.session.client.userID;
    final rawProfile = mine
        ? (ownProfile ?? widget.session.cachedOwnProfile)
        : (peerProfile ??
              widget.session.cachedFriendProfile(_peerFriendId ?? -1));
    final id = ((rawProfile?['avatarId'] as num?)?.toInt() ?? 0).clamp(0, 9);
    return CircleAvatar(
      radius: 18,
      backgroundColor: avatarColors[id],
      child: Icon(avatarIcons[id], size: 20, color: Colors.white),
    );
  }

  Future<void> _loadTimeline() async {
    try {
      final loaded = await widget.session.loadRoomTimeline(
        widget.room,
        limit: 60,
        onUpdate: () {
          if (mounted) setState(() {});
        },
      );
      _primeReplyLabels(loaded);
      if (mounted) {
        setState(() {
          timeline = loaded;
          loading = false;
        });
      }
      await _markRoomRead();
      await _loadReplyLabels();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final current = timeline;
    if (current == null || loadingHistory || !current.canRequestHistory) return;
    setState(() => loadingHistory = true);
    try {
      await current.requestHistory(historyCount: 60);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loadingHistory = false);
    }
  }

  Future<void> _markRoomRead() async {
    final latest = timeline?.events
        .where((event) => event.type == EventTypes.Message)
        .lastOrNull;
    if (latest == null) return;
    try {
      await widget.session.clearRoomUnread(widget.room);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadReplyLabels() async {
    final pending = messageEvents
        .where(
          (event) =>
              event.inReplyToEventId() != null &&
              !replyLabels.containsKey(event.eventId),
        )
        .toList();
    final labels = await Future.wait(
      pending.map(
        (event) async => MapEntry(event.eventId, await _replyLabel(event)),
      ),
    );
    replyLabels.addEntries(labels);
    if (mounted) setState(() {});
  }

  void _primeReplyLabels(Timeline loaded) {
    final eventsById = <String, Event>{
      for (final event in loaded.events) event.eventId: event,
    };
    for (final event in loaded.events) {
      final replyId = event.inReplyToEventId();
      if (replyId == null || replyLabels.containsKey(event.eventId)) continue;
      final original = eventsById[replyId];
      if (original == null) {
        replyLabels[event.eventId] = _fallbackReplyText(event);
        continue;
      }
      final name = original.senderFromMemoryOrFallback.displayName?.trim();
      final sender = name?.isNotEmpty == true ? name! : '对方';
      replyLabels[event.eventId] = '$sender: ${_plainEventBody(original)}';
    }
  }

  String _plainEventBody(Event event) {
    final lines = event.body.split('\n');
    final index = lines.lastIndexWhere(
      (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
    );
    return index >= 0 ? lines[index].trim() : event.body;
  }

  void _setImmediateReplyLabel(Event event, String text) {
    final id = event.inReplyToEventId();
    if (id == null) return;
    final lines = event.body.split('\n');
    final contentIndex = lines.lastIndexWhere(
      (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
    );
    final content = contentIndex >= 0 ? lines[contentIndex].trim() : text;
    replyLabels[event.eventId] = '对方: $content';
  }

  Future<void> _send() async {
    final text = composer.text.trim();
    if (text.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
      sendError = null;
    });
    try {
      final sentEventId = replyingTo == null
          ? null
          : await widget.session.sendReply(widget.room, replyingTo!, text);
      if (replyingTo == null) {
        await widget.session.sendText(widget.room, text);
      }
      if (sentEventId != null && sentEventId.isNotEmpty) {
        final event = timeline?.events
            .where((item) => item.eventId == sentEventId)
            .firstOrNull;
        if (event != null) _setImmediateReplyLabel(event, text);
      }
      final latestReply = timeline?.events
          .where(
            (event) =>
                event.senderId == widget.session.client.userID &&
                event.inReplyToEventId() == replyingTo?.eventId,
          )
          .lastOrNull;
      if (latestReply != null) _setImmediateReplyLabel(latestReply, text);
      if (mounted) {
        setState(() {
          sendError = null;
          failedText = null;
          failedReplyTo = null;
          error = null;
        });
      }
      composer.clear();
      await widget.session.clearRoomDraft(widget.room.id);
      if (mounted) setState(() => replyingTo = null);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          sendError = e.toString();
          failedText = text;
          failedReplyTo = replyingTo;
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _retryFailedMessage() async {
    final text = failedText;
    if (text == null || sending) return;
    setState(() {
      composer.text = text;
      composer.selection = TextSelection.collapsed(offset: text.length);
      replyingTo = failedReplyTo;
      sendError = null;
    });
    await _send();
  }

  Future<void> _pickAndSendImage() async {
    if (sending) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final bytes = Uint8List.fromList(await image.readAsBytes());
      await widget.session.sendImage(
        widget.room,
        bytes: bytes,
        name: image.name,
        mimeType: 'image/${image.name.split('.').last}',
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _showMessageActions(Event event) async {
    final mine = event.senderId == widget.session.client.userID;
    final canRedact =
        mine && DateTime.now().difference(event.originServerTs).inSeconds <= 60;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('回复'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),

            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),

            if (canRedact)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('撤回'),
                onTap: () => Navigator.pop(context, 'redact'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('举报'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'reply') {
        setState(() => replyingTo = event);
      } else if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: _messageBody(event)));
      } else if (action == 'report') {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('举报消息'),
              content: const Text('举报功能暂未连接后端'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
      } else if (action == 'redact') {
        await widget.session.redactMessage(widget.room, event);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  List<Event> get messageEvents =>
      timeline?.events
          .where((event) => event.type == EventTypes.Message)
          .toList() ??
      const [];

  Event _displayEvent(Event event) =>
      timeline == null ? event : event.getDisplayEvent(timeline!);

  String _messageBody(Event event) {
    if (event.redacted) return '已撤回一条消息';
    final replyId = event.inReplyToEventId();
    if (replyId != null) {
      final fallback = event.body;
      final lines = fallback.split('\n');
      final contentIndex = lines.lastIndexWhere(
        (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
      );
      if (contentIndex >= 0) return lines[contentIndex].trim();
    }
    return event.body == 'Redacted' ? '已撤回一条消息' : event.body;
  }

  String _fallbackReplyText(Event event) {
    final id = event.inReplyToEventId();
    if (id == null) return '';
    final lines = event.body.split('\n');
    final contentIndex = lines.lastIndexWhere(
      (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
    );
    return contentIndex >= 0 ? lines[contentIndex].trim() : '';
  }

  bool _isRedaction(Event event) => event.redacted || event.body == 'Redacted';

  Future<Widget> _messageContent(Event event, ColorScheme colors) async {
    if (event.messageType == MessageTypes.Image) {
      if (!event.hasAttachment) return const Text('[图片加载失败]');
      return _imageWidget(event);
    }
    if (event.messageType != MessageTypes.Image || !event.hasAttachment) {
      return Text(_messageBody(event));
    }
    return Text(_messageBody(event));
  }

  Future<Widget> _cachedMessageContent(Event event, ColorScheme colors) {
    return _messageContentFutures.putIfAbsent(
      event.eventId,
      () => _messageContent(event, colors),
    );
  }

  Future<Widget> _imageWidget(Event event) async {
    try {
      final bytes = await widget.session.loadAttachmentBytes(event);
      return GestureDetector(
        onTap: () => _showFullImageBytes(bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Text('[图片加载失败]'),
          ),
        ),
      );
    } catch (_) {
      return const Text('[图片加载失败]');
    }
  }

  void _showFullImageBytes(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
    );
  }

  Widget _messageLoading(Event event, ColorScheme colors) {
    if (event.messageType == MessageTypes.Image) {
      return const SizedBox(
        width: 220,
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Text(_messageBody(event));
  }

  Future<String> _replyLabel(Event event) async {
    final id = event.inReplyToEventId();
    if (id == null) return event.body;
    final original = await widget.room.getEventById(id);
    if (original == null) return event.body;
    final sender = await original.fetchSenderUser();
    final name = sender?.displayName?.trim();
    return '${name?.isNotEmpty == true ? name : '对方'}: ${original.body}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final events = messageEvents;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openPeerProfile,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              roomTitle ??
                  MatrixSession.sanitizeDisplayName(
                    widget.room.getLocalizedDisplayname(),
                  ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openSearch,
            tooltip: '搜索聊天记录',
            icon: const Icon(Icons.search),
          ),
          if (peerProfile != null)
            TextButton(
              onPressed: followLoading ? null : _toggleFollow,
              child: Text(peerProfile!['following'] == true ? '已关注' : '关注'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: const Text('关闭'),
                ),
              ],
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : events.isEmpty
                ? Center(
                    child: Text(
                      '暂无消息',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 80) {
                        unawaited(_loadOlderMessages());
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final displayed = _displayEvent(event);
                        final mine =
                            event.senderId == widget.session.client.userID;
                        if (_isRedaction(displayed)) {
                          final redactedByMe =
                              event.senderId == widget.session.client.userID;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                redactedByMe
                                    ? '—— 你已撤回一条消息 ——'
                                    : '—— 对方已撤回一条消息 ——',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }
                        return GestureDetector(
                          onLongPress: () => _showMessageActions(event),
                          child: Row(
                            mainAxisAlignment: mine
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!mine) _avatarFor(event),
                              const SizedBox(width: 6),
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? colors.primaryContainer
                                      : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (event.inReplyToEventId() != null)
                                      Text(
                                        '回复：${replyLabels[event.eventId] ?? _fallbackReplyText(event)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    FutureBuilder<Widget>(
                                      future: _cachedMessageContent(
                                        displayed,
                                        colors,
                                      ),
                                      builder: (context, snapshot) =>
                                          snapshot.hasData
                                          ? snapshot.data!
                                          : _messageLoading(displayed, colors),
                                    ),
                                  ],
                                ),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 6),
                                _avatarFor(event),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (replyingTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 2),
              color: colors.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '回复：${replyingTo!.body}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => replyingTo = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          if (sendError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sendError!,
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _retryFailedMessage,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: sending ? null : _pickAndSendImage,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: '发送图片',
                  ),
                  Expanded(
                    child: TextField(
                      controller: composer,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: '输入消息',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    composer.removeListener(_scheduleDraftSave);
    if (composer.text.trim().isNotEmpty) {
      widget.session.saveRoomDraft(widget.room.id, composer.text);
    }
    _updates?.cancel();
    composer.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
