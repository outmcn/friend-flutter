part of 'main.dart';

class _ContactsPage extends StatelessWidget {
  const _ContactsPage({
    required this.conversations,
    required this.avatarFor,
    required this.onOpen,
  });

  final List<_ChatPreview> conversations;
  final ImageProvider Function(_ChatPreview) avatarFor;
  final Future<void> Function(_ChatPreview) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('通讯录'),
          actions: [
            IconButton(
              tooltip: '搜索',
              onPressed: () {},
              icon: _tdIcon('search'),
            ),
            IconButton(
              tooltip: '添加联系人',
              onPressed: () {},
              icon: _tdIcon('user-add'),
            ),
          ],
        ),
        body: conversations.isEmpty
            ? const Center(child: Text('暂无联系人'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final contact = conversations[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundImage: avatarFor(contact)),
                    title: Text(contact.name),
                    onTap: () => onOpen(contact),
                  );
                },
              ),
      );
}
