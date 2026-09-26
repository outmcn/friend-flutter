import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/matrix_session.dart';
import '../widgets/post_card.dart';
import 'matrix_chat_page.dart';

class GreetingMessagesPage extends StatefulWidget {
  const GreetingMessagesPage({
    super.key,
    required this.session,
    required this.token,
  });

  final MatrixSession session;
  final String token;

  @override
  State<GreetingMessagesPage> createState() => _GreetingMessagesPageState();
}

class _GreetingMessagesPageState extends State<GreetingMessagesPage> {
  bool loading = true;
  List<MatrixRoomSummary> greetings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = <MatrixRoomSummary>[];
    for (final summary in widget.session.cachedRoomSummaries) {
      final room = widget.session.client.getRoomById(summary.roomId);
      final peer = room?.directChatMatrixID;
      final id = peer == null
          ? null
          : int.tryParse(peer.split(':').first.replaceFirst('@friend_', ''));
      if (id == null) continue;
      try {
        final response = await ApiClient(
          token: widget.token,
        ).get('/api/users/$id');
        final data = Map<String, dynamic>.from(response['data'] as Map);
        if (data['following'] != true || data['followedBy'] != true) {
          result.add(summary);
        }
      } catch (_) {}
    }
    if (mounted)
      setState(() {
        greetings = result;
        loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('打招呼信息')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : greetings.isEmpty
          ? const Center(child: Text('暂无打招呼信息'))
          : ListView.separated(
              itemCount: greetings.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
              itemBuilder: (_, index) {
                final item = greetings[index];
                final avatar = item.avatarId.clamp(0, 9);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: avatarColors[avatar],
                    child: Icon(avatarIcons[avatar], color: Colors.white),
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    item.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: item.unreadCount > 0
                      ? Badge(label: Text('${item.unreadCount}'))
                      : null,
                  onTap: () {
                    final room = widget.session.client.getRoomById(item.roomId);
                    if (room == null) return;
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatrixChatPage(
                          session: widget.session,
                          room: room,
                          token: widget.token,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
