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
  List<Map<String, dynamic>> _following = const [];

  @override
  void initState() {
    super.initState();
    _api = ApiClient(token: widget.token);
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _api.get('/api/users?relation=following');
      final data = response['data'];
      _following = data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : const [];
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _name(Map<String, dynamic> user) {
    final nickname = user['nickname']?.toString().trim() ?? '';
    return nickname.isNotEmpty ? nickname : 'Friend 用户';
  }

  Color _avatarColor(Map<String, dynamic> user) {
    const palette = <Color>[
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
    return palette[id];
  }

  Widget _avatar(Map<String, dynamic> user, {double radius = 24}) {
    final name = _name(user);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _avatarColor(user),
      child: Text(
        name.characters.first,
        style: const TextStyle(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: colors.surface,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
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
                      onPressed: _loadFollowing,
                      tooltip: '刷新',
                      icon: const Icon(Icons.refresh),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFollowing,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Text(
                    '聊天',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_loading && _following.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 42),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null && _following.isEmpty)
                  _StateMessage(
                    message: '加载失败，请重试',
                    action: '重试',
                    onPressed: _loadFollowing,
                  )
                else if (_following.isEmpty)
                  const _StateMessage(message: '聊天服务尚未接入')
                else
                  ..._following.map(
                    (user) => ListTile(
                      leading: _avatar(user),
                      title: Text(_name(user)),
                      subtitle: const Text('聊天服务暂未接入'),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colors.onSurfaceVariant,
                      ),
                      onTap: () => _openProfile(user),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  const _StateMessage({required this.message, this.action, this.onPressed});

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
