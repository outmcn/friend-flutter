part of 'main.dart';

class _ContactsPage extends StatefulWidget {
  const _ContactsPage({
    required this.conversations,
    required this.avatarFor,
    required this.onOpen,
  });

  final List<_ChatPreview> conversations;
  final ImageProvider Function(_ChatPreview) avatarFor;
  final Future<void> Function(_ChatPreview) onOpen;

  @override
  State<_ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<_ContactsPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  List<_ChatPreview> get currentContacts {
    switch (tabs.index) {
      case 1:
        return widget.conversations
            .where((item) => item.updatedAt != null)
            .toList();
      case 2:
        return const [];
      default:
        return widget.conversations;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('通讯录'),
          actions: [
            IconButton(
              tooltip: '添加联系人',
              onPressed: () {},
              icon: _tdIcon('user-add'),
            ),
          ],
          bottom: TabBar(
            controller: tabs,
            tabs: const [
              Tab(text: '好友'),
              Tab(text: '最近'),
              Tab(text: '黑名单'),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: tabs,
          builder: (_, __) {
            final contacts = currentContacts;
            if (contacts.isEmpty) {
              return Center(
                child: Text(
                  tabs.index == 2 ? '暂无黑名单用户' : '暂无联系人',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final contact = contacts[index];
                return ListTile(
                  leading:
                      CircleAvatar(backgroundImage: widget.avatarFor(contact)),
                  title: Text(contact.name),
                  onTap: () => widget.onOpen(contact),
                );
              },
            );
          },
        ),
      );
}
