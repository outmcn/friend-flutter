part of 'main.dart';

class _HistoryRecordsPage extends _UserRelationListPage {
  const _HistoryRecordsPage() : super(relation: 'history', title: '历史访客');
}

class _UserRelationListPage extends StatefulWidget {
  const _UserRelationListPage({required this.relation, required this.title});
  final String relation;
  final String title;

  @override
  State<_UserRelationListPage> createState() => _UserRelationListPageState();
}

class _UserRelationListPageState extends State<_UserRelationListPage> {
  final DDPostService service = DDPostService();
  List<Map<String, dynamic>> users = const [];
  bool loading = true;
  String? error;

  String _relationLabel(Map<String, dynamic> user) {
    final followingByViewer = user['followingByViewer'] == true;
    final followedByViewer = user['followedByViewer'] == true;
    if (followingByViewer && followedByViewer) return '好友';
    if (followingByViewer) return '已关注';
    if (followedByViewer) return '回关';
    return '关注';
  }

  Future<void> _toggleRelation(int index) async {
    final userId = _intValue(users[index]['id']);
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final followed = await service.toggleFollow(token, userId);
      if (!mounted) return;
      setState(() {
        final current = Map<String, dynamic>.from(users[index]);
        current['followingByViewer'] = followed;
        current['followedByViewer'] = current['followedByViewer'] == true;
        users[index] = current;
        error = null;
      });
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final loaded = await service.fetchUsers(token, relation: widget.relation);
      if (mounted) setState(() => users = loaded);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _PageErrorState(
                    title: '加载失败', subtitle: error!, onRetry: load)
                : RefreshIndicator(
                    onRefresh: load,
                    child: users.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(child: Text('暂无用户')),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            itemCount: users.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final userId = _intValue(user['id']);
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  onTap: userId == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OtherProfilePage(
                                                userId: userId,
                                                name:
                                                    '${user['nickname'] ?? '用户'}',
                                              ),
                                            ),
                                          ),
                                  leading: '${user['avatar'] ?? ''}'.isEmpty
                                      ? const CircleAvatar(
                                          child: Icon(Icons.person_outline))
                                      : ClipOval(
                                          child: _PermanentCachedImage(
                                            url: DDPostService.mediaUrl(
                                                '${user['avatar']}'),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                  title: Text('${user['nickname'] ?? '用户'}'),
                                  subtitle: Text(widget.relation == 'history'
                                      ? '${user['city'] ?? '未知地区'} · 访问 ${user['visitCount'] ?? 1} 次'
                                      : '${user['city'] ?? '未知地区'}'),
                                  trailing: OutlinedButton(
                                    onPressed: userId == null
                                        ? null
                                        : () => _toggleRelation(index),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ),
                                    child: Text(_relationLabel(user)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      );
}
