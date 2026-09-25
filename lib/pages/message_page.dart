import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/matrix_session.dart';
import 'contacts_page.dart';
import 'matrix_rooms_page.dart';
import '../widgets/post_card.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({
    super.key,
    required this.token,
    required this.sessionLoader,
    this.cachedSummaries = const [],
    this.sessionError,
  });

  final String token;
  final Future<MatrixSession?> Function() sessionLoader;
  final List<MatrixRoomSummary> cachedSummaries;
  final String? sessionError;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  MatrixSession? session;
  String? error;
  int? retryAfter;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void didUpdateWidget(covariant MessagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionError != oldWidget.sessionError &&
        widget.sessionError != null) {
      setState(() {
        error = widget.sessionError;
        loading = false;
      });
    }
  }

  Future<void> _loadSession() async {
    try {
      final value = await widget.sessionLoader();
      if (!mounted) return;
      setState(() {
        session = value;
        error = widget.sessionError;
        retryAfter = null;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          retryAfter = e is ApiException ? e.retryAfter : null;
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

  Widget _cachedSummaryBody(BuildContext context) {
    if (widget.cachedSummaries.isEmpty) {
      return const Center(child: Text('正在恢复消息缓存…'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: widget.cachedSummaries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final item = widget.cachedSummaries[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: avatarColors[item.avatarId.clamp(0, 9)],
            child: Icon(
              avatarIcons[item.avatarId.clamp(0, 9)],
              color: Colors.white,
            ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = session;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: const Text('消息'),
        actions: [
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
      body: SafeArea(
        top: false,
        child: current == null && loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!),
                    if (retryAfter != null) ...[
                      const SizedBox(height: 6),
                      Text('建议等待约 $retryAfter 秒后再重试'),
                    ],
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
            ? _cachedSummaryBody(context)
            : MatrixRoomsPage(
                session: current,
                token: widget.token,
                embedded: true,
              ),
      ),
    );
  }
}
