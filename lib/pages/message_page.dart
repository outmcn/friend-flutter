import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../services/api_client.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.token});

  final String token;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late final ApiClient _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = const [];

  @override
  void initState() {
    super.initState();
    _api = ApiClient(token: widget.token);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _api.get('/api/users?relation=following');
      final data = response['data'];
      _users = data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : const [];
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _name(Map<String, dynamic> user) {
    final nickname = user['nickname']?.toString().trim() ?? '';
    return nickname.isEmpty ? 'Friend 用户' : nickname;
  }

  Color _avatarColor(Map<String, dynamic> user) {
    const colors = <Color>[
      Color(0xff376bd6),
      Color(0xff7c4dff),
      Color(0xffe64a75),
      Color(0xff00897b),
      Color(0xff3949ab),
      Color(0xff43a047),
      Color(0xfffb8c00),
      Color(0xff8e24aa),
      Color(0xff039be5),
      Color(0xff546e7a),
    ];
    final id = ((user['avatarId'] as num?)?.toInt() ?? 0).clamp(0, 9);
    return colors[id];
  }

  Widget _avatar(Map<String, dynamic> user) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: _avatarColor(user),
      child: Text(
        _name(user).characters.first,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> user) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FlyerChatDetailPage(
          title: _name(user),
          userId: user['id']?.toString() ?? 'friend-contact',
        ),
      ),
    );
  }

  Widget _header() {
    return AppBar(
      toolbarHeight: 40,
      automaticallyImplyLeading: false,
      title: const Text('消息'),
      actions: [
        IconButton(
          onPressed: _loadUsers,
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _body(ColorScheme colors) {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_loading && _users.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _users.isEmpty)
              _StateMessage(
                message: '加载失败，请重试',
                action: '重试',
                onPressed: _loadUsers,
              )
            else if (_users.isEmpty)
              const _StateMessage(message: '暂无聊天记录')
            else
              ..._users.map((user) => _conversationRow(user, colors)),
          ],
        ),
      ),
    );
  }

  Widget _conversationRow(Map<String, dynamic> user, ColorScheme colors) {
    return InkWell(
      onTap: () => _openChat(user),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            _avatar(user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击进入聊天',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [_header(), _body(Theme.of(context).colorScheme)]);
  }
}

class FlyerChatDetailPage extends StatefulWidget {
  const FlyerChatDetailPage({
    super.key,
    required this.title,
    required this.userId,
  });

  final String title;
  final String userId;

  @override
  State<FlyerChatDetailPage> createState() => _FlyerChatDetailPageState();
}

class _FlyerChatDetailPageState extends State<FlyerChatDetailPage> {
  late final ChatController _chatController;
  late final Map<String, User> _users;
  static const _currentUserId = 'friend-current-user';

  @override
  void initState() {
    super.initState();
    _users = {
      _currentUserId: const User(id: _currentUserId, name: '我'),
      widget.userId: User(id: widget.userId, name: widget.title),
    };
    _chatController = InMemoryChatController(
      messages: [
        Message.text(
          id: 'demo-incoming-1',
          authorId: widget.userId,
          text: '你好，欢迎使用 Friend。',
          createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
        ),
        Message.text(
          id: 'demo-outgoing-1',
          authorId: _currentUserId,
          text: '你好！这是 Flyer Chat UI 的消息页面演示。',
          createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
          sentAt: DateTime.now().subtract(const Duration(minutes: 6)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<User?> _resolveUser(String id) async {
    return _users[id] ?? User(id: id, name: 'Friend 用户');
  }

  void _sendMessage(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    final now = DateTime.now();
    _chatController.insertMessage(
      Message.text(
        id: 'local-${now.microsecondsSinceEpoch}',
        authorId: _currentUserId,
        text: value,
        createdAt: now,
        sentAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Chat(
        chatController: _chatController,
        currentUserId: _currentUserId,
        resolveUser: _resolveUser,
        onMessageSend: _sendMessage,
        backgroundColor: Theme.of(context).colorScheme.surface,
        theme: ChatTheme.fromThemeData(Theme.of(context)),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, this.action, this.onPressed});

  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 34, color: color),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onPressed, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
