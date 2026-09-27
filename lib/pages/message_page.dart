import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'other_profile_page.dart';

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
      radius: 24,
      backgroundColor: _avatarColor(user),
      child: Text(
        _name(user).characters.first,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openProfile(Map<String, dynamic> user) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OtherProfilePage(data: user, dataToken: widget.token),
      ),
    );
  }

  Widget _header(ColorScheme colors) {
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: true,
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '消息',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadUsers,
                  tooltip: '刷新',
                  icon: const Icon(Icons.refresh),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
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
              const _StateMessage(message: '聊天服务尚未接入')
            else
              ..._users.map((user) => _conversationRow(user, colors)),
          ],
        ),
      ),
    );
  }

  Widget _conversationRow(Map<String, dynamic> user, ColorScheme colors) {
    return InkWell(
      onTap: () => _openProfile(user),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            _avatar(user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    '聊天服务暂未接入',
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
    final colors = Theme.of(context).colorScheme;
    return Column(children: [_header(colors), _body(colors)]);
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
