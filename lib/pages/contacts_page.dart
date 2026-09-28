import 'package:flutter/material.dart';
import 'message_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    required this.token,
    this.initialUsers = const [],
    required this.onLoadUsers,
  });
  final String token;
  final List<Map<String, dynamic>> initialUsers;
  final Future<List<Map<String, dynamic>>> Function(String query) onLoadUsers;
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final TextEditingController search;
  List<Map<String, dynamic>> users = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    search = TextEditingController();
    users = widget.initialUsers;
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      users = await widget.onLoadUsers(search.text.trim());
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  String _name(Map<String, dynamic> user) =>
      (user['nickname']?.toString().trim().isNotEmpty == true)
      ? user['nickname'].toString()
      : (user['username']?.toString() ?? '用户');
  Widget _avatar(Map<String, dynamic> user) =>
      CircleAvatar(child: Text(_name(user).characters.first));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 40,
      title: const Text('通讯录'),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.block_outlined)),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: search,
            onSubmitted: (_) => _load(),
            decoration: const InputDecoration(
              hintText: '搜索用户',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text(error!))
              : ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final user = users[index];
                    return ListTile(
                      leading: _avatar(user),
                      title: Text(_name(user)),
                      trailing: const Icon(Icons.chat_outlined),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MessagePage(token: widget.token),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
