import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserListPage extends StatefulWidget {
  final String token;
  final String title;
  final String? relation;
  final bool searchable;
  const UserListPage({
    super.key,
    required this.token,
    required this.title,
    this.relation,
    this.searchable = false,
  });

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final query = <String, String>{};
    if (widget.relation != null) query['relation'] = widget.relation!;
    final keyword = searchController.text.trim();
    if (keyword.isNotEmpty) query['q'] = keyword;
    final uri = Uri.https('friend.outmcn.net', '/api/users', query);
    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] != true || body['data'] is! List) {
        throw Exception(body['message'] ?? '加载失败');
      }
      if (mounted) {
        setState(() {
          users = (body['data'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: '搜索用户',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.arrow_forward),
                  ),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: c.primary,
                            child: Icon(Icons.public, color: c.onPrimary),
                          ),
                          title: Text(name),
                          subtitle: Text(
                            '关注 ${user['following'] ?? 0}  粉丝 ${user['followers'] ?? 0}',
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
}
