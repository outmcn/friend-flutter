import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as fc;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart' as mx;

import '../services/matrix_session.dart';

class MatrixChatPage extends StatefulWidget {
  const MatrixChatPage({
    super.key,
    required this.session,
    required this.room,
    required this.token,
  });

  final MatrixSession session;
  final mx.Room room;
  final String token;

  @override
  State<MatrixChatPage> createState() => _MatrixChatPageState();
}

class _MatrixChatPageState extends State<MatrixChatPage> {
  final ImagePicker _imagePicker = ImagePicker();
  late final fc.InMemoryChatController _chatController;
  StreamSubscription<void>? _updates;
  mx.Timeline? _timeline;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _roomTitle;
  final Map<String, mx.Event> _eventsById = {};

  String get _myUserId => widget.session.client.userID ?? '';

  @override
  void initState() {
    super.initState();
    _chatController = fc.InMemoryChatController();
    unawaited(widget.session.restoreRoomChat(widget.room.id));
    _updates = widget.session.updates.listen((_) {
      unawaited(_refreshMessages());
    });
    unawaited(_loadRoomTitle());
    unawaited(_loadTimeline());
  }

  Future<void> _loadRoomTitle() async {
    try {
      await widget.room.loadHeroUsers();
      if (mounted) {
        setState(() {
          _roomTitle = MatrixSession.sanitizeDisplayName(
            widget.room.getLocalizedDisplayname(),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTimeline() async {
    try {
      _timeline = await widget.session.loadRoomTimeline(
        widget.room,
        limit: 60,
        onUpdate: () => unawaited(_refreshMessages()),
      );
      await _refreshMessages();
      await widget.session.clearRoomUnread(widget.room);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshMessages() async {
    final timeline = _timeline;
    if (timeline == null) return;
    final messages = <fc.Message>[];
    _eventsById.clear();
    for (final event in timeline.events) {
      if (event.type != mx.EventTypes.Message || event.redacted) continue;
      _eventsById[event.eventId] = event;
      messages.add(_toFlyerMessage(event));
    }
    messages.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    await _chatController.setMessages(messages);
    if (mounted) setState(() {});
  }

  fc.Message _toFlyerMessage(mx.Event event) {
    final replyId = event.inReplyToEventId();
    final body = _plainBody(event);
    final metadata = <String, dynamic>{
      'matrixEventId': event.eventId,
      'matrixMessageType': event.messageType,
    };
    if (event.messageType == mx.MessageTypes.Image) {
      metadata['image'] = true;
    }
    return fc.Message.text(
      id: event.eventId,
      authorId: event.senderId,
      replyToMessageId: replyId,
      createdAt: event.originServerTs,
      sentAt: event.originServerTs,
      seenAt: event.senderId == _myUserId ? event.originServerTs : null,
      metadata: metadata,
      text: event.messageType == mx.MessageTypes.Image ? '[图片]' : body,
    );
  }

  String _plainBody(mx.Event event) {
    final lines = event.body.split('\n');
    final index = lines.lastIndexWhere(
      (line) => line.trim().isNotEmpty && !line.trim().startsWith('>'),
    );
    return index >= 0 ? lines[index].trim() : event.body.trim();
  }

  Future<fc.User> _resolveUser(fc.UserID id) async {
    if (id == _myUserId) {
      return fc.User(id: id, name: '我');
    }
    return fc.User(id: id, name: _roomTitle ?? '对方');
  }

  Future<void> _sendText(String text) async {
    final value = text.trim();
    if (value.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.session.sendText(widget.room, value);
      await _refreshMessages();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    if (_sending) return;
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final bytes = await image.readAsBytes();
      await widget.session.sendImage(
        widget.room,
        bytes: Uint8List.fromList(bytes),
        name: image.name,
        mimeType: 'image/${image.name.split('.').last}',
      );
      await _refreshMessages();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showMessageActions(
    BuildContext context,
    fc.Message message, {
    required int index,
    required LongPressStartDetails details,
  }) async {
    final eventId = message.metadata?['matrixEventId'] as String?;
    final mx.Event? event = eventId == null ? null : _eventsById[eventId];
    if (event == null) return;
    final mine = event.senderId == _myUserId;
    final canRedact =
        mine && DateTime.now().difference(event.originServerTs).inSeconds <= 60;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
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
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: _plainBody(event)));
      } else if (action == 'redact') {
        await widget.session.redactMessage(widget.room, event);
        await _refreshMessages();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_roomTitle ?? '聊天'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '已关注',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('关闭'),
                ),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Chat(
                    currentUserId: _myUserId,
                    resolveUser: _resolveUser,
                    chatController: _chatController,
                    onMessageSend: _sendText,
                    onAttachmentTap: _pickImage,
                    onMessageLongPress: _showMessageActions,
                  ),
          ),
        ],
      ),
    );
  }
}
