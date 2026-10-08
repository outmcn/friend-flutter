part of 'main.dart';

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet({required this.controller});
  final TextEditingController controller;
  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  List<Map<String, dynamic>> users = const [];
  bool loading = false;
  Future<void> search() async {
    final query = widget.controller.text.trim();
    if (query.isEmpty) return;
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('friend.auth.token') ?? '';
      final service = DDPostService();
      final result = await service.searchUsers(token, query);
      service.dispose();
      if (mounted) setState(() => users = result);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: widget.controller,
                autofocus: true,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  hintText: '搜索用户',
                  suffixIcon: IconButton(
                    onPressed: search,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (loading) const CircularProgressIndicator(),
              ...users.map((user) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title:
                        Text('${user['nickname'] ?? user['username'] ?? '用户'}'),
                    subtitle: Text('${user['city'] ?? ''}'),
                    onTap: () => Navigator.pop(context, user),
                  )),
            ],
          ),
        ),
      );
}
