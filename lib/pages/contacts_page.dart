import 'package:flutter/material.dart';
import 'user_list_page.dart';

class ContactsPage extends StatelessWidget {
  final String token;
  const ContactsPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserListPage(
                  token: token,
                  title: '搜索用户',
                  searchable: true,
                  embedded: false,
                ),
              ),
            ),
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '添加联系人',
          ),
        ],
      ),
      body: UserListPage(
        token: token,
        title: '通讯录',
        searchable: false,
        embedded: true,
      ),
    );
  }
}
