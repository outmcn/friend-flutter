import 'package:flutter/material.dart';
import '../models/matrix_bridge_session.dart';
import '../services/api_client.dart';
import '../services/matrix_session.dart';
import 'contacts_page.dart';
import 'matrix_rooms_page.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.token});

  final String token;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  MatrixSession? session;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final response = await ApiClient(token: widget.token).getMatrixSession();
      final bridge = MatrixBridgeSession.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
      final value = await MatrixSession.fromBridgeSession(bridge);
      if (!mounted) {
        value.dispose();
        return;
      }
      setState(() {
        session = value;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _openContacts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ContactsPage(token: widget.token)),
    );
    if (mounted) await session?.joinInvitedRooms();
  }

  Widget _topBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '消息',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _openContacts,
                tooltip: '通讯录',
                icon: const Icon(Icons.people_alt_outlined),
              ),

              IconButton(
                onPressed: null,
                tooltip: '搜索聊天记录',
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: _openContacts,
                tooltip: '添加好友',
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = session;
    return Column(
      children: [
        _topBar(context),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            error = null;
                            loading = true;
                          });
                          _loadSession();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : current == null
              ? const Center(child: Text('Matrix 会话不可用'))
              : MatrixRoomsPage(
                  session: current,
                  token: widget.token,
                  embedded: true,
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    session?.dispose();
    super.dispose();
  }
}
