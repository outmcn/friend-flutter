import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/matrix_session.dart';
import 'matrix_chat_page.dart';

class ContactsPage extends StatefulWidget {
  final String token;
  const ContactsPage({super.key, required this.token});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final ApiClient api = ApiClient(token: widget.token);
  final search = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  bool opening = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
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
      final response = await api.get(path);
      final data = response['data'];
      if (data is! List) throw const ApiException('用户数据格式无效', 200);
      if (mounted) {
        setState(() {
          users = data.whereType<Map<String, dynamic>>().toList();
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

  Future<void> _openChat(Map<String, dynamic> user) async {
    if (opening) return;
    setState(() => opening = true);
    MatrixSession? session;
    try {
      final matrixResponse = await api.getMatrixSession();
      final bridge = Map<String, dynamic>.from(matrixResponse['data'] as Map);
      session = await MatrixSession.fromBridgeJson(bridge);
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
        session.dispose();
        if (mounted && room == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Matrix 私聊房间创建成功但暂未同步，请稍后重试')),
          );
        }
        return;
      }
      final activeSession = session;
      final activeRoom = room;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MatrixChatPage(
            session: activeSession,
            room: activeRoom,
            token: widget.token,
          ),
        ),
      );
      session.dispose();
    } catch (e) {
      session?.dispose();
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: '搜索',
            icon: const Icon(Icons.search),
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
                      final nickname = user['nickname']?.toString().trim();
                      final name = nickname?.isNotEmpty == true
                          ? nickname!
                          : user['username']?.toString() ?? '';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primary,
                            child: Icon(Icons.person, color: colors.onPrimary),
                          ),
                          title: Text(name),
                          subtitle: null,
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
