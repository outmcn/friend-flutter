import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/matrix_session.dart';
import '../widgets/post_card.dart';
import 'matrix_chat_page.dart';

class ContactsPage extends StatefulWidget {
  final String token;
  final List<Map<String, dynamic>> initialUsers;
  final Future<List<Map<String, dynamic>>> Function(String query)? onLoadUsers;
  const ContactsPage({
    super.key,
    required this.token,
    this.initialUsers = const [],
    this.onLoadUsers,
  });

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final ApiClient api = ApiClient(token: widget.token);
  final search = TextEditingController();
  late List<Map<String, dynamic>> users = [...widget.initialUsers];
  bool loading = false;
  bool opening = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (users.isEmpty)
      _load();
    else
      unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final query = search.text.trim();
      final path = query.isEmpty
          ? '/api/users'
          : Uri(path: '/api/users', queryParameters: {'q': query}).toString();
      final loaded = widget.onLoadUsers != null
          ? await widget.onLoadUsers!(query)
          : await _requestUsers(path);
      if (mounted) {
        setState(() {
          users = loaded;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _requestUsers(String path) async {
    final response = await api.get(path);
    final data = response['data'];
    if (data is! List) throw const ApiException('用户数据格式无效', 200);
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _openBlacklist() async {
    try {
      final response = await api.get('/api/users?relation=blocked');
      final data = response['data'];
      final blocked = data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: blocked.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text('黑名单为空')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: blocked.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final user = blocked[index];
                    return ListTile(
                      leading: _avatar(user),
                      title: Text(_displayName(user)),
                      trailing: TextButton(
                        onPressed: () async {
                          await api.post('/api/users/${user['id']}/unblock');
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text('解除'),
                      ),
                    );
                  },
                ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _displayName(Map<String, dynamic> user) {
    final nickname = user['nickname']?.toString().trim();
    return nickname?.isNotEmpty == true
        ? nickname!
        : user['username']?.toString() ?? '未知用户';
  }

  Widget _avatar(Map<String, dynamic> user) {
    final id = ((user['avatarId'] as num?)?.toInt() ?? 0).clamp(0, 9);
    return CircleAvatar(
      backgroundColor: avatarColors[id],
      child: Icon(avatarIcons[id], color: Colors.white),
    );
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final matrixResponse = await api.getMatrixSession();
      final bridge = Map<String, dynamic>.from(matrixResponse['data'] as Map);
      final session = await MatrixSession.fromBridgeJson(bridge);
      await session.waitUntilReady();
      await session.joinInvitedRooms();
      final targetId = user['id'];
      if (targetId == null) throw const ApiException('用户 ID 无效', 200);
      final matrixUserId = '@friend_$targetId:matrix.friend.outmcn.net';
      var room = session.directRoomForUser(matrixUserId);
      final roomId = room?.id ?? await session.startDirectChat(matrixUserId);
      room ??= session.roomById(roomId);
      if (room == null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        room = session.roomById(roomId);
      }
      if (!mounted || room == null) {
        if (mounted && room == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Matrix 私聊房间正在同步，请稍后重试')),
          );
        }
        session.dispose();
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MatrixChatPage(
            session: session,
            room: room!,
            token: widget.token,
          ),
        ),
      );
      // MatrixSession is owned by this route and is disposed after chat returns.
      session.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          TextButton.icon(
            onPressed: _openBlacklist,
            icon: const Icon(Icons.block_outlined),
            label: const Text('黑名单'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(
                hintText: '搜索用户',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text(error!))
                : users.isEmpty
                ? const Center(child: Text('暂无用户'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final user = users[index];
                      return Card(
                        child: ListTile(
                          leading: _avatar(user),
                          title: Text(_displayName(user)),
                          trailing: const Icon(Icons.chat_outlined),
                          onTap: () => _openChat(user),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}
